#!/usr/bin/env bun
/**
 * blitz vs pi-core-edit micro-benchmark — v0.1 direct-swap only.
 *
 * Measures TWO things per case:
 *
 *   1. Output-token cost — what the LLM has to emit to produce the edit.
 *      - core edit: { oldText: <full original symbol body>, newText: <full new body> }
 *      - blitz:     { snippet: <full new body>, replace: <symbol name> }
 *      Tokens estimated as bytes / 4 (rough OpenAI/Claude average for code).
 *
 *   2. Wall time end-to-end — real spawn of the blitz binary against
 *      a fresh copy of the fixture.
 *
 * IMPORTANT: this benchmark only exercises full-symbol replace (direct
 * swap). It does NOT yet measure the marker-preservation case
 * (`// ... existing code ...`) which is where fastedit reports its
 * largest gains; that requires Layer A splice (ticket d1o-cewc).
 *
 * Run:
 *   bun run bench/run.ts
 *   bun run bench/run.ts --target=x86_64-linux-musl   # match release build
 */

import { readFile, mkdtemp, writeFile, rm } from "node:fs/promises";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ_BINARY = `${REPO_ROOT}/zig-out/bin/blitz`;
const ITERATIONS = 5;

const DEFAULT_THRESHOLDS = {
	maxWallMs: 25,
	minSavingsPct: 5,
} as const;

type Case = {
	id: string;
	fixture: string; // basename under bench/fixtures/
	symbol: string;
	new_body: string; // what the LLM would emit for both lanes
};

const CASES: Case[] = [
	{
		id: "small/wrap-try-catch",
		fixture: "small.ts",
		symbol: "greet",
		new_body: `function greet(name: string): string {
  try {
    return "hello " + name.toUpperCase();
  } catch (e) {
    return "error";
  }
}`,
	},
	{
		id: "medium/add-options-method",
		fixture: "medium.ts",
		symbol: "handleRequest",
		new_body: `function handleRequest(req: Request): Response {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: { "access-control-allow-origin": "*" },
    });
  }

  if (method !== "GET" && method !== "POST") {
    return new Response("method not allowed", { status: 405 });
  }

  if (path === "/health") {
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "content-type": "application/json" },
    });
  }

  if (path.startsWith("/api/")) {
    return new Response("api stub", { status: 200 });
  }

  return new Response("not found", { status: 404 });
}`,
	},
	{
		id: "large/add-rate-limit",
		fixture: "large.ts",
		symbol: "processBatch",
		new_body: `function processBatch(items: ReadonlyArray<{ id: string; payload: unknown }>): Map<string, BatchResult> {
  const results = new Map<string, BatchResult>();
  const startTime = performance.now();
  const rateLimit = items.length > 1000 ? 100 : items.length;
  let processed = 0;

  for (const item of items) {
    if (processed >= rateLimit) {
      results.set(item.id || crypto.randomUUID(), {
        ok: false,
        error: "rate limit exceeded",
        durationMs: 0,
      });
      continue;
    }
    processed += 1;

    if (!item.id) {
      results.set(crypto.randomUUID(), {
        ok: false,
        error: "missing id",
        durationMs: 0,
      });
      continue;
    }

    if (item.payload === null || item.payload === undefined) {
      results.set(item.id, {
        ok: false,
        error: "missing payload",
        durationMs: 0,
      });
      continue;
    }

    const itemStart = performance.now();
    try {
      const validated = validate(item.payload);
      const transformed = transform(validated);
      const enriched = enrich(transformed);
      const persisted = persist(item.id, enriched);

      results.set(item.id, {
        ok: true,
        value: persisted,
        durationMs: performance.now() - itemStart,
      });
    } catch (err) {
      results.set(item.id, {
        ok: false,
        error: err instanceof Error ? err.message : String(err),
        durationMs: performance.now() - itemStart,
      });
    }
  }

  const totalDuration = performance.now() - startTime;
  console.log("[processBatch] " + items.length + " items in " + totalDuration.toFixed(2) + "ms");
  return results;
}`,
	},
	{
		id: "marker/analyze-values",
		fixture: "marker.ts",
		symbol: "analyzeValues",
		new_body: `function analyzeValues(values: ReadonlyArray<number>): string {
  if (values.length === 0) {
    return "n/a";
  }

  const sorted = [...values].filter(Number.isFinite);
  const count = sorted.length + 0;
  const min = sorted[0]!;
  let outliers = 0;
  // ... existing code ...
  const report = "report:${'${'}body} range=${'${'}min}..${'${'}max}";
  return report + " [bounded]";
}`,
	},
];

const estimateTokens = (text: string): number => Math.ceil(Buffer.byteLength(text, "utf8") / 4);

const extractSymbolBody = (source: string, symbol: string): string => {
	// crude regex scan good enough for the fixtures: function NAME until matching closing brace at top level
	const startIdx = source.indexOf(`function ${symbol}`);
	if (startIdx === -1) throw new Error(`symbol ${symbol} not found in fixture`);
	let depth = 0;
	let i = source.indexOf("{", startIdx);
	if (i === -1) throw new Error(`open brace for ${symbol} not found`);
	depth = 1;
	i += 1;
	while (i < source.length && depth > 0) {
		const ch = source[i]!;
		if (ch === "{") depth += 1;
		else if (ch === "}") depth -= 1;
		i += 1;
	}
	return source.slice(startIdx, i);
};

const runBlitzReplace = async (file: string, symbol: string, body: string): Promise<number> => {
	const start = performance.now();
	await new Promise<void>((resolve, reject) => {
		const proc = spawn(BLITZ_BINARY, [
			"edit",
			file,
			"--snippet",
			"-",
			"--replace",
			symbol,
		]);
		let stderr = "";
		proc.stderr.on("data", (d) => {
			stderr += d.toString();
		});
		proc.on("error", reject);
		proc.on("exit", (code) => {
			if (code === 0) resolve();
			else reject(new Error(`blitz exited ${code}: ${stderr}`));
		});
		proc.stdin.write(body);
		proc.stdin.end();
	});
	return performance.now() - start;
};

const median = (xs: number[]): number => {
	const sorted = [...xs].sort((a, b) => a - b);
	const mid = Math.floor(sorted.length / 2);
	if (sorted.length % 2 === 0) return (sorted[mid - 1]! + sorted[mid]!) / 2;
	return sorted[mid]!;
};

type Row = {
	case_id: string;
	core_oldtext_tokens: number;
	core_newtext_tokens: number;
	core_total_tokens: number;
	blitz_snippet_tokens: number;
	blitz_total_tokens: number; // snippet + symbol-name + small flag overhead
	tokens_saved: number;
	pct_saved: number;
	median_wall_ms: number;
};

type RegressionThresholds = {
	maxWallMs: number;
	minSavingsPct: number;
};

const readThresholds = async (): Promise<RegressionThresholds> => {
	const thresholdPath = join(REPO_ROOT, "bench", "regression-thresholds.json");
	try {
		const raw = await readFile(thresholdPath, "utf8");
		const parsed = JSON.parse(raw);
		const maxWallMs = typeof parsed?.maxWallMs === "number" ? parsed.maxWallMs : DEFAULT_THRESHOLDS.maxWallMs;
		const minSavingsPct =
			typeof parsed?.minSavingsPct === "number"
				? parsed.minSavingsPct
				: DEFAULT_THRESHOLDS.minSavingsPct;
		return { maxWallMs, minSavingsPct };
	} catch (err) {
		const maybeNodeErr = err as NodeJS.ErrnoException;
		if (maybeNodeErr.code === "ENOENT") {
			return DEFAULT_THRESHOLDS;
		}
		console.error("WARN: cannot read regression thresholds, using defaults", String(err));
		return DEFAULT_THRESHOLDS;
	}
};

const main = async () => {
	console.log(`# blitz vs core edit — direct-swap micro-benchmark\n`);
	console.log(`Binary:    ${BLITZ_BINARY}`);
	console.log(`Iterations per case: ${ITERATIONS}`);
	console.log(`Generated: ${new Date().toISOString()}\n`);

	const thresholds = await readThresholds();
	console.log(
		`Regression thresholds: max wall ${thresholds.maxWallMs}ms, min savings ${thresholds.minSavingsPct}%`,
	);
	console.log(`Using thresholds from ${join(REPO_ROOT, "bench", "regression-thresholds.json")} if present.\n`);

	const rows: Row[] = [];

	for (const c of CASES) {
		const fixturePath = `${REPO_ROOT}/bench/fixtures/${c.fixture}`;
		const original = await readFile(fixturePath, "utf8");
		const oldText = extractSymbolBody(original, c.symbol);

		const wallTimes: number[] = [];
		const tmpDir = await mkdtemp(join(tmpdir(), "blitz-bench-"));
		try {
			const target = join(tmpDir, c.fixture);
			for (let i = 0; i < ITERATIONS; i++) {
				await writeFile(target, original, "utf8");
				const ms = await runBlitzReplace(target, c.symbol, c.new_body);
				wallTimes.push(ms);
			}
		} finally {
			await rm(tmpDir, { recursive: true, force: true });
		}

		const coreOld = estimateTokens(oldText);
		const coreNew = estimateTokens(c.new_body);
		const coreTotal = coreOld + coreNew;
		const blitzSnippet = estimateTokens(c.new_body);
		// Symbol name + envelope overhead: roughly 8 tokens for tool wrapper
		const blitzTotal = blitzSnippet + estimateTokens(c.symbol) + 8;
		const saved = coreTotal - blitzTotal;
		const pctSaved = (saved / coreTotal) * 100;
		const medianWallMs = median(wallTimes);

		rows.push({
			case_id: c.id,
			core_oldtext_tokens: coreOld,
			core_newtext_tokens: coreNew,
			core_total_tokens: coreTotal,
			blitz_snippet_tokens: blitzSnippet,
			blitz_total_tokens: blitzTotal,
			tokens_saved: saved,
			pct_saved: pctSaved,
			median_wall_ms: medianWallMs,
		});
	}

	const cols = [
		{ key: "case_id" as const, label: "Case", format: (v: string) => v },
		{ key: "core_total_tokens" as const, label: "core (oldT+newT)", format: (v: number) => String(v) },
		{ key: "blitz_total_tokens" as const, label: "blitz (snippet+sym)", format: (v: number) => String(v) },
		{ key: "tokens_saved" as const, label: "saved", format: (v: number) => String(v) },
		{ key: "pct_saved" as const, label: "%", format: (v: number) => `${v.toFixed(1)}%` },
		{ key: "median_wall_ms" as const, label: "wall ms (median)", format: (v: number) => v.toFixed(1) },
	] as const;

	type Col = (typeof cols)[number];
	const widths = cols.map((c: Col) => {
		const cellWidths = rows.map((r) => c.format(r[c.key]).length);
		return Math.max(c.label.length, ...cellWidths);
	});
	const header = cols.map((c, i) => c.label.padEnd(widths[i]!)).join(" | ");
	const sep = widths.map((w) => "-".repeat(w)).join("-|-");
	console.log(`| ${header} |`);
	console.log(`|-${sep}-|`);
	for (const r of rows) {
		const cells = cols.map((c, i) => c.format(r[c.key]).padEnd(widths[i]!));
		console.log(`| ${cells.join(" | ")} |`);
	}

	console.log("");
	const totalCoreTokens = rows.reduce((acc, r) => acc + r.core_total_tokens, 0);
	const totalSaved = rows.reduce((acc, r) => acc + r.tokens_saved, 0);
	const aggregateSavingsPct = totalCoreTokens > 0 ? (totalSaved / totalCoreTokens) * 100 : 0;
	const aggregateMedianWallMs = median(rows.map((r) => r.median_wall_ms));
	console.log(
		`Aggregate: ~${aggregateSavingsPct.toFixed(1)}% output-token reduction, median wall-time ~${aggregateMedianWallMs.toFixed(1)}ms / case.`,
	);

	if (aggregateMedianWallMs > thresholds.maxWallMs) {
		console.log(
			`FAIL: aggregate median wall-time ${aggregateMedianWallMs.toFixed(1)}ms exceeded threshold ${thresholds.maxWallMs}ms`,
		);
		console.log("FAIL: benchmark regression threshold exceeded.");
		process.exit(1);
	}

	if (aggregateSavingsPct < thresholds.minSavingsPct) {
		console.log(
			`FAIL: aggregate savings ${aggregateSavingsPct.toFixed(1)}% below threshold ${thresholds.minSavingsPct}%`,
		);
		console.log("FAIL: benchmark regression threshold exceeded.");
		process.exit(1);
	}

	console.log("PASS: benchmark regression gate satisfied.");
	console.log("");
	console.log("Caveats:");
	console.log("- Tokens are bytes/4 estimate, not real tokenizer output.");
	console.log("- Direct-swap mode only: agent writes the full new symbol body.");
	console.log("- Marker splice (`// ... existing code ...`) ships in d1o-cewc and");
	console.log("  is where the larger savings live; expect those numbers later.");
	console.log("- Wall-time excludes the LLM round-trip; it is binary spawn + parse + write.");
};

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
