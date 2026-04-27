#!/usr/bin/env bun
/**
 * Authentic Pi-driven token bench.
 *
 * For each fixture, runs `pi -p` in two isolated configurations:
 *   core lane:  --no-extensions --no-skills --no-context-files --no-prompt-templates --tools edit
 *   blitz lane: --no-extensions --extension <pi-blitz dist/index.js> --tools pi_blitz_edit
 *
 * Both lanes get identical prompts that include the file contents inline,
 * so the model never needs a read tool.
 *
 * Reads the per-session JSONL from --session-dir to extract:
 *   - Real provider-tokenizer usage.output / usage.input / cost
 *   - The exact JSON arguments emitted by the model for the edit tool call
 *   - Tokenizes those arguments via cl100k_base for an apples-to-apples
 *     fastedit-style payload comparison
 *
 * Run:
 *   bun bench/llm-pi.ts
 *   bun bench/llm-pi.ts --model claude-haiku-4-5 --iters 1
 */

import { readFile, writeFile, readdir, mkdtemp, rm, mkdir } from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, basename, dirname } from "node:path";
import { existsSync } from "node:fs";
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const PI_BLITZ_DIST = "/home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz/dist/index.js";
const PI_BLITZ_SKILL = "/home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz/skills/pi-blitz";

type Fixture = {
	id: string;
	relPath: string;
	intent: (filePath: string) => string;
	expectedFile: string; // contents after edit
};

const argv = process.argv.slice(2);
const argFlag = (k: string, dflt: string) => {
	const idx = argv.findIndex((a) => a === k || a.startsWith(`${k}=`));
	if (idx < 0) return dflt;
	const v = argv[idx];
	if (v.includes("=")) return v.split("=")[1]!;
	return argv[idx + 1] ?? dflt;
};
const provider = argFlag("--provider", "anthropic");
const model = argFlag("--model", "claude-haiku-4-5");
const iters = parseInt(argFlag("--iters", "1"), 10);
const verbose = argv.includes("--verbose");
const timeoutMs = parseInt(argFlag("--timeout-ms", "60000"), 10);
const caseFilter = argFlag("--case", "");

const fixtureDir = join(REPO_ROOT, "bench/fixtures-llm");

const buildSmallIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: change the body of the smallTarget function so it returns "hello " followed by name.toUpperCase() instead of "hi " + name. The signature stays the same.

Original file contents:
${src}`;

const buildHugeIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: change the final return statement of the hugeCompute function from \`return total;\` to \`return total + 1;\`. Leave every other line unchanged.

Original file contents:
${src}`;

const FIXTURES: Fixture[] = [
	{
		id: "small/wrap-tail",
		relPath: "small.ts",
		intent: (p: string) => buildSmallIntent(p, smallSrc),
		expectedFile: "",
	},
	{
		id: "huge-100k/marker-tail",
		relPath: "huge.ts",
		intent: (p: string) => buildHugeIntent(p, hugeSrc),
		expectedFile: "",
	},
];

const smallSrc = await readFile(join(fixtureDir, "small.ts"), "utf8");
const smallExpected = smallSrc.replace(
	`function smallTarget(name: string): string {
  return "hi " + name;
}`,
	`function smallTarget(name: string): string {
  return "hello " + name.toUpperCase();
}`,
);
const hugeSrc = await readFile(join(fixtureDir, "huge.ts"), "utf8");
const hugeExpected = hugeSrc.replace("  return total;", "  return total + 1;");

FIXTURES[0]!.expectedFile = smallExpected;
FIXTURES[1]!.expectedFile = hugeExpected;

const isLineLike = (a: string, b: string): boolean => a.trim() === b.trim();

type Lane = "core" | "blitz";

const piArgs = (
	lane: Lane,
	prompt: string,
	sessionDir: string,
	cwd: string,
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
		return [...common, "--no-skills", "--no-extensions", "--tools", "edit", prompt];
	}
	return [
		...common,
		"--no-extensions",
		"--extension",
		PI_BLITZ_DIST,
		"--skill",
		PI_BLITZ_SKILL,
		"--tools",
		"pi_blitz_edit",
		prompt,
	];
};

const runPi = (lane: Lane, prompt: string, cwd: string) => {
	const sessionDir = join(cwd, `sessions-${lane}`);
	const args = piArgs(lane, prompt, sessionDir, cwd);
	const t0 = performance.now();
	const r = spawnSync("pi", args, { cwd, encoding: "utf8", maxBuffer: 200 * 1024 * 1024, timeout: timeoutMs, killSignal: "SIGTERM" });
	const ms = performance.now() - t0;
	return { ms, status: r.status ?? -1, stdout: r.stdout ?? "", stderr: r.stderr ?? "", sessionDir, timedOut: r.error?.name === "Error" && /ETIMEDOUT/.test(String(r.error)) };
};

const findSessionFile = async (sessionDir: string): Promise<string> => {
	const stack = [sessionDir];
	while (stack.length) {
		const cur = stack.pop()!;
		if (!existsSync(cur)) continue;
		for (const ent of await readdir(cur, { withFileTypes: true })) {
			const p = join(cur, ent.name);
			if (ent.isDirectory()) stack.push(p);
			else if (ent.isFile() && ent.name.endsWith(".jsonl")) return p;
		}
	}
	throw new Error(`no session jsonl in ${sessionDir}`);
};

type Usage = {
	input: number;
	output: number;
	cacheRead?: number;
	cacheWrite?: number;
	totalTokens?: number;
	cost?: { total?: number };
};

type ToolCallEntry = {
	name: string;
	arguments: unknown;
};

type ParsedSession = {
	turnCount: number;
	totalOutputTokens: number;
	totalInputTokens: number;
	totalCacheRead: number;
	totalCacheWrite: number;
	totalCost: number;
	editToolCalls: ToolCallEntry[];
	editToolCallArgsTokens: number;
	editToolName: string | null;
};

const parseSession = (file: string, lane: Lane): Promise<ParsedSession> =>
	readFile(file, "utf8").then((raw) => {
		let turnCount = 0;
		let totalOutputTokens = 0;
		let totalInputTokens = 0;
		let totalCacheRead = 0;
		let totalCacheWrite = 0;
		let totalCost = 0;
		const editCalls: ToolCallEntry[] = [];
		let editToolName: string | null = null;
		for (const line of raw.split("\n")) {
			if (!line.trim()) continue;
			const j = JSON.parse(line);
			if (j.type !== "message") continue;
			if (j.message?.role !== "assistant") continue;
			turnCount += 1;
			const u: Usage | undefined = j.message?.usage;
			if (u) {
				totalOutputTokens += u.output ?? 0;
				totalInputTokens += u.input ?? 0;
				totalCacheRead += u.cacheRead ?? 0;
				totalCacheWrite += u.cacheWrite ?? 0;
				totalCost += u.cost?.total ?? 0;
			}
			for (const part of j.message?.content ?? []) {
				if (part?.type === "toolCall") {
					if (
						(lane === "core" && part.name === "edit") ||
						(lane === "blitz" && (part.name === "pi_blitz_edit" || part.name === "pi_blitz_batch"))
					) {
						editCalls.push({ name: part.name, arguments: part.arguments });
						editToolName = part.name;
					}
				}
			}
		}
		const argsToken = editCalls
			.map((c) => countTokens(JSON.stringify(c.arguments)))
			.reduce((a, b) => a + b, 0);
		return {
			turnCount,
			totalOutputTokens,
			totalInputTokens,
			totalCacheRead,
			totalCacheWrite,
			totalCost,
			editToolCalls: editCalls,
			editToolCallArgsTokens: argsToken,
			editToolName,
		};
	});

type LaneResult = {
	lane: Lane;
	wallMs: number;
	session: ParsedSession;
	correct: boolean;
	exitCode: number;
};

const runLane = async (lane: Lane, fx: Fixture): Promise<LaneResult> => {
	const tmp = await mkdtemp(join(tmpdir(), `pi-bench-${lane}-`));
	const targetDir = join(tmp, "work");
	await mkdir(targetDir, { recursive: true });
	const targetPath = join(targetDir, fx.relPath);
	const original = await readFile(join(fixtureDir, fx.relPath), "utf8");
	await writeFile(targetPath, original, "utf8");

	const prompt = fx.intent(targetPath);
	const r = runPi(lane, prompt, targetDir);
	if (r.status !== 0) {
		if (verbose) console.error(`[${lane}] pi exit ${r.status}${r.timedOut ? " (timeout)" : ""}\nstderr: ${r.stderr}\nstdout: ${r.stdout}`);
	}

	const sessionFile = await findSessionFile(r.sessionDir).catch(() => "");
	let parsed: ParsedSession = {
		turnCount: 0,
		totalOutputTokens: 0,
		totalInputTokens: 0,
		totalCacheRead: 0,
		totalCacheWrite: 0,
		totalCost: 0,
		editToolCalls: [],
		editToolCallArgsTokens: 0,
		editToolName: null,
	};
	if (sessionFile) parsed = await parseSession(sessionFile, lane);

	const got = await readFile(targetPath, "utf8").catch(() => "");
	const correct = got === fx.expectedFile;
	if (!correct && verbose) console.error(`[${lane}] golden mismatch`);

	if (!verbose) await rm(tmp, { recursive: true, force: true });
	return { lane, wallMs: r.ms, session: parsed, correct, exitCode: r.status };
};

const median = (xs: number[]) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)]!;
const pct = (n: number) => `${n.toFixed(1)}%`;

const main = async () => {
	console.log(`# Pi-driven authentic LLM token bench`);
	console.log(`Provider: ${provider} / Model: ${model}`);
	console.log(`Iterations: ${iters}`);
	console.log(`Timeout per Pi run: ${timeoutMs}ms`);
	if (caseFilter) console.log(`Case filter: ${caseFilter}`);
	console.log(`Tokenizer: cl100k_base via tiktoken (for tool-call arg compare)`);
	console.log("");

	type Row = {
		fixture: string;
		lane: Lane;
		wallMsMedian: number;
		outputMedian: number;
		argsTokensMedian: number;
		correctRate: number;
		costSum: number;
	};
	const rows: Row[] = [];

	const selectedFixtures = caseFilter
		? FIXTURES.filter((fx) => fx.id.includes(caseFilter))
		: FIXTURES;
	if (selectedFixtures.length === 0) throw new Error(`no fixtures match --case ${caseFilter}`);

	for (const fx of selectedFixtures) {
		for (const lane of ["core", "blitz"] as Lane[]) {
			const runs: LaneResult[] = [];
			for (let i = 0; i < iters; i++) {
				const r = await runLane(lane, fx);
				runs.push(r);
				if (verbose) console.error(`[${fx.id}][${lane}][iter ${i}] output=${r.session.totalOutputTokens} args=${r.session.editToolCallArgsTokens} ok=${r.correct} wall=${r.wallMs.toFixed(0)}`);
			}
			rows.push({
				fixture: fx.id,
				lane,
				wallMsMedian: median(runs.map((r) => r.wallMs)),
				outputMedian: median(runs.map((r) => r.session.totalOutputTokens)),
				argsTokensMedian: median(runs.map((r) => r.session.editToolCallArgsTokens)),
				correctRate: runs.filter((r) => r.correct).length / runs.length,
				costSum: runs.reduce((a, r) => a + r.session.totalCost, 0),
			});
		}
	}

	console.log("| Fixture | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |");
	console.log("|---|---|---:|---:|---:|---:|---:|");
	for (const r of rows) {
		console.log(`| ${r.fixture} | ${r.lane} | ${r.wallMsMedian.toFixed(0)} | ${r.outputMedian} | ${r.argsTokensMedian} | ${pct(r.correctRate * 100)} | ${r.costSum.toFixed(4)} |`);
	}

	console.log("");
	for (const fx of selectedFixtures) {
		const core = rows.find((r) => r.fixture === fx.id && r.lane === "core")!;
		const blitz = rows.find((r) => r.fixture === fx.id && r.lane === "blitz")!;
		const savedOutput = core.outputMedian
			? 100 * (1 - blitz.outputMedian / core.outputMedian)
			: 0;
		const savedArgs = core.argsTokensMedian
			? 100 * (1 - blitz.argsTokensMedian / core.argsTokensMedian)
			: 0;
		console.log(`${fx.id}: saved session output ${pct(savedOutput)}, saved tool-call args ${pct(savedArgs)}`);
	}

	releaseTokenizer();
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
