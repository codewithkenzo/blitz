#!/usr/bin/env bun
import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";

const BLITZ = "/home/kenzo/dev/blitz/zig-out/bin/blitz";
const ITER = 5;
const SIZES = [100_000, 500_000, 1_000_000];

type Row = {
  sizeLabel: string;
  originalBytes: number;
  corePayloadBytes: number;
  blitzPayloadBytes: number;
  payloadSavedPct: number;
  coreWriteMs: number;
  blitzMs: number;
  diffMs: number;
  diffBytes: number;
  ok: boolean;
};

const median = (xs: number[]) => [...xs].sort((a,b)=>a-b)[Math.floor(xs.length/2)]!;
const pct = (n: number) => `${n.toFixed(1)}%`;

function makeFunction(targetBytes: number) {
  const lines: string[] = [];
  lines.push("function hugeCompute(seed: number): number {");
  lines.push("  let total = seed;");
  let i = 0;
  while (lines.join("\n").length < targetBytes - 40) {
    lines.push(`  total += (${i} % 17) * (${i} % 31);`);
    i++;
  }
  lines.push("  return total;");
  lines.push("}");
  const original = lines.join("\n") + "\n";
  const expected = original.replace("  return total;", "  return total + 1;");
  const snippet = "function hugeCompute(seed: number): number {\n  // ... existing code ...\n  return total + 1;\n}";
  return { original, expected, snippet, lineCount: lines.length };
}

function run(cmd: string[], stdin?: string, cwd?: string) {
  const t0 = performance.now();
  const res = spawnSync(cmd[0]!, cmd.slice(1), { input: stdin, cwd, encoding: "utf8", maxBuffer: 200 * 1024 * 1024 });
  const ms = performance.now() - t0;
  return { ms, status: res.status ?? -1, stdout: res.stdout ?? "", stderr: res.stderr ?? "" };
}

async function coreExactReplace(file: string, oldText: string, newText: string) {
  const t0 = performance.now();
  const src = await readFile(file, "utf8");
  const idx = src.indexOf(oldText);
  if (idx < 0) throw new Error("oldText not found");
  const out = src.slice(0, idx) + newText + src.slice(idx + oldText.length);
  await writeFile(file, out, "utf8");
  return performance.now() - t0;
}

async function main() {
  const rows: Row[] = [];
  const dir = await mkdtemp(join(tmpdir(), "blitz-deep-"));
  try {
    for (const target of SIZES) {
      const { original, expected, snippet, lineCount } = makeFunction(target);
      const sizeLabel = `${Math.round(Buffer.byteLength(original)/1000)}KB/${lineCount}L`;
      const corePayloadBytes = Buffer.byteLength(original) + Buffer.byteLength(expected);
      const blitzPayloadBytes = Buffer.byteLength(snippet) + Buffer.byteLength("hugeCompute") + 32;
      const payloadSavedPct = 100 * (1 - blitzPayloadBytes / corePayloadBytes);

      const coreMs: number[] = [];
      const blitzMs: number[] = [];
      const diffMs: number[] = [];
      const diffBytes: number[] = [];
      let ok = true;

      for (let i=0; i<ITER; i++) {
        const coreFile = join(dir, `core-${target}-${i}.ts`);
        const blitzFile = join(dir, `blitz-${target}-${i}.ts`);
        const beforeFile = join(dir, `before-${target}-${i}.ts`);
        await writeFile(coreFile, original, "utf8");
        await writeFile(blitzFile, original, "utf8");
        await writeFile(beforeFile, original, "utf8");

        coreMs.push(await coreExactReplace(coreFile, original, expected));
        const coreOut = await readFile(coreFile, "utf8");
        if (coreOut !== expected) ok = false;

        const b = run([BLITZ, "edit", blitzFile, "--snippet", "-", "--replace", "hugeCompute"], snippet);
        blitzMs.push(b.ms);
        if (b.status !== 0) {
          ok = false;
          console.error("blitz failed", target, b.status, b.stderr);
        }
        const blitzOut = await readFile(blitzFile, "utf8");
        if (blitzOut !== expected) {
          ok = false;
          console.error("output mismatch", target, i, { gotBytes: blitzOut.length, expectedBytes: expected.length });
        }

        const d = run(["git", "diff", "--no-index", "--no-ext-diff", "--", beforeFile, blitzFile], undefined, dir);
        diffMs.push(d.ms);
        diffBytes.push(Buffer.byteLength(d.stdout) + Buffer.byteLength(d.stderr));
      }

      rows.push({
        sizeLabel,
        originalBytes: Buffer.byteLength(original),
        corePayloadBytes,
        blitzPayloadBytes,
        payloadSavedPct,
        coreWriteMs: median(coreMs),
        blitzMs: median(blitzMs),
        diffMs: median(diffMs),
        diffBytes: median(diffBytes),
        ok,
      });
    }

    console.log("# Blitz deep large-file benchmark");
    console.log(`Iterations/case: ${ITER}`);
    console.log("Core-style latency = JS exact oldText/newText replace + write (lower bound, no Pi tool overhead).");
    console.log("Blitz latency = real blitz CLI spawn + tree-sitter parse + marker splice + atomic write.");
    console.log("Payload bytes compare LLM output required by core exact edit (oldText+newText) vs blitz marker snippet+symbol.\n");
    console.log("| Symbol size | Core payload | Blitz payload | Saved | Core write ms | Blitz ms | Diff ms | Diff bytes | OK |");
    console.log("|---:|---:|---:|---:|---:|---:|---:|---:|:--:|");
    for (const r of rows) {
      console.log(`| ${r.sizeLabel} | ${r.corePayloadBytes.toLocaleString()} | ${r.blitzPayloadBytes.toLocaleString()} | ${pct(r.payloadSavedPct)} | ${r.coreWriteMs.toFixed(2)} | ${r.blitzMs.toFixed(2)} | ${r.diffMs.toFixed(2)} | ${r.diffBytes.toLocaleString()} | ${r.ok ? "✅" : "❌"} |`);
    }

    const totalCorePayload = rows.reduce((a,r)=>a+r.corePayloadBytes,0);
    const totalBlitzPayload = rows.reduce((a,r)=>a+r.blitzPayloadBytes,0);
    console.log(`\nWeighted payload saved: ${pct(100*(1-totalBlitzPayload/totalCorePayload))}`);
    console.log(`Median blitz wall across sizes: ${median(rows.map(r=>r.blitzMs)).toFixed(2)}ms`);
  } finally {
    await rm(dir, { recursive: true, force: true });
  }
}

main().catch(e => { console.error(e); process.exit(1); });
