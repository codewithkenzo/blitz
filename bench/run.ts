#!/usr/bin/env bun
/**
 * blitz vs pi-core-edit micro-benchmark.
 *
 * Measures per case:
 *   1. Output-token cost.
 *      - core edit: { oldText: <full original symbol body>, newText: <full final body> }
 *      - blitz:     { snippet: <edit snippet>, replace: <symbol name> }
 *   2. Wall time end-to-end for spawned blitz binary.
 *   3. Exact output bytes after each run. Bench aborts on mismatch before regression gate.
 *
 * Run:
 *   bun run bench/run.ts
 *   bun run bench/run.ts --target=x86_64-linux-musl
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

type Lane = "direct" | "marker";

type Case = {
	id: string;
	lane: Lane;
	fixture: string;
	symbol: string;
	snippet: string;
	expectedSymbolBody?: string;
	expectedOutput?: string;
};

const materializeTemplateText = (text: string): string =>
	text.replaceAll("§", "`").replaceAll("@{", "${");

const CASES: Case[] = [
	{
		id: "small/wrap-try-catch",
		lane: "direct",
		fixture: "small.ts",
		symbol: "greet",
		snippet: `function greet(name: string): string {
  try {
    return "hello " + name.toUpperCase();
  } catch (e) {
    return "error";
  }
}`,
	},
	{
		id: "medium/add-options-method",
		lane: "direct",
		fixture: "medium.ts",
		symbol: "handleRequest",
		snippet: `function handleRequest(req: Request): Response {
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
		lane: "direct",
		fixture: "large.ts",
		symbol: "processBatch",
		snippet: `function processBatch(items: ReadonlyArray<{ id: string; payload: unknown }>): Map<string, BatchResult> {
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
		lane: "marker",
		fixture: "marker.ts",
		symbol: "analyzeValues",
		snippet: materializeTemplateText(`function analyzeValues(values: ReadonlyArray<number>): string {
  if (values.length === 0) {
    return "n/a";
  }

  const sorted = [...values].filter(Number.isFinite);
  const count = sorted.length + 0;
  const min = sorted[0]!;
  let outliers = 0;
  // ... existing code ...
  const report = §report:@{body} range=@{min}..@{max}§;
  return report + " [bounded]";
}`),
		expectedSymbolBody: materializeTemplateText(`function analyzeValues(values: ReadonlyArray<number>): string {
  if (values.length === 0) {
    return "n/a";
  }

  const sorted = [...values].filter(Number.isFinite);
  const count = sorted.length + 0;
  const min = sorted[0]!;
  const max = sorted[sorted.length - 1]!;
  let total = 0;
  let squares = 0;
  let outliers = 0;

  for (const value of sorted) {
    if (value < -1000 || value > 1000) {
      outliers += 1;
      continue;
    }

    total += value;
    squares += value * value;
  }

  const average = total / Math.max(count, 1);
  const variance = squares / Math.max(count, 1) - average * average;
  const spread = max - min;
  const midpoint = (min + max) / 2;
  const stability = spread <= midpoint ? "tight" : "wide";
  const score = Math.round((average + spread - Math.abs(variance)) * 100) / 100;
  const quality = outliers > 0 ? §outlier:@{outliers}§ : §stable:@{stability}§;
  const margin = spread - average;
  const header = §count=@{count}§;
  const details = §@{header} avg=@{average.toFixed(2)} spread=@{spread.toFixed(2)} score=@{score.toFixed(2)} quality=@{quality}§;
  const body = §@{details} margin=@{margin.toFixed(2)}§;
  const report = §report:@{body} range=@{min}..@{max}§;

  return report + " [bounded]";
}`),
	},
];

const estimateTokens = (text: string): number => Math.ceil(Buffer.byteLength(text, "utf8") / 4);

const findFunctionBodyRange = (source: string, symbol: string): { start: number; end: number } => {
	const startIdx = source.indexOf(`function ${symbol}`);
	if (startIdx === -1) throw new Error(`symbol ${symbol} not found in fixture`);

	let i = startIdx;
	let seenParams = false;
	let parenDepth = 0;
	while (i < source.length) {
		const ch = source[i]!;
		if (ch === "(") {
			seenParams = true;
			parenDepth += 1;
		} else if (ch === ")") {
			parenDepth -= 1;
			if (seenParams && parenDepth === 0) {
				i += 1;
				break;
			}
		}
		i += 1;
	}
	if (!seenParams || parenDepth !== 0) throw new Error(`parameter list for ${symbol} not found`);

	while (i < source.length && source[i] !== "{") i += 1;
	if (i >= source.length) throw new Error(`open brace for ${symbol} not found`);

	const bodyStart = i;
	let depth = 1;
	i += 1;
	let state: "code" | "single" | "double" | "template" | "line-comment" | "block-comment" = "code";

	while (i < source.length && depth > 0) {
		const ch = source[i]!;
		const next = source[i + 1] ?? "";

		switch (state) {
			case "code":
				if (ch === "'" ) state = "single";
				else if (ch === '"') state = "double";
				else if (ch === "`") state = "template";
				else if (ch === "/" && next === "/") {
					state = "line-comment";
					i += 1;
				} else if (ch === "/" && next === "*") {
					state = "block-comment";
					i += 1;
				} else if (ch === "{") depth += 1;
				else if (ch === "}") depth -= 1;
				break;
			case "single":
				if (ch === "\\") i += 1;
				else if (ch === "'") state = "code";
				break;
			case "double":
				if (ch === "\\") i += 1;
				else if (ch === '"') state = "code";
				break;
			case "template":
				if (ch === "\\") i += 1;
				else if (ch === "`") state = "code";
				break;
			case "line-comment":
				if (ch === "\n") state = "code";
				break;
			case "block-comment":
				if (ch === "*" && next === "/") {
					state = "code";
					i += 1;
				}
				break;
		}

		i += 1;
	}
	if (depth !== 0) throw new Error(`closing brace for ${symbol} not found`);

	return { start: startIdx, end: i };
};

const extractSymbolBody = (source: string, symbol: string): string => {
	const range = findFunctionBodyRange(source, symbol);
	return source.slice(range.start, range.end);
};

const replaceSymbolBody = (source: string, symbol: string, nextBody: string): string => {
	const range = findFunctionBodyRange(source, symbol);
	return `${source.slice(0, range.start)}${nextBody}${source.slice(range.end)}`;
};

const runBlitzReplace = async (file: string, symbol: string, snippet: string): Promise<number> => {
	const start = performance.now();
	await new Promise<void>((resolve, reject) => {
		const proc = spawn(BLITZ_BINARY, ["edit", file, "--snippet", "-", "--replace", symbol]);
		let stderr = "";
		proc.stderr.on("data", (d) => {
			stderr += d.toString();
		});
		proc.on("error", reject);
		proc.on("exit", (code) => {
			if (code === 0) resolve();
			else reject(new Error(`blitz exited ${code}: ${stderr}`));
		});
		proc.stdin.write(snippet);
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
	lane: Lane;
	case_id: string;
	core_oldtext_tokens: number;
	core_newtext_tokens: number;
	core_total_tokens: number;
	blitz_snippet_tokens: number;
	blitz_total_tokens: number;
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
		if (maybeNodeErr.code === "ENOENT") return DEFAULT_THRESHOLDS;
		console.error("WARN: cannot read regression thresholds, using defaults", String(err));
		return DEFAULT_THRESHOLDS;
	}
};

const aggregateForRows = (rows: Row[]) => {
	const totalCoreTokens = rows.reduce((acc, r) => acc + r.core_total_tokens, 0);
	const totalSaved = rows.reduce((acc, r) => acc + r.tokens_saved, 0);
	return {
		savingsPct: totalCoreTokens > 0 ? (totalSaved / totalCoreTokens) * 100 : 0,
		medianWallMs: rows.length > 0 ? median(rows.map((r) => r.median_wall_ms)) : 0,
	};
};

const printTable = (rows: Row[]) => {
	const cols = [
		{ key: "lane" as const, label: "Lane", format: (v: string) => v },
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
};

const main = async () => {
	console.log(`# blitz vs core edit — correctness + micro-benchmark\n`);
	console.log(`Binary:    ${BLITZ_BINARY}`);
	console.log(`Iterations per case: ${ITERATIONS}`);
	console.log(`Generated: ${new Date().toISOString()}\n`);

	const thresholds = await readThresholds();
	console.log(
		`Regression thresholds (direct lane): max wall ${thresholds.maxWallMs}ms, min savings ${thresholds.minSavingsPct}%`,
	);
	console.log(`Using thresholds from ${join(REPO_ROOT, "bench", "regression-thresholds.json")} if present.\n`);

	const rows: Row[] = [];

	for (const c of CASES) {
		const fixturePath = `${REPO_ROOT}/bench/fixtures/${c.fixture}`;
		const original = await readFile(fixturePath, "utf8");
		const oldText = extractSymbolBody(original, c.symbol);
		const finalBody = c.expectedSymbolBody ?? c.snippet;
		const expectedOutput = c.expectedOutput ?? replaceSymbolBody(original, c.symbol, finalBody);

		const wallTimes: number[] = [];
		const tmpDir = await mkdtemp(join(tmpdir(), "blitz-bench-"));
		try {
			const target = join(tmpDir, c.fixture);
			for (let i = 0; i < ITERATIONS; i++) {
				await writeFile(target, original, "utf8");
				const ms = await runBlitzReplace(target, c.symbol, c.snippet);
				wallTimes.push(ms);
				const actual = await readFile(target, "utf8");
				if (actual !== expectedOutput) {
					throw new Error(
						`output mismatch for ${c.id} iteration ${i + 1}\n--- expected ---\n${expectedOutput}\n--- actual ---\n${actual}`,
					);
				}
			}
		} finally {
			await rm(tmpDir, { recursive: true, force: true });
		}

		const coreOld = estimateTokens(oldText);
		const coreNew = estimateTokens(finalBody);
		const coreTotal = coreOld + coreNew;
		const blitzSnippet = estimateTokens(c.snippet);
		const blitzTotal = blitzSnippet + estimateTokens(c.symbol) + 8;
		const saved = coreTotal - blitzTotal;
		const pctSaved = (saved / coreTotal) * 100;
		const medianWallMs = median(wallTimes);

		rows.push({
			lane: c.lane,
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

	printTable(rows);
	console.log("");

	const directRows = rows.filter((row) => row.lane === "direct");
	const markerRows = rows.filter((row) => row.lane === "marker");
	const directAggregate = aggregateForRows(directRows);
	const markerAggregate = aggregateForRows(markerRows);
	const overallAggregate = aggregateForRows(rows);

	console.log(
		`Direct-swap aggregate: ~${directAggregate.savingsPct.toFixed(1)}% output-token reduction, median wall-time ~${directAggregate.medianWallMs.toFixed(1)}ms / case.`,
	);
	console.log(
		`Marker aggregate: ~${markerAggregate.savingsPct.toFixed(1)}% output-token reduction, median wall-time ~${markerAggregate.medianWallMs.toFixed(1)}ms / case.`,
	);
	console.log(
		`Overall aggregate: ~${overallAggregate.savingsPct.toFixed(1)}% output-token reduction, median wall-time ~${overallAggregate.medianWallMs.toFixed(1)}ms / case.`,
	);

	if (directAggregate.medianWallMs > thresholds.maxWallMs) {
		console.log(
			`FAIL: direct-swap median wall-time ${directAggregate.medianWallMs.toFixed(1)}ms exceeded threshold ${thresholds.maxWallMs}ms`,
		);
		console.log("FAIL: benchmark regression threshold exceeded.");
		process.exit(1);
	}

	if (directAggregate.savingsPct < thresholds.minSavingsPct) {
		console.log(
			`FAIL: direct-swap savings ${directAggregate.savingsPct.toFixed(1)}% below threshold ${thresholds.minSavingsPct}%`,
		);
		console.log("FAIL: benchmark regression threshold exceeded.");
		process.exit(1);
	}

	console.log("PASS: benchmark regression gate satisfied.");
	console.log("");
	console.log("Notes:");
	console.log("- Tokens are bytes/4 estimate, not real tokenizer output.");
	console.log("- Direct lane = full-body replace; marker lane = preserved-region splice.");
	console.log("- Wall-time excludes LLM round-trip; it is binary spawn + parse + write.");
};

main().catch((err) => {
	console.error(err);
	process.exit(1);
});
