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
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import {
	copyFile,
	mkdir,
	mkdtemp,
	readFile,
	rm,
	writeFile,
} from "node:fs/promises";
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
const tokscaleAlias = argv.includes("--tokscale");
const tokscaleMode = tokscaleAlias
	? "validate"
	: argFlag("--tokscale-mode", "not-run");
const toolProfile = argFlag("--tool-profile", "");
const keepTemp = argv.includes("--keep-temp");
const verbose = argv.includes("--verbose");
const selfCheckParser = argv.includes("--self-check-parser");
const selfCheckSessionJsonl = argFlag("--session-jsonl", "");
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

/** Canonical route outcome taxonomy — never infer fallback as blitz. */
type RouteOutcome =
	| "blitz"
	| "core"
	| "decline"
	| "fallback"
	| "clarify"
	| "noop"
	| "incorrect";

const classifyRouteOutcome = (outcome: Outcome, _lane: Lane): RouteOutcome => {
	switch (outcome) {
		case "blitz_mutated":
			return "blitz";
		case "core_mutated":
			return "core";
		case "noop":
			return "noop";
		case "decline_or_no_mutation":
			return "decline";
		case "incorrect":
			return "incorrect";
	}
};

type Provenance = {
	extensionPath: string;
	skillPath: string;
	visibleTools: string;
	toolProfile: string;
};

type SessionJsonl = {
	/** Path to session JSONL file. */
	path: string;
	/** sha256(16) hex digest of file content. */
	hash: string;
	/** Independent parser totals from Pi session JSONL assistant messages. */
	totals: SessionTotals;
};

type SessionTotals = {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	messages: number;
	cost: number;
};

type TokscaleAudit = {
	mode: string;
	status: "not-run" | "ok" | "missing" | "failed" | "mismatch";
	match: boolean | null;
	deltas: Record<string, number> | null;
	totals: Record<string, number | null> | null;
	details: string;
};

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
	provider: string;
	model: string;
	lane: Lane;
	scenarioId: string;
	iter: number;
	outcome: Outcome;
	routeOutcome: RouteOutcome;
	/** True only if correct && exitCode===0 && !timedOut && (tokscale match || not-run). */
	accepted: boolean;
	correct: boolean;
	filesMatch: boolean;
	wallMs: number;
	exitCode: number;
	timedOut: boolean;
	stderr: string;
	stdout: string;
	runDir: string;
	sessionDir: string;
	sessionJsonl: SessionJsonl | null;
	tokscale: TokscaleAudit;
	provenance: Provenance;
	files: {
		path: string;
		gotSha: string;
		expectedSha: string;
		match: boolean;
	}[];
};

type ScenarioResult = {
	scenarioId: string;
	title: string;
	lane: Lane;
	iterations: RunItem[];
	outcome: Outcome;
	outcomeLabel: string;
	routeOutcome: RouteOutcome;
	accepted: boolean;
	totalIters: number;
	correctIters: number;
};

// ── Natural scenario definitions ────────────────────────────────────────────

/**
 * Helper: build the common "Use only the edit tool" preamble that tells the
 * model what lane it's in without prescribing exact tool-call JSON.
 */
const preamble = (lane: Lane, _scenarioId: string): string =>
	lane === "core"
		? `You have the "edit" tool available. Use it to make the changes described below. Use the file contents provided in this prompt to choose oldText/newText. Call the edit tool, then output exactly done.`
		: `You have only the "blitz_edit" tool available. Use it to make the changes described below. Use the file contents provided in this prompt to choose safe edits. Call blitz_edit, then output exactly done.`;

const FIXTURES_DIR = join(REPO_ROOT, "bench/fixtures-llm");

const SCENARIOS: Scenario[] = [
	// 1. Tiny exact — replace a single unique return line
	{
		id: "tiny-exact",
		title: "Tiny exact unique return-line replace",
		description:
			"Change the return of a 3-line function. Trivially unique match.",
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
		description:
			"Update a TypeScript config key and an HTML title in the same session.",
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
		description:
			"Replace a return, insert a line after an anchor, wrap a function body in try/catch — all in multi.ts.",
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
		description:
			"Wrap the ~280-line body of mediumCompute in try/catch without naming exact line text.",
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
					return (
						src.slice(0, bodyStart) +
						"  try {\n" +
						indented +
						"\n  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n" +
						src.slice(bodyEnd)
					);
				})(),
			},
		],
	},

	// 5. No-op idempotent — file already has the target change
	{
		id: "no-op-idempotent",
		title: "No-op / idempotent — change already applied",
		description:
			"File already has the target change; model should detect nothing to do.",
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
		title:
			"Ambiguous: replace only the last return in a function with multiple returns",
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

const sha256 = (text: string): string =>
	createHash("sha256").update(text).digest("hex").slice(0, 16);

const tokNotRun = (): TokscaleAudit => ({
	mode: tokscaleMode,
	status: "not-run",
	match: null,
	deltas: null,
	totals: null,
	details: "Tokscale not requested",
});

const tokFailure = (
	status: TokscaleAudit["status"],
	details: string,
): TokscaleAudit => ({
	mode: tokscaleMode,
	status,
	match: false,
	deltas: null,
	totals: null,
	details,
});

const numberFrom = (value: unknown): number | null =>
	typeof value === "number" && Number.isFinite(value) ? value : null;

type UsageShape = Record<string, unknown>;

const usageNumber = (usage: UsageShape, keys: string[]): number => {
	for (const key of keys) {
		const value = usage[key];
		if (typeof value === "number" && Number.isFinite(value)) return value;
	}
	return 0;
};

const usageCost = (usage: UsageShape): number => {
	const direct = usage.cost;
	if (typeof direct === "number" && Number.isFinite(direct)) return direct;
	if (direct && typeof direct === "object") {
		const total = (direct as Record<string, unknown>).total;
		if (typeof total === "number" && Number.isFinite(total)) return total;
	}
	return 0;
};

const parseSessionJsonlTotals = (content: string): SessionTotals => {
	const totals: SessionTotals = {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		messages: 0,
		cost: 0,
	};
	for (const line of content.split("\n")) {
		if (!line.trim()) continue;
		let event: Record<string, unknown>;
		try {
			event = JSON.parse(line) as Record<string, unknown>;
		} catch {
			continue;
		}
		if (event.type !== "message") continue;
		const message = event.message as Record<string, unknown> | undefined;
		if (!message || message.role !== "assistant") continue;
		totals.messages += 1;
		const usage = message.usage as UsageShape | undefined;
		if (!usage) continue;
		totals.input += usageNumber(usage, [
			"input",
			"inputTokens",
			"input_tokens",
		]);
		totals.output += usageNumber(usage, [
			"output",
			"outputTokens",
			"output_tokens",
		]);
		totals.cacheRead += usageNumber(usage, [
			"cacheRead",
			"cache_read",
			"cachedInputTokens",
			"cached_input_tokens",
		]);
		totals.cacheWrite += usageNumber(usage, [
			"cacheWrite",
			"cache_write",
			"cacheCreationInputTokens",
			"cache_creation_input_tokens",
		]);
		totals.cost += usageCost(usage);
	}
	return totals;
};

if (selfCheckParser) {
	if (!selfCheckSessionJsonl) {
		console.error("--self-check-parser requires --session-jsonl <path>");
		process.exit(2);
	}
	const content = await readFile(selfCheckSessionJsonl, "utf8");
	console.log(
		JSON.stringify(
			{
				path: selfCheckSessionJsonl,
				totals: parseSessionJsonlTotals(content),
			},
			null,
			2,
		),
	);
	process.exit(0);
}

const tokDeltas = (
	tokscaleTotals: Record<string, number | null>,
	parserTotals: SessionTotals,
): Record<string, number> => ({
	input: (tokscaleTotals.input ?? 0) - parserTotals.input,
	output: (tokscaleTotals.output ?? 0) - parserTotals.output,
	cacheRead: (tokscaleTotals.cacheRead ?? 0) - parserTotals.cacheRead,
	cacheWrite: (tokscaleTotals.cacheWrite ?? 0) - parserTotals.cacheWrite,
	messages: (tokscaleTotals.messages ?? 0) - parserTotals.messages,
});

const tokMatch = (
	tokscaleTotals: Record<string, number | null>,
	parserTotals: SessionTotals,
): boolean =>
	tokscaleTotals.input === parserTotals.input &&
	tokscaleTotals.output === parserTotals.output &&
	tokscaleTotals.cacheRead === parserTotals.cacheRead &&
	tokscaleTotals.cacheWrite === parserTotals.cacheWrite &&
	tokscaleTotals.messages === parserTotals.messages;

const runTokscale = async (
	sessionJsonl: SessionJsonl | null,
	cwd: string,
): Promise<TokscaleAudit> => {
	if (tokscaleMode === "not-run" || tokscaleMode === "disabled")
		return tokNotRun();
	if (!sessionJsonl) return tokFailure("missing", "session JSONL missing");
	const version = spawnSync("tokscale", ["--version"], {
		encoding: "utf8",
		timeout: 10_000,
	});
	if (version.status !== 0)
		return tokFailure("missing", "tokscale not found on PATH");
	const home = await mkdtemp(join(tmpdir(), "natural-edit-tokscale-"));
	try {
		const destDir = join(
			home,
			".pi/agent/sessions/natural-edit",
			basename(dirname(sessionJsonl.path)),
		);
		await mkdir(destDir, { recursive: true });
		await copyFile(
			sessionJsonl.path,
			join(destDir, basename(sessionJsonl.path)),
		);
		const r = spawnSync(
			"tokscale",
			[
				"--home",
				home,
				"--client",
				"pi",
				"--json",
				"--light",
				"--benchmark",
				"--no-spinner",
			],
			{
				cwd,
				encoding: "utf8",
				maxBuffer: 50 * 1024 * 1024,
				timeout: 60_000,
			},
		);
		if (r.status !== 0) {
			return tokFailure(
				"failed",
				(r.stderr || r.stdout).trim().split("\n").slice(0, 3).join(" "),
			);
		}
		let payload: Record<string, unknown>;
		try {
			payload = JSON.parse(r.stdout) as Record<string, unknown>;
		} catch (error) {
			return tokFailure(
				"failed",
				`tokscale JSON parse failed: ${String(error)}`,
			);
		}
		const totals = {
			input: numberFrom(payload.totalInput),
			output: numberFrom(payload.totalOutput),
			cacheRead: numberFrom(payload.totalCacheRead),
			cacheWrite: numberFrom(payload.totalCacheWrite),
			messages: numberFrom(payload.totalMessages),
			cost: numberFrom(payload.totalCost),
			processingTimeMs: numberFrom(payload.processingTimeMs),
		};
		const hasTokenTotals =
			totals.input !== null &&
			totals.output !== null &&
			totals.cacheRead !== null &&
			totals.cacheWrite !== null &&
			totals.messages !== null;
		if (!hasTokenTotals) {
			return {
				mode: tokscaleMode,
				status: "mismatch",
				match: false,
				deltas: null,
				totals,
				details: "Tokscale missing required token totals",
			};
		}
		const deltas = tokDeltas(totals, sessionJsonl.totals);
		const match = tokMatch(totals, sessionJsonl.totals);
		const details = match
			? "Tokscale totals match Pi JSONL parser totals"
			: `Tokscale totals mismatch parser totals: ${Object.entries(deltas)
					.filter(([, delta]) => delta !== 0)
					.map(([key, delta]) => `${key} delta=${delta}`)
					.join("; ")}`;
		return {
			mode: tokscaleMode,
			status: match ? "ok" : "mismatch",
			match,
			deltas,
			totals,
			details,
		};
	} finally {
		if (!keepTemp) await rm(home, { recursive: true, force: true });
	}
};

/** Discover and hash session JSONL files under a directory. */
const discoverSessionJsonl = async (
	dir: string,
): Promise<SessionJsonl | null> => {
	const { readdirSync } = await import("node:fs");
	try {
		const entries = readdirSync(dir);
		const jsonl = entries.find(
			(e) => e.endsWith(".jsonl") && !e.startsWith("."),
		);
		if (!jsonl) return null;
		const path = join(dir, jsonl);
		const content = await readFile(path, "utf8");
		return { path, hash: sha256(content), totals: parseSessionJsonlTotals(content) };
	} catch {
		return null;
	}
};

// ── Helpers ─────────────────────────────────────────────────────────────────

function readFixture(name: string): string {
	// Synchronous read at module init — ok for bench scripts
	const path = join(FIXTURES_DIR, name);
	return require("fs").readFileSync(path, "utf8") as string;
}

// ── Runner ───────────────────────────────────────────────────────────────────

const piArgs = (lane: Lane, prompt: string, sessionDir: string): string[] => {
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
		"blitz_edit",
		prompt,
	];
};

const runPi = (
	lane: Lane,
	prompt: string,
	cwd: string,
): {
	ms: number;
	status: number;
	stdout: string;
	stderr: string;
	timedOut: boolean;
	sessionDir: string;
} => {
	const sessionDir = join(cwd, `sessions-${lane}`);
	const args = piArgs(lane, prompt, sessionDir);
	const t0 = performance.now();
	const currentToolProfile =
		toolProfile || (lane === "blitz" ? "minimal" : "full");
	const env = {
		...process.env,
		PATH: `${BLITZ_BIN_DIR}:${process.env.PATH ?? ""}`,
		PI_BLITZ_TOOL_PROFILE: currentToolProfile,
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
	const timedOut =
		Boolean(r.error) ||
		r.signal !== null ||
		(r.status === 143 && ms >= timeoutMs - 1000);
	return {
		ms,
		status: r.status ?? (timedOut ? 143 : -1),
		stdout: r.stdout ?? "",
		stderr: r.stderr ?? "",
		timedOut,
		sessionDir,
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

		for (const lane of ["core", "blitz"] as Lane[]) {
			if (laneFilter && lane !== laneFilter) continue;

			const iterations: RunItem[] = [];

			for (let iter = 0; iter < iters; iter++) {
				const runDir = keepTemp
					? join(
							reportRoot,
							"natural-edit-runs",
							`${scenario.id}__${lane}__${iter}__${STAMP}`,
						)
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

				// Build full prompt with file contents. Natural rows should not
				// prescribe exact tool JSON, but the model still needs enough
				// context to construct safe oldText/newText or Blitz tuples.
				const fileContext = scenario.files
					.map((f) => `--- ${f.path} ---\n${f.before}`)
					.join("\n\n");
				const prompt = `${preamble(lane, scenario.id)}\n\nWorking directory contains: ${scenario.files.map((f) => f.path).join(", ")}.\n\n${fileContext}\n\nTask:\n${scenario.prompt}\n\nMake the edit using your available tool. After the tool call, output exactly done.`;

				if (verbose) {
					console.error(`\n[${scenario.id}][${lane}][iter ${iter}] running...`);
				}

				const r = runPi(lane, prompt, workDir);

				// Check file results
				const fileResults = [] as RunItem["files"];
				for (const f of scenario.files) {
					const fp = join(workDir, f.path);
					const gotContent = existsSync(fp) ? await readFile(fp, "utf8") : "";
					fileResults.push({
						path: f.path,
						gotSha: sha256(gotContent),
						expectedSha: sha256(f.after),
						match: gotContent === f.after,
					});
				}

				const allMatch = fileResults.every((fr) => fr.match);
				const outcome = classifyOutcome(
					lane,
					allMatch,
					scenario.idempotent ?? false,
					r.status,
					r.timedOut,
				);
				const routeOutcome = classifyRouteOutcome(outcome, lane);

				// Discover session JSONL
				const sessionJsonl = await discoverSessionJsonl(r.sessionDir);
				const tokscale = await runTokscale(sessionJsonl, workDir);
				const visibleTools = lane === "core" ? "edit" : "blitz_edit";
				const currentToolProfile =
					toolProfile || (lane === "blitz" ? "minimal" : "full");

				// Accepted: correct + exit 0 + !timedOut + (Tokscale match or not-run)
				const accepted =
					allMatch &&
					r.status === 0 &&
					!r.timedOut &&
					tokscale.match !== false &&
					(tokscaleMode === "not-run" || tokscale.match === true);

				const item: RunItem = {
					provider,
					model,
					lane,
					scenarioId: scenario.id,
					iter,
					outcome,
					routeOutcome,
					accepted,
					correct: allMatch,
					filesMatch: allMatch,
					wallMs: r.ms,
					exitCode: r.status,
					timedOut: r.timedOut,
					stderr: r.stderr,
					stdout: r.stdout,
					runDir,
					sessionDir: r.sessionDir,
					sessionJsonl,
					tokscale,
					provenance: {
						extensionPath: lane === "blitz" ? extension : "(core-no-extension)",
						skillPath: lane === "blitz" ? skill : "(core-no-skill)",
						visibleTools,
						toolProfile: currentToolProfile,
					},
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

			const dominantOutcome = iterations.reduce<{
				outcome: Outcome;
				count: number;
			}>(
				(best, i) => {
					const count = iterations.filter(
						(x) => x.outcome === i.outcome,
					).length;
					return count > best.count ? { outcome: i.outcome, count } : best;
				},
				{ outcome: iterations[0]?.outcome ?? "incorrect", count: 0 },
			).outcome;

			const correctIters = iterations.filter((i) => i.correct).length;
			const acceptedIters = iterations.filter((i) => i.accepted).length;
			const dominantRouteOutcome = classifyRouteOutcome(dominantOutcome, lane);

			allResults.push({
				scenarioId: scenario.id,
				title: scenario.title,
				lane,
				iterations,
				outcome: dominantOutcome,
				outcomeLabel: dominantOutcome,
				routeOutcome: dominantRouteOutcome,
				accepted: acceptedIters > 0,
				totalIters: iterations.length,
				correctIters,
			});

			const outcomeLabel = dominantOutcome;
			const icon =
				outcomeLabel === "blitz_mutated" || outcomeLabel === "core_mutated"
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
		tokscaleMode,
		toolProfile: toolProfile || "full",
		piBin,
		extension,
		skill,
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
	tokscaleMode: string;
	toolProfile: string;
	piBin: string;
	extension: string;
	skill: string;
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
	lines.push(`Tokscale mode: ${report.tokscaleMode}`);
	lines.push(`Tool profile: ${report.toolProfile}`);
	lines.push(`Pi: ${report.piBin}`);
	lines.push(`Extension: ${report.extension}`);
	lines.push(`Skill: ${report.skill}`);
	lines.push(`Blitz PATH prepend: ${report.blitzBinPathPrepend}`);
	lines.push("");
	lines.push(
		"> **Caveat: spawn harness.** Accepted requires correct + exit 0 + !timedOut, and when Tokscale validation is requested, Tokscale must be present and return required token totals. Fallback is never inferred; only explicit route outcomes are counted.",
	);
	lines.push("");

	// Summary table
	lines.push("## Results");
	lines.push("");
	lines.push(
		"| Scenario | Lane | Route outcome | Correct / Iters | Accepted / Iters | Wall ms (median) |",
	);
	lines.push("|---|---|:---|---:|:---:|---:|");
	for (const r of report.results) {
		const medianWall =
			[...r.iterations].sort((a, b) => a.wallMs - b.wallMs)[
				Math.floor(r.iterations.length / 2)
			]?.wallMs ?? 0;
		lines.push(
			`| ${r.scenarioId} | ${r.lane} | \`${r.routeOutcome}\` | ${r.correctIters}/${r.totalIters} | ${r.iterations.filter((i) => i.accepted).length}/${r.totalIters} | ${medianWall.toFixed(0)} |`,
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
		lines.push(
			`Files: ${s.files.map((f) => `${f.path} (sha: ${f.afterSha})`).join(", ")}`,
		);
		lines.push("");

		const results = report.results.filter((r) => r.scenarioId === s.id);
		for (const r of results) {
			lines.push(
				`**Lane: ${r.lane}** — outcome: \`${r.outcomeLabel}\` — route: \`${r.routeOutcome}\``,
			);
			lines.push("");
			lines.push(
				"| Iter | Outcome | Route | Accepted | Correct | Exit | Wall ms | Files match | Session JSONL |",
			);
			lines.push("|---|---|:---|:---|:---:|---:|---:|---:|---:|");
			for (const run of r.iterations) {
				const jsonlInfo = run.sessionJsonl ? `${run.sessionJsonl.hash}` : "—";
				lines.push(
					`| ${run.iter} | ${run.outcome} | \`${run.routeOutcome}\` | ${run.accepted ? "yes" : "no"} | ${run.correct ? "yes" : "no"} | ${run.exitCode}${run.timedOut ? " (timeout)" : ""} | ${run.wallMs.toFixed(0)} | ${run.files.filter((f) => f.match).length}/${run.files.length} | ${jsonlInfo} |`,
				);
			}
			lines.push("");
		}
	}

	// Aggregate audit summary
	lines.push("## Aggregate audit summary");
	lines.push("");
	const total = report.runs.length;
	const totalAccepted = report.runs.filter((r) => r.accepted).length;
	const totalCorrect = report.runs.filter((r) => r.correct).length;
	const totalTimedOut = report.runs.filter((r) => r.timedOut).length;
	lines.push(`- Accepted: ${totalAccepted}/${total}`);
	lines.push(`- Correct: ${totalCorrect}/${total}`);
	lines.push(`- Timed out: ${totalTimedOut}/${total}`);
	lines.push("");

	// Outcome summary
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

	// Route outcome counts
	lines.push("## Route outcome counts");
	lines.push("");
	const routeCounts: Record<string, number> = {};
	for (const run of report.runs) {
		routeCounts[run.routeOutcome] = (routeCounts[run.routeOutcome] ?? 0) + 1;
	}
	for (const [ro, count] of Object.entries(routeCounts).sort()) {
		lines.push(`- \`${ro}\`: ${count}`);
	}
	lines.push("");

	// Tokscale status counts
	lines.push("## Tokscale status counts");
	lines.push("");
	const tokCounts: Record<string, number> = {};
	for (const run of report.runs) {
		const key = `${run.tokscale.mode}:${run.tokscale.status}:${run.tokscale.match}`;
		tokCounts[key] = (tokCounts[key] ?? 0) + 1;
	}
	for (const [key, count] of Object.entries(tokCounts).sort()) {
		lines.push(`- \`${key}\`: ${count}`);
	}
	lines.push("");

	// Required per-row audit fields
	lines.push("## Per-row audit fields");
	lines.push("");
	lines.push(
		"| Provider | Model | Lane | Scenario | Iter | Accepted | Correct | Files match | Outcome | Route | Exit | Timed out | Wall ms | Run dir | Session dir | Session JSONL | Provenance | Tokscale |",
	);
	lines.push(
		"|---|---|---|---|---:|:---:|:---:|:---:|---|---|---:|:---:|---:|---|---|---|---|---|",
	);
	for (const run of report.runs) {
		const sessionJsonl = run.sessionJsonl
			? `${run.sessionJsonl.path} (${run.sessionJsonl.hash})`
			: "—";
		const provenance = `extension=${run.provenance.extensionPath}; skill=${run.provenance.skillPath}; tools=${run.provenance.visibleTools}; profile=${run.provenance.toolProfile}`;
		const tok = `mode=${run.tokscale.mode}; status=${run.tokscale.status}; match=${run.tokscale.match}; deltas=${JSON.stringify(run.tokscale.deltas)}; totals=${JSON.stringify(run.tokscale.totals)}`;
		lines.push(
			`| ${run.provider} | ${run.model} | ${run.lane} | ${run.scenarioId} | ${run.iter} | ${run.accepted ? "yes" : "no"} | ${run.correct ? "yes" : "no"} | ${run.filesMatch ? "yes" : "no"} | ${run.outcome} | ${run.routeOutcome} | ${run.exitCode} | ${run.timedOut ? "yes" : "no"} | ${run.wallMs.toFixed(0)} | ${run.runDir} | ${run.sessionDir} | ${sessionJsonl} | ${provenance} | ${tok} |`,
		);
	}
	lines.push("");

	// Accepted summary
	lines.push("## Acceptance summary");
	lines.push("");
	lines.push(
		`**Accepted: ${totalAccepted}/${total} (${((totalAccepted / total) * 100).toFixed(1)}%)**`,
	);
	lines.push(
		`**Correct: ${totalCorrect}/${total} (${((totalCorrect / total) * 100).toFixed(1)}%)**`,
	);
	lines.push(
		`**Tokscale mode: \`${report.tokscaleMode}\`** — validate mode fails accepted rows closed when Tokscale is missing or status/match fails.`,
	);

	return lines.join("\n");
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
