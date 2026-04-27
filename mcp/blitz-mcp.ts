#!/usr/bin/env bun
import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";

const blitz = process.env.BLITZ_BIN ?? "blitz";
const cwd = process.env.BLITZ_WORKSPACE ?? process.cwd();

type JsonRpc = { jsonrpc?: "2.0"; id?: string | number | null; method?: string; params?: Record<string, unknown> };

type ToolResult = { content: Array<{ type: "text"; text: string }>; isError?: boolean };

const tools = [
  {
    name: "blitz_doctor",
    description: "Run blitz doctor and return supported languages/commands/cache status.",
    inputSchema: { type: "object", properties: {}, additionalProperties: false },
  },
  {
    name: "blitz_read",
    description: "Read a file with blitz AST/source summary.",
    inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false },
  },
  {
    name: "blitz_patch",
    description: "Apply compact Blitz patch tuples to one file. Ops include replace, insert_after, wrap, replace_return, try_catch.",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string" },
        ops: { type: "array", items: { type: "array", items: { anyOf: [{ type: "string" }, { type: "number" }] } }, minItems: 1 },
        dry_run: { type: "boolean" },
        include_diff: { type: "boolean" },
      },
      required: ["file", "ops"],
      additionalProperties: false,
    },
  },
  {
    name: "blitz_try_catch",
    description: "Wrap a symbol body in try/catch without repeating the body.",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string" },
        symbol: { type: "string" },
        catchBody: { type: "string" },
        indent: { type: "number" },
        dry_run: { type: "boolean" },
        include_diff: { type: "boolean" },
      },
      required: ["file", "symbol", "catchBody"],
      additionalProperties: false,
    },
  },
  {
    name: "blitz_replace_return",
    description: "Replace a return expression in a symbol body.",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string" },
        symbol: { type: "string" },
        expr: { type: "string" },
        occurrence: { anyOf: [{ type: "string" }, { type: "number" }] },
        dry_run: { type: "boolean" },
        include_diff: { type: "boolean" },
      },
      required: ["file", "symbol", "expr"],
      additionalProperties: false,
    },
  },
  {
    name: "blitz_undo",
    description: "Undo the last Blitz mutation for a file.",
    inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false },
  },
] as const;

const jsonText = (text: string, isError = false): ToolResult => ({ content: [{ type: "text", text }], ...(isError ? { isError: true } : {}) });

const run = (args: string[], stdin?: string): ToolResult => {
  const result = spawnSync(blitz, args, { cwd, input: stdin, encoding: "utf8", maxBuffer: 1024 * 1024 * 8 });
  const text = [result.stdout, result.stderr].filter(Boolean).join(result.stdout && result.stderr ? "\n" : "");
  return jsonText(text.trim(), (result.status ?? 1) !== 0);
};

const requiredString = (args: Record<string, unknown>, key: string): string => {
  const value = args[key];
  if (typeof value !== "string" || value.length === 0) throw new Error(`missing string ${key}`);
  return value;
};

const callTool = (name: string, args: Record<string, unknown> = {}): ToolResult => {
  switch (name) {
    case "blitz_doctor":
      return run(["doctor"]);
    case "blitz_read":
      return run(["read", requiredString(args, "file")]);
    case "blitz_undo":
      return run(["undo", requiredString(args, "file")]);
    case "blitz_patch": {
      const file = requiredString(args, "file");
      const ops = args.ops;
      if (!Array.isArray(ops) || ops.length === 0) throw new Error("missing ops array");
      const payload = { version: 1, file, operation: "patch", edit: { ops }, dry_run: args.dry_run, include_diff: args.include_diff };
      return run(["apply", "--edit", "-", "--json"], JSON.stringify(payload));
    }
    case "blitz_try_catch": {
      const file = requiredString(args, "file");
      const symbol = requiredString(args, "symbol");
      const catchBody = requiredString(args, "catchBody");
      const op = ["try_catch", symbol, catchBody, ...(typeof args.indent === "number" ? [args.indent] : [])];
      const payload = { version: 1, file, operation: "patch", edit: { ops: [op] }, dry_run: args.dry_run, include_diff: args.include_diff };
      return run(["apply", "--edit", "-", "--json"], JSON.stringify(payload));
    }
    case "blitz_replace_return": {
      const file = requiredString(args, "file");
      const symbol = requiredString(args, "symbol");
      const expr = requiredString(args, "expr");
      const op = ["replace_return", symbol, expr, ...(args.occurrence !== undefined ? [args.occurrence] : [])];
      const payload = { version: 1, file, operation: "patch", edit: { ops: [op] }, dry_run: args.dry_run, include_diff: args.include_diff };
      return run(["apply", "--edit", "-", "--json"], JSON.stringify(payload));
    }
    default:
      throw new Error(`unknown tool ${name}`);
  }
};

const respond = (message: Record<string, unknown>) => {
  process.stdout.write(`Content-Length: ${Buffer.byteLength(JSON.stringify(message), "utf8")}\r\n\r\n${JSON.stringify(message)}`);
};

const ok = (id: JsonRpc["id"], result: unknown) => respond({ jsonrpc: "2.0", id, result });
const err = (id: JsonRpc["id"], code: number, message: string) => respond({ jsonrpc: "2.0", id, error: { code, message } });

const handle = (msg: JsonRpc) => {
  try {
    if (msg.method === "initialize") {
      ok(msg.id, { protocolVersion: "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "blitz-mcp", version: "0.1.0" } });
      return;
    }
    if (msg.method === "notifications/initialized") return;
    if (msg.method === "tools/list") {
      ok(msg.id, { tools });
      return;
    }
    if (msg.method === "tools/call") {
      const params = msg.params ?? {};
      const name = params.name;
      const args = params.arguments;
      if (typeof name !== "string") throw new Error("tools/call missing name");
      if (args !== undefined && (typeof args !== "object" || args === null || Array.isArray(args))) throw new Error("tools/call arguments must be object");
      ok(msg.id, callTool(name, (args ?? {}) as Record<string, unknown>));
      return;
    }
    if (msg.id !== undefined) err(msg.id, -32601, `method not found: ${msg.method}`);
  } catch (error) {
    err(msg.id, -32000, error instanceof Error ? error.message : String(error));
  }
};

let buffer = Buffer.alloc(0);
const tryReadMessage = (): JsonRpc | undefined => {
  const headerEnd = buffer.indexOf("\r\n\r\n");
  if (headerEnd >= 0) {
    const header = buffer.subarray(0, headerEnd).toString("utf8");
    const match = /^Content-Length:\s*(\d+)$/im.exec(header);
    if (!match) throw new Error("missing Content-Length");
    const len = Number(match[1]);
    const start = headerEnd + 4;
    if (buffer.length < start + len) return undefined;
    const raw = buffer.subarray(start, start + len).toString("utf8");
    buffer = buffer.subarray(start + len);
    return JSON.parse(raw);
  }

  const nl = buffer.indexOf("\n");
  if (nl >= 0) {
    const raw = buffer.subarray(0, nl).toString("utf8").trim();
    buffer = buffer.subarray(nl + 1);
    if (!raw) return undefined;
    return JSON.parse(raw);
  }
  return undefined;
};

process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  while (true) {
    const msg = tryReadMessage();
    if (!msg) break;
    handle(msg);
  }
});

process.stdin.resume();
