#!/usr/bin/env bun
/**
 * True same-session Pi/tmux/Tokscale edit-streak runner.
 *
 * One Pi command receives one ordered multi-step prompt and performs all edits in
 * one session dir. This is intentionally separate from pi-matrix.ts so existing
 * isolated-row benchmark behavior stays stable.
 */

import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { chmod, mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, join, resolve } from "node:path";
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ_BIN_DIR = join(REPO_ROOT, "zig-out/bin");
const DEFAULT_PI_BIN = "/home/kenzo/.local/bin/pi";
const DEFAULT_PI_BLITZ_DIST = "/home/kenzo/dev/pi-blitz/dist/index.js";
const DEFAULT_PI_BLITZ_SKILL = "/home/kenzo/dev/pi-blitz/skills/pi-blitz";

type Lane = "core" | "router" | "blitz-edit";
type ScenarioId = "tiny-10" | "mixed-20" | "same-file-multi";
type Step = { id: string; path: string; before: string; after: string };
type Scenario = { id: ScenarioId; title: string; steps: Step[] };

type UsageTotals = {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
};

type ToolCallRecord = { name: string; arguments: unknown; argTokens: number };
type ToolResultRecord = {
	toolName: string;
	text: string;
	resultPayloadTokens: number;
};

type StepResult = {
	id: string;
	path: string;
	correct: boolean;
	expectedSha: string;
	actualSha: string;
};

const argv = process.argv.slice(2);
const argFlag = (flag: string, fallback: string) => {
	const idx = argv.findIndex(
		(arg) => arg === flag || arg.startsWith(`${flag}=`),
	);
	if (idx < 0) return fallback;
	const raw = argv[idx]!;
	if (raw.includes("=")) return raw.split("=").slice(1).join("=");
	return argv[idx + 1] ?? fallback;
};
const hasFlag = (flag: string) => argv.includes(flag);

const provider = argFlag("--provider", "zai");
const model = argFlag("--model", "glm-4.5-air");
const lane = argFlag("--lane", "core") as Lane;
const scenarioId = argFlag("--scenario", "tiny-10") as ScenarioId;
const timeoutMs = Number.parseInt(argFlag("--timeout-ms", "180000"), 10);
const piBin = argFlag("--pi-bin", process.env.PI_BIN ?? DEFAULT_PI_BIN);
const extension = argFlag(
	"--extension",
	process.env.PI_BLITZ_DIST ?? DEFAULT_PI_BLITZ_DIST,
);
const skill = argFlag(
	"--skill",
	process.env.PI_BLITZ_SKILL ?? DEFAULT_PI_BLITZ_SKILL,
);
const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const runRoot = resolve(
	argFlag(
		"--run-root",
		join(REPO_ROOT, "reports/pi-tmux-runs", `true-streak-${stamp}`),
	),
);
const jsonOut = resolve(
	argFlag(
		"--json-out",
		join(
			REPO_ROOT,
			"reports",
			`pi-tmux-true-streak-${scenarioId}-${lane}-${stamp}.json`,
		),
	),
);
const mdOut = resolve(
	argFlag(
		"--md-out",
		join(
			REPO_ROOT,
			"reports",
			`pi-tmux-true-streak-${scenarioId}-${lane}-${stamp}.md`,
		),
	),
);
const tokScaleRequired = hasFlag("--tokscale");
const tmuxSession = `pi-true-streak-${stamp}`;

if (!["core", "router", "blitz-edit"].includes(lane))
	throw new Error(`invalid --lane ${lane}`);
if (!["tiny-10", "mixed-20", "same-file-multi"].includes(scenarioId))
	throw new Error(`invalid --scenario ${scenarioId}`);

const shellQuote = (value: string) => `'${value.replaceAll("'", `'\\''`)}'`;
const safeName = (value: string) =>
	value.replace(/[^a-zA-Z0-9_.-]+/g, "_").slice(0, 80);
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const sha = (text: string) =>
	createHash("sha256").update(text).digest("hex").slice(0, 16);

const tinyScenario = (): Scenario => ({
	id: "tiny-10",
	title: "10 tiny/core-like edits",
	steps: Array.from({ length: 10 }, (_, i) => {
		const n = i + 1;
		return {
			id: `tiny-${String(n).padStart(2, "0")}`,
			path: `tiny-${String(n).padStart(2, "0")}.ts`,
			before: `export const label${n} = "old-${n}";\n`,
			after: `export const label${n} = "new-${n}";\n`,
		};
	}),
});

const mixedScenario = (): Scenario => {
	const base = tinyScenario().steps;
	const extras: Step[] = [
		{
			id: "json-version",
			path: "package.json",
			before: `{"name":"demo","version":"0.1.0"}\n`,
			after: `{"name":"demo","version":"0.2.0"}\n`,
		},
		{
			id: "md-heading",
			path: "README.md",
			before: `# Demo\n\nStatus: draft\n`,
			after: `# Demo\n\nStatus: ready\n`,
		},
		{
			id: "css-color",
			path: "style.css",
			before: `.header {\n  color: red;\n}\n`,
			after: `.header {\n  color: blue;\n}\n`,
		},
		{
			id: "html-title",
			path: "index.html",
			before: `<title>Old</title>\n`,
			after: `<title>New</title>\n`,
		},
		{
			id: "yaml-port",
			path: "config.yml",
			before: `port: 3000\n`,
			after: `port: 4000\n`,
		},
		{
			id: "toml-flag",
			path: "settings.toml",
			before: `enabled = false\n`,
			after: `enabled = true\n`,
		},
		{
			id: "js-return",
			path: "util.js",
			before: `export function answer() { return 41; }\n`,
			after: `export function answer() { return 42; }\n`,
		},
		{
			id: "ts-type",
			path: "types.ts",
			before: `export type Mode = "dev";\n`,
			after: `export type Mode = "prod";\n`,
		},
		{
			id: "txt-word",
			path: "notes.txt",
			before: `alpha beta gamma\n`,
			after: `alpha delta gamma\n`,
		},
		{
			id: "env-key",
			path: ".env.example",
			before: `FEATURE_X=0\n`,
			after: `FEATURE_X=1\n`,
		},
	];
	return {
		id: "mixed-20",
		title: "20 mixed language/config/markdown/code edits",
		steps: [...base, ...extras],
	};
};

const sameFileScenario = (): Scenario => {
	const before = `export const a = "old-a";\nexport const b = "old-b";\nexport const c = "old-c";\n`;
	return {
		id: "same-file-multi",
		title: "same-file multi-edit scenario",
		steps: [
			{
				id: "same-a",
				path: "same.ts",
				before,
				after: before.replace('"old-a"', '"new-a"'),
			},
			{
				id: "same-b",
				path: "same.ts",
				before: before.replace('"old-a"', '"new-a"'),
				after: before
					.replace('"old-a"', '"new-a"')
					.replace('"old-b"', '"new-b"'),
			},
			{
				id: "same-c",
				path: "same.ts",
				before: before
					.replace('"old-a"', '"new-a"')
					.replace('"old-b"', '"new-b"'),
				after: before
					.replace('"old-a"', '"new-a"')
					.replace('"old-b"', '"new-b"')
					.replace('"old-c"', '"new-c"'),
			},
		],
	};
};

const scenario =
	scenarioId === "mixed-20"
		? mixedScenario()
		: scenarioId === "same-file-multi"
			? sameFileScenario()
			: tinyScenario();

const writeInitialFiles = async (workDir: string, steps: Step[]) => {
	const seen = new Set<string>();
	for (const step of steps) {
		if (seen.has(step.path)) continue;
		seen.add(step.path);
		const full = join(workDir, step.path);
		await mkdir(dirname(full), { recursive: true });
		await writeFile(full, step.before, "utf8");
	}
};

const finalExpectedByPath = (steps: Step[]) => {
	const map = new Map<string, string>();
	for (const step of steps) map.set(step.path, step.after);
	return map;
};


const exactChangedSpan = (before: string, after: string) => {
	let start = 0;
	while (start < before.length && start < after.length && before[start] === after[start]) start += 1;
	let beforeEnd = before.length;
	let afterEnd = after.length;
	while (beforeEnd > start && afterEnd > start && before[beforeEnd - 1] === after[afterEnd - 1]) {
		beforeEnd -= 1;
		afterEnd -= 1;
	}
	const isBoundary = (ch: string | undefined) => ch === undefined || /\s|[=;:,{}()<>]/.test(ch);
	while (start > 0 && !isBoundary(before[start - 1]) && !isBoundary(after[start - 1])) start -= 1;
	while (beforeEnd < before.length && afterEnd < after.length && !isBoundary(before[beforeEnd]) && !isBoundary(after[afterEnd])) {
		beforeEnd += 1;
		afterEnd += 1;
	}
	return { oldText: before.slice(start, beforeEnd), newText: after.slice(start, afterEnd) };
};

const buildPrompt = async (workDir: string, steps: Step[]): Promise<string> => {
	if (lane === "blitz-edit") {
		const e = steps.map((step) => {
			const { oldText, newText } = exactChangedSpan(step.before, step.after);
			return ["x", join(workDir, step.path), oldText, newText];
		});
		return [
			`Run ${steps.length} ordered exact edits in this one Pi session.`,
			"Use only blitz_edit. No prose. Call blitz_edit exactly once with this exact JSON:",
			JSON.stringify({ e }),
		].join("\n");
	}

	const lines = [
		`Run ${steps.length} ordered edits in this one Pi session.`,
		`Use only the available ${lane === "core" ? "edit" : "pi_blitz_route_edit"} tool.`,
		"No prose. Keep calling tools until every step is done. Then stop.",
		"",
		"Steps:",
	];
	steps.forEach((step, idx) => {
		const file = join(workDir, step.path);
		if (lane === "core") {
			lines.push(
				`${idx + 1}. Call edit with exact JSON: ${JSON.stringify({ path: file, oldText: step.before, newText: step.after })}`,
			);
		} else {
			lines.push(
				`${idx + 1}. Call pi_blitz_route_edit with exact JSON: ${JSON.stringify({ f: file, r: "blitz", s: `ru\t${step.before}\t${step.after}`, fallbackContextTokensExpected: 5000 })}`,
			);
		}
	});
	lines.push("", "Initial file contents:");
	for (const [path] of finalExpectedByPath(steps)) {
		lines.push(
			`--- ${join(workDir, path)} ---`,
			await readFile(join(workDir, path), "utf8"),
		);
	}
	return lines.join("\n");
};

const piArgs = (promptFile: string, sessionDir: string) => {
	const common = [
		"--offline",
		"-p",
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
	if (lane === "core")
		return [
			...common,
			"--no-skills",
			"--no-extensions",
			"--tools",
			"edit",
			`@${promptFile}`,
		];
	return [
		...common,
		"--no-extensions",
		"--extension",
		extension,
		"--skill",
		skill,
		"--tools",
		lane === "blitz-edit" ? "blitz_edit" : "pi_blitz_route_edit",
		`@${promptFile}`,
	];
};

const runTmux = async (
	commandFile: string,
	exitFile: string,
	stdoutLog: string,
	stderrLog: string,
) => {
	const window = safeName(`${scenario.id}-${lane}`) || "run";
	spawnSync(
		"tmux",
		["new-session", "-d", "-s", tmuxSession, "-n", window, commandFile],
		{ encoding: "utf8" },
	);
	spawnSync("tmux", ["set-option", "-t", tmuxSession, "remain-on-exit", "on"], {
		encoding: "utf8",
	});
	spawnSync(
		"tmux",
		[
			"set-window-option",
			"-t",
			`${tmuxSession}:${window}`,
			"remain-on-exit",
			"on",
		],
		{ encoding: "utf8" },
	);
	console.error(`tmux attach -t ${tmuxSession}`);
	const t0 = performance.now();
	while (!existsSync(exitFile) && performance.now() - t0 < timeoutMs)
		await sleep(500);
	if (!existsSync(exitFile)) {
		await writeFile(
			exitFile,
			JSON.stringify(
				{ status: -1, wallMs: performance.now() - t0, timedOut: true },
				null,
				2,
			),
		);
	}
	const exit = JSON.parse(await readFile(exitFile, "utf8")) as {
		status: number;
		wallMs: number;
		timedOut?: boolean;
	};
	return {
		...exit,
		stdout: await readFile(stdoutLog, "utf8").catch(() => ""),
		stderr: await readFile(stderrLog, "utf8").catch(() => ""),
	};
};

const findJsonl = async (dir: string): Promise<string[]> => {
	const out: string[] = [];
	for (const name of await readdir(dir).catch(() => [])) {
		const full = join(dir, name);
		if (name.endsWith(".jsonl")) out.push(full);
	}
	return out;
};

const parseSession = async (sessionDir: string) => {
	const usage: UsageTotals = {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		totalTokens: 0,
	};
	const toolCalls: ToolCallRecord[] = [];
	const toolResults: ToolResultRecord[] = [];
	const files = await findJsonl(sessionDir);
	for (const file of files) {
		for (const line of (await readFile(file, "utf8"))
			.split(/\n+/)
			.filter(Boolean)) {
			let event: any;
			try {
				event = JSON.parse(line);
			} catch {
				continue;
			}
			const msg = event.message;
			const u = msg?.usage;
			if (u) {
				usage.input += Number(u.input ?? 0);
				usage.output += Number(u.output ?? 0);
				usage.cacheRead += Number(u.cacheRead ?? 0);
				usage.cacheWrite += Number(u.cacheWrite ?? 0);
				usage.totalTokens += Number(u.totalTokens ?? 0);
			}
			for (const part of msg?.content ?? []) {
				if (part?.type === "toolCall") {
					const argsText = JSON.stringify(part.arguments ?? {});
					toolCalls.push({
						name: part.name,
						arguments: part.arguments,
						argTokens: countTokens(argsText),
					});
				}
			}
			if (event.type === "message" && msg?.role === "toolResult") {
				const text = (msg.content ?? [])
					.map((p: any) => p?.text ?? "")
					.join("\n");
				toolResults.push({
					toolName: msg.toolName,
					text,
					resultPayloadTokens: countTokens(text),
				});
			}
		}
	}
	return { sessionFiles: files, usage, toolCalls, toolResults };
};

const runTokscale = (sessionDir: string) => {
	const home = join(runRoot, "tokscale-home");
	spawnSync("mkdir", ["-p", join(home, ".pi/agent")]);
	spawnSync("cp", ["-R", sessionDir, join(home, ".pi/agent/sessions")]);
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
		{ encoding: "utf8", maxBuffer: 20 * 1024 * 1024 },
	);
	return {
		status: r.status ?? -1,
		stdout: r.stdout ?? "",
		stderr: r.stderr ?? "",
	};
};

const main = async () => {
	const workDir = join(runRoot, "work");
	const sessionDir = join(runRoot, "sessions");
	await mkdir(workDir, { recursive: true });
	await mkdir(sessionDir, { recursive: true });
	await writeInitialFiles(workDir, scenario.steps);
	const prompt = await buildPrompt(workDir, scenario.steps);
	const promptFile = join(runRoot, "prompt.md");
	const commandFile = join(runRoot, "command.sh");
	const stdoutLog = join(runRoot, "stdout.log");
	const stderrLog = join(runRoot, "stderr.log");
	const exitFile = join(runRoot, "exit.json");
	await writeFile(promptFile, prompt, "utf8");
	await writeFile(stdoutLog, "", "utf8");
	await writeFile(stderrLog, "", "utf8");
	const args = piArgs(promptFile, sessionDir);
	await writeFile(
		commandFile,
		`#!/usr/bin/env bash\nset -u\nexport PATH=${shellQuote(BLITZ_BIN_DIR)}":$PATH"\nexport PI_BLITZ_TOOL_PROFILE=${lane === "blitz-edit" ? "minimal" : "router"}\ncd ${shellQuote(workDir)}\nstart_ms=$(date +%s%3N)\nstatus=0\n${[piBin, ...args].map(shellQuote).join(" ")} > >(tee ${shellQuote(stdoutLog)}) 2> >(tee ${shellQuote(stderrLog)} >&2) || status=$?\nend_ms=$(date +%s%3N)\nprintf '{"status":%s,"wallMs":%s,"timedOut":false}\\n' "$status" "$((end_ms - start_ms))" > ${shellQuote(exitFile)}\nexit "$status"\n`,
		"utf8",
	);
	await chmod(commandFile, 0o755);
	const exit = await runTmux(commandFile, exitFile, stdoutLog, stderrLog);
	const parsed = await parseSession(sessionDir);
	const expected = finalExpectedByPath(scenario.steps);
	const stepResults: StepResult[] = [];
	for (const [path, text] of expected) {
		const actual = await readFile(join(workDir, path), "utf8").catch(() => "");
		stepResults.push({
			id: path,
			path,
			correct: actual === text,
			expectedSha: sha(text),
			actualSha: sha(actual),
		});
	}
	const skillText =
		lane === "router"
			? await readFile(join(skill, "SKILL.md"), "utf8").catch(() => "")
			: "";
	const tokScale = tokScaleRequired ? runTokscale(sessionDir) : null;
	if (tokScaleRequired && tokScale?.status !== 0)
		console.error(tokScale?.stderr || tokScale?.stdout);
	const totals = {
		schemaTokens: 0,
		skillTokens: countTokens(skillText),
		promptTokens: countTokens(prompt),
		argTokens: parsed.toolCalls.reduce((sum, t) => sum + t.argTokens, 0),
		outputTokens: parsed.usage.output,
		cacheRead: parsed.usage.cacheRead,
		cacheWrite: parsed.usage.cacheWrite,
		resultPayloadTokens: parsed.toolResults.reduce(
			(sum, t) => sum + t.resultPayloadTokens,
			0,
		),
		residualInputTokens: Math.max(
			0,
			parsed.usage.input - countTokens(prompt) - countTokens(skillText),
		),
		totalContextTokens:
			parsed.usage.input +
			parsed.usage.output +
			parsed.usage.cacheRead +
			parsed.usage.cacheWrite,
	};
	const report = {
		generatedAt: new Date().toISOString(),
		status:
			stepResults.every((s) => s.correct) && exit.status === 0 && !exit.timedOut
				? "accepted"
				: "caveated",
		provider,
		model,
		runner: "tmux",
		lane,
		scenario: scenario.id,
		scenarioTitle: scenario.title,
		runRoot,
		tmuxSession,
		piBin,
		extension: lane === "router" ? extension : null,
		skill: lane === "router" ? skill : null,
		tokScaleMode: tokScaleRequired ? "required" : "not-run",
		tokScale,
		exit: {
			status: exit.status,
			wallMs: exit.wallMs,
			timedOut: Boolean(exit.timedOut),
		},
		artifacts: {
			promptFile,
			commandFile,
			stdoutLog,
			stderrLog,
			exitFile,
			sessionDir,
			sessionFiles: parsed.sessionFiles,
			workDir,
		},
		steps: stepResults,
		toolCalls: parsed.toolCalls,
		toolResults: parsed.toolResults,
		usage: parsed.usage,
		totals,
		caveats: [
			"schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.",
			"true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.",
		],
	};
	await mkdir(dirname(jsonOut), { recursive: true });
	await writeFile(jsonOut, JSON.stringify(report, null, 2));
	const md = `# Pi/tmux/Tokscale true sequential streak — ${scenario.id} ${lane}\n\nStatus: ${report.status}\nProvider/model: ${provider}/${model}\nRunner: tmux\nRun root: ${runRoot}\nTmux session: ${tmuxSession}\nTokscale: ${report.tokScaleMode}${tokScale ? ` (exit ${tokScale.status})` : ""}\n\n## Cumulative tokens\n\n| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |\n|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n| ${totals.schemaTokens} | ${totals.skillTokens} | ${totals.promptTokens} | ${totals.argTokens} | ${totals.outputTokens} | ${totals.cacheRead} | ${totals.cacheWrite} | ${totals.resultPayloadTokens} | ${totals.residualInputTokens} | ${totals.totalContextTokens} |\n\n## Correctness\n\n| Step/file | Correct | Expected sha | Actual sha |\n|---|---|---:|---:|\n${stepResults.map((s) => `| ${s.path} | ${s.correct ? "yes" : "no"} | ${s.expectedSha} | ${s.actualSha} |`).join("\n")}\n\n## Caveats\n\n${report.caveats.map((c) => `- ${c}`).join("\n")}\n`;
	await writeFile(mdOut, md);
	releaseTokenizer();
	console.log(
		JSON.stringify(
			{
				jsonOut,
				mdOut,
				status: report.status,
				totalContextTokens: totals.totalContextTokens,
				correct: stepResults.every((s) => s.correct),
			},
			null,
			2,
		),
	);
};

await main();
