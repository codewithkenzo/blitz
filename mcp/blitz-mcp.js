#!/usr/bin/env node
// mcp/blitz-mcp.ts
import { existsSync as existsSync2, realpathSync } from "fs";
import { dirname as dirname2, isAbsolute, relative, resolve } from "path";
import { spawnSync } from "child_process";

// scripts/resolve-platform-bin.js
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
var here = dirname(fileURLToPath(import.meta.url));
var root = dirname(here);
var platformPackage = () => {
  const { platform, arch } = process;
  if (platform === "linux" && arch === "x64")
    return "@codewithkenzo/blitz-linux-x64-musl";
  if (platform === "linux" && arch === "arm64")
    return "@codewithkenzo/blitz-linux-arm64-musl";
  if (platform === "darwin" && arch === "arm64")
    return "@codewithkenzo/blitz-darwin-arm64";
  if (platform === "darwin" && arch === "x64")
    return "@codewithkenzo/blitz-darwin-x64";
  if (platform === "win32" && arch === "x64")
    return "@codewithkenzo/blitz-windows-x64";
  return null;
};
var candidateBinaries = () => {
  const exe = process.platform === "win32" ? "blitz.exe" : "blitz";
  const pkg = platformPackage();
  const candidates = [];
  if (process.env.BLITZ_BIN)
    candidates.push(process.env.BLITZ_BIN);
  if (pkg) {
    const unscoped = pkg.replace("@codewithkenzo/", "");
    candidates.push(join(root, "node_modules", pkg, "bin", exe));
    candidates.push(join(root, "..", unscoped, "bin", exe));
    candidates.push(join(root, "..", "..", pkg, "bin", exe));
  }
  candidates.push(join(root, "zig-out", "bin", exe));
  candidates.push(join(root, "bin", exe));
  return candidates;
};
var findBlitzBinary = () => candidateBinaries().find((candidate) => existsSync(candidate));

// mcp/blitz-mcp.ts
var parseEnvInt = (name, fallback, min, max) => {
  const raw = process.env[name];
  if (raw === undefined || raw === "")
    return fallback;
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < min || value > max)
    throw new Error(`${name} must be an integer from ${min} to ${max}`);
  return value;
};
var blitz = findBlitzBinary() ?? "blitz";
if (!process.env.BLITZ_WORKSPACE)
  throw new Error("BLITZ_WORKSPACE must be set to the project root");
var cwd = realpathSync.native(resolve(process.env.BLITZ_WORKSPACE));
var timeoutMs = parseEnvInt("BLITZ_MCP_TIMEOUT_MS", 30000, 1, 600000);
var maxFrameBytes = parseEnvInt("BLITZ_MCP_MAX_FRAME_BYTES", 1024 * 1024, 128, 16 * 1024 * 1024);
var maxBufferedBytes = maxFrameBytes + 4096;
var initialized = false;
var tools = [
  { name: "blitz_doctor", description: "Run blitz doctor and return supported languages/commands/cache status.", inputSchema: { type: "object", properties: {}, additionalProperties: false } },
  { name: "blitz_read", description: "Read a file with blitz AST/source summary.", inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false } },
  { name: "blitz_patch", description: "Apply compact Blitz patch tuples to one file. Ops include replace, insert_after, wrap, replace_return, try_catch.", inputSchema: { type: "object", properties: { file: { type: "string" }, ops: { type: "array", items: { type: "array", items: { anyOf: [{ type: "string" }, { type: "number" }] } }, minItems: 1 }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "ops"], additionalProperties: false } },
  { name: "blitz_try_catch", description: "Wrap a symbol body in try/catch without repeating the body.", inputSchema: { type: "object", properties: { file: { type: "string" }, symbol: { type: "string" }, catchBody: { type: "string" }, indent: { type: "number" }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "symbol", "catchBody"], additionalProperties: false } },
  { name: "blitz_replace_return", description: "Replace a return expression in a symbol body.", inputSchema: { type: "object", properties: { file: { type: "string" }, symbol: { type: "string" }, expr: { type: "string" }, occurrence: { anyOf: [{ type: "string" }, { type: "number" }] }, dry_run: { type: "boolean" }, include_diff: { type: "boolean" } }, required: ["file", "symbol", "expr"], additionalProperties: false } },
  { name: "blitz_undo", description: "Undo the last Blitz mutation for a file.", inputSchema: { type: "object", properties: { file: { type: "string" } }, required: ["file"], additionalProperties: false } }
];
var jsonText = (text, isError = false) => ({ content: [{ type: "text", text }], ...isError ? { isError: true } : {} });
var run = (args, stdin) => {
  const result = spawnSync(blitz, ["--workspace-root", cwd, ...args], {
    cwd,
    input: stdin,
    encoding: "utf8",
    maxBuffer: 1024 * 1024 * 8,
    timeout: timeoutMs,
    env: {
      HOME: process.env.HOME ?? "",
      PATH: process.env.PATH ?? "",
      XDG_CACHE_HOME: process.env.XDG_CACHE_HOME ?? "",
      BLITZ_NO_UPDATE_CHECK: "1",
      FASTEDIT_NO_UPDATE_CHECK: "1",
      BLITZ_WORKSPACE: cwd
    }
  });
  const stdout = (result.stdout ?? "").trim();
  const stderr = (result.stderr ?? "").trim();
  const text = result.status === 0 ? stdout : [stdout, stderr ? `stderr:
${stderr.replaceAll(cwd, "$WORKSPACE")}` : ""].filter(Boolean).join(`
`);
  return jsonText(text, (result.status ?? 1) !== 0 || Boolean(result.error));
};
var requiredString = (args, key) => {
  const value = args[key];
  if (typeof value !== "string" || value.length === 0)
    throw new Error(`missing string ${key}`);
  return value;
};
var existingAncestor = (abs) => {
  let cur = abs;
  while (!existsSync2(cur)) {
    const parent = dirname2(cur);
    if (parent === cur)
      throw new Error(`no existing ancestor for path: ${abs}`);
    cur = parent;
  }
  return cur;
};
var bindPath = (file) => {
  const abs = resolve(cwd, file);
  const ancestor = existingAncestor(abs);
  const real = resolve(realpathSync.native(ancestor), relative(ancestor, abs));
  const rel = relative(cwd, real);
  if (rel === "" || !rel.startsWith("..") && !isAbsolute(rel))
    return real;
  throw new Error(`path escapes workspace: ${file}`);
};
var applyArgs = (args) => {
  const argv = ["apply", "--edit", "-", "--json"];
  if (args.dry_run === true)
    argv.push("--dry-run");
  if (args.include_diff === true)
    argv.push("--diff");
  return argv;
};
var callTool = (name, args = {}) => {
  switch (name) {
    case "blitz_doctor":
      return run(["doctor"]);
    case "blitz_read":
      return run(["read", bindPath(requiredString(args, "file"))]);
    case "blitz_undo":
      return run(["undo", bindPath(requiredString(args, "file"))]);
    case "blitz_patch": {
      const file = bindPath(requiredString(args, "file"));
      if (!Array.isArray(args.ops) || args.ops.length === 0)
        throw new Error("missing ops array");
      return run(applyArgs(args), JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: args.ops } }));
    }
    case "blitz_try_catch": {
      const file = bindPath(requiredString(args, "file"));
      const symbol = requiredString(args, "symbol");
      const catchBody = requiredString(args, "catchBody");
      const indent = typeof args.indent === "number" && Number.isFinite(args.indent) && args.indent >= 0 ? [args.indent] : [];
      return run(applyArgs(args), JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: [["try_catch", symbol, catchBody, ...indent]] } }));
    }
    case "blitz_replace_return": {
      const file = bindPath(requiredString(args, "file"));
      const symbol = requiredString(args, "symbol");
      const expr = requiredString(args, "expr");
      return run(applyArgs(args), JSON.stringify({ version: 1, file, operation: "patch", edit: { ops: [["replace_return", symbol, expr, ...args.occurrence !== undefined ? [args.occurrence] : []]] } }));
    }
    default:
      throw new Error(`unknown tool ${name}`);
  }
};
var respond = (message) => {
  const body = JSON.stringify(message);
  process.stdout.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r
\r
${body}`);
};
var ok = (id, result) => respond({ jsonrpc: "2.0", id, result });
var err = (id, code, message) => respond({ jsonrpc: "2.0", id: id ?? null, error: { code, message } });
var handle = (msg) => {
  try {
    if (msg.method === "initialize") {
      initialized = true;
      ok(msg.id, { protocolVersion: "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "blitz-mcp", version: "0.1.0-alpha.7" } });
      return;
    }
    if (msg.method === "notifications/initialized")
      return;
    if (!initialized && msg.id !== undefined) {
      err(msg.id, -32002, "server not initialized");
      return;
    }
    if (msg.method === "tools/list") {
      ok(msg.id, { tools });
      return;
    }
    if (msg.method === "tools/call") {
      const params = msg.params ?? {};
      const name = params.name;
      const args = params.arguments;
      if (typeof name !== "string")
        throw new Error("tools/call missing name");
      if (args !== undefined && (typeof args !== "object" || args === null || Array.isArray(args)))
        throw new Error("tools/call arguments must be object");
      ok(msg.id, callTool(name, args ?? {}));
      return;
    }
    if (msg.id !== undefined)
      err(msg.id, -32601, `method not found: ${msg.method}`);
  } catch (error) {
    err(msg.id, -32000, error instanceof Error ? error.message : String(error));
  }
};
var buffer = Buffer.alloc(0);
var tryReadMessage = () => {
  const headerEnd = buffer.indexOf(`\r
\r
`);
  if (headerEnd < 0) {
    if (buffer.length > maxBufferedBytes)
      throw new Error("frame header too large");
    return;
  }
  const header = buffer.subarray(0, headerEnd).toString("utf8");
  const match = /^Content-Length:\s*(\d+)$/im.exec(header);
  if (!match)
    throw new Error("missing Content-Length");
  const len = Number(match[1]);
  if (!Number.isSafeInteger(len) || len < 0 || len > maxFrameBytes)
    throw new Error("invalid Content-Length");
  const start = headerEnd + 4;
  if (buffer.length < start + len)
    return;
  const raw = buffer.subarray(start, start + len).toString("utf8");
  buffer = buffer.subarray(start + len);
  return JSON.parse(raw);
};
process.stdin.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  while (true) {
    try {
      const msg = tryReadMessage();
      if (!msg)
        break;
      handle(msg);
    } catch (error) {
      buffer = Buffer.alloc(0);
      err(null, -32700, error instanceof Error ? error.message : "parse error");
      break;
    }
  }
});
process.stdin.resume();
