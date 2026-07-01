#!/usr/bin/env bun
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

type Payload = Record<string, unknown>;

type CaseDef = {
	id: "rb" | "ia";
	name: string;
	fileName: string;
	before: string;
	expected: string;
	compact: (file: string) => Payload;
	verbose: (file: string) => Payload;
	coreEdit: (file: string) => Payload;
};

type Row = {
	case: string;
	lane: "compact_cli" | "verbose_apply" | "pi_core_payload_only";
	requestBytes: number;
	requestTokens: number;
	outputBytes: number | null;
	outputTokens: number | null;
	correct: boolean | "not-run";
	omitsBloat: boolean | "n/a";
};

const repoRoot = resolve(process.cwd());
const blitzBin = join(repoRoot, "zig-out/bin/blitz");
const reportPath = join(repoRoot, ".pi/reports/compact-ir-cli-payload-20260610.md");

const cases: CaseDef[] = [
	{
		id: "rb",
		name: "replace body via compact rb/set_body",
		fileName: "rb.ts",
		before: `function compact(value: number): number {\n  return value * 2;\n}\n`,
		expected: `function compact(value: number): number {\n  return value + 1;\n}\n`,
		compact: (file) => ({ v: 1, f: file, ops: [{ op: "rb", t: { k: "function", n: "compact" }, s: "\n  return value + 1;\n" }] }),
		verbose: (file) => ({ version: 1, file, operation: "set_body", target: { kind: "function", symbol: "compact" }, edit: "\n  return value + 1;\n" }),
		coreEdit: (file) => ({ path: file, oldText: "  return value * 2;", newText: "  return value + 1;" }),
	},
	{
		id: "ia",
		name: "insert after symbol via compact ia",
		fileName: "ia.ts",
		before: `function first(): number { return 1; }\nfunction last(): number { return 2; }\n`,
		expected: `function first(): number { return 1; }\nfunction inserted(): number { return 3; }\n\nfunction last(): number { return 2; }\n`,
		compact: (file) => ({ v: 1, f: file, ops: [["ia", "function", "first", "\nfunction inserted(): number { return 3; }\n"]] }),
		verbose: (file) => ({ version: 1, file, operation: "insert_after_symbol", target: { kind: "function", symbol: "first" }, edit: "\nfunction inserted(): number { return 3; }\n" }),
		coreEdit: (file) => ({ path: file, oldText: "function first(): number { return 1; }", newText: "function first(): number { return 1; }\nfunction inserted(): number { return 3; }\n" }),
	},
];

function stableJson(value: unknown): string {
	return JSON.stringify(value);
}

function stats(payload: unknown) {
	const json = stableJson(payload);
	return { json, bytes: Buffer.byteLength(json), tokens: countTokens(json) };
}

function runApply(request: Payload, before: string, expected: string, file: string) {
	writeFileSync(file, before);
	const req = stableJson(request);
	const proc = spawnSync(blitzBin, ["apply", "--edit", "-", "--json"], { cwd: repoRoot, input: req, encoding: "utf8" });
	const stdout = proc.stdout.toString();
	const stderr = proc.stderr.toString();
	if (proc.status !== 0) {
		throw new Error(`blitz apply failed (${proc.status})\nstdout=${stdout}\nstderr=${stderr}`);
	}
	const after = readFileSync(file, "utf8");
	const parsed = JSON.parse(stdout);
	return { stdout: stdout.trim(), correct: after === expected, parsed };
}

const rows: Row[] = [];
const details: string[] = [];

for (const c of cases) {
	const caseDir = mkdtempSync(join(tmpdir(), `blitz-${c.id}-payload-`));
	const compactFile = join(caseDir, `compact-${c.fileName}`);
	const verboseFile = join(caseDir, `verbose-${c.fileName}`);
	const coreFile = join(caseDir, `core-${c.fileName}`);

	const compactReq = c.compact(compactFile);
	const verboseReq = c.verbose(verboseFile);
	const coreReq = c.coreEdit(coreFile);

	const compactRun = runApply(compactReq, c.before, c.expected, compactFile);
	const verboseRun = runApply(verboseReq, c.before, c.expected, verboseFile);

	for (const [lane, req, run] of [
		["compact_cli", compactReq, compactRun],
		["verbose_apply", verboseReq, verboseRun],
	] as const) {
		const reqStats = stats(req);
		const outStats = stats(run.parsed);
		const hasBloat = ["routeDecision", "metrics", "diffSummary"].some((field) => Object.hasOwn(run.parsed, field));
		rows.push({
			case: c.id,
			lane,
			requestBytes: reqStats.bytes,
			requestTokens: reqStats.tokens,
			outputBytes: outStats.bytes,
			outputTokens: outStats.tokens,
			correct: run.correct,
			omitsBloat: !hasBloat,
		});
	}

	const coreStats = stats(coreReq);
	rows.push({
		case: c.id,
		lane: "pi_core_payload_only",
		requestBytes: coreStats.bytes,
		requestTokens: coreStats.tokens,
		outputBytes: null,
		outputTokens: null,
		correct: "not-run",
		omitsBloat: "n/a",
	});

	details.push(`### ${c.id}: ${c.name}\n\n- Compact stdout: \`${compactRun.stdout}\`\n- Verbose output has bloat fields: ${["routeDecision", "metrics", "diffSummary"].filter((field) => Object.hasOwn(verboseRun.parsed, field)).join(", ")}\n- Compact output has bloat fields: ${["routeDecision", "metrics", "diffSummary"].filter((field) => Object.hasOwn(compactRun.parsed, field)).join(", ") || "none"}\n`);
}

const lines: string[] = [];
lines.push("# Compact IR CLI payload/token benchmark-only evidence");
lines.push("");
lines.push("Date: 2026-06-10");
lines.push("Status: benchmark-only CLI payload/token evidence; not product-real Pi/Tokscale evidence; not default-ready evidence.");
lines.push("");
lines.push("## Method");
lines.push("");
lines.push("Script: `bun bench/compact-ir-cli-payload.ts`");
lines.push("Command under test: `zig-out/bin/blitz apply --edit - --json`");
lines.push("Cases: representative `rb` replace-body and `ia` insert-after-symbol TypeScript fixtures created under `/tmp`.");
lines.push("Token count: repo-local `bench/llm-tokenizer.ts` rough cl100k payload token count. This is payload-only tokenizer evidence, not provider/Tokscale accounting.");
lines.push("Pi core comparison: equivalent `functions.edit`-style payload JSON bytes/tokens only. Core payloads were not executed here, no Pi session used, no Tokscale used.");
lines.push("");
lines.push("## Results");
lines.push("");
lines.push("| case | lane | req bytes | req tokens | output bytes | output tokens | correct | omits routeDecision/metrics/diffSummary |");
lines.push("|---|---|---:|---:|---:|---:|---|---|");
for (const row of rows) {
	lines.push(`| ${row.case} | ${row.lane} | ${row.requestBytes} | ${row.requestTokens} | ${row.outputBytes ?? "n/a"} | ${row.outputTokens ?? "n/a"} | ${row.correct} | ${row.omitsBloat} |`);
}
lines.push("");
lines.push("## Fixture run details");
lines.push("");
lines.push(...details);
lines.push("## Caveats");
lines.push("");
lines.push("- Benchmark-only CLI evidence: compact IR is measured through local Blitz CLI, not exposed as a product-real Pi tool route in `/home/kenzo/dev/pi-blitz`.");
lines.push("- No tmux matrix, provider run, Pi JSONL, or Tokscale validation occurred in this slice.");
lines.push("- Core row is payload-only JSON comparison for equivalent transformation, not executed core edit output or provider-visible session total.");
lines.push("- Default-ready/product-real Pi claims remain blocked until compact route is exposed in Pi, benchmarked with real Pi/tmux/Tokscale, and compared against core across accepted correct rows.");
lines.push("");
lines.push("## Next step");
lines.push("");
lines.push("Expose compact CLI IR through an explicit Pi route/tool in `/home/kenzo/dev/pi-blitz` only in a later authorized slice, then run true Pi/tmux/Tokscale compact-vs-core rows before any default-readiness claim.");
lines.push("");
mkdirSync(join(repoRoot, "reports"), { recursive: true });
writeFileSync(reportPath, `${lines.join("\n")}\n`);

console.log(`wrote ${reportPath}`);
for (const row of rows) {
	console.log(`${row.case}\t${row.lane}\treq=${row.requestTokens}tok/${row.requestBytes}B\tout=${row.outputTokens ?? "n/a"}tok/${row.outputBytes ?? "n/a"}B\tcorrect=${row.correct}`);
}
releaseTokenizer();
