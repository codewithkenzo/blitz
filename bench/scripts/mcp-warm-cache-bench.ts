#!/usr/bin/env bun
import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { performance } from "node:perf_hooks";

type JsonRpc = { jsonrpc: "2.0"; id: number; method?: string; params?: unknown; result?: unknown; error?: unknown };
type Mode = "cold" | "warm";

const workspace = resolve(process.env.BLITZ_WORKSPACE ?? process.cwd());
const file = process.env.BLITZ_MCP_BENCH_FILE ?? "README.md";
const reportPath = resolve(workspace, process.env.BLITZ_MCP_BENCH_REPORT ?? `.pi/reports/mcp-warm-cache-bench-${new Date().toISOString().replaceAll(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z")}.md`);
const iterations = Number(process.env.BLITZ_MCP_BENCH_ITERS ?? "25");
if (!Number.isSafeInteger(iterations) || iterations < 5 || iterations > 200) throw new Error("BLITZ_MCP_BENCH_ITERS must be 5..200");
if (!existsSync(resolve(workspace, file))) throw new Error(`bench file missing: ${file}`);

const send = (child: ChildProcessWithoutNullStreams, msg: JsonRpc): void => {
  const body = JSON.stringify(msg);
  child.stdin.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
};

const readOne = (child: ChildProcessWithoutNullStreams): Promise<JsonRpc> => new Promise((resolveMsg) => {
  let buffer = Buffer.alloc(0);
  const onData = (chunk: Buffer) => {
    buffer = Buffer.concat([buffer, chunk]);
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd < 0) return;
    const header = buffer.subarray(0, headerEnd).toString("utf8");
    const match = /^Content-Length:\s*(\d+)$/im.exec(header);
    if (!match) throw new Error(`missing Content-Length in ${header}`);
    const len = Number(match[1]);
    const start = headerEnd + 4;
    if (buffer.length < start + len) return;
    child.stdout.off("data", onData);
    resolveMsg(JSON.parse(buffer.subarray(start, start + len).toString("utf8")) as JsonRpc);
  };
  child.stdout.on("data", onData);
});

const rpc = async (child: ChildProcessWithoutNullStreams, id: number, method: string, params?: unknown): Promise<JsonRpc> => {
  const pending = readOne(child);
  send(child, { jsonrpc: "2.0", id, method, params });
  const msg = await pending;
  if (msg.error) throw new Error(JSON.stringify(msg.error));
  return msg;
};

const toolCall = async (child: ChildProcessWithoutNullStreams, id: number, name: string, args: Record<string, unknown>, expectedText: string): Promise<void> => {
  const msg = await rpc(child, id, "tools/call", { name, arguments: args });
  const result = msg.result;
  if (typeof result !== "object" || result === null) throw new Error(`tools/call missing result for id ${id}`);
  if ("isError" in result && result.isError === true) throw new Error(JSON.stringify(result));
  const content = "content" in result ? result.content : undefined;
  if (!Array.isArray(content) || !content.some((part) => typeof part === "object" && part !== null && "text" in part && typeof part.text === "string" && part.text.includes(expectedText))) throw new Error(`tools/call missing expected text ${expectedText} for id ${id}`);
};

const percentile = (values: number[], pct: number): number => {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.ceil((pct / 100) * sorted.length) - 1)] ?? 0;
};

const runMode = async (mode: Mode): Promise<{ doctor: number[]; read: number[] }> => {
  const child = spawn("bun", ["mcp/blitz-mcp.ts", "--workspace", workspace], {
    cwd: workspace,
    env: { ...process.env, BLITZ_MCP_WARM: mode === "warm" ? "1" : "0" },
    stdio: ["pipe", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
  await rpc(child, 1, "initialize", { protocolVersion: "2025-06-18", capabilities: {}, clientInfo: { name: "mcp-warm-cache-bench", version: "0" } });
  send(child, { jsonrpc: "2.0", id: 0, method: "notifications/initialized" });

  const doctor: number[] = [];
  const read: number[] = [];
  for (let i = 0; i < iterations; i += 1) {
    let start = performance.now();
    await toolCall(child, 10_000 + i, "blitz_doctor", {}, "blitz doctor");
    doctor.push(performance.now() - start);
    start = performance.now();
    await toolCall(child, 20_000 + i, "blitz_read", { file }, file);
    read.push(performance.now() - start);
  }
  child.kill();
  if (stderr.trim()) process.stderr.write(`[${mode} stderr]\n${stderr}`);
  return { doctor: doctor.slice(1), read: read.slice(1) };
};

const cold = await runMode("cold");
const warm = await runMode("warm");
const summarize = (name: string, values: number[]) => ({ name, p50Ms: Number(percentile(values, 50).toFixed(3)), p95Ms: Number(percentile(values, 95).toFixed(3)) });
const result = {
  workspace,
  file,
  iterations,
  note: "first iteration dropped; cold = MCP subprocess with stateless CLI per call; warm = BLITZ_MCP_WARM=1 doctor/read cache only",
  cold: [summarize("doctor", cold.doctor), summarize("read", cold.read)],
  warm: [summarize("doctor", warm.doctor), summarize("read", warm.read)],
};

const rows = [
  ...result.cold.map((entry) => ["cold", entry] as const),
  ...result.warm.map((entry) => ["warm", entry] as const),
];
const report = `# MCP warm cache bench — ${new Date().toISOString()}

Command:

\`\`\`bash
bun bench/scripts/mcp-warm-cache-bench.ts
\`\`\`

Scope:

- Workspace: \`${workspace}\`
- File: \`${file}\`
- Iterations: ${iterations}; first iteration dropped
- Cold: MCP subprocess with stateless Blitz CLI per call
- Warm: \`BLITZ_MCP_WARM=1\`; MCP-host doctor cache and bounded read cache keyed by same-fd SHA-256/content metadata fingerprint when safe pre/post fingerprints match, file is regular, input is within \`BLITZ_MCP_WARM_MAX_HASH_BYTES\`, and result is within \`BLITZ_MCP_WARM_MAX_RESULT_BYTES\`
- Mutation ops stayed stateless CLI fallback; no mutation result cache

Results:

| mode | operation | p50 ms | p95 ms |
|---|---:|---:|---:|
${rows.map(([mode, entry]) => `| ${mode} | ${entry.name} | ${entry.p50Ms.toFixed(3)} | ${entry.p95Ms.toFixed(3)} |`).join("\n")}

Conclusion: bounded MCP warm cache targets repeated safe \`doctor\` and \`read\` calls. Fingerprint guard reduces accidental stale reuse but is not a replacement for future same-fd daemon parsing under hostile concurrent writers. Rebenchmark larger safe-read files before default-on.
`;
mkdirSync(dirname(reportPath), { recursive: true });
writeFileSync(reportPath, report);
process.stderr.write(`wrote report: ${reportPath}\n`);
console.log(JSON.stringify(result, null, 2));
