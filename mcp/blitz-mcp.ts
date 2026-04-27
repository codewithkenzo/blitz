#!/usr/bin/env bun
import { existsSync, realpathSync } from "node:fs";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { findBlitzBinary } from "../scripts/resolve-platform-bin.js";

const parseEnvInt = (name: string, fallback: number, min: number, max: number): number => {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < min || value > max) throw new Error(`${name} must be an integer from ${min} to ${max}`);
  return value;
};

const blitz = findBlitzBinary() ?? "blitz";
const cwd = realpathSync.native(resolve(process.env.BLITZ_WORKSPACE ?? process.cwd()));
const timeoutMs = parseEnvInt("BLITZ_MCP_TIMEOUT_MS", 30_000, 1, 600_000);
const maxFrameBytes = parseEnvInt("BLITZ_MCP_MAX_FRAME_BYTES", 1024 * 1024, 128, 16 * 1024 * 1024);
const maxBufferedBytes = maxFrameBytes + 4096;
let initialized = false;

type JsonRpc = { jsonrpc?: "2.0"; id?: string | number | null; method?: string; params?: Record<string, unknown> };
type ToolResult = { content: Array<{ type: "text"; text: string }>; isError?: boolean };

const tools = [
  { name: "blitz_doctor", description: "Run blitz doctor and return supported languages/commands/cache status.", inputSchema: { type: "object", properties: {}, additionalProperties: false } },
  { name: "blitz_read", description: "Read a file with blitz AST/source summary.", inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false } },
  { name: "blitz_patch", description: "Apply compact Blitz patch tuples to one file. Ops include replace, insert_after, wrap, replace_return, try_catch.", inputSchema: { type: "object", properties: { file: { type: "string" }, ops: { type: "array", items: { type: "array", items: { anyOf: [{ type: "string" }, { type: "number" }] } }, minItems: 1 }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "ops"], additionalProperties: false } },
  { name: "blitz_try_catch", description: "Wrap a symbol body in try/catch without repeating the body.", inputSchema: { type: "object", properties: { file: { type: "string" }, symbol: { type: "string" }, catchBody: { type: "string" }, indent: { type: "number" }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "symbol", "catchBody"], additionalProperties: false } },
  { name: "blitz_replace_return", description: "Replace a return expression in a symbol body.", inputSchema: { type: "object", properties: { file: { type: "string" }, symbol: { type: "string" }, expr: { type: "string" }, occurrence: { anyOf: [{ type: "string" }, { type: "number" }] }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "symbol", "expr"], additionalProperties: false } },
  { name: "blitz_undo", description: "Undo the last Blitz mutation for a file.", inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false } },
] as const;

const jsonText = (text: string, isError = false): ToolResult => ({ content: [{ type: "text", text }], ...(isError ? { isError: true } : {}) });

const run = (args: string[], stdin?: string): ToolResult => {
  const result = spawnSync(blitz, args, { cwd, input: stdin, encoding: "utf8", maxBuffer: 1024 * 1024 * 8, timeout: timeoutMs });
  const stdout = (result.stdout ?? "").trim();
  const stderr = (result.stderr ?? "").trim();
  const text = result.status === 0 ? stdout : [stdout, stderr ? `stderr:\n${stderr.replaceAll(cwd, "$WORKSPACE")}` : ""].filter(Boolean).join("\n");
  return jsonText(text, (result.status ?? 1) !== 0 || Boolean(result.error));
};

const requiredString = (args: Record<string, unknown>, key: string): string => {
  const value = args[key];
  if (typeof value !== "string" || value.length === 0) throw new Error(`missing string ${key}`);
  return value;
};

const existingAncestor = (abs: string): string => {
  let cur = abs;
  while (!existsSync(cur)) {
    const parent = dirname(cur);
    if (parent === cur) throw new Error(`no existing ancestor for path: ${abs}`);
    cur = parent;
  }
  return cur;
};

const bindPath = (file: string): string => {
  const abs = resolve(cwd, file);
  const ancestor = existingAncestor(abs);
  const real = resolve(realpathSync.native(ancestor), relative(ancestor, abs));
  const rel = relative(cwd, real);
  if (rel === "" || (!rel.startsWith("..") && !isAbsolute(rel))) return real;
  throw new Error(`path escapes workspace: ${file}`);
};

const callTool = (name: string, args: Record<string, unknown> = {}): ToolResult => {
  switch (name) {
    case "blitz_doctor": return run(["doctor"]);
    case "blitz_read": return run(["read", bindPath(requiredString(args, "file"))]);
    case "blitz_undo": return run(["undo", bindPath(requiredString(args, "file"))]);
    case "blitz_patch": {
      const file = bindPath(requiredString(args, "file"));
      if (!Array.isArray(args.ops) || args.ops.length === 0) throw new Error("missing ops array");
      return run(["apply", "--edit", "-", "--json"], JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: args.ops }, dry_run: args.dry_run, include_diff: args.include_diff }));
    }
    case "blitz_try_catch": {
      const file = bindPath(requiredString(args, "file"));
      const symbol = requiredString(args, "symbol");
      const catchBody = requiredString(args, "catchBody");
      const indent = typeof args.indent === "number" && Number.isFinite(args.indent) && args.indent >= 0 ? [args.indent] : [];
      return run(["apply", "--edit", "-", "--json"], JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: [["try_catch", symbol, catchBody, ...indent]] }, dry_run: args.dry_run, include_diff: args.include_diff }));
    }
    case "blitz_replace_return": {
      const file = bindPath(requiredString(args, "file"));
      const symbol = requiredString(args, "symbol");
      const expr = requiredString(args, "expr");
      return run(["apply", "--edit", "-", "--json"], JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: [["replace_return", symbol, expr, ...(args.occurrence !== undefined ? [args.occurrence] : [])]] }, dry_run: args.dry_run, include_diff: args.include_diff }));
    }
    default: throw new Error(`unknown tool ${name}`);
  }
};

const respond = (message: Record<string, unknown>) => {
  const body = JSON.stringify(message);
  process.stdout.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
};
const ok = (id: JsonRpc["id"], result: unknown) => respond({ jsonrpc: "2.0", id, result });
const err = (id: JsonRpc["id"], code: number, message: string) => respond({ jsonrpc: "2.0", id: id ?? null, error: { code, message } });

const handle = (msg: JsonRpc) => {
  try {
    if (msg.method === "initialize") {
      initialized = true;
      ok(msg.id, { protocolVersion: "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "blitz-mcp", version: "0.1.0-alpha.0" } });
      return;
    }
    if (msg.method === "notifications/initialized") return;
    if (!initialized && msg.id !== undefined) { err(msg.id, -32002, "server not initialized"); return; }
    if (msg.method === "tools/list") { ok(msg.id, { tools }); return; }
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
  if (headerEnd < 0) {
    if (buffer.length > maxBufferedBytes) throw new Error("frame header too large");
    return undefined;
  }
  const header = buffer.subarray(0, headerEnd).toString("utf8");
  const match = /^Content-Length:\s*(\d+)$/im.exec(header);
  if (!match) throw new Error("missing Content-Length");
  const len = Number(match[1]);
  if (!Number.isSafeInteger(len) || len < 0 || len > maxFrameBytes) throw new Error("invalid Content-Length");
  const start = headerEnd + 4;
  if (buffer.length < start + len) return undefined;
  const raw = buffer.subarray(start, start + len).toString("utf8");
  buffer = buffer.subarray(start + len);
  return JSON.parse(raw);
};

process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  while (true) {
    try {
      const msg = tryReadMessage();
      if (!msg) break;
      handle(msg);
    } catch (error) {
      buffer = Buffer.alloc(0);
      err(null, -32700, error instanceof Error ? error.message : "parse error");
      break;
    }
  }
});

process.stdin.resume();
