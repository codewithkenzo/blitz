#!/usr/bin/env bun
/**
 * Route-aware authentic Pi-driven token matrix bench.
 *
 * For each fixture, runs `pi -p` in two isolated configurations:
 *   core lane:  --no-extensions --no-skills --no-context-files --no-prompt-templates --tools edit
 *   blitz lane: --no-extensions --extension <pi-blitz dist/index.js> --tools narrow pi_blitz_* structured apply tools
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
	blitzGuidance?: string;
	// core-only fixtures route to core edit; others compare core vs blitz
	lanePolicy?: "core-only" | "compare";
	recommendedLane?: Lane;
	className?: string;
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
const laneFilter = argFlag("--lane", "") as Lane | "";
const jsonOut = argFlag("--json-out", "");
const mdOut = argFlag("--md-out", "");

const fixtureDir = join(REPO_ROOT, "bench/fixtures-llm");

const buildSmallIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: change the body of the smallTarget function so it returns "hello " followed by name.toUpperCase() instead of "hi " + name. The signature stays the same.

Original file contents:
${src}`;

const buildHugeIntent = (filePath: string, src: string, symbol = "hugeCompute"): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: change the final return statement of the ${symbol} function from \`return total;\` to \`return total + 1;\`. Leave every other line unchanged.

Original file contents:
${src}`;

const buildWrapIntent = (filePath: string, src: string, symbol = "mediumCompute"): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: wrap the entire body of the ${symbol} function in a try/catch. Preserve every existing statement inside the try block unchanged. In the catch block, call console.error(error); then throw error.

Original file contents:
${src}`;

const buildComposeIntent = (filePath: string, src: string, symbol = "mediumCompute"): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: update ${symbol} with two preserved islands and small structural edits:
1) immediately after \`let total = seed;\`, add a finite check throwing RangeError when seed is not finite,
2) before return, add an early return when total is negative.

Preserve every original arithmetic statement exactly. Do not rewrite unchanged lines.

Original file contents:
${src}`;

const buildMultiBodyIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: make three edits in the same file:
1) in adjust, replace the final return statement with \`return base + 1;\`,
2) in emit, insert \`const markerUpper = value.toUpperCase();\` immediately after \`const marker = value;\`,
3) in risky, wrap the function body in try/catch and rethrow error.

Original file contents:
${src}`;

const buildMultiLargeIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: make three edits in the same file:
1) wrap the entire body of mediumCompute in try/catch; catch should call console.error(error); then throw error,
2) in auditEvent, insert a tagged audit string immediately after \`const normalized = event.trim();\`,
3) in formatStatus, replace final return with \`return status.toUpperCase();\`.

Original file contents:
${src}`;

const buildSemanticIntent = (filePath: string, src: string, goal: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: ${goal}

Original file contents:
${src}`;

const FIXTURES: Fixture[] = [
	{
		id: "small/wrap-tail",
		relPath: "small.ts",
		intent: (p: string) => buildSmallIntent(p, smallSrc),
		expectedFile: "",
		lanePolicy: "core-only",
		recommendedLane: "core",
		className: "tiny_unique_replace",
	},
	{
		id: "medium-10k/marker-tail",
		relPath: "medium.ts",
		intent: (p: string) => buildHugeIntent(p, mediumSrc, "mediumCompute"),
		expectedFile: "",
		recommendedLane: "core",
		className: "medium_tail_replace",
	},
	{
		id: "medium-10k/wrap-body",
		relPath: "medium.ts",
		intent: (p: string) => buildWrapIntent(p, mediumSrc, "mediumCompute"),
		expectedFile: "",
		blitzGuidance:
			"For this edit, use compact body-marker shape: `  try {\\n    let total = seed;\\n    // ... existing code ...\\n    return total;\\n  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }`.",
		recommendedLane: "blitz",
		className: "medium_wrap_body",
	},
	{
		id: "medium-10k/compose-preserve-islands",
		relPath: "medium.ts",
		intent: (p: string) => buildComposeIntent(p, mediumSrc, "mediumCompute"),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "compose_preserve_islands",
	},
	{
		id: "multi/three-body-ops",
		relPath: "multi.ts",
		intent: (p: string) => buildMultiBodyIntent(p, multiSrc),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "multi_body_three_ops",
	},
	{
		id: "multi/large-structural",
		relPath: "multi-large.ts",
		intent: (p: string) => buildMultiLargeIntent(p, multiLargeSrc),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "multi_body_large_structural",
	},
	{
		id: "huge-100k/marker-tail",
		relPath: "huge.ts",
		intent: (p: string) => buildHugeIntent(p, hugeSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "huge_tail_replace",
	},
	{
		id: "semantic/async-try-catch",
		relPath: "semantic.ts",
		intent: (p: string) => buildSemanticIntent(p, semanticSrc, "wrap the entire body of async function loadUser in try/catch. Preserve all await statements unchanged. Catch should call console.error(error); then throw error."),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "async_try_catch",
	},
	{
		id: "semantic/class-method-try-catch",
		relPath: "semantic.ts",
		intent: (p: string) => buildSemanticIntent(p, semanticSrc, "wrap the entire body of class method renderScore in try/catch. Catch should call console.error(error); then throw error."),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "class_method_try_catch",
	},
	{
		id: "semantic/arrow-replace-return",
		relPath: "semantic.ts",
		intent: (p: string) => buildSemanticIntent(p, semanticSrc, "in arrow function pickLabel, replace the last return expression with \"unknown\". Leave the earlier active return unchanged."),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "arrow_replace_return",
	},
	{
		id: "semantic/nested-return-occurrence",
		relPath: "semantic.ts",
		intent: (p: string) => buildSemanticIntent(p, semanticSrc, "in function classify, replace only the last return expression with \"other\". Leave the negative and zero returns unchanged."),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "nested_return_occurrence",
	},
	{
		id: "semantic/tsx-replace-return",
		relPath: "component.tsx",
		intent: (p: string) => buildSemanticIntent(p, componentSrc, "in function StatusBadge, replace the return expression with <strong className=\"badge\">{label.toUpperCase()}</strong>."),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "tsx_replace_return",
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
const mediumSrc = await readFile(join(fixtureDir, "medium.ts"), "utf8");
const mediumExpected = mediumSrc.replace("  return total;", "  return total + 1;");
const mediumComposeExpected = (() => {
	const withSeedGuard = mediumSrc.replace(
		"  let total = seed;\n",
		`  let total = seed;\n  if (!Number.isFinite(total)) {\n    throw new RangeError("seed must be finite");\n  }\n\n`,
	);
	return withSeedGuard.replace(
		"  return total;\n",
		"  if (total < 0) {\n    return 0;\n  }\n\n  return total;\n",
	);
})();
const mediumBody = mediumSrc.slice(
	mediumSrc.indexOf("{\n") + 2,
	mediumSrc.lastIndexOf("\n}"),
);
const mediumWrapExpected = `function mediumCompute(seed: number): number {\n  try {\n${mediumBody.replace(/^/gm, "  ")}\n  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n}\n`;
const multiSrc = await readFile(join(fixtureDir, "multi.ts"), "utf8");
const multiExpected = multiSrc
	.replace("  return base;", "  return base + 1;")
	.replace("  const marker = value;\n", "  const marker = value;\n  const markerUpper = value.toUpperCase();\n")
	.replace(
		`export function risky(value: number): number {\n  return value;\n}`,
		`export function risky(value: number): number {\n  try {\n    return value;\n  } catch (error) {\n    throw error;\n  }\n}`,
	);
const multiLargeSrc = await readFile(join(fixtureDir, "multi-large.ts"), "utf8");
const multiLargeBody = multiLargeSrc.slice(
	multiLargeSrc.indexOf("{\n") + 2,
	multiLargeSrc.indexOf("\n}\n\nexport function auditEvent"),
);
const multiLargeIndented = multiLargeBody
	.split("\n")
	.map((line) => `  ${line}`)
	.join("\n");
const multiLargeExpected = multiLargeSrc
	.replace(
		`function mediumCompute(seed: number): number {\n${multiLargeBody}\n}`,
		`function mediumCompute(seed: number): number {\n  try {\n${multiLargeIndented}\n  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n}`,
	)
	.replace("  const normalized = event.trim();\n", "  const normalized = event.trim();\n  const tagged = `[audit] ${normalized}`;\n")
	.replace("  return status;", "  return status.toUpperCase();");
const hugeSrc = await readFile(join(fixtureDir, "huge.ts"), "utf8");
const hugeExpected = hugeSrc.replace("  return total;", "  return total + 1;");
const semanticSrc = await readFile(join(fixtureDir, "semantic.ts"), "utf8");
const asyncTryCatchExpected = semanticSrc.replace(
	`export async function loadUser(id: string): Promise<string> {
  const response = await fetch(\`/api/users/\${id}\`);
  const payload = await response.json();
  return payload.name;
}`,
	`export async function loadUser(id: string): Promise<string> {
  try {
    const response = await fetch(\`/api/users/\${id}\`);
    const payload = await response.json();
    return payload.name;
  } catch (error) {
    console.error(error);
    throw error;
  }
}`,
);
const classTryCatchExpected = semanticSrc.replace(
	`  renderScore(score: number): string {
    const rounded = Math.round(score);
    return \`score:\${rounded}\`;
  }`,
	`  renderScore(score: number): string {
    try {
      const rounded = Math.round(score);
      return \`score:\${rounded}\`;
    } catch (error) {
      console.error(error);
      throw error;
    }
  }`,
);
const arrowReturnExpected = semanticSrc.replace(`  return "idle";`, `  return "unknown";`);
const nestedReturnExpected = semanticSrc.replace(`  return "positive";`, `  return "other";`);
const componentSrc = await readFile(join(fixtureDir, "component.tsx"), "utf8");
const componentReturnExpected = componentSrc.replace(
	`  return <span className="badge">{label}</span>;`,
	`  return <strong className="badge">{label.toUpperCase()}</strong>;`,
);

FIXTURES[0]!.expectedFile = smallExpected;
FIXTURES[1]!.expectedFile = mediumExpected;
FIXTURES[2]!.expectedFile = mediumWrapExpected;
FIXTURES[3]!.expectedFile = mediumComposeExpected;
FIXTURES[4]!.expectedFile = multiExpected;
FIXTURES[5]!.expectedFile = multiLargeExpected;
FIXTURES[6]!.expectedFile = hugeExpected;
FIXTURES[7]!.expectedFile = asyncTryCatchExpected;
FIXTURES[8]!.expectedFile = classTryCatchExpected;
FIXTURES[9]!.expectedFile = arrowReturnExpected;
FIXTURES[10]!.expectedFile = nestedReturnExpected;
FIXTURES[11]!.expectedFile = componentReturnExpected;

const isLineLike = (a: string, b: string): boolean => a.trim() === b.trim();

type Lane = "core" | "blitz";

const piArgs = (
	lane: Lane,
	prompt: string,
	sessionDir: string,
	cwd: string,
	toolsOverride?: string,
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
		toolsOverride ?? "pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return",
		prompt,
	];
};

const runPi = (lane: Lane, prompt: string, cwd: string, toolsOverride?: string) => {
	const sessionDir = join(cwd, `sessions-${lane}`);
	const args = piArgs(lane, prompt, sessionDir, cwd, toolsOverride);
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
						(lane === "blitz" && typeof part.name === "string" && part.name.startsWith("pi_blitz_"))
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

	let prompt = fx.intent(targetPath);
	if (lane === "blitz") {
		let guidance = "Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`.";
		if (fx.id.includes("wrap-body")) {
			guidance += " For this edit, call `pi_blitz_wrap_body` with symbol `mediumCompute`, before `\\n  try {`, after `  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }\\n`, and indentKeptBodyBy 2.";
		} else if (fx.id.includes("compose-preserve-islands")) {
			guidance +=
				" For this edit, call `pi_blitz_compose_body` with symbol `mediumCompute` and segments: [ { keep: { afterKeep: `  let total = seed;`, includeAfter: true, occurrence: \"only\" } }, { text: `\\n  if (!Number.isFinite(total)) {\\n    throw new RangeError(\\\"seed must be finite\\\");\\n  }\\n` }, { keep: { beforeKeep: `  let total = seed;`, afterKeep: `  return total;`, includeBefore: false, includeAfter: false, occurrence: \"last\" } }, { text: `  if (total < 0) {\\n    return 0;\\n  }\\n\\n` }, { keep: { beforeKeep: `  return total;`, includeBefore: true, occurrence: \"last\" } } ].";
		} else if (fx.id.includes("medium-10k/marker-tail")) {
			guidance += " For this edit, call `pi_blitz_replace_body_span` with symbol `mediumCompute`, find `return total;`, replace `return total + 1;`, occurrence `last`.";
		} else if (fx.id.includes("multi/three-body-ops")) {
			guidance += " For this edit, call `pi_blitz_patch` with ops [[`replace`,`adjust`,`return base;`,`return base + 1;`,`only`], [`insert_after`,`emit`,`const marker = value;`,`\n  const markerUpper = value.toUpperCase();`,`only`], [`try_catch`,`risky`,`throw error;`]].";
		} else if (fx.id.includes("multi/large-structural")) {
			guidance += " For this edit, call `pi_blitz_patch` with ops [[`try_catch`,`mediumCompute`,`console.error(error);\nthrow error;`], [`insert_after`,`auditEvent`,`const normalized = event.trim();`,`\n  const tagged = `[audit] ${normalized}`;`,`only`], [`replace_return`,`formatStatus`,`status.toUpperCase()`,`only`]].";
		} else if (fx.id.includes("huge-100k/marker-tail")) {
			guidance += " For this edit, call `pi_blitz_replace_body_span` with symbol `hugeCompute`, find `return total;`, replace `return total + 1;`, occurrence `last`.";
		} else if (fx.id.includes("semantic/async-try-catch")) {
			guidance += " For this edit, call `pi_blitz_try_catch` with symbol `loadUser`, catchBody `console.error(error);\nthrow error;`, and indent 2.";
		} else if (fx.id.includes("semantic/class-method-try-catch")) {
			guidance += " For this edit, call `pi_blitz_try_catch` with symbol `renderScore`, catchBody `console.error(error);\nthrow error;`, and indent 2.";
		} else if (fx.id.includes("semantic/arrow-replace-return")) {
			guidance += " For this edit, call `pi_blitz_replace_return` with symbol `pickLabel`, expr `\"unknown\"`, occurrence `last`.";
		} else if (fx.id.includes("semantic/nested-return-occurrence")) {
			guidance += " For this edit, call `pi_blitz_replace_return` with symbol `classify`, expr `\"other\"`, occurrence `last`.";
		} else if (fx.id.includes("semantic/tsx-replace-return")) {
			guidance += " For this edit, call `pi_blitz_replace_return` with symbol `StatusBadge`, expr `<strong className=\"badge\">{label.toUpperCase()}</strong>`, occurrence `only`.";
		} else if (fx.id.includes("small")) {
			guidance += " For this edit, route to core oldText/newText.";
		}
		prompt = `${guidance}\n\n${prompt}`;
	}
	const semanticTools: Record<string, string> = {
		"semantic/async-try-catch": "pi_blitz_try_catch",
		"semantic/class-method-try-catch": "pi_blitz_try_catch",
		"semantic/arrow-replace-return": "pi_blitz_replace_return",
		"semantic/nested-return-occurrence": "pi_blitz_replace_return",
		"semantic/tsx-replace-return": "pi_blitz_replace_return",
	};
	const toolsOverride = lane !== "blitz"
		? undefined
		: fx.id.includes("multi/large-structural")
			? "pi_blitz_patch"
			: semanticTools[fx.id];
	const r = runPi(lane, prompt, targetDir, toolsOverride);
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
	if (laneFilter) console.log(`Lane filter: ${laneFilter}`);
	console.log(`Tokenizer: cl100k_base via tiktoken (for tool-call arg compare)`);
	console.log("");

	type Row = {
		fixture: string;
		className: string;
		recommendedLane: Lane | "";
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

	const lanesForFixture = (fx: Fixture): Lane[] => {
		if (laneFilter) return [laneFilter];
		if (fx.lanePolicy === "core-only") return ["core"];
		return ["core", "blitz"];
	};
	for (const fx of selectedFixtures) {
		for (const lane of lanesForFixture(fx)) {
			const runs: LaneResult[] = [];
			for (let i = 0; i < iters; i++) {
				const r = await runLane(lane, fx);
				runs.push(r);
				if (verbose) console.error(`[${fx.id}][${lane}][iter ${i}] output=${r.session.totalOutputTokens} args=${r.session.editToolCallArgsTokens} ok=${r.correct} wall=${r.wallMs.toFixed(0)}`);
			}
			rows.push({
				fixture: fx.id,
				className: fx.className ?? "",
				recommendedLane: fx.recommendedLane ?? "",
				lane,
				wallMsMedian: median(runs.map((r) => r.wallMs)),
				outputMedian: median(runs.map((r) => r.session.totalOutputTokens)),
				argsTokensMedian: median(runs.map((r) => r.session.editToolCallArgsTokens)),
				correctRate: runs.filter((r) => r.correct).length / runs.length,
				costSum: runs.reduce((a, r) => a + r.session.totalCost, 0),
			});
		}
	}

	const lines: string[] = [];
	lines.push("| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |");
	lines.push("|---|---|---|---|---:|---:|---:|---:|---:|");
	for (const r of rows) {
		lines.push(`| ${r.fixture} | ${r.className} | ${r.recommendedLane} | ${r.lane} | ${r.wallMsMedian.toFixed(0)} | ${r.outputMedian} | ${r.argsTokensMedian} | ${pct(r.correctRate * 100)} | ${r.costSum.toFixed(4)} |`);
	}

	console.log(lines.join("\n"));
	const summaryLines: string[] = [];
	summaryLines.push("", "## Pairwise savings");
	for (const fx of selectedFixtures) {
		const core = rows.find((r) => r.fixture === fx.id && r.lane === "core");
		const blitz = rows.find((r) => r.fixture === fx.id && r.lane === "blitz");
		if (!core || !blitz) continue;
		const savedOutput = core.outputMedian
			? 100 * (1 - blitz.outputMedian / core.outputMedian)
			: 0;
		const savedArgs = core.argsTokensMedian
			? 100 * (1 - blitz.argsTokensMedian / core.argsTokensMedian)
			: 0;
		summaryLines.push(`${fx.id}: saved session output ${pct(savedOutput)}, saved tool-call args ${pct(savedArgs)}`);
	}

	console.log(summaryLines.join("\n"));
	const payload = { provider, model, iters, timeoutMs, generatedAt: new Date().toISOString(), rows };
	if (jsonOut) await writeFile(jsonOut, JSON.stringify(payload, null, 2));
	if (mdOut) await writeFile(mdOut, [`# Pi matrix results`, ``, `Provider: ${provider}`, `Model: ${model}`, `Iterations: ${iters}`, `Generated: ${payload.generatedAt}`, ``, lines.join("\n"), summaryLines.join("\n")].join("\n"));
	releaseTokenizer();
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
