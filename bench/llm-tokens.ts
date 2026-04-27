#!/usr/bin/env bun
/**
 * blitz vs core edit token comparison using a real LLM tokenizer.
 *
 * Uses cl100k_base via tiktoken (same family as gpt-4o/gpt-5.x text input).
 * Computes the LLM-output token cost of the tool call payload:
 *   - core edit:  { file, oldText, newText } where oldText/newText are line-padded with N context lines.
 *   - blitz edit: { file, replace|after, snippet }.
 *
 * Reports vs three baselines:
 *   - full-symbol  (worst case core)
 *   - realistic    (3 context lines on each side)
 *   - minimal      (byte-level diff window)
 *
 * Run:
 *   bun bench/llm-tokens.ts
 */

import { mkdtemp, readFile, writeFile, rm } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ = `${REPO_ROOT}/zig-out/bin/blitz`;
const ITER = 5;
const CONTEXT_LINES = 3;

type Case = {
	id: string;
	lane: "direct" | "marker";
	makeFiles: () => { fixture: string; symbol: string; original: string; expected: string; snippet: string };
};

const median = (xs: number[]) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)]!;
const pct = (n: number) => `${n.toFixed(1)}%`;

const lineStart = (buf: string, byte: number): number => {
	let i = Math.min(byte, buf.length);
	while (i > 0 && buf[i - 1] !== "\n") i -= 1;
	return i;
};

const lineEnd = (buf: string, byte: number): number => {
	let i = Math.min(byte, buf.length);
	while (i < buf.length && buf[i] !== "\n") i += 1;
	if (i < buf.length) i += 1;
	return i;
};

const expandUp = (buf: string, start: number, lines: number): number => {
	let i = start;
	for (let n = 0; n < lines && i > 0; n++) {
		i -= 1;
		if (i > 0) i = lineStart(buf, i);
	}
	return i;
};

const expandDown = (buf: string, end: number, lines: number): number => {
	let i = end;
	for (let n = 0; n < lines && i < buf.length; n++) i = lineEnd(buf, i + 1);
	return i;
};

const computeAnchor = (before: string, after: string, ctxLines: number) => {
	let prefix = 0;
	const minLen = Math.min(before.length, after.length);
	while (prefix < minLen && before[prefix] === after[prefix]) prefix += 1;
	let beforeEnd = before.length;
	let afterEnd = after.length;
	while (beforeEnd > prefix && afterEnd > prefix && before[beforeEnd - 1] === after[afterEnd - 1]) {
		beforeEnd -= 1;
		afterEnd -= 1;
	}
	const oldStart = expandUp(before, lineStart(before, prefix), ctxLines);
	const oldEnd = expandDown(before, lineEnd(before, beforeEnd), ctxLines);
	const newStart = expandUp(after, lineStart(after, prefix), ctxLines);
	const newEnd = expandDown(after, lineEnd(after, afterEnd), ctxLines);
	return {
		minimalOld: before.slice(prefix, beforeEnd),
		minimalNew: after.slice(prefix, afterEnd),
		realisticOld: before.slice(oldStart, oldEnd),
		realisticNew: after.slice(newStart, newEnd),
	};
};

const runBlitz = (file: string, snippet: string, symbol: string, mode: "after" | "replace") => {
	const t0 = performance.now();
	const r = spawnSync(BLITZ, ["edit", file, "--snippet", "-", `--${mode}`, symbol, "--json"], {
		input: snippet,
		encoding: "utf8",
		maxBuffer: 200 * 1024 * 1024,
	});
	const ms = performance.now() - t0;
	if (r.status !== 0) throw new Error(`blitz failed (${r.status}): ${r.stderr}`);
	return { ms, stdout: r.stdout, stderr: r.stderr };
};

const buildHugeSymbol = (target: number) => {
	const lines = ["function hugeCompute(seed: number): number {", "  let total = seed;"];
	let i = 0;
	while (lines.join("\n").length < target - 40) {
		lines.push(`  total += (${i} % 17) * (${i} % 31);`);
		i += 1;
	}
	lines.push("  return total;");
	lines.push("}");
	const original = lines.join("\n") + "\n";
	const expected = original.replace("  return total;", "  return total + 1;");
	const snippet = "function hugeCompute(seed: number): number {\n  // ... existing code ...\n  return total + 1;\n}";
	return { fixture: "huge.ts", symbol: "hugeCompute", original, expected, snippet };
};

const buildSmallSymbol = () => {
	const original = `const helper = makeHelper();

function smallTarget(name: string): string {
  return "hi " + name;
}

const after = otherCall();
`;
	const expected = original.replace(
		`function smallTarget(name: string): string {
  return "hi " + name;
}`,
		`function smallTarget(name: string): string {
  return "hello " + name.toUpperCase();
}`,
	);
	const snippet = `function smallTarget(name: string): string {
  return "hello " + name.toUpperCase();
}`;
	return { fixture: "small.ts", symbol: "smallTarget", original, expected, snippet };
};

const buildMediumSymbol = () => {
	const original = `function handleRequest(req: Request): Response {
  const url = new URL(req.url);
  const path = url.pathname;
  const method = req.method.toUpperCase();

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
}
`;
	const snippet = `function handleRequest(req: Request): Response {
  // ... existing code ...
  if (method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { "access-control-allow-origin": "*" } });
  }
  // ... existing code ...
}`;
	const expected = original.replace(
		`  const method = req.method.toUpperCase();

  if (method !== "GET"`,
		`  const method = req.method.toUpperCase();

  if (method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { "access-control-allow-origin": "*" } });
  }
  if (method !== "GET"`,
	);
	return { fixture: "medium.ts", symbol: "handleRequest", original, expected, snippet };
};

const CASES: Case[] = [
	{ id: "small/wrap-tail", lane: "direct", makeFiles: buildSmallSymbol },

	{ id: "huge-100k/marker-tail", lane: "marker", makeFiles: () => buildHugeSymbol(100_000) },
	{ id: "huge-500k/marker-tail", lane: "marker", makeFiles: () => buildHugeSymbol(500_000) },
];

const tokenizeToolCall = (name: string, args: Record<string, unknown>) =>
	countTokens(JSON.stringify({ tool: name, params: args }));

const main = async () => {
	const dir = await mkdtemp(join(tmpdir(), "blitz-llm-tokens-"));
	type Row = {
		case: string;
		lane: string;
		blitzTokens: number;
		coreFullSymbolTokens: number;
		coreRealisticTokens: number;
		coreMinimalTokens: number;
		realisticSavedPct: number;
		fullSymbolSavedPct: number;
		blitzMs: number;
	};
	const rows: Row[] = [];

	for (const c of CASES) {
		const fx = c.makeFiles();
		const blitzMsList: number[] = [];
		const blitzPath = join(dir, `${c.id.replace(/\//g, "_")}.ts`);
		const symbolBefore = fx.original.indexOf(`function ${fx.symbol}`);
		// crude full symbol body extraction (single function)
		const symStart = symbolBefore;
		let braces = 0;
		let symEnd = symStart;
		while (symEnd < fx.original.length) {
			const ch = fx.original[symEnd]!;
			if (ch === "{") braces += 1;
			else if (ch === "}") {
				braces -= 1;
				if (braces === 0) {
					symEnd += 1;
					break;
				}
			}
			symEnd += 1;
		}
		const oldFullBody = fx.original.slice(symStart, symEnd);
		const newFullBodyMatch = fx.expected.indexOf(`function ${fx.symbol}`);
		let newSymEnd = newFullBodyMatch;
		braces = 0;
		while (newSymEnd < fx.expected.length) {
			const ch = fx.expected[newSymEnd]!;
			if (ch === "{") braces += 1;
			else if (ch === "}") {
				braces -= 1;
				if (braces === 0) {
					newSymEnd += 1;
					break;
				}
			}
			newSymEnd += 1;
		}
		const newFullBody = fx.expected.slice(newFullBodyMatch, newSymEnd);

		const anchors = computeAnchor(fx.original, fx.expected, CONTEXT_LINES);

		const blitzTokens = tokenizeToolCall("pi_blitz_edit", {
			file: blitzPath,
			[c.lane === "marker" ? "replace" : "replace"]: fx.symbol,
			snippet: fx.snippet,
		});
		const coreFullTokens = tokenizeToolCall("edit", {
			file: blitzPath,
			oldText: oldFullBody,
			newText: newFullBody,
		});
		const coreRealisticTokens = tokenizeToolCall("edit", {
			file: blitzPath,
			oldText: anchors.realisticOld,
			newText: anchors.realisticNew,
		});
		const coreMinimalTokens = tokenizeToolCall("edit", {
			file: blitzPath,
			oldText: anchors.minimalOld,
			newText: anchors.minimalNew,
		});

		for (let i = 0; i < ITER; i++) {
			await writeFile(blitzPath, fx.original, "utf8");
			const r = runBlitz(blitzPath, fx.snippet, fx.symbol, "replace");
			blitzMsList.push(r.ms);
			const got = await readFile(blitzPath, "utf8");
			if (got !== fx.expected) throw new Error(`golden mismatch for ${c.id}`);
		}

		rows.push({
			case: c.id,
			lane: c.lane,
			blitzTokens,
			coreFullSymbolTokens: coreFullTokens,
			coreRealisticTokens: coreRealisticTokens,
			coreMinimalTokens: coreMinimalTokens,
			realisticSavedPct: 100 * (1 - blitzTokens / coreRealisticTokens),
			fullSymbolSavedPct: 100 * (1 - blitzTokens / coreFullTokens),
			blitzMs: median(blitzMsList),
		});
	}

	console.log("# blitz vs core edit — real-tokenizer LLM token bench (cl100k_base)");
	console.log(`Iterations/case: ${ITER}, context lines: ${CONTEXT_LINES}\n`);
	console.log("| Case | Lane | blitz tok | core full | core realistic | core minimal | saved vs realistic | saved vs full | blitz ms |");
	console.log("|---|---|---:|---:|---:|---:|---:|---:|---:|");
	for (const r of rows) {
		console.log(
			`| ${r.case} | ${r.lane} | ${r.blitzTokens} | ${r.coreFullSymbolTokens} | ${r.coreRealisticTokens} | ${r.coreMinimalTokens} | ${pct(r.realisticSavedPct)} | ${pct(r.fullSymbolSavedPct)} | ${r.blitzMs.toFixed(2)} |`,
		);
	}

	const realisticAvg = rows.reduce((a, r) => a + r.realisticSavedPct, 0) / rows.length;
	const fullAvg = rows.reduce((a, r) => a + r.fullSymbolSavedPct, 0) / rows.length;
	console.log(`\nAverage saved vs realistic anchor (3-line context): ${pct(realisticAvg)}`);
	console.log(`Average saved vs full-symbol upper bound: ${pct(fullAvg)}`);
	console.log("\nFastedit reference range: 43.6%-54.3% saved vs core edit (their published table).");

	await rm(dir, { recursive: true, force: true });
	releaseTokenizer();
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
