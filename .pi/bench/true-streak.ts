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

const REPO_ROOT = new URL("../..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ_BIN_DIR = join(REPO_ROOT, "zig-out/bin");
const DEFAULT_PI_BIN = "/home/kenzo/.local/bin/pi";
const DEFAULT_PI_BLITZ_DIST = "/home/kenzo/dev/pi-blitz/dist/index.js";
const DEFAULT_PI_BLITZ_SKILL = "/home/kenzo/dev/pi-blitz/skills/pi-blitz";
const DEFAULT_PI_BLITZ_PROFILE_DUMP =
	"/home/kenzo/dev/pi-blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260611.json";

type Lane = "core" | "router" | "blitz-edit" | "core-optimized";
type ScenarioId =
	| "tiny-10"
	| "mixed-20"
	| "same-file-multi"
	| "structural-3"
	| "class-b-inserts"
	| "class-d-config-docs"
	| "class-b-inserts-10"
	| "class-c-structural-10"
	| "class-d-config-docs-10"
	| "all-edit-types-gate";
type EditClassId =
	| "E01"
	| "E02"
	| "E03"
	| "E04"
	| "E05"
	| "E06"
	| "E07"
	| "E08"
	| "E09"
	| "E10"
	| "E11"
	| "E12"
	| "E13"
	| "E14"
	| "E15"
	| "E16"
	| "E17"
	| "E18";
type GateOutcome = "success" | "decline" | "noop" | "error";
type GateLane = "paired" | "blitz-only";
type GateRow = {
	id: string;
	classId: EditClassId;
	className: string;
	lanePolicy: GateLane;
	expectedBlitzOutcome: GateOutcome;
	expectedCoreOutcome?: GateOutcome;
	scenarioId: ScenarioId;
	fixture: string;
	notes: string;
};
type Step = { id: string; path: string; before: string; after: string };
type Scenario = { id: ScenarioId; title: string; steps: Step[] };
type AllEditTypeReportMetadata = {
	requestedScenario: ScenarioId;
	resolvedScenario: ScenarioId;
	rows: Array<Pick<GateRow, "id" | "classId" | "scenarioId" | "fixture">>;
	classIds: EditClassId[];
};
type SafetyFixture = {
	id: string;
	classId: Extract<EditClassId, "E13" | "E14" | "E15" | "E16" | "E17" | "E18">;
	fixture: string;
	path: string;
	initial: string;
	operation: string;
	expectedOutcome: Exclude<GateOutcome, "success">;
	expectedMutation: "none";
	expectedClassification: string;
	notes: string;
};

type UsageTotals = {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
	messages: number;
};

type ToolCallRecord = { name: string; arguments: unknown; argTokens: number };
type ToolResultRecord = {
	toolName: string;
	text: string;
	resultPayloadTokens: number;
};

export const isMinimalStructuralDecline = (
	laneValue: Lane,
	scenarioValue: ScenarioId,
	toolResults: Pick<ToolResultRecord, "toolName" | "text">[],
) =>
	laneValue === "blitz-edit" &&
	scenarioValue === "class-c-structural-10" &&
	toolResults.some(
		(result) =>
			result.toolName === "blitz_edit" &&
			result.text.includes("decline op=rb") &&
			result.text.includes("unsupported_structural_op_minimal") &&
			result.text.includes("no_mutation=true"),
	);

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
const profileDump = argFlag(
	"--profile-dump",
	process.env.PI_BLITZ_PROFILE_DUMP ?? DEFAULT_PI_BLITZ_PROFILE_DUMP,
);
const stamp = new Date().toISOString().replace(/[:.]/g, "-");
const runRoot = resolve(
	argFlag(
		"--run-root",
		join(REPO_ROOT, ".pi/reports/pi-tmux-runs", `true-streak-${stamp}`),
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
const selfCheckAllEditTypes = hasFlag("--self-check-all-edit-types");
const tmuxSession = `pi-true-streak-${stamp}`;

if (!["core", "router", "blitz-edit", "core-optimized"].includes(lane))
	throw new Error(`invalid --lane ${lane}`);
if (
	![
		"tiny-10",
		"mixed-20",
		"same-file-multi",
		"structural-3",
		"class-b-inserts",
		"class-d-config-docs",
		"class-b-inserts-10",
		"class-c-structural-10",
		"class-d-config-docs-10",
		"all-edit-types-gate",
	].includes(scenarioId)
)
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

const classBInsertsScenario = (): Scenario => ({
	id: "class-b-inserts",
	title: "Class B small anchor inserts",
	steps: [
		{
			id: "logging-timer",
			path: "logging.ts",
			before: `export function processOrder(orderId: string): void {\n  console.log(\`Processing order \${orderId}\`);\n  submit(orderId);\n}\n`,
			after: `export function processOrder(orderId: string): void {\n  console.log(\`Processing order \${orderId}\`);\n  console.time(\`Processing order \${orderId}\`);\n  submit(orderId);\n}\n`,
		},
		{
			id: "markdown-section",
			path: "README.md",
			before: `# Demo\n\n<!-- append-target -->\n`,
			after: `# Demo\n\n<!-- append-target -->\n## Configuration Reference\n\nSee the \`blitz --help\` command.\n`,
		},
	],
});

const classDConfigDocsScenario = (): Scenario => ({
	id: "class-d-config-docs",
	title: "Class D config/docs exact edits",
	steps: [
		{
			id: "ts-config-log-level",
			path: "config.ts",
			before: `export const config = {\n  logLevel: "info",\n  retries: 2,\n};\n`,
			after: `export const config = {\n  logLevel: "debug",\n  retries: 2,\n};\n`,
		},
		{
			id: "json-debug",
			path: "config.json",
			before: `{ "debug": false, "port": 3000 }\n`,
			after: `{ "debug": true, "port": 3000 }\n`,
		},
		{
			id: "toml-debug",
			path: "config.toml",
			before: `debug = false\nport = 3000\n`,
			after: `debug = true\nport = 3000\n`,
		},
		{
			id: "doc-status",
			path: "NOTES.md",
			before: `# Notes\n\nStatus: draft\n`,
			after: `# Notes\n\nStatus: ready\n`,
		},
	],
});

export const allEditTypesSuccessScenario = (): Scenario => ({
	id: "all-edit-types-gate",
	title: "Sprint D all edit-type success fixtures",
	steps: [
		{
			id: "e06-import-edit",
			path: "imports.ts",
			before: `import { readFile } from "node:fs/promises";\n\nexport async function load(path: string): Promise<string> {\n  return readFile(path, "utf8");\n}\n`,
			after: `import { existsSync } from "node:fs";\nimport { readFile } from "node:fs/promises";\n\nexport async function load(path: string): Promise<string> {\n  if (!existsSync(path)) return "";\n  return readFile(path, "utf8");\n}\n`,
		},
		{
			id: "e07-rename-local-usage",
			path: "rename-local.ts",
			before: `export function total(items: number[]): number {\n  const sum = items.reduce((acc, item) => acc + item, 0);\n  return sum;\n}\n`,
			after: `export function total(items: number[]): number {\n  const totalValue = items.reduce((acc, item) => acc + item, 0);\n  return totalValue;\n}\n`,
		},
		{
			id: "e10-wrap-try-catch",
			path: "wrap-body.ts",
			before: `export async function refresh(): Promise<string> {\n  const res = await fetch("/api/status");\n  return res.text();\n}\n`,
			after: `export async function refresh(): Promise<string> {\n  try {\n    const res = await fetch("/api/status");\n    return res.text();\n  } catch (error) {\n    return "offline";\n  }\n}\n`,
		},
		{
			id: "e11-delete-range",
			path: "delete-range.ts",
			before: `export function score(value: number): number {\n  const debug = value * 100;\n  console.log("debug", debug);\n  return value + 1;\n}\n`,
			after: `export function score(value: number): number {\n  return value + 1;\n}\n`,
		},
		{
			id: "e12-append-section",
			path: "append-section.md",
			before: `# Release Notes\n\n## Fixed\n\n- Correct stale cache state.\n`,
			after: `# Release Notes\n\n## Fixed\n\n- Correct stale cache state.\n\n## Added\n\n- Document all edit-type gate fixtures.\n`,
		},
	],
});

export const allEditTypesSafetyFixtures = (): SafetyFixture[] => [
	{
		id: "e13-noop-already-present",
		classId: "E13",
		fixture: "noop.ts",
		path: "noop.ts",
		initial: `export const mode = "ready";\n`,
		operation: `replace "ready" with "ready"`,
		expectedOutcome: "noop",
		expectedMutation: "none",
		expectedClassification: "already_present/noop",
		notes:
			"Requested state already present; Blitz must report noop without counting success.",
	},
	{
		id: "e14-ambiguous-match",
		classId: "E14",
		fixture: "ambiguous.ts",
		path: "ambiguous.ts",
		initial: `export const first = "same";\nexport const second = "same";\n`,
		operation: `replace ambiguous "same" with "done"`,
		expectedOutcome: "decline",
		expectedMutation: "none",
		expectedClassification: "ambiguous_match/decline",
		notes: "Repeated old text must decline before mutation.",
	},
	{
		id: "e15-no-match-stale",
		classId: "E15",
		fixture: "stale.ts",
		path: "stale.ts",
		initial: `export const version = "current";\n`,
		operation: `replace stale "previous" with "next"`,
		expectedOutcome: "decline",
		expectedMutation: "none",
		expectedClassification: "no_match/stale_context",
		notes: "Missing old text must decline with original file intact.",
	},
	{
		id: "e16-unsupported-structural",
		classId: "E16",
		fixture: "plain.txt",
		path: "plain.txt",
		initial: `plain text has no function symbol\n`,
		operation: `rb function missingSymbol`,
		expectedOutcome: "decline",
		expectedMutation: "none",
		expectedClassification: "unsupported_structural_op_minimal",
		notes:
			"Unsupported structural op in minimal profile must decline, not fall back.",
	},
	{
		id: "e17-path-escape",
		classId: "E17",
		fixture: "outside-link.ts",
		path: "outside-link.ts",
		initial: `export const safe = true;\n`,
		operation: `attempt edit through path traversal/symlink outside workspace`,
		expectedOutcome: "decline",
		expectedMutation: "none",
		expectedClassification: "path_escape_or_symlink_boundary",
		notes: "Path boundary safety row must not mutate outside workspace.",
	},
	{
		id: "e18-rollback-failure",
		classId: "E18",
		fixture: "rollback-a.ts + rollback-b.ts",
		path: "rollback-a.ts",
		initial: `export const a = "original";\n`,
		operation: `multi-edit where later rollback-b.ts edit fails after rollback-a.ts would change`,
		expectedOutcome: "decline",
		expectedMutation: "none",
		expectedClassification:
			"rollback_decline_no_partial_mutation_or_truthful_failure",
		notes:
			"Failed batch must leave no partial mutation or report incomplete rollback truthfully.",
	},
];

const allEditTypeGateRows = (): GateRow[] => [
	{
		id: "all-e01-tiny-exact",
		classId: "E01",
		className: "tiny exact single",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "tiny-10",
		fixture: "tiny-01.ts",
		notes: "Tiny guard row; one exact old/new replacement.",
	},
	{
		id: "all-e02-same-file-multi",
		classId: "E02",
		className: "exact same-file multi",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "same-file-multi",
		fixture: "same.ts",
		notes: "Multiple exact replacements in one file.",
	},
	{
		id: "all-e03-cross-file-multi",
		classId: "E03",
		className: "exact cross-file multi",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "mixed-20",
		fixture: "tiny-01.ts + package.json + README.md",
		notes:
			"Mixed scenario covers cross-file exact replacements with rollback-backed application.",
	},
	{
		id: "all-e04-config-set-key",
		classId: "E04",
		className: "config set/key edit",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "class-d-config-docs-10",
		fixture: "config-1.json/settings.toml/config.yml",
		notes:
			"Config exact/key-like edits; JSONC parity remains a separate implementation decision if strict set_key route is required.",
	},
	{
		id: "all-e05-doc-comment",
		classId: "E05",
		className: "doc/comment edit",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "class-d-config-docs-10",
		fixture: "doc-2.md",
		notes: "Markdown/doc text update without formatting drift.",
	},
	{
		id: "all-e06-import-edit",
		classId: "E06",
		className: "import edit",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "all-edit-types-gate",
		fixture: "imports.ts",
		notes:
			"Sprint D runnable paired fixture: import insertion plus usage guard with exact expected output.",
	},
	{
		id: "all-e07-rename-local-usage",
		classId: "E07",
		className: "rename/local usage",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "all-edit-types-gate",
		fixture: "rename-local.ts",
		notes:
			"Sprint D runnable paired fixture: exact same-file local definition and usage rename, not a global symbol graph claim.",
	},
	{
		id: "all-e08-structural-replace",
		classId: "E08",
		className: "structural function body replace",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "class-c-structural-10",
		fixture: "structural-10.ts",
		notes: "TS/JS unique function body replacement from bli-sh7d policy.",
	},
	{
		id: "all-e09-structural-insert-after",
		classId: "E09",
		className: "structural insert-after function",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "structural-3",
		fixture: "structural.ts",
		notes: "TS/JS unique function insert-after from bli-sh7d policy.",
	},
	{
		id: "all-e10-wrap-try-catch",
		classId: "E10",
		className: "wrap body / try-catch",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "all-edit-types-gate",
		fixture: "wrap-body.ts",
		notes:
			"Sprint D runnable paired fixture: exact replacement wraps body in try/catch; structural route remains separate if claimed.",
	},
	{
		id: "all-e11-delete-range",
		classId: "E11",
		className: "delete range",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "all-edit-types-gate",
		fixture: "delete-range.ts",
		notes:
			"Sprint D runnable paired fixture: exact range removal represented by oldText to empty replacement.",
	},
	{
		id: "all-e12-append-section",
		classId: "E12",
		className: "append section",
		lanePolicy: "paired",
		expectedBlitzOutcome: "success",
		expectedCoreOutcome: "success",
		scenarioId: "all-edit-types-gate",
		fixture: "append-section.md",
		notes:
			"Sprint D runnable paired fixture: exact anchor expansion appends a Markdown section.",
	},
	{
		id: "all-e13-noop-already-present",
		classId: "E13",
		className: "noop/already-present",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "noop",
		scenarioId: "all-edit-types-gate",
		fixture: "noop.ts",
		notes: "Must classify as noop/already_present, not Blitz edit success.",
	},
	{
		id: "all-e14-ambiguous-match",
		classId: "E14",
		className: "ambiguous match",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "decline",
		scenarioId: "all-edit-types-gate",
		fixture: "ambiguous.ts",
		notes: "Repeated old text must decline with no mutation.",
	},
	{
		id: "all-e15-no-match-stale",
		classId: "E15",
		className: "no-match/stale context",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "decline",
		scenarioId: "all-edit-types-gate",
		fixture: "stale.ts",
		notes: "Missing/stale old text must decline with no mutation.",
	},
	{
		id: "all-e16-unsupported-structural",
		classId: "E16",
		className: "unsupported structural",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "decline",
		scenarioId: "all-edit-types-gate",
		fixture: "plain.txt",
		notes:
			"Unsupported structural target must decline; safety only, not success.",
	},
	{
		id: "all-e17-path-escape",
		classId: "E17",
		className: "path escape/symlink/traversal",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "decline",
		scenarioId: "all-edit-types-gate",
		fixture: "outside-link.ts",
		notes: "Path escape/symlink/traversal must not mutate outside workspace.",
	},
	{
		id: "all-e18-rollback-failure",
		classId: "E18",
		className: "rollback failure case",
		lanePolicy: "blitz-only",
		expectedBlitzOutcome: "decline",
		scenarioId: "all-edit-types-gate",
		fixture: "rollback-a.ts + rollback-b.ts",
		notes:
			"Later failed edit must roll back earlier mutations or report incomplete rollback truthfully.",
	},
];

const selfCheckAllEditTypeRows = () => {
	const rows = allEditTypeGateRows();
	const required: EditClassId[] = [
		"E01",
		"E02",
		"E03",
		"E04",
		"E05",
		"E06",
		"E07",
		"E08",
		"E09",
		"E10",
		"E11",
		"E12",
		"E13",
		"E14",
		"E15",
		"E16",
		"E17",
		"E18",
	];
	const byClass = new Map<EditClassId, GateRow[]>();
	for (const row of rows) {
		const existing = byClass.get(row.classId) ?? [];
		existing.push(row);
		byClass.set(row.classId, existing);
	}
	const missing = required.filter((id) => !byClass.has(id));
	if (missing.length > 0)
		throw new Error(`missing all edit-type classes: ${missing.join(",")}`);
	const duplicateRows = rows
		.map((row) => row.id)
		.filter((id, index, ids) => ids.indexOf(id) !== index);
	if (duplicateRows.length > 0)
		throw new Error(
			`duplicate all edit-type row ids: ${duplicateRows.join(",")}`,
		);
	const invalidSuccess = rows.filter(
		(row) =>
			(row.expectedBlitzOutcome === "decline" ||
				row.expectedBlitzOutcome === "noop") &&
			row.lanePolicy === "paired",
	);
	if (invalidSuccess.length > 0)
		throw new Error(
			`decline/noop rows must not be paired success rows: ${invalidSuccess
				.map((row) => row.id)
				.join(",")}`,
		);
	const successRows = rows.filter(
		(row) => row.expectedBlitzOutcome === "success",
	);
	if (successRows.some((row) => row.lanePolicy !== "paired"))
		throw new Error("success-intended rows must be paired core+Blitz rows");
	const safetyRows = rows.filter(
		(row) => row.expectedBlitzOutcome !== "success",
	);
	if (safetyRows.some((row) => row.expectedCoreOutcome !== undefined))
		throw new Error("safety rows must not define core success baselines");
	const successFixturePaths = new Set(
		allEditTypesSuccessScenario().steps.map((step) => step.path),
	);
	const sprintDSuccessRows = rows.filter((row) =>
		["E06", "E07", "E10", "E11", "E12"].includes(row.classId),
	);
	const missingSuccessFixtures = sprintDSuccessRows.filter(
		(row) =>
			row.scenarioId !== "all-edit-types-gate" ||
			!successFixturePaths.has(row.fixture) ||
			row.notes.includes("required"),
	);
	if (missingSuccessFixtures.length > 0)
		throw new Error(
			`unmaterialized Sprint D success fixtures: ${missingSuccessFixtures
				.map((row) => row.id)
				.join(",")}`,
		);
	const safetyFixtures = allEditTypesSafetyFixtures();
	const safetyByClass = new Map(
		safetyFixtures.map((fixture) => [fixture.classId, fixture]),
	);
	const missingSafetyFixtures = safetyRows.filter((row) => {
		const fixture = safetyByClass.get(row.classId as SafetyFixture["classId"]);
		return (
			fixture === undefined ||
			fixture.fixture !== row.fixture ||
			fixture.expectedOutcome !== row.expectedBlitzOutcome ||
			fixture.expectedMutation !== "none"
		);
	});
	if (missingSafetyFixtures.length > 0)
		throw new Error(
			`unmaterialized Sprint D safety fixtures: ${missingSafetyFixtures
				.map((row) => row.id)
				.join(",")}`,
		);
	console.log(
		`all-edit-type self-check passed: rows=${rows.length} classes=${required.length} success=${successRows.length} safety=${safetyRows.length}`,
	);
};

const classBInserts10Scenario = (): Scenario => ({
	id: "class-b-inserts-10",
	title: "Class B 10 anchor inserts",
	steps: Array.from({ length: 10 }, (_, i) => {
		const n = i + 1;
		return {
			id: `insert-${n}`,
			path: `insert-${n}.ts`,
			before: `export function task${n}(): void {\n  log("task-${n}");\n  run("task-${n}");\n}\n`,
			after: `export function task${n}(): void {\n  log("task-${n}");\n  time("task-${n}");\n  run("task-${n}");\n}\n`,
		};
	}),
});

const classCStructural10Scenario = (): Scenario => {
	let before = "";
	for (let i = 1; i <= 10; i++)
		before += `export function node${i}(value: number): number {\n  return value + ${i};\n}\n\n`;
	const steps: Step[] = [];
	let current = before;
	for (let i = 1; i <= 10; i++) {
		const next = current.replace(
			`export function node${i}(value: number): number {\n  return value + ${i};\n}`,
			`export function node${i}(value: number): number {\n  return value * ${i + 1};\n}`,
		);
		steps.push({
			id: `replace-node-${i}`,
			path: "structural-10.ts",
			before: current,
			after: next,
		});
		current = next;
	}
	return {
		id: "class-c-structural-10",
		title: "Class C 10 structural body replacements",
		steps,
	};
};

const classDConfigDocs10Scenario = (): Scenario => ({
	id: "class-d-config-docs-10",
	title: "Class D 10 config/docs exact edits",
	steps: Array.from({ length: 10 }, (_, i) => {
		const n = i + 1;
		return n % 2 === 0
			? {
					id: `doc-${n}`,
					path: `doc-${n}.md`,
					before: `# Doc ${n}\n\nStatus: draft\n`,
					after: `# Doc ${n}\n\nStatus: ready\n`,
				}
			: {
					id: `json-${n}`,
					path: `config-${n}.json`,
					before: `{ "feature${n}": false, "stable": true }\n`,
					after: `{ "feature${n}": true, "stable": true }\n`,
				};
	}),
});

const structuralScenario = (): Scenario => ({
	id: "structural-3",
	title: "3 structural symbol edits",
	steps: [
		{
			id: "replace-alpha-body",
			path: "structural.ts",
			before: `export function alpha(value: number): number {\n  const doubled = value * 2;\n  return doubled;\n}\n\nexport function beta(): string {\n  return "old";\n}\n`,
			after: `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "old";\n}\n`,
		},
		{
			id: "replace-beta-body",
			path: "structural.ts",
			before: `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "old";\n}\n`,
			after: `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "new";\n}\n`,
		},
		{
			id: "insert-after-beta",
			path: "structural.ts",
			before: `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "new";\n}\n`,
			after: `export function alpha(value: number): number {\n  return value + 1;\n}\n\nexport function beta(): string {\n  return "new";\n}\n\nexport function gamma(): boolean { return true; }\n`,
		},
	],
});

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

export const resolveScenario = (requestedScenarioId: ScenarioId): Scenario => {
	switch (requestedScenarioId) {
		case "tiny-10":
			return tinyScenario();
		case "mixed-20":
			return mixedScenario();
		case "same-file-multi":
			return sameFileScenario();
		case "structural-3":
			return structuralScenario();
		case "class-b-inserts":
			return classBInsertsScenario();
		case "class-d-config-docs":
			return classDConfigDocsScenario();
		case "class-b-inserts-10":
			return classBInserts10Scenario();
		case "class-c-structural-10":
			return classCStructural10Scenario();
		case "class-d-config-docs-10":
			return classDConfigDocs10Scenario();
		case "all-edit-types-gate":
			return allEditTypesSuccessScenario();
	}
};

const scenario = resolveScenario(scenarioId);

if (scenario.id !== scenarioId)
	throw new Error(
		`scenario resolver mismatch: requested=${scenarioId} resolved=${scenario.id}`,
	);

const allEditTypeReportMetadata = (
	requestedScenario: ScenarioId,
	resolvedScenario: Scenario,
): AllEditTypeReportMetadata | null => {
	if (requestedScenario !== "all-edit-types-gate") return null;
	const rows = allEditTypeGateRows().filter(
		(row) => row.scenarioId === requestedScenario,
	);
	return {
		requestedScenario,
		resolvedScenario: resolvedScenario.id,
		rows: rows.map(({ id, classId, scenarioId: rowScenarioId, fixture }) => ({
			id,
			classId,
			scenarioId: rowScenarioId,
			fixture,
		})),
		classIds: rows.map((row) => row.classId),
	};
};

const selfCheckAllEditTypeScenarioResolution = () => {
	const resolved = resolveScenario("all-edit-types-gate");
	if (resolved.id !== "all-edit-types-gate")
		throw new Error(
			`all-edit-types-gate resolved to ${resolved.id}; requested row would emit mismatched scenario id`,
		);
	if (resolved.id === "tiny-10")
		throw new Error("all-edit-types-gate must never resolve to tiny-10");
	const expectedFixturePaths = new Set(
		allEditTypeGateRows()
			.filter((row) => row.scenarioId === "all-edit-types-gate")
			.filter((row) => row.expectedBlitzOutcome === "success")
			.map((row) => row.fixture),
	);
	const resolvedFixturePaths = new Set(resolved.steps.map((step) => step.path));
	const missing = [...expectedFixturePaths].filter(
		(fixture) => !resolvedFixturePaths.has(fixture),
	);
	if (missing.length > 0)
		throw new Error(
			`all-edit-types-gate resolver missing fixture paths: ${missing.join(",")}`,
		);
	const metadata = allEditTypeReportMetadata("all-edit-types-gate", resolved);
	if (!metadata || metadata.requestedScenario !== metadata.resolvedScenario)
		throw new Error("all-edit-types-gate metadata lost requested/resolved identity");
	const classIds = new Set(metadata.classIds);
	for (const required of ["E06", "E07", "E10", "E11", "E12"] as const) {
		if (!classIds.has(required))
			throw new Error(`all-edit-types-gate metadata missing class ${required}`);
	}
};

if (selfCheckAllEditTypes) {
	selfCheckAllEditTypeRows();
	selfCheckAllEditTypeScenarioResolution();
	releaseTokenizer();
	process.exit(0);
}

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

export const exactChangedSpan = (before: string, after: string) => {
	let start = 0;
	while (
		start < before.length &&
		start < after.length &&
		before[start] === after[start]
	)
		start += 1;
	let beforeEnd = before.length;
	let afterEnd = after.length;
	while (
		beforeEnd > start &&
		afterEnd > start &&
		before[beforeEnd - 1] === after[afterEnd - 1]
	) {
		beforeEnd -= 1;
		afterEnd -= 1;
	}
	const isBoundary = (ch: string | undefined) =>
		ch === undefined || /\s|[=;:,{}()<>]/.test(ch);
	while (
		start > 0 &&
		!isBoundary(before[start - 1]) &&
		!isBoundary(after[start - 1])
	)
		start -= 1;
	while (
		beforeEnd < before.length &&
		afterEnd < after.length &&
		!isBoundary(before[beforeEnd]) &&
		!isBoundary(after[afterEnd])
	) {
		beforeEnd += 1;
		afterEnd += 1;
	}
	let oldText = before.slice(start, beforeEnd);
	let newText = after.slice(start, afterEnd);
	const occurrences = (haystack: string, needle: string) => {
		if (needle.length === 0) return 0;
		let count = 0;
		let at = haystack.indexOf(needle);
		while (at >= 0) {
			count += 1;
			at = haystack.indexOf(needle, at + 1);
		}
		return count;
	};
	while (
		oldText.length > 0 &&
		occurrences(before, oldText) > 1 &&
		beforeEnd < before.length &&
		afterEnd < after.length &&
		before[beforeEnd] === after[afterEnd]
	) {
		beforeEnd += 1;
		afterEnd += 1;
		oldText = before.slice(start, beforeEnd);
		newText = after.slice(start, afterEnd);
	}
	if (oldText.length === 0) {
		const anchorEnd = start;
		let anchorStart = before.lastIndexOf("\n", Math.max(0, anchorEnd - 2)) + 1;
		let anchor = before.slice(anchorStart, anchorEnd);
		while (
			anchor.length > 0 &&
			occurrences(before, anchor) > 1 &&
			anchorStart > 0
		) {
			anchorStart = before.lastIndexOf("\n", Math.max(0, anchorStart - 2)) + 1;
			anchor = before.slice(anchorStart, anchorEnd);
		}
		if (anchor.length > 0) {
			oldText = anchor;
			newText = anchor + newText;
		}
	}
	return { oldText, newText };
};

const buildPrompt = async (workDir: string, steps: Step[]): Promise<string> => {
	if (lane === "blitz-edit") {
		const e =
			scenarioId === "structural-3"
				? [
						[
							"rb",
							join(workDir, "structural.ts"),
							"function",
							"alpha",
							"\n  return value + 1;\n",
						],
						[
							"rb",
							join(workDir, "structural.ts"),
							"function",
							"beta",
							'\n  return "new";\n',
						],
						[
							"ia",
							join(workDir, "structural.ts"),
							"function",
							"beta",
							"\n\nexport function gamma(): boolean { return true; }",
						],
					]
				: scenarioId === "class-c-structural-10"
					? Array.from({ length: 10 }, (_, i) => [
							"rb",
							join(workDir, "structural-10.ts"),
							"function",
							`node${i + 1}`,
							`\n  return value * ${i + 2};\n`,
						])
					: steps.map((step) => {
							const { oldText, newText } = exactChangedSpan(
								step.before,
								step.after,
							);
							return ["x", join(workDir, step.path), oldText, newText];
						});
		return [
			`Run ${steps.length} ordered exact edits in this one Pi session.`,
			"Use only blitz_edit. No prose. Call blitz_edit exactly once with this exact JSON:",
			JSON.stringify({ e }),
		].join("\n");
	}

	if (lane === "core-optimized") {
		// same-file-multi: try one edit call with edits array if simple
		if (
			scenarioId === "same-file-multi" &&
			steps.every((s) => s.path === steps[0].path)
		) {
			const spans = steps.map((step) => {
				const { oldText, newText } = exactChangedSpan(step.before, step.after);
				return { oldText, newText };
			});
			const allSimple = spans.every(
				(s) => s.oldText.length < 200 && s.newText.length < 200,
			);
			if (allSimple) {
				return [
					`Run ${steps.length} ordered edits in this one Pi session on the same file.`,
					"Use only edit. No prose. Call edit exactly once with this exact JSON:",
					JSON.stringify({
						path: join(workDir, steps[0].path),
						edits: spans,
					}),
				].join("\n");
			}
		}
		// Default: minimal spans per step
		const lines = [
			`Run ${steps.length} ordered edits in this one Pi session.`,
			"Use only edit. No prose. Keep calling tools until every step is done. Then stop.",
			"",
			"Steps:",
		];
		steps.forEach((step, idx) => {
			const file = join(workDir, step.path);
			const { oldText, newText } = exactChangedSpan(step.before, step.after);
			lines.push(
				`${idx + 1}. Call edit with exact JSON: ${JSON.stringify({ path: file, oldText, newText })}`,
			);
		});
		lines.push("", "Initial file contents:");
		for (const [path] of finalExpectedByPath(steps)) {
			lines.push(
				`--- ${join(workDir, path)} ---`,
				await readFile(join(workDir, path), "utf8"),
			);
		}
		return lines.join("\n");
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
	if (lane === "core" || lane === "core-optimized")
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
		messages: 0,
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
				usage.messages += 1;
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

const parseTokscaleTotals = (
	tokScale: ReturnType<typeof runTokscale> | null,
) => {
	if (!tokScale?.stdout) return null;
	try {
		const parsed = JSON.parse(tokScale.stdout);
		return {
			input: Number(parsed.totalInput ?? 0),
			output: Number(parsed.totalOutput ?? 0),
			cacheRead: Number(parsed.totalCacheRead ?? 0),
			cacheWrite: Number(parsed.totalCacheWrite ?? 0),
			messages: Number(parsed.totalMessages ?? 0),
		};
	} catch {
		return null;
	}
};

const buildTokscaleMatch = (
	usage: UsageTotals,
	tokScale: ReturnType<typeof runTokscale> | null,
) => {
	const totals = parseTokscaleTotals(tokScale);
	if (!totals) {
		return { matched: !tokScaleRequired, totals: null, deltas: null };
	}
	const deltas = {
		input: usage.input - totals.input,
		output: usage.output - totals.output,
		cacheRead: usage.cacheRead - totals.cacheRead,
		cacheWrite: usage.cacheWrite - totals.cacheWrite,
		messages: usage.messages - totals.messages,
	};
	return {
		matched: Object.values(deltas).every((value) => value === 0),
		totals,
		deltas,
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
		`#!/usr/bin/env bash\nset -u\nexport PATH=${shellQuote(BLITZ_BIN_DIR)}":$PATH"\nexport PI_BLITZ_TOOL_PROFILE=${lane === "blitz-edit" ? "minimal" : lane === "core-optimized" ? "" : "router"}\ncd ${shellQuote(workDir)}\nstart_ms=$(date +%s%3N)\nstatus=0\n${[piBin, ...args].map(shellQuote).join(" ")} > >(tee ${shellQuote(stdoutLog)}) 2> >(tee ${shellQuote(stderrLog)} >&2) || status=$?\nend_ms=$(date +%s%3N)\nprintf '{"status":%s,"wallMs":%s,"timedOut":false}\\n' "$status" "$((end_ms - start_ms))" > ${shellQuote(exitFile)}\nexit "$status"\n`,
		"utf8",
	);
	await chmod(commandFile, 0o755);
	const exit = await runTmux(commandFile, exitFile, stdoutLog, stderrLog);
	const parsed = await parseSession(sessionDir);
	const expected = finalExpectedByPath(scenario.steps);
	const minimalStructuralDecline = isMinimalStructuralDecline(
		lane,
		scenarioId,
		parsed.toolResults,
	);
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
	const usesBlitzExtension = lane === "router" || lane === "blitz-edit";
	const skillText = usesBlitzExtension
		? await readFile(join(skill, "SKILL.md"), "utf8").catch(() => "")
		: "";
	const schemaText =
		lane === "blitz-edit"
			? await readFile(profileDump, "utf8").catch(() => "")
			: "";
	const tokScale = tokScaleRequired ? runTokscale(sessionDir) : null;
	if (tokScaleRequired && tokScale?.status !== 0)
		console.error(tokScale?.stderr || tokScale?.stdout);
	const tokScaleMatch = buildTokscaleMatch(parsed.usage, tokScale);
	const totals = {
		schemaTokens: countTokens(schemaText),
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
			parsed.usage.input -
				countTokens(prompt) -
				countTokens(skillText) -
				countTokens(schemaText),
		),
		totalContextTokens:
			parsed.usage.input +
			parsed.usage.output +
			parsed.usage.cacheRead +
			parsed.usage.cacheWrite,
	};
	const correctnessPassed = stepResults.every((s) => s.correct);
	const accountingPassed =
		exit.status === 0 &&
		!exit.timedOut &&
		(!tokScaleRequired || (tokScale?.status === 0 && tokScaleMatch.matched));
	const status = minimalStructuralDecline
		? "declined"
		: correctnessPassed && accountingPassed
			? "accepted"
			: "caveated";
	const report = {
		generatedAt: new Date().toISOString(),
		status,
		provider,
		model,
		runner: "tmux",
		lane,
		requestedScenario: scenarioId,
		scenario: scenario.id,
		scenarioTitle: scenario.title,
		allEditTypes: allEditTypeReportMetadata(scenarioId, scenario),
		runRoot,
		tmuxSession,
		piBin,
		extension: usesBlitzExtension ? extension : null,
		skill: usesBlitzExtension ? skill : null,
		profileDump: lane === "blitz-edit" ? profileDump : null,
		tokScaleMode: tokScaleRequired ? "required" : "not-run",
		tokScale,
		tokScaleMatch,
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
		decline: minimalStructuralDecline
			? {
					reason: "unsupported_structural_op_minimal",
					noMutation: true,
					note: "Minimal blitz_edit intentionally declines structural rb in Class C instead of mutating or falling back.",
				}
			: null,
		caveats: [
			"schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.",
			"true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.",
			...(minimalStructuralDecline
				? [
						"minimal blitz_edit declined unsupported structural rb with no_mutation=true; this row is an explicit decline, not a correctness pass or hidden fallback.",
					]
				: []),
		],
	};
	await mkdir(dirname(jsonOut), { recursive: true });
	await writeFile(jsonOut, JSON.stringify(report, null, 2));
	const md = `# Pi/tmux/Tokscale true sequential streak — ${scenario.id} ${lane}\n\nStatus: ${report.status}\nProvider/model: ${provider}/${model}\nRunner: tmux\nRun root: ${runRoot}\nTmux session: ${tmuxSession}\nTokscale: ${report.tokScaleMode}${tokScale ? ` (exit ${tokScale.status}, match ${tokScaleMatch.matched ? "yes" : "no"})` : ""}\n\n## Cumulative tokens\n\n| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |\n|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n| ${totals.schemaTokens} | ${totals.skillTokens} | ${totals.promptTokens} | ${totals.argTokens} | ${totals.outputTokens} | ${totals.cacheRead} | ${totals.cacheWrite} | ${totals.resultPayloadTokens} | ${totals.residualInputTokens} | ${totals.totalContextTokens} |\n\n## Tokscale match\n\nMatched: ${tokScaleMatch.matched ? "yes" : "no"}\n\nDeltas: ${JSON.stringify(tokScaleMatch.deltas)}\n\n## Correctness\n\n| Step/file | Correct | Expected sha | Actual sha |\n|---|---|---:|---:|\n${stepResults.map((s) => `| ${s.path} | ${s.correct ? "yes" : "no"} | ${s.expectedSha} | ${s.actualSha} |`).join("\n")}\n\n## Caveats\n\n${report.caveats.map((c) => `- ${c}`).join("\n")}\n`;
	await writeFile(mdOut, md);
	releaseTokenizer();
	console.log(
		JSON.stringify(
			{
				jsonOut,
				mdOut,
				status: report.status,
				totalContextTokens: totals.totalContextTokens,
				correct: correctnessPassed,
				declined: minimalStructuralDecline,
			},
			null,
			2,
		),
	);
};

if (import.meta.main) await main();
