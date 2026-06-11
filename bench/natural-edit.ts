#!/usr/bin/env bun
/**
 * Natural/unscripted benchmark harness slice.
 *
 * Defines 6 natural-user-prompt edit scenarios, runs each through Pi core
 * and Pi blitz lanes with normal free-form prompts (no exact JSON),
 * parses outcomes, and writes a json+md report with run artifacts preserved.
 *
 * Run:
 *   bun bench/natural-edit.ts --iters 1
 *   bun bench/natural-edit.ts --keep-temp  # preserve artifacts
 *   bun bench/natural-edit.ts --lane core  # run only core lane
 */

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ_BIN_DIR = join(REPO_ROOT, "zig-out/bin");
const DEFAULT_PI_BIN = "/home/kenzo/.local/bin/pi";
const DEFAULT_PI_BLITZ_DIST = "/home/kenzo/dev/pi-blitz/dist/index.js";
const DEFAULT_PI_BLITZ_SKILL = "/home/kenzo/dev/pi-blitz/skills/pi-blitz";
const STAMP = new Date().toISOString().replace(/[:.]/g, "-");

// ── Args ────────────────────────────────────────────────────────────────────

const argv = process.argv.slice(2);
const argFlag = (k: string, d: string) => {
	const idx = argv.findIndex((a) => a === k || a.startsWith(`${k}=`));
	if (idx < 0) return d;
	const v = argv[idx];
	if (v.includes("=")) return v.split("=").slice(1).join("=");
	return argv[idx + 1] ?? d;
};

const provider = argFlag("--provider", "anthropic");
const model = argFlag("--model", "claude-haiku-4-5");
const iters = parseInt(argFlag("--iters", "1"), 10);
const laneFilter = argFlag("--lane", "") as Lane | "";
const scenarioFilter = argFlag("--scenario", "");
const timeoutMs = parseInt(argFlag("--timeout-ms", "60000"), 10);
const keepTemp = argv.includes("--keep-temp");
const verbose = argv.includes("--verbose");
const piBin = argFlag("--pi-bin", process.env.PI_BIN ?? DEFAULT_PI_BIN);
const extension = argFlag(
	"--extension",
	process.env.PI_BLITZ_DIST ?? DEFAULT_PI_BLITZ_DIST,
);
const skill = argFlag(
	"--skill",
	process.env.PI_BLITZ_SKILL ?? DEFAULT_PI_BLITZ_SKILL,
);
const reportRoot = resolve(
	argFlag("--report-root", join(REPO_ROOT, "reports")),
);

// ── Outcome taxonomy ────────────────────────────────────────────────────────

type Outcome =
	| "blitz_mutated"
	| "core_mutated"
	| "noop"
	| "decline_or_no_mutation"
	| "incorrect";

// ── Lane types ──────────────────────────────────────────────────────────────

type Lane = "core" | "blitz";

// ── Scenario types ──────────────────────────────────────────────────────────

type ScenarioFile = {
	/** Relative path in the temp workdir. */
	path: string;
	/** Initial content to write. */
	before: string;
	/** Expected content after successful edit. */
	after: string;
};

type Scenario = {
	id: string;
	title: string;
	description: string;
	/** The natural prompt shown to the model — no exact JSON, no tool names. */
	prompt: string;
	/** Files that make up this scenario. */
	files: ScenarioFile[];
	/**
	 * If true, the scenario starts with the AFTER content already in place,
	 * testing that the model detects there's nothing to do.
	 */
	idempotent?: boolean;
};

// ── Result types ────────────────────────────────────────────────────────────

type RunItem = {
	lane: Lane;
	scenarioId: string;
	iter: number;
	outcome: Outcome;
	correct: boolean;
	filesMatch: boolean;
	wallMs: number;
	exitCode: number;
	timedOut: boolean;
	stderr: string;
	stdout: string;
	runDir: string;
	files: { path: string; gotSha: string; expectedSha: string; match: boolean }[];
};

type ScenarioResult = {
	scenarioId: string;
	title: string;
	lane: Lane;
	iterations: RunItem[];
	outcome: Outcome;
	outcomeLabel: string;
};

// ── Natural scenario definitions ────────────────────────────────────────────

/**
 * Helper: build the common "Use only the edit tool" preamble that tells the
 * model what lane it's in without prescribing exact tool-call JSON.
 */
const preamble = (lane: Lane, scenarioId: string): string =>
	lane === "core"
		? `You have the "edit" tool available. Use it to make the changes described below. Do not output any prose or explanation — just call the edit tool.`
		: `You have a set of AST-aware code editing tools available (pi_blitz_* tools). Use them to make the changes described below. Do not output any prose or explanation — just call the editing tool.`;

const FIXTURES_DIR = join(REPO_ROOT, "bench/fixtures-llm");

const SCENARIOS: Scenario[] = [
	// 1. Tiny exact — replace a single unique return line
	{
		id: "tiny-exact",
		title: "Tiny exact unique return-line replace",
		description: "Change the return of a 3-line function. Trivially unique match.",
		prompt: `Goal: In smallTarget, change the return value so it returns "hello " + name.toUpperCase() instead of "hi " + name. The function signature and everything else must stay the same.`,
		files: [
			{
				path: "small.ts",
				before: readFixture("small.ts"),
				after: readFixture("small.ts").replace(
					`  return "hi " + name;`,
					`  return "hello " + name.toUpperCase();`,
				),
			},
		],
	},

	// 2. Mixed config/doc — two files, different languages
	{
		id: "mixed-config-doc",
		title: "Mixed config/document edit across two files",
		description: "Update a TypeScript config key and an HTML title in the same session.",
		prompt: `I need two changes:

1. In config.ts change logLevel from "info" to "debug".
2. In index.html change the page title from "Blitz App" to "Blitz CLI".

Both files are in the working directory. Make both edits.`,
		files: [
			{
				path: "config.ts",
				before: readFixture("config.ts"),
				after: readFixture("config.ts").replace(
					'logLevel: "info"',
					'logLevel: "debug"',
				),
			},
			{
				path: "index.html",
				before: readFixture("index.html"),
				after: readFixture("index.html").replace(
					"<title>Blitz App</title>",
					"<title>Blitz CLI</title>",
				),
			},
		],
	},

	// 3. Same-file multi — three edits in one file
	{
		id: "same-file-multi",
		title: "Three edits in the same file",
		description: "Replace a return, insert a line after an anchor, wrap a function body in try/catch — all in multi.ts.",
		prompt: `Make three changes in multi.ts (all in the same file):

1. In adjust, replace \`return base;\` with \`return base + 1;\`.
2. In emit, insert a new line \`const markerUpper = value.toUpperCase();\` immediately after \`const marker = value;\`.
3. In risky, wrap the entire function body in try/catch. In the catch block, call \`throw error;\`.

Keep all other code exactly as-is.`,
		files: [
			{
				path: "multi.ts",
				before: readFixture("multi.ts"),
				after: (() => {
					const src = readFixture("multi.ts");
					return src
						.replace("  return base;", "  return base + 1;")
						.replace(
							"  const marker = value;\n",
							"  const marker = value;\n  const markerUpper = value.toUpperCase();\n",
						)
						.replace(
							`export function risky(value: number): number {\n  return value;\n}`,
							`export function risky(value: number): number {\n  try {\n    return value;\n  } catch (error) {\n    throw error;\n  }\n}`,
						);
				})(),
			},
		],
	},

	// 4. Structural body — wrap a large function body in try/catch
	{
		id: "structural-body",
		title: "Wrap function body in try/catch (structural)",
		description: "Wrap the ~280-line body of mediumCompute in try/catch without naming exact line text.",
		prompt: `In medium.ts, wrap the entire body of mediumCompute in a try/catch. Every existing statement inside the function body must stay in the try block unchanged. In the catch block, call console.error(error) then throw error. Keep the indentation of the original body at 2 spaces inside try.`,
		files: [
			{
				path: "medium.ts",
				before: readFixture("medium.ts"),
				after: (() => {
					const src = readFixture("medium.ts");
					const bodyStart = src.indexOf("\n") + 1;
					const bodyEnd = src.lastIndexOf("\n}");
					const body = src.slice(bodyStart, bodyEnd);
					const indented = body
						.split("\n")
						.map((l) => "  " + l)
						.join("\n");
					return src.slice(0, bodyStart) +
						"  try {\n" +
						indented +
						"\n  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n" +
						src.slice(bodyEnd);
				})(),
			},
		],
	},

	// 5. No-op idempotent — file already has the target change
	{
		id: "no-op-idempotent",
		title: "No-op / idempotent — change already applied",
		description: "File already has the target change; model should detect nothing to do.",
		prompt: `In small.ts, change the return of smallTarget from "hi " + name to "hello " + name.toUpperCase().`,
		files: [
			{
				path: "small.ts",
				before: readFixture("small.ts").replace(
					`  return "hi " + name;`,
					`  return "hello " + name.toUpperCase();`,
				),
				after: readFixture("small.ts").replace(
					`  return "hi " + name;`,
					`  return "hello " + name.toUpperCase();`,
				),
			},
		],
		idempotent: true,
	},

	// 6. Ambiguous/repeated-anchor safety — pick the last of 3 identical returns
	{
		id: "ambiguous-repeated-anchor",
		title: "Ambiguous: replace only the last return in a function with multiple returns",
		description:
			"In classify, three return statements return different values. Model must replace only the last one (positive → other) without touching negative or zero.",
		prompt: `In semantic.ts, inside the classify function, replace only the LAST return expression with "other". Leave the negative return and zero return completely unchanged.`,
		files: [
			{
				path: "semantic.ts",
				before: readFixture("semantic.ts"),
				after: readFixture("semantic.ts").replace(
					`  return "positive";`,
					`  return "other";`,
				),
			},
		],
	},
];

const sha256 = (text: string): string => {
	// Simple hex digest using Bun's built-in
	const buf = new Bun.CryptoHasher("sha256").update(text).digest();
	return Buffer.from(buf).toString("hex").slice(0, 16);
};

// ── Helpers ─────────────────────────────────────────────────────────────────

function readFixture(name: string): string {
	// Synchronous read at module init — ok for bench scripts
	const path = join(FIXTURES_DIR, name);
	return require("fs").readFileSync(path, "utf8") as string;
}

const countTokens = (text: string): number => {
	try {
		// Use tiktoken if available (matches existing harness)
		const { countTokens: tk } = require("./llm-tokenizer.ts") as {
			countTokens: (t: string) => number;
		};
		return tk(text);
	} catch {
		// Fallback: approximate with split
		return text.split(/\s+/).length;
	}
};

// ── Runner ───────────────────────────────────────────────────────────────────

const piArgs = (
	lane: Lane,
	prompt: string,
	sessionDir: string,
): string[] => {
	const common = [
		"--offline",
		"--print",
		"--no-context-files",
		"--no-prompt-templates",
		"--provider",
		provider,
		"--model",
		model,
		"--thinking",
		"off",
		"--session-dir",
		sessionDir,
	];
	if (lane === "core") {
		return [
			...common,
			"--no-skills",
			"--no-extensions",
			"--tools",
			"edit",
			prompt,
		];
	}
	return [
		...common,
		"--no-extensions",
		"--extension",
		extension,
		"--skill",
		skill,
		"--tools",
		[
			"pi_blitz_op",
			"pi_blitz_replace_body_span",
			"pi_blitz_insert_body_span",
			"pi_blitz_wrap_body",
			"pi_blitz_compose_body",
			"pi_blitz_multi_body",
			"pi_blitz_patch",
			"pi_blitz_try_catch",
			"pi_blitz_replace_return",
		].join(","),
		prompt,
	];
};

const runPi = (
	lane: Lane,
	prompt: string,
	cwd: string,
): { ms: number; status: number; stdout: string; stderr: string; timedOut: boolean } => {
	const sessionDir = join(cwd, `sessions-${lane}`);
	const args = piArgs(lane, prompt, sessionDir);
	const t0 = performance.now();
	const env = {
		...process.env,
		PATH: `${BLITZ_BIN_DIR}:${process.env.PATH ?? ""}`,
		PI_BLITZ_TOOL_PROFILE: "full",
	};
	const r = spawnSync(piBin, args, {
		cwd,
		env,
		encoding: "utf8",
		maxBuffer: 200 * 1024 * 1024,
		timeout: timeoutMs,
		killSignal: "SIGTERM",
	});
	const ms = performance.now() - t0;
	return {
		ms,
		status: r.status ?? -1,
		stdout: r.stdout ?? "",
		stderr: r.stderr ?? "",
		timedOut: r.error?.name === "Error" && /ETIMEDOUT/.test(String(r.error)),
	};
};

const classifyOutcome = (
	lane: Lane,
	allFilesMatch: boolean,
	idempotent: boolean,
	exitCode: number,
	timedOut: boolean,
): Outcome => {
	if (timedOut) return "incorrect";
	if (idempotent && allFilesMatch && exitCode === 0) return "noop";
	if (allFilesMatch && exitCode === 0) {
		return lane === "core" ? "core_mutated" : "blitz_mutated";
	}
	if (!timedOut && exitCode !== 0) return "decline_or_no_mutation";
	return "incorrect";
};

// ── Main ────────────────────────────────────────────────────────────────────

const main = async () => {
	console.log(`# Natural edit harness`);
	console.log(`Provider: ${provider} / Model: ${model}`);
	console.log(`Iterations: ${iters}`);
	console.log(`Timeout: ${timeoutMs}ms`);
	console.log(`Pi: ${piBin}`);
	console.log(`Blitz PATH prepend: ${BLITZ_BIN_DIR}`);
	console.log(`Scenarios: ${SCENARIOS.length}`);

	const allResults: ScenarioResult[] = [];
	const runRecords: RunItem[] = [];

	for (const scenario of SCENARIOS) {
		if (scenarioFilter && !scenario.id.includes(scenarioFilter)) continue;

		for (const lane of (["core", "blitz"] as Lane[])) {
			if (laneFilter && lane !== laneFilter) continue;

			const iterations: RunItem[] = [];

			for (let iter = 0; iter < iters; iter++) {
				const runDir = keepTemp
					? join(reportRoot, "natural-edit-runs", `${scenario.id}__${lane}__${iter}__${STAMP}`)
					: await mkdtemp(join(tmpdir(), `natural-edit-`));
				const workDir = join(runDir, "work");
				await mkdir(workDir, { recursive: true });
				await mkdir(join(runDir, "sessions"), { recursive: true });

				// Write initial files
				for (const f of scenario.files) {
					const fp = join(workDir, f.path);
					await mkdir(dirname(fp), { recursive: true });
					await writeFile(fp, f.before, "utf8");
				}

				// Build full prompt
				const prompt = `${preamble(lane, scenario.id)}\n\nWorking directory contains: ${scenario.files.map((f) => f.path).join(", ")}.\n\n${scenario.prompt}\n\nMake the edit using your available tool. No prose. Just the tool call.`;

				if (verbose) {
					console.error(`\n[${scenario.id}][${lane}][iter ${iter}] running...`);
				}

				const r = runPi(lane, prompt, workDir);

				// Check file results
				const fileResults = scenario.files.map((f) => {
					const fp = join(workDir, f.path);
					const got = existsSync(fp) ? readFile(fp, "utf8") : "";
					const gotContent = typeof got === "string" ? got : "";
					return {
						path: f.path,
						gotSha: sha256(gotContent),
						expectedSha: sha256(f.after),
						match: gotContent === f.after,
					};
				});

				const allMatch = fileResults.every((fr) => fr.match);
				const outcome = classifyOutcome(
					lane,
					allMatch,
					scenario.idempotent ?? false,
					r.status,
					r.timedOut,
				);

				const item: RunItem = {
					lane,
					scenarioId: scenario.id,
					iter,
					outcome,
					correct: allMatch,
					filesMatch: allMatch,
					wallMs: r.ms,
					exitCode: r.status,
					timedOut: r.timedOut,
					stderr: r.stderr,
					stdout: r.stdout,
					runDir,
					files: fileResults,
				};

				iterations.push(item);
				runRecords.push(item);

				if (!keepTemp) {
					await rm(runDir, { recursive: true, force: true });
				}

				if (verbose) {
					console.error(
						`[${scenario.id}][${lane}][iter ${iter}] outcome=${outcome} wall=${r.ms.toFixed(0)}ms exit=${r.status}`,
					);
				}
			}

			const dominantOutcome = iterations.reduce<{ outcome: Outcome; count: number }>(
				(best, i) => {
					const count = iterations.filter((x) => x.outcome === i.outcome).length;
					return count > best.count ? { outcome: i.outcome, count } : best;
				},
				{ outcome: iterations[0]?.outcome ?? "incorrect", count: 0 },
			).outcome;

			allResults.push({
				scenarioId: scenario.id,
				title: scenario.title,
				lane,
				iterations,
				outcome: dominantOutcome,
				outcomeLabel: dominantOutcome,
			});

			const outcomeLabel = dominantOutcome;
			const icon = outcomeLabel === "blitz_mutated" || outcomeLabel === "core_mutated"
				? "✓"
				: outcomeLabel === "noop"
					? "○"
					: outcomeLabel === "decline_or_no_mutation"
						? "△"
						: "✗";
			console.log(
				`  ${icon} ${scenario.id} / ${lane}: ${outcomeLabel} (${iterations.filter((i) => i.correct).length}/${iters} correct)`,
			);
		}
	}

	// ── Report ────────────────────────────────────────────────────────────────

	const report = {
		generatedAt: new Date().toISOString(),
		provider,
		model,
		iters,
		timeoutMs,
		piBin,
		blitzBinPathPrepend: BLITZ_BIN_DIR,
		scenarios: SCENARIOS.map((s) => ({
			id: s.id,
			title: s.title,
			description: s.description,
			idempotent: s.idempotent ?? false,
			files: s.files.map((f) => ({
				path: f.path,
				beforeSha: sha256(f.before),
				afterSha: sha256(f.after),
			})),
		})),
		results: allResults,
		runs: runRecords,
	};

	const reportDir = resolve(reportRoot, "natural-edit-harness");
	await mkdir(reportDir, { recursive: true });

	const jsonPath = join(reportDir, `natural-edit-${STAMP}.json`);
	const mdPath = join(reportDir, `natural-edit-${STAMP}.md`);

	await writeFile(jsonPath, JSON.stringify(report, null, 2));

	const md = generateMdReport(report);
	await writeFile(mdPath, md);

	console.log(`\nReport JSON: ${jsonPath}`);
	console.log(`Report MD:   ${mdPath}`);
};

const generateMdReport = (report: {
	generatedAt: string;
	provider: string;
	model: string;
	iters: number;
	timeoutMs: number;
	piBin: string;
	blitzBinPathPrepend: string;
	scenarios: Array<{
		id: string;
		title: string;
		description: string;
		idempotent: boolean;
		files: Array<{ path: string; beforeSha: string; afterSha: string }>;
	}>;
	results: ScenarioResult[];
	runs: RunItem[];
}): string => {
	const lines: string[] = [];
	lines.push("# Natural edit harness report");
	lines.push("");
	lines.push(`Generated: ${report.generatedAt}`);
	lines.push(`Provider: ${report.provider}`);
	lines.push(`Model: ${report.model}`);
	lines.push(`Iterations: ${report.iters}`);
	lines.push(`Timeout: ${report.timeoutMs}ms`);
	lines.push(`Pi: ${report.piBin}`);
	lines.push(`Blitz PATH prepend: ${report.blitzBinPathPrepend}`);
	lines.push("");

	// Summary table
	lines.push("## Results");
	lines.push("");
	lines.push(
		"| Scenario | Description | Lane | Outcome | Correct / Iters | Wall ms (median) |",
	);
	lines.push("|---|---|---|---|---:|");
	for (const r of report.results) {
		const s = report.scenarios.find((s) => s.id === r.scenarioId);
		const medianWall = [...r.iterations]
			.sort((a, b) => a.wallMs - b.wallMs)
			[Math.floor(r.iterations.length / 2)]?.wallMs ?? 0;
		lines.push(
			`| ${r.scenarioId} | ${s?.description ?? ""} | ${r.lane} | ${r.outcomeLabel} | ${r.iterations.filter((i) => i.correct).length}/${r.iterations.length} | ${medianWall.toFixed(0)} |`,
		);
	}
	lines.push("");

	// Detailed per-scenario breakdown
	lines.push("## Detailed breakdown");
	lines.push("");
	for (const s of report.scenarios) {
		lines.push(`### ${s.id}: ${s.title}`);
		lines.push("");
		lines.push(`> ${s.description}`);
		lines.push("");
		lines.push(`Idempotent: ${s.idempotent}`);
		lines.push(`Files: ${s.files.map((f) => `${f.path} (sha: ${f.afterSha})`).join(", ")}`);
		lines.push("");

		const results = report.results.filter((r) => r.scenarioId === s.id);
		for (const r of results) {
			lines.push(`**Lane: ${r.lane}** — outcome: \`${r.outcomeLabel}\``);
			lines.push("");
			lines.push("| Iter | Outcome | Correct | Exit | Wall ms | Files match |");
			lines.push("|---|---|---:|---:|---:|---:|");
			for (const run of r.iterations) {
				lines.push(
					`| ${run.iter} | ${run.outcome} | ${run.correct ? "yes" : "no"} | ${run.exitCode}${run.timedOut ? " (timeout)" : ""} | ${run.wallMs.toFixed(0)} | ${run.files.filter((f) => f.match).length}/${run.files.length} |`,
				);
			}
			lines.push("");
		}
	}

	// Overall summary
	lines.push("## Outcome summary");
	lines.push("");
	const outcomeCounts: Record<string, number> = {};
	for (const run of report.runs) {
		outcomeCounts[run.outcome] = (outcomeCounts[run.outcome] ?? 0) + 1;
	}
	for (const [outcome, count] of Object.entries(outcomeCounts).sort()) {
		lines.push(`- \`${outcome}\`: ${count}`);
	}
	lines.push("");

	const totalCorrect = report.runs.filter((r) => r.correct).length;
	const total = report.runs.length;
	lines.push(`**Correct: ${totalCorrect}/${total} (${(totalCorrect / total * 100).toFixed(1)}%)**`);

	return lines.join("\n");
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
