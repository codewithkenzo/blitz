#!/usr/bin/env bun
/**
 * Route-aware authentic local Pi-driven token matrix bench.
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
 *   bun bench/pi-matrix.ts --iters 1
 *   bun bench/pi-matrix.ts --case medium-10k --lane blitz --timeout-ms 120000
 *
 * Syntax check note: do not use `bun --check bench/pi-matrix.ts` here; in some
 * Bun versions that still executes the script. Use `bun build bench/pi-matrix.ts
 * --target=bun --outfile=/tmp/pi-matrix-check.js` for a parse/type-ish smoke
 * without running provider benchmarks.
 */

import {
	readFile,
	writeFile,
	readdir,
	mkdtemp,
	rm,
	mkdir,
	copyFile,
	chmod,
} from "node:fs/promises";
import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join, basename, dirname, resolve } from "node:path";
import { existsSync } from "node:fs";
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const BLITZ_BIN_DIR = join(REPO_ROOT, "zig-out/bin");
const DEFAULT_PI_BIN = "/home/kenzo/.local/bin/pi";
const DEFAULT_PI_BLITZ_DIST = "/home/kenzo/dev/pi-blitz/dist/index.js";
const DEFAULT_PI_BLITZ_SKILL = "/home/kenzo/dev/pi-blitz/skills/pi-blitz";
const DEFAULT_PI_BLITZ_PACKAGE = "/home/kenzo/dev/pi-blitz";
const ALL_BLITZ_EDIT_TOOLS = [
	"pi_blitz_op",
	"pi_blitz_replace_body_span",
	"pi_blitz_insert_body_span",
	"pi_blitz_wrap_body",
	"pi_blitz_compose_body",
	"pi_blitz_multi_body",
	"pi_blitz_patch",
	"pi_blitz_try_catch",
	"pi_blitz_replace_return",
].join(",");

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
const piBin = argFlag("--pi-bin", process.env.PI_BIN ?? DEFAULT_PI_BIN);
const extension = argFlag(
	"--extension",
	process.env.PI_BLITZ_DIST ?? DEFAULT_PI_BLITZ_DIST,
);
const skill = argFlag(
	"--skill",
	process.env.PI_BLITZ_SKILL ?? DEFAULT_PI_BLITZ_SKILL,
);
const keepTemp = argv.includes("--keep-temp");
const toolProfile = argFlag(
	"--tool-profile",
	process.env.PI_BLITZ_TOOL_PROFILE ?? "full",
);
const artifactProfilesArg = argFlag("--artifact-profiles", toolProfile);
const piBlitzPackage = argFlag(
	"--pi-blitz-package",
	process.env.PI_BLITZ_PACKAGE ?? DEFAULT_PI_BLITZ_PACKAGE,
);
const artifactRootArg = argFlag("--artifact-root", "");
const runner = argFlag("--runner", "spawn") as "spawn" | "tmux";
if (runner !== "spawn" && runner !== "tmux") {
	throw new Error(`invalid --runner ${runner}; expected spawn or tmux`);
}
const runRootArg = argFlag("--run-root", "");
const runStamp = new Date().toISOString().replace(/[:.]/g, "-");
const runRoot =
	runner === "tmux"
		? runRootArg || join(REPO_ROOT, "reports/pi-tmux-runs", runStamp)
		: runRootArg;
const tmuxSession = `pi-bench-${runStamp}`;
const artifactRoot = resolve(
	artifactRootArg || join(REPO_ROOT, "reports/pi-accounting-runs", runStamp),
);
const tokScaleRequired = argv.includes("--tokscale");
const tokScaleDisabled = argv.includes("--no-tokscale");
if (tokScaleRequired && tokScaleDisabled) {
	throw new Error("pass only one of --tokscale or --no-tokscale");
}
const tokScaleMode: "required" | "attempt" | "disabled" = tokScaleRequired
	? "required"
	: tokScaleDisabled
		? "disabled"
		: "attempt";

const fixtureDir = join(REPO_ROOT, "bench/fixtures-llm");

const buildSmallIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: change the body of the smallTarget function so it returns "hello " followed by name.toUpperCase() instead of "hi " + name. The signature stays the same.

Original file contents:
${src}`;

const buildHugeIntent = (
	filePath: string,
	src: string,
	symbol = "hugeCompute",
): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: change the final return statement of the ${symbol} function from \`return total;\` to \`return total + 1;\`. Leave every other line unchanged.

Original file contents:
${src}`;

const buildWrapIntent = (
	filePath: string,
	src: string,
	symbol = "mediumCompute",
): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: wrap the entire body of the ${symbol} function in a try/catch. Preserve every existing statement inside the try block unchanged. In the catch block, call console.error(error); then throw error.

Original file contents:
${src}`;

const buildComposeIntent = (
	filePath: string,
	src: string,
	symbol = "mediumCompute",
): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: update ${symbol} with two preserved islands and small structural edits:
1) immediately after \`let total = seed;\`, add a finite check throwing RangeError when seed is not finite,
2) before return, add an early return when total is negative.

Preserve every original arithmetic statement exactly. Do not rewrite unchanged lines.

Original file contents:
${src}`;

const buildInsertIntent = (
	filePath: string,
	src: string,
	symbol = "mediumCompute",
): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: in ${symbol}, insert this guard immediately after \`let total = seed;\`:
\`if (!Number.isFinite(total)) { throw new RangeError("seed must be finite"); }\`

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

const buildSemanticIntent = (
	filePath: string,
	src: string,
	goal: string,
): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once. Use the smallest valid tool-call arguments; do not repeat unchanged code.

Goal: ${goal}

Original file contents:
${src}`;

const buildReadmeIntent = (filePath: string, src: string): string =>
	`Apply this change to the Markdown file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.

Goal: under the marker \`<!-- benchmark-smoke-list -->\`, add this bullet before the existing bullet:
\`- Confirm README smoke path stays cheap.\`

Original file contents:
${src}`;

const buildConfigIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: change logLevel from "info" to "debug". Leave every other line unchanged.
Original file contents:
${src}`;

const buildLoggingIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: after the existing console.log line, add a new line: console.time(\`Processing order \${orderId}\`);
Original file contents:
${src}`;

const buildLongSectionIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: replace the return statement at the end from \`return \`Invoice \${id} for \${customer}: $0.00\`;\` to \`return \`Invoice \${id} for \${customer}: $\${total.toFixed(2)}\`;\`.
Original file contents:
${src}`;

const buildRenameIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: rename the function from computeScore to calculateAverage. Update both the function declaration and all references (there are none except the declaration).
Original file contents:
${src}`;

const buildMarkdownAppendIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: under the marker \`<!-- append-target -->\`, add a new section. Append the following lines after that marker:
\`## Configuration Reference\n\nSee the \`blitz --help\` command.\`
Original file contents:
${src}`;

const buildJsonConfigIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: change "debug" from false to true. Leave every other line unchanged.
Original file contents:
${src}`;

const buildYamlConfigIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: change debug from false to true. Leave every other line unchanged.
Original file contents:
${src}`;

const buildTomlConfigIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: change debug from false to true. Leave every other line unchanged.
Original file contents:
${src}`;

const buildCssIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: in the .header rule, change the background color from "#333" to "#222".
Original file contents:
${src}`;

const buildHtmlIntent = (filePath: string, src: string): string =>
	`Apply this change to the file at ${filePath}. Use only the available edit tool. Do not output any prose, plan, or explanation: just call the edit tool exactly once.
Goal: change the page title from "Blitz App" to "Blitz CLI".
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
			'For this edit, call `pi_blitz_wrap_body`. Copy exact tool args JSON: {"symbol":"mediumCompute","before":"\\n  try {","after":"  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }\\n","indentKeptBodyBy":2}. `before` starts with newline escape `\\n` and has no trailing newline. `after` has no leading newline and MUST end with newline escape `\\n`. JSON escapes must decode to newline chars; do not pass literal backslash-n text.',
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
		id: "medium-10k/insert-body-span",
		relPath: "medium.ts",
		intent: (p: string) => buildInsertIntent(p, mediumSrc, "mediumCompute"),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "insert_body_span",
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
		intent: (p: string) =>
			buildSemanticIntent(
				p,
				semanticSrc,
				"wrap the entire body of async function loadUser in try/catch. Preserve all await statements unchanged. Catch should call console.error(error); then throw error on the next line.",
			),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "async_try_catch",
	},
	{
		id: "semantic/class-method-try-catch",
		relPath: "semantic.ts",
		intent: (p: string) =>
			buildSemanticIntent(
				p,
				semanticSrc,
				"wrap the entire body of class method renderScore in try/catch. Catch should call console.error(error); then throw error on the next line.",
			),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "class_method_try_catch",
	},
	{
		id: "semantic/arrow-replace-return",
		relPath: "semantic.ts",
		intent: (p: string) =>
			buildSemanticIntent(
				p,
				semanticSrc,
				'in arrow function pickLabel, replace the last return expression with "unknown". Leave the earlier active return unchanged.',
			),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "arrow_replace_return",
	},
	{
		id: "semantic/nested-return-occurrence",
		relPath: "semantic.ts",
		intent: (p: string) =>
			buildSemanticIntent(
				p,
				semanticSrc,
				'in function classify, replace only the last return expression with "other". Leave the negative and zero returns unchanged.',
			),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "nested_return_occurrence",
	},
	{
		id: "semantic/tsx-replace-return",
		relPath: "component.tsx",
		intent: (p: string) =>
			buildSemanticIntent(
				p,
				componentSrc,
				'in function StatusBadge, replace the return expression with <strong className="badge">{label.toUpperCase()}</strong>.',
			),
		expectedFile: "",
		recommendedLane: "blitz",
		className: "tsx_replace_return",
	},
	{
		id: "readme/core-smoke",
		relPath: "readme.md",
		intent: (p: string) => buildReadmeIntent(p, readmeSrc),
		expectedFile: "",
		lanePolicy: "core-only",
		recommendedLane: "core",
		className: "markdown_core_only",
	},
	{
		id: "config/key-update",
		relPath: "config.ts",
		intent: (p: string) => buildConfigIntent(p, configSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "config_key_update",
	},
	{
		id: "logging/insert-timer",
		relPath: "logging.ts",
		intent: (p: string) => buildLoggingIntent(p, loggingSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "logging_insert_timer",
	},
	{
		id: "long-section/replace-return",
		relPath: "long-section.ts",
		intent: (p: string) => buildLongSectionIntent(p, longSectionSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "long_section_replace_return",
	},
	{
		id: "rename/function-name",
		relPath: "rename.ts",
		intent: (p: string) => buildRenameIntent(p, renameSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "rename_function_name",
	},
	{
		id: "markdown/append-section",
		relPath: "markdown-append.md",
		intent: (p: string) => buildMarkdownAppendIntent(p, markdownAppendSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "markdown_append_section",
	},
	{
		id: "json/config-key",
		relPath: "config.json",
		intent: (p: string) => buildJsonConfigIntent(p, jsonConfigSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "json_config_key",
	},
	{
		id: "yaml/config-key",
		relPath: "config.yaml",
		intent: (p: string) => buildYamlConfigIntent(p, yamlConfigSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "yaml_config_key",
	},
	{
		id: "toml/config-key",
		relPath: "config.toml",
		intent: (p: string) => buildTomlConfigIntent(p, tomlConfigSrc),
		expectedFile: "",
		recommendedLane: "core",
		className: "toml_config_key",
	},
	{
		id: "css/small-edit",
		relPath: "style.css",
		intent: (p: string) => buildCssIntent(p, cssSrc),
		expectedFile: "",
		lanePolicy: "core-only",
		recommendedLane: "core",
		className: "css_small_edit",
	},
	{
		id: "html/small-edit",
		relPath: "index.html",
		intent: (p: string) => buildHtmlIntent(p, htmlSrc),
		expectedFile: "",
		lanePolicy: "core-only",
		recommendedLane: "core",
		className: "html_small_edit",
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
const mediumExpected = mediumSrc.replace(
	"  return total;",
	"  return total + 1;",
);
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
const mediumInsertExpected = mediumSrc.replace(
	"  let total = seed;\n",
	`  let total = seed;\n  if (!Number.isFinite(total)) {\n    throw new RangeError("seed must be finite");\n  }\n`,
);
const mediumBody = mediumSrc.slice(
	mediumSrc.indexOf("{\n") + 2,
	mediumSrc.lastIndexOf("\n}"),
);
const mediumWrapExpected = `function mediumCompute(seed: number): number {\n  try {\n${mediumBody.replace(/^/gm, "  ")}\n  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n}\n`;
const multiSrc = await readFile(join(fixtureDir, "multi.ts"), "utf8");
const multiExpected = multiSrc
	.replace("  return base;", "  return base + 1;")
	.replace(
		"  const marker = value;\n",
		"  const marker = value;\n  const markerUpper = value.toUpperCase();\n",
	)
	.replace(
		`export function risky(value: number): number {\n  return value;\n}`,
		`export function risky(value: number): number {\n  try {\n    return value;\n  } catch (error) {\n    throw error;\n  }\n}`,
	);
const multiLargeSrc = await readFile(
	join(fixtureDir, "multi-large.ts"),
	"utf8",
);
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
	.replace(
		"  const normalized = event.trim();\n",
		"  const normalized = event.trim();\n  const tagged = `[audit] ${normalized}`;\n",
	)
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
const arrowReturnExpected = semanticSrc.replace(
	`  return "idle";`,
	`  return "unknown";`,
);
const nestedReturnExpected = semanticSrc.replace(
	`  return "positive";`,
	`  return "other";`,
);
const componentSrc = await readFile(join(fixtureDir, "component.tsx"), "utf8");
const componentReturnExpected = componentSrc.replace(
	`  return <span className="badge">{label}</span>;`,
	`  return <strong className="badge">{label.toUpperCase()}</strong>;`,
);
const readmeSrc = await readFile(join(fixtureDir, "readme.md"), "utf8");
const readmeExpected = readmeSrc.replace(
	"<!-- benchmark-smoke-list -->\n",
	"<!-- benchmark-smoke-list -->\n- Confirm README smoke path stays cheap.\n",
);

const configSrc = await readFile(join(fixtureDir, "config.ts"), "utf8");
const configExpected = configSrc.replace('logLevel: "info"', 'logLevel: "debug"');

const loggingSrc = await readFile(join(fixtureDir, "logging.ts"), "utf8");
const loggingExpected = loggingSrc.replace(
	"  console.log(`Processing order ${orderId}`);\n",
	"  console.log(`Processing order ${orderId}`);\n  console.time(`Processing order ${orderId}`);\n",
);

const longSectionSrc = await readFile(join(fixtureDir, "long-section.ts"), "utf8");
const longSectionExpected = longSectionSrc.replace(
	"  return `Invoice ${id} for ${customer}: $0.00`;",
	"  return `Invoice ${id} for ${customer}: $${total.toFixed(2)}`;",
);

const renameSrc = await readFile(join(fixtureDir, "rename.ts"), "utf8");
const renameExpected = renameSrc.replace(
	"export function computeScore",
	"export function calculateAverage",
);

const markdownAppendSrc = await readFile(join(fixtureDir, "markdown-append.md"), "utf8");
const markdownAppendExpected = markdownAppendSrc.replace(
	"<!-- append-target -->\n",
	"<!-- append-target -->\n## Configuration Reference\n\nSee the `blitz --help` command.\n",
);

const jsonConfigSrc = await readFile(join(fixtureDir, "config.json"), "utf8");
const jsonConfigExpected = jsonConfigSrc.replace('"debug": false', '"debug": true');

const yamlConfigSrc = await readFile(join(fixtureDir, "config.yaml"), "utf8");
const yamlConfigExpected = yamlConfigSrc.replace("  debug: false", "  debug: true");

const tomlConfigSrc = await readFile(join(fixtureDir, "config.toml"), "utf8");
const tomlConfigExpected = tomlConfigSrc.replace("debug = false", "debug = true");

const cssSrc = await readFile(join(fixtureDir, "style.css"), "utf8");
const cssExpected = cssSrc.replace("background: #333;", "background: #222;");

const htmlSrc = await readFile(join(fixtureDir, "index.html"), "utf8");
const htmlExpected = htmlSrc.replace("<title>Blitz App</title>", "<title>Blitz CLI</title>");

FIXTURES[0]!.expectedFile = smallExpected;
FIXTURES[1]!.expectedFile = mediumExpected;
FIXTURES[2]!.expectedFile = mediumWrapExpected;
FIXTURES[3]!.expectedFile = mediumComposeExpected;
FIXTURES[4]!.expectedFile = mediumInsertExpected;
FIXTURES[5]!.expectedFile = multiExpected;
FIXTURES[6]!.expectedFile = multiLargeExpected;
FIXTURES[7]!.expectedFile = hugeExpected;
FIXTURES[8]!.expectedFile = asyncTryCatchExpected;
FIXTURES[9]!.expectedFile = classTryCatchExpected;
FIXTURES[10]!.expectedFile = arrowReturnExpected;
FIXTURES[11]!.expectedFile = nestedReturnExpected;
FIXTURES[12]!.expectedFile = componentReturnExpected;
FIXTURES[13]!.expectedFile = readmeExpected;
FIXTURES[14]!.expectedFile = configExpected;
FIXTURES[15]!.expectedFile = loggingExpected;
FIXTURES[16]!.expectedFile = longSectionExpected;
FIXTURES[17]!.expectedFile = renameExpected;
FIXTURES[18]!.expectedFile = markdownAppendExpected;
FIXTURES[19]!.expectedFile = jsonConfigExpected;
FIXTURES[20]!.expectedFile = yamlConfigExpected;
FIXTURES[21]!.expectedFile = tomlConfigExpected;
FIXTURES[22]!.expectedFile = cssExpected;
FIXTURES[23]!.expectedFile = htmlExpected;

type Lane = "core" | "blitz" | "router";
type Route = "core_edit" | "ast_narrow" | "ast_batch" | "token_router";
type RouteReasonCode =
	| "lane_core_edit"
	| "lane_blitz_structured_tool"
	| "lane_router_facade";

type TokenRouteDecision = {
	contextSavingsPct: number | null;
	schemaTokensExpected: number;
	argTokensExpected: number;
	outputTokensExpected: number;
	fallbackContextTokensExpected: number | null;
	selectedBecause: string;
};

const routeForLane = (
	lane: Lane,
	fx?: Fixture,
): { route: Route; routeReasonCode: RouteReasonCode } =>
	lane === "core"
		? { route: "core_edit", routeReasonCode: "lane_core_edit" }
		: lane === "router"
			? { route: "token_router", routeReasonCode: "lane_router_facade" }
			: {
				route:
					fx?.id.includes("multi/") || fx?.id.includes("patch")
						? "ast_batch"
						: "ast_narrow",
				routeReasonCode: "lane_blitz_structured_tool",
			};

const piArgs = (
	lane: Lane,
	prompt: string,
	sessionDir: string,
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
		toolsOverride ?? ALL_BLITZ_EDIT_TOOLS,
		prompt,
	];
};

type PiRunResult = {
	ms: number;
	status: number;
	stdout: string;
	stderr: string;
	sessionDir: string;
	timedOut: boolean;
	runDir?: string;
	commandFile?: string;
	stdoutLog?: string;
	stderrLog?: string;
	exitFile?: string;
	workDir?: string;
};

const runPiSpawn = (
	lane: Lane,
	prompt: string,
	cwd: string,
	toolsOverride?: string,
): PiRunResult => {
	const sessionDir = join(cwd, `sessions-${lane}`);
	const args = piArgs(lane, prompt, sessionDir, toolsOverride);
	const t0 = performance.now();
	const env = {
		...process.env,
		PATH: `${BLITZ_BIN_DIR}:${process.env.PATH ?? ""}`,
		PI_BLITZ_TOOL_PROFILE: lane === "router" ? "router" : toolProfile,
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
		sessionDir,
		timedOut: r.error?.name === "Error" && /ETIMEDOUT/.test(String(r.error)),
	};
};

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
const safeName = (value: string) => value.replace(/[^a-zA-Z0-9_.-]+/g, "_");
const shellQuote = (value: string) => `'${value.replaceAll("'", `'\\''`)}'`;

const runPiTmux = async (
	lane: Lane,
	prompt: string,
	workDir: string,
	fx: Fixture,
	iter: number,
	toolsOverride?: string,
): Promise<PiRunResult> => {
	const runDir = resolve(dirname(workDir));
	const workDirAbs = resolve(workDir);
	const sessionDir = join(runDir, "sessions");
	const promptFile = join(runDir, "prompt.md");
	const commandFile = join(runDir, "command.sh");
	const stdoutLog = join(runDir, "stdout.log");
	const stderrLog = join(runDir, "stderr.log");
	const exitFile = join(runDir, "exit.json");
	await mkdir(sessionDir, { recursive: true });
	await writeFile(promptFile, prompt, "utf8");
	await writeFile(stdoutLog, "", "utf8");
	await writeFile(stderrLog, "", "utf8");
	const args = piArgs(lane, `@${promptFile}`, sessionDir, toolsOverride);
	const tmuxArgs = args.map((arg) => (arg === "--print" ? "-p" : arg));
	const command = [piBin, ...tmuxArgs].map(shellQuote).join(" ");
	await writeFile(
		commandFile,
		`#!/usr/bin/env bash
set -u
RUN_DIR=${shellQuote(runDir)}
STDOUT_LOG="$RUN_DIR/stdout.log"
STDERR_LOG="$RUN_DIR/stderr.log"
EXIT_FILE="$RUN_DIR/exit.json"
export PATH=${shellQuote(BLITZ_BIN_DIR)}":$PATH"
export PI_BLITZ_TOOL_PROFILE=${shellQuote(lane === "router" ? "router" : toolProfile)}
cd ${shellQuote(workDirAbs)}
start_ms=$(date +%s%3N)
status=0
{
	${command}
} > >(tee "$STDOUT_LOG") 2> >(tee "$STDERR_LOG" >&2) || status=$?
end_ms=$(date +%s%3N)
wall_ms=$((end_ms - start_ms))
printf '{"status":%s,"wallMs":%s,"timedOut":false}\n' "$status" "$wall_ms" > "$EXIT_FILE.tmp"
mv "$EXIT_FILE.tmp" "$EXIT_FILE"
exit "$status"
`,
		"utf8",
	);
	await chmod(commandFile, 0o755);
	await mkdir(join(runDir, "work"), { recursive: true });
	await mkdir(join(runDir, "sessions"), { recursive: true });

	const window = safeName(`${fx.id}-${lane}-${iter}`).slice(0, 80) || "run";
	const hasSession = spawnSync("tmux", ["has-session", "-t", tmuxSession], {
		encoding: "utf8",
	});
	if (hasSession.status === 0) {
		spawnSync(
			"tmux",
			["new-window", "-t", tmuxSession, "-n", window, commandFile],
			{ encoding: "utf8" },
		);
	} else {
		spawnSync(
			"tmux",
			["new-session", "-d", "-s", tmuxSession, "-n", window, commandFile],
			{ encoding: "utf8" },
		);
		spawnSync(
			"tmux",
			["set-option", "-t", tmuxSession, "remain-on-exit", "on"],
			{ encoding: "utf8" },
		);
	}
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
	console.error(`tmux attach -t ${tmuxSession} # window ${window}`);

	const t0 = performance.now();
	while (!existsSync(exitFile) && performance.now() - t0 < timeoutMs) {
		await sleep(500);
	}
	if (!existsSync(exitFile)) {
		const ms = performance.now() - t0;
		await writeFile(
			exitFile,
			JSON.stringify({ status: -1, wallMs: ms, timedOut: true }, null, 2),
		);
		return {
			ms,
			status: -1,
			stdout: await readFile(stdoutLog, "utf8").catch(() => ""),
			stderr: await readFile(stderrLog, "utf8").catch(() => ""),
			sessionDir,
			timedOut: true,
			runDir,
			commandFile,
			stdoutLog,
			stderrLog,
			exitFile,
			workDir,
		};
	}
	const exit = JSON.parse(await readFile(exitFile, "utf8")) as {
		status: number;
		wallMs: number;
		timedOut?: boolean;
	};
	return {
		ms: exit.wallMs,
		status: exit.status,
		stdout: await readFile(stdoutLog, "utf8").catch(() => ""),
		stderr: await readFile(stderrLog, "utf8").catch(() => ""),
		sessionDir,
		timedOut: Boolean(exit.timedOut),
		runDir,
		commandFile,
		stdoutLog,
		stderrLog,
		exitFile,
		workDir,
	};
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
	inputTokens?: number;
	outputTokens?: number;
	input_tokens?: number;
	output_tokens?: number;
	cacheRead?: number;
	cacheWrite?: number;
	cache_read?: number;
	cache_write?: number;
	cachedInputTokens?: number;
	cacheCreationInputTokens?: number;
	cached_input_tokens?: number;
	cache_creation_input_tokens?: number;
	totalTokens?: number;
	cost?: { total?: number } | number;
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
		const usageNum = (u: Usage, keys: (keyof Usage)[]): number => {
			for (const key of keys) {
				const value = u[key];
				if (typeof value === "number") return value;
			}
			return 0;
		};
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
				totalOutputTokens += usageNum(u, [
					"output",
					"outputTokens",
					"output_tokens",
				]);
				totalInputTokens += usageNum(u, [
					"input",
					"inputTokens",
					"input_tokens",
				]);
				totalCacheRead += usageNum(u, [
					"cacheRead",
					"cache_read",
					"cachedInputTokens",
					"cached_input_tokens",
				]);
				totalCacheWrite += usageNum(u, [
					"cacheWrite",
					"cache_write",
					"cacheCreationInputTokens",
					"cache_creation_input_tokens",
				]);
				totalCost += typeof u.cost === "number" ? u.cost : (u.cost?.total ?? 0);
			}
			for (const part of j.message?.content ?? []) {
				if (part?.type === "toolCall") {
					if (
						(lane === "core" && part.name === "edit") ||
						(lane === "blitz" &&
							typeof part.name === "string" &&
							part.name.startsWith("pi_blitz_"))
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

type TokScaleValidation = {
	input: number | null;
	output: number | null;
	cacheRead: number | null;
	cacheWrite: number | null;
	messages: number | null;
	cost: number | null;
	processingTimeMs: number | null;
	matchesParser: boolean;
	details: string;
};

type LaneResult = {
	lane: Lane;
	wallMs: number;
	promptTokens: number;
	session: ParsedSession;
	tokScale: TokScaleValidation;
	correct: boolean;
	exitCode: number;
	timedOut: boolean;
	stderr: string;
	stdout: string;
	runDir?: string;
	sessionDir?: string;
	sessionFile?: string;
	commandFile?: string;
	stdoutLog?: string;
	stderrLog?: string;
	exitFile?: string;
};

const emptyTokScale = (details: string): TokScaleValidation => ({
	input: null,
	output: null,
	cacheRead: null,
	cacheWrite: null,
	messages: null,
	cost: null,
	processingTimeMs: null,
	matchesParser: false,
	details,
});

type ToolSpecArtifact = {
	profile: string;
	profileLabel: string;
	visibleToolNames: string[];
	serializedToolSpecsPath: string;
	serializedToolSpecsTokens: number;
	serializedToolSpecsBytes: number;
};

const ALL_TOOL_PROFILES = [
	"minimal",
	"router",
	"semantic",
	"structural",
	"admin",
	"full",
] as const;

const parseArtifactProfiles = (value: string): string[] => {
	const requested =
		value === "all"
			? [...ALL_TOOL_PROFILES]
			: value
					.split(",")
					.map((profile) => profile.trim())
					.filter(Boolean);
	if (!requested.includes(toolProfile)) requested.push(toolProfile);
	return [...new Set(requested)];
};

const artifactProfiles = parseArtifactProfiles(artifactProfilesArg);

let selectedVisibleToolNames = new Set<string>();

const assertProfileSupportsTools = (toolsOverride: string | undefined) => {
	if (!toolsOverride) return;
	const requested = toolsOverride
		.split(",")
		.map((tool) => tool.trim())
		.filter(Boolean);
	const unavailable = requested.filter(
		(tool) => !selectedVisibleToolNames.has(tool),
	);
	if (unavailable.length) {
		throw new Error(
			`tool profile ${toolProfile} does not expose requested Blitz tools: ${unavailable.join(",")}`,
		);
	}
};

type SkillArtifact = {
	path: string;
	snapshotPath: string;
	tokens: number;
	bytes: number;
};

type TokenizerMetadata = {
	toolSpecTokenizer: string;
	skillTokenizer: string;
	toolCallArgTokenizer: string;
	model: string;
	provider: string;
};

const captureAccountingArtifacts = async (): Promise<{
	artifactRoot: string;
	toolSpec: ToolSpecArtifact | null;
	toolSpecs: ToolSpecArtifact[];
	skill: SkillArtifact;
	tokenizer: TokenizerMetadata;
	metadataPath: string;
}> => {
	await mkdir(artifactRoot, { recursive: true });
	const tokenizer: TokenizerMetadata = {
		toolSpecTokenizer: "cl100k_base via tiktoken",
		skillTokenizer: "cl100k_base via tiktoken",
		toolCallArgTokenizer: "cl100k_base via tiktoken",
		model,
		provider,
	};
	const skillText = await readFile(join(skill, "SKILL.md"), "utf8").catch(
		() => "",
	);
	const skillSnapshotPath = join(artifactRoot, `skill.${toolProfile}.md`);
	for (const profile of artifactProfiles) {
		await writeFile(
			join(artifactRoot, `skill.${profile}.md`),
			skillText,
			"utf8",
		);
	}
	let toolSpec: ToolSpecArtifact | null = null;
	const toolSpecs: ToolSpecArtifact[] = [];
	for (const profile of [...new Set(artifactProfiles)]) {
		const serializedToolSpecsPath = join(
			artifactRoot,
			`tool-specs.${profile}.json`,
		);
		const dump = spawnSync(
			"bun",
			[
				"scripts/dump-tool-specs.ts",
				"--profile",
				profile,
				"--out",
				serializedToolSpecsPath,
			],
			{
				cwd: piBlitzPackage,
				env: { ...process.env, PI_BLITZ_TOOL_PROFILE: profile },
				encoding: "utf8",
				maxBuffer: 20 * 1024 * 1024,
			},
		);
		if (dump.status !== 0) {
			if (tokScaleMode === "required" || profile === toolProfile) {
				throw new Error(
					`tool spec dump failed for ${profile}: ${(dump.stderr || dump.stdout).trim()}`,
				);
			}
			continue;
		}
		const text = await readFile(serializedToolSpecsPath, "utf8");
		const parsed = JSON.parse(text) as {
			profile: string;
			profileLabel: string;
			tools: Array<{ name: string }>;
		};
		const artifact = {
			profile: parsed.profile,
			profileLabel: parsed.profileLabel,
			visibleToolNames: parsed.tools.map((tool) => tool.name),
			serializedToolSpecsPath,
			serializedToolSpecsTokens: countTokens(text),
			serializedToolSpecsBytes: Buffer.byteLength(text, "utf8"),
		};
		toolSpecs.push(artifact);
		if (profile === toolProfile) toolSpec = artifact;
	}
	const metadataPath = join(artifactRoot, `tokenizer.${toolProfile}.json`);
	for (const profile of artifactProfiles) {
		await writeFile(
			join(artifactRoot, `tokenizer.${profile}.json`),
			JSON.stringify({ ...tokenizer, profile }, null, 2),
			"utf8",
		);
	}
	return {
		artifactRoot,
		toolSpec,
		toolSpecs,
		skill: {
			path: join(skill, "SKILL.md"),
			snapshotPath: skillSnapshotPath,
			tokens: countTokens(skillText),
			bytes: Buffer.byteLength(skillText, "utf8"),
		},
		tokenizer,
		metadataPath,
	};
};

const tokScaleAvailable = () => {
	const r = spawnSync("tokscale", ["--version"], {
		encoding: "utf8",
		timeout: 10_000,
	});
	return r.status === 0;
};

const copySessionForTokScale = async (sessionFile: string) => {
	const home = await mkdtemp(join(tmpdir(), "pi-bench-tokscale-"));
	const destDir = join(
		home,
		".pi/agent/sessions/bench",
		basename(dirname(sessionFile)),
	);
	await mkdir(destDir, { recursive: true });
	await copyFile(sessionFile, join(destDir, basename(sessionFile)));
	return home;
};

const numberFrom = (value: unknown): number | null =>
	typeof value === "number" && Number.isFinite(value) ? value : null;

const runTokScale = async (
	sessionFile: string,
	parsed: ParsedSession,
	cwd: string,
): Promise<TokScaleValidation> => {
	if (tokScaleMode === "disabled") return emptyTokScale("");
	if (!tokScaleAvailable()) {
		const details = "tokscale not found on PATH";
		if (tokScaleMode === "required") throw new Error(details);
		return emptyTokScale(details);
	}
	const home = await copySessionForTokScale(sessionFile);
	const args = [
		"--home",
		home,
		"--client",
		"pi",
		"--json",
		"--light",
		"--benchmark",
		"--no-spinner",
	];
	const r = spawnSync("tokscale", args, {
		cwd,
		encoding: "utf8",
		maxBuffer: 50 * 1024 * 1024,
		timeout: 60_000,
	});
	if (!keepTemp) await rm(home, { recursive: true, force: true });
	if (r.status !== 0) {
		const details = (r.stderr || r.stdout)
			.trim()
			.split("\n")
			.slice(0, 3)
			.join(" ");
		if (tokScaleMode === "required")
			throw new Error(`tokscale failed: ${details}`);
		return emptyTokScale(`tokscale failed: ${details}`);
	}
	let payload: Record<string, unknown>;
	try {
		payload = JSON.parse(r.stdout) as Record<string, unknown>;
	} catch (error) {
		const details = `tokscale JSON parse failed: ${String(error)}`;
		if (tokScaleMode === "required") throw new Error(details);
		return emptyTokScale(details);
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
	const tokenMismatches: string[] = [];
	const details: string[] = [];
	const compare = (name: string, got: number | null, expected: number) => {
		if (got === null || Math.abs(got - expected) > 0.000001) {
			tokenMismatches.push(
				`${name} tokscale=${got ?? "null"} parser=${expected}`,
			);
		}
	};
	compare("input", totals.input, parsed.totalInputTokens);
	compare("output", totals.output, parsed.totalOutputTokens);
	compare("cacheRead", totals.cacheRead, parsed.totalCacheRead);
	compare("cacheWrite", totals.cacheWrite, parsed.totalCacheWrite);
	compare("messages", totals.messages, parsed.turnCount);
	if (parsed.totalCost !== 0) {
		if (
			totals.cost === null ||
			Math.abs(totals.cost - parsed.totalCost) > 0.000001
		) {
			details.push(
				`cost tokscale=${totals.cost ?? "null"} parser=${parsed.totalCost}`,
			);
		}
	}
	if (tokenMismatches.length && tokScaleMode === "required") {
		throw new Error(`tokscale mismatch: ${tokenMismatches.join("; ")}`);
	}
	details.unshift(...tokenMismatches);
	return {
		...totals,
		matchesParser: tokenMismatches.length === 0,
		details: details.join("; "),
	};
};

const runLane = async (
	lane: Lane,
	fx: Fixture,
	iter: number,
): Promise<LaneResult> => {
	const tmp =
		runner === "tmux"
			? join(runRoot, `${safeName(fx.id)}__${lane}__${iter}`)
			: await mkdtemp(join(tmpdir(), `pi-bench-${lane}-`));
	const targetDir = join(tmp, "work");
	await mkdir(targetDir, { recursive: true });
	const targetPath = join(targetDir, fx.relPath);
	const original = await readFile(join(fixtureDir, fx.relPath), "utf8");
	await writeFile(targetPath, original, "utf8");

	let prompt = fx.intent(targetPath);
	if (lane !== "core") {
		const useRouter = lane === "router";
		const useCompactOp = toolProfile === "minimal" || useRouter;
		let guidance = useRouter
			? "Use only `pi_blitz_route_edit`. Copy exact args JSON. Do not call other pi_blitz_* tools. Use route preference `blitz` for executable Blitz rows."
			: useCompactOp
				? "Use only `pi_blitz_op`. Copy exact args JSON. Do not call other pi_blitz_* tools."
				: "Use the narrow pi_blitz_* structured tool that matches the edit. Do not repeat unchanged code. Pass symbol name only in `symbol`.";
		const compactArgs = (script: string) =>
			JSON.stringify({ f: targetPath, ops: script.split("\n").map((line) => line.split("\t")) });
		const routeArgs = (script: string, fallback = 5000, route = "blitz") =>
			JSON.stringify({ f: targetPath, r: route, s: script, fallbackContextTokensExpected: fallback });
		if (fx.id.includes("wrap-body")) {
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs("wb\tmediumCompute\t\\n  try {\t  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }\\n\t2")}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: {"f":${JSON.stringify(targetPath)},"ops":[["wb","mediumCompute","\\n  try {","  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }\\n",2]]}.`
				: ' For this edit, call `pi_blitz_wrap_body`. Copy exact tool args JSON: {"symbol":"mediumCompute","before":"\\n  try {","after":"  } catch (error) {\\n    console.error(error);\\n    throw error;\\n  }\\n","indentKeptBodyBy":2}. `before` starts with newline escape `\\n` and has no trailing newline. `after` has no leading newline and MUST end with newline escape `\\n`. JSON escapes must decode to newline chars; do not pass literal backslash-n text.';
		} else if (fx.id.includes("compose-preserve-islands")) {
			guidance +=
				' For this edit, call `pi_blitz_compose_body` with symbol `mediumCompute` and segments: [ { keep: { afterKeep: `  let total = seed;`, includeAfter: true, occurrence: "only" } }, { text: `\\n  if (!Number.isFinite(total)) {\\n    throw new RangeError(\\"seed must be finite\\");\\n  }\\n` }, { keep: { beforeKeep: `  let total = seed;`, afterKeep: `  return total;`, includeBefore: false, includeAfter: false, occurrence: "last" } }, { text: `  if (total < 0) {\\n    return 0;\\n  }\\n\\n` }, { keep: { beforeKeep: `  return total;`, includeBefore: true, occurrence: "last" } } ].';
		} else if (fx.id.includes("insert-body-span")) {
			guidance +=
				' For this edit, call `pi_blitz_insert_body_span` with symbol `mediumCompute`, anchor `let total = seed;`, position `after`, text `\\n  if (!Number.isFinite(total)) {\\n    throw new RangeError("seed must be finite");\\n  }`, occurrence `only`.';
		} else if (fx.id.includes("medium-10k/marker-tail")) {
			const script = "rb\tmediumCompute\treturn total;\treturn total + 1;\tlast";
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: " For this edit, call `pi_blitz_replace_body_span` with symbol `mediumCompute`, find `return total;`, replace `return total + 1;`, occurrence `last`.";
		} else if (fx.id.includes("multi/three-body-ops")) {
			guidance +=
				' For this edit, call `pi_blitz_multi_body`. Exact tool args JSON: {"edits":[{"symbol":"adjust","op":"replace_body_span","find":"return base;","replace":"return base + 1;","occurrence":"only"},{"symbol":"emit","op":"insert_body_span","anchor":"const marker = value;","position":"after","text":"\\n  const markerUpper = value.toUpperCase();","occurrence":"only"},{"symbol":"risky","op":"wrap_body","before":"\\n  try {","keep":"body","after":"  } catch (error) {\\n    throw error;\\n  }\\n","indentKeptBodyBy":2}]}. JSON escapes must decode to newline characters; do not pass literal backslash-n text. Emit insert text starts with newline escape `\\n`; risky `after` MUST end with newline escape `\\n`.';
		} else if (fx.id.includes("multi/large-structural")) {
			const patchArgs = JSON.stringify({
				file: targetPath,
				ops: [
					["try_catch", "mediumCompute", "console.error(error);\nthrow error;"],
					[
						"insert_after",
						"auditEvent",
						"const normalized = event.trim();",
						"\n  const tagged = `[audit] ${normalized}`;",
						"only",
					],
					["replace_return", "formatStatus", "status.toUpperCase()", "only"],
				],
			});
			guidance += ` For this edit, call \`pi_blitz_patch\`. Copy exact one-line tool args JSON: ${patchArgs}. Critical: insert_after text MUST start with newline escape \`\\n\` followed by two spaces.`;
		} else if (fx.id.includes("huge-100k/marker-tail")) {
			guidance +=
				" For this edit, call `pi_blitz_replace_body_span` with symbol `hugeCompute`, find `return total;`, replace `return total + 1;`, occurrence `last`.";
		} else if (fx.id.includes("semantic/async-try-catch")) {
			const script = "tc\tloadUser\tconsole.error(error);\\nthrow error;\t2";
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: ' For this edit, call `pi_blitz_try_catch`. Exact tool args JSON: {"symbol":"loadUser","catchBody":"console.error(error);\\nthrow error;","indent":2}. JSON escape must decode to a newline character; do not pass catchBody as one line.';
		} else if (fx.id.includes("semantic/class-method-try-catch")) {
			const script = "tc\trenderScore\tconsole.error(error);\\nthrow error;\t2";
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: ' For this edit, call `pi_blitz_try_catch`. Exact tool args JSON: {"symbol":"renderScore","catchBody":"console.error(error);\\nthrow error;","indent":2}. JSON escape must decode to a newline character; do not pass catchBody as one line.';
		} else if (fx.id.includes("semantic/arrow-replace-return")) {
			const script = 'rr\tpickLabel\t"unknown"\tlast';
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: ' For this edit, call `pi_blitz_replace_return` with symbol `pickLabel`, occurrence `last`. IMPORTANT: `expr` must be JSON string value containing the quoted TypeScript string literal, not identifier text. Exact one-line tool args JSON: {"symbol":"pickLabel","expr":"\\"unknown\\"","occurrence":"last"}.';
		} else if (fx.id.includes("semantic/nested-return-occurrence")) {
			const script = 'rr\tclassify\t"other"\tlast';
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: ' For this edit, call `pi_blitz_replace_return` with symbol `classify`, occurrence `last`. IMPORTANT: `expr` must be JSON string value containing the quoted TypeScript string literal, not identifier text. Exact one-line tool args JSON: {"symbol":"classify","expr":"\\"other\\"","occurrence":"last"}.';
		} else if (fx.id.includes("semantic/tsx-replace-return")) {
			const script = 'rr\tStatusBadge\t<strong className="badge">{label.toUpperCase()}</strong>\tonly';
			guidance += useRouter
				? ` For this edit, call \`pi_blitz_route_edit\` with exact args JSON: ${routeArgs(script)}.`
				: useCompactOp
					? ` For this edit, call \`pi_blitz_op\` with exact args JSON: ${compactArgs(script)}.`
				: ' For this edit, call `pi_blitz_replace_return` with symbol `StatusBadge`, occurrence `only`. Exact one-line tool args JSON: {"symbol":"StatusBadge","expr":"<strong className=\\"badge\\">{label.toUpperCase()}</strong>","occurrence":"only"}.';
		} else if (fx.id.includes("small")) {
			guidance += useRouter
				? ` For this unsupported exact-text edit, call \`pi_blitz_route_edit\` once with exact no-write decline args JSON: ${routeArgs("", 500, "apply_patch")}.`
				: " For this edit, route to core oldText/newText.";
		} else if (useRouter) {
			guidance += ` This fixture has no valid compact Blitz alias yet. Be honest: call \`pi_blitz_route_edit\` once with exact no-write decline args JSON: ${routeArgs("", 5000, "apply_patch")}.`;
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
	const toolsOverride =
		lane === "core"
			? undefined
			: lane === "router"
				? "pi_blitz_route_edit"
				: toolProfile === "minimal"
				? "pi_blitz_op"
				: fx.id.includes("multi/large-structural")
					? "pi_blitz_patch"
					: fx.id.includes("multi/three-body-ops")
						? "pi_blitz_multi_body"
						: fx.id.includes("insert-body-span")
							? "pi_blitz_insert_body_span"
							: fx.id.includes("compose-preserve-islands")
								? "pi_blitz_compose_body"
								: fx.id.includes("wrap-body")
									? "pi_blitz_wrap_body"
									: fx.id.includes("marker-tail")
										? "pi_blitz_replace_body_span"
										: semanticTools[fx.id];
	assertProfileSupportsTools(toolsOverride);
	const r =
		runner === "tmux"
			? await runPiTmux(lane, prompt, targetDir, fx, iter, toolsOverride)
			: runPiSpawn(lane, prompt, targetDir, toolsOverride);
	if (r.status !== 0) {
		if (verbose)
			console.error(
				`[${lane}] pi exit ${r.status}${r.timedOut ? " (timeout)" : ""}\nstderr: ${r.stderr}\nstdout: ${r.stdout}`,
			);
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
	const missingSessionAfterFailedRun =
		!sessionFile && (r.status !== 0 || r.timedOut);
	const tokScale = sessionFile
		? await runTokScale(sessionFile, parsed, targetDir)
		: emptyTokScale(
				missingSessionAfterFailedRun
					? "no session jsonl (run failed/timed out)"
					: "no session jsonl",
			);
	if (
		tokScaleMode === "required" &&
		!sessionFile &&
		!missingSessionAfterFailedRun
	) {
		throw new Error("tokscale validation required but no session jsonl found");
	}

	const got = await readFile(targetPath, "utf8").catch(() => "");
	const correct = got === fx.expectedFile;
	if (!correct && verbose) console.error(`[${lane}] golden mismatch`);

	if (runner === "spawn" && !keepTemp)
		await rm(tmp, { recursive: true, force: true });
	return {
		lane,
		wallMs: r.ms,
		promptTokens: countTokens(prompt),
		session: parsed,
		tokScale,
		correct,
		exitCode: r.status,
		timedOut: r.timedOut,
		stderr: r.stderr,
		stdout: r.stdout,
		runDir: r.runDir,
		sessionDir: r.sessionDir,
		sessionFile: sessionFile || undefined,
		commandFile: r.commandFile,
		stdoutLog: r.stdoutLog,
		stderrLog: r.stderrLog,
		exitFile: r.exitFile,
	};
};

const median = (xs: number[]) =>
	[...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)]!;
const medianNullable = (xs: (number | null)[]) => {
	const numbers = xs.filter((v): v is number => v !== null);
	return numbers.length ? median(numbers) : null;
};
const sumNullable = (xs: (number | null)[]) =>
	xs.some((v) => v !== null)
		? xs.reduce<number>((a, v) => a + (v ?? 0), 0)
		: null;
const formatNullable = (v: number | null, digits = 0) =>
	v === null ? "" : v.toFixed(digits);
const pct = (n: number) => `${n.toFixed(1)}%`;

const main = async () => {
	console.log(`# Pi-driven authentic LLM token bench`);
	console.log(`Provider: ${provider} / Model: ${model}`);
	console.log(`Iterations: ${iters}`);
	console.log(`Runner: ${runner}`);
	if (runner === "tmux") console.log(`Run root: ${runRoot}`);
	console.log(`Timeout per Pi run: ${timeoutMs}ms`);
	console.log(`Pi: ${piBin}`);
	console.log(`Blitz binary PATH prepend: ${BLITZ_BIN_DIR}`);
	console.log(`Extension: ${extension}`);
	console.log(`Skill: ${skill}`);
	console.log(`Tokscale validation: ${tokScaleMode}`);
	console.log(`Tool profile: ${toolProfile}`);
	console.log(`Accounting artifact profiles: ${artifactProfiles.join(",")}`);
	console.log(`Accounting artifact root: ${artifactRoot}`);
	const accountingArtifacts = await captureAccountingArtifacts();
	selectedVisibleToolNames = new Set(
		accountingArtifacts.toolSpec?.visibleToolNames ?? [],
	);
	if (caseFilter) console.log(`Case filter: ${caseFilter}`);
	if (laneFilter) console.log(`Lane filter: ${laneFilter}`);
	console.log(
		`Tokenizer: cl100k_base via tiktoken (for tool-call arg compare)`,
	);
	console.log(
		`Visible Blitz tools: ${accountingArtifacts.toolSpec?.visibleToolNames.join(",") ?? "unavailable"}`,
	);
	console.log(
		`Tool spec tokens: ${accountingArtifacts.toolSpec?.serializedToolSpecsTokens ?? "unavailable"}`,
	);
	console.log(`Skill tokens: ${accountingArtifacts.skill.tokens}`);
	if (argv.includes("--dump-accounting-only")) {
		console.log(JSON.stringify(accountingArtifacts, null, 2));
		releaseTokenizer();
		return;
	}
	console.log("");

	type Row = {
		fixture: string;
		className: string;
		recommendedLane: Lane | "";
		lane: Lane;
		route: Route;
		routeReasonCode: RouteReasonCode;
		toolProfile: string;
		visibleToolNames: string[];
		toolSpecTokens: number | null;
		schemaTokens: number;
		skillTokens: number;
		promptTokens: number;
		argTokens: number;
		outputTokens: number;
		cacheRead: number;
		cacheWrite: number;
		resultPayloadTokens: number;
		residualInputTokens: number | null;
		totalContextTokens: number;
		toolName: string;
		wallMsMedian: number;
		inputMedian: number;
		outputMedian: number;
		cacheReadMedian: number;
		cacheWriteMedian: number;
		argsTokensMedian: number;
		tokScaleInputMedian: number | null;
		tokScaleOutputMedian: number | null;
		tokScaleCacheReadMedian: number | null;
		tokScaleCacheWriteMedian: number | null;
		tokScaleMessagesMedian: number | null;
		tokScaleCostSum: number | null;
		tokScaleProcessingTimeMsMedian: number | null;
		tokScaleTokenMatchesParser: boolean;
		tokScaleMatchesParser: boolean;
		tokScaleDetails: string;
		correctRate: number;
		costSum: number;
		exitCodes: number[];
		timedOut: boolean;
		failure: string;
	};
	const rows: Row[] = [];
	type ProfileCoverage = {
		profile: string;
		supportedFixtures: string[];
		skippedFixtures: { fixture: string; reason: string }[];
	};
	type OverheadComparison = {
		profile: string;
		schemaTokens: number;
		skillTokens: number;
		combinedResidentTokens: number;
		reductionVsFullPct: number | null;
		meetsCommonLaneTarget: boolean | null;
	};
	type RunRecord = {
		fixture: string;
		lane: Lane;
		route: Route;
		routeReasonCode: RouteReasonCode;
		iter: number;
		toolProfile: string;
		visibleToolNames: string[];
		toolSpecTokens: number | null;
		schemaTokens: number;
		skillTokens: number;
		promptTokens: number;
		argTokens: number;
		outputTokens: number;
		cacheRead: number;
		cacheWrite: number;
		resultPayloadTokens: number;
		residualInputTokens: number | null;
		totalContextTokens: number;
		toolName: string | null;
		wallMs: number;
		inputTokens: number;
		cacheReadTokens: number;
		cacheWriteTokens: number;
		toolCallArgTokens: number;
		cost: number;
		tokScaleInput: number | null;
		tokScaleOutput: number | null;
		tokScaleCacheRead: number | null;
		tokScaleCacheWrite: number | null;
		tokScaleMessages: number | null;
		tokScaleCost: number | null;
		tokScaleProcessingTimeMs: number | null;
		tokScaleTokenMatchesParser: boolean;
		tokScaleMatchesParser: boolean;
		tokScaleDetails: string;
		correct: boolean;
		exitCode: number;
		timedOut: boolean;
		failure: string;
		tokenRouteDecision: TokenRouteDecision;
		runDir?: string;
		sessionDir?: string;
		sessionFile?: string;
		commandFile?: string;
		stdoutLog?: string;
		stderrLog?: string;
		exitFile?: string;
	};
	const runRecords: RunRecord[] = [];

	const caseFilters = caseFilter
		.split(",")
		.map((v) => v.trim())
		.filter(Boolean);
	const selectedFixtures =
		caseFilters.length > 0
			? FIXTURES.filter((fx) =>
					caseFilters.some((filter) => fx.id.includes(filter)),
				)
			: FIXTURES;
	if (selectedFixtures.length === 0)
		throw new Error(`no fixtures match --case ${caseFilter}`);

	const profileSupportsFixture = (profile: string, fx: Fixture): boolean => {
		if (fx.lanePolicy === "core-only") return false;
		if (profile === "full") return true;
		if (profile === "router") return true;
		if (profile === "minimal" || profile === "minimal-v0") {
			return true;
		}
		if (profile === "semantic") return fx.id.startsWith("semantic/");
		if (profile === "structural") {
			return (
				fx.id.startsWith("multi/") ||
				fx.className === "medium_wrap_body" ||
				fx.className === "insert_body_span" ||
				fx.className === "compose_preserve_islands"
			);
		}
		if (profile === "admin") return false;
		return false;
	};

	const artifactProfileLabels = new Set<string>(
		accountingArtifacts.toolSpecs.map((spec) => spec.profileLabel),
	);
	if (accountingArtifacts.toolSpec?.profileLabel) {
		artifactProfileLabels.add(accountingArtifacts.toolSpec.profileLabel);
	}
	const profileCoverage: ProfileCoverage[] = [...artifactProfileLabels].map(
		(profile) => {
			const supportedFixtures = selectedFixtures
				.filter((fx) => profileSupportsFixture(profile, fx))
				.map((fx) => fx.id);
			const skippedFixtures = selectedFixtures
				.filter((fx) => !profileSupportsFixture(profile, fx))
				.map((fx) => ({
					fixture: fx.id,
					reason:
						fx.lanePolicy === "core-only"
							? "core-only fixture"
							: `unsupported by ${profile} registered tool profile`,
				}));
			return { profile, supportedFixtures, skippedFixtures };
		},
	);
	const fullSpec = accountingArtifacts.toolSpecs.find(
		(spec) => spec.profileLabel === "full" || spec.profile === "full",
	);
	const fullCombinedResidentTokens = fullSpec
		? fullSpec.serializedToolSpecsTokens + accountingArtifacts.skill.tokens
		: null;
	const overheadComparisons: OverheadComparison[] =
		accountingArtifacts.toolSpecs.map((spec) => {
			const combinedResidentTokens =
				spec.serializedToolSpecsTokens + accountingArtifacts.skill.tokens;
			const reductionVsFullPct = fullCombinedResidentTokens
				? 100 * (1 - combinedResidentTokens / fullCombinedResidentTokens)
				: null;
			return {
				profile: spec.profileLabel,
				schemaTokens: spec.serializedToolSpecsTokens,
				skillTokens: accountingArtifacts.skill.tokens,
				combinedResidentTokens,
				reductionVsFullPct,
				meetsCommonLaneTarget:
					reductionVsFullPct === null ? null : reductionVsFullPct >= 70,
			};
		});
	const toolSpecForLane = (lane: Lane): ToolSpecArtifact | null => {
		if (lane === "core") return null;
		if (lane === "router") {
			return (
				accountingArtifacts.toolSpecs.find(
					(spec) => spec.profileLabel === "router" || spec.profile === "router",
				) ?? null
			);
		}
		return accountingArtifacts.toolSpec;
	};

	const lanesForFixture = (fx: Fixture): Lane[] => {
		if (laneFilter) return [laneFilter];
		if (fx.lanePolicy === "core-only") return ["core"];
		return ["core", "blitz", "router"];
	};
	for (const fx of selectedFixtures) {
		for (const lane of lanesForFixture(fx)) {
			const runs: LaneResult[] = [];
			const laneToolSpec = toolSpecForLane(lane);
			const schemaTokens =
				lane !== "core"
					? (laneToolSpec?.serializedToolSpecsTokens ?? 0)
					: 0;
			const skillTokens =
				lane !== "core" ? accountingArtifacts.skill.tokens : 0;
			for (let i = 0; i < iters; i++) {
				const r = await runLane(lane, fx, i);
				const argTokens = r.session.editToolCallArgsTokens;
				const outputTokens = r.session.totalOutputTokens;
				const cacheRead = r.session.totalCacheRead;
				const cacheWrite = r.session.totalCacheWrite;
				const resultPayloadTokens = countTokens(r.stdout);
				const residualInputTokens =
					r.session.totalInputTokens - argTokens - schemaTokens - skillTokens;
				const totalContextTokens =
					schemaTokens +
					skillTokens +
					r.promptTokens +
					r.session.totalInputTokens +
					cacheRead +
					cacheWrite +
					argTokens +
					outputTokens +
					resultPayloadTokens;
				const tokenRouteDecision: TokenRouteDecision = {
					contextSavingsPct: null,
					schemaTokensExpected: schemaTokens,
					argTokensExpected: argTokens,
					outputTokensExpected: outputTokens,
					fallbackContextTokensExpected: null,
					selectedBecause:
						lane === "core"
							? "core lane selected as baseline/fallback"
							: "Blitz lane selected by explicit profile; paired core row required before savings claim",
				};
				runs.push(r);
				runRecords.push({
					fixture: fx.id,
					lane,
					...routeForLane(lane, fx),
					iter: i,
					toolProfile:
						lane === "core"
							? "core"
							: lane === "router"
								? "router"
								: (laneToolSpec?.profileLabel ?? toolProfile),
					visibleToolNames:
						lane === "core"
							? ["edit"]
							: lane === "router"
								? ["pi_blitz_route_edit"]
								: (laneToolSpec?.visibleToolNames ?? []),
					toolSpecTokens: schemaTokens,
					schemaTokens,
					skillTokens,
					promptTokens: r.promptTokens,
					argTokens,
					outputTokens,
					cacheRead,
					cacheWrite,
					resultPayloadTokens,
					residualInputTokens,
					totalContextTokens,
					toolName: r.session.editToolName,
					wallMs: r.wallMs,
					inputTokens: r.session.totalInputTokens,
					cacheReadTokens: cacheRead,
					cacheWriteTokens: cacheWrite,
					toolCallArgTokens: argTokens,
					cost: r.session.totalCost,
					tokScaleInput: r.tokScale.input,
					tokScaleOutput: r.tokScale.output,
					tokScaleCacheRead: r.tokScale.cacheRead,
					tokScaleCacheWrite: r.tokScale.cacheWrite,
					tokScaleMessages: r.tokScale.messages,
					tokScaleCost: r.tokScale.cost,
					tokScaleProcessingTimeMs: r.tokScale.processingTimeMs,
					tokScaleTokenMatchesParser: r.tokScale.matchesParser,
					tokScaleMatchesParser: r.tokScale.matchesParser,
					tokScaleDetails: r.tokScale.details,
					correct: r.correct,
					exitCode: r.exitCode,
					timedOut: r.timedOut,
					failure:
						r.exitCode === 0
							? ""
							: (r.stderr || r.stdout).trim().split("\n").slice(0, 3).join(" "),
					tokenRouteDecision: tokenRouteDecision,
					runDir: r.runDir,
					sessionDir: r.sessionDir,
					sessionFile: r.sessionFile,
					commandFile: r.commandFile,
					stdoutLog: r.stdoutLog,
					stderrLog: r.stderrLog,
					exitFile: r.exitFile,
				});
				if (verbose)
					console.error(
						`[${fx.id}][${lane}][iter ${i}] output=${r.session.totalOutputTokens} args=${r.session.editToolCallArgsTokens} ok=${r.correct} wall=${r.wallMs.toFixed(0)}`,
					);
			}
			const toolNames = [
				...new Set(
					runs
						.map((r) => r.session.editToolName)
						.filter((v): v is string => Boolean(v)),
				),
			];
			const tokScaleDetails = [
				...new Set(
					runs.map((r) => r.tokScale.details).filter((detail) => detail),
				),
			].join("; ");
			const resultPayloadTokenValues = runs.map((r) => countTokens(r.stdout));
			const residualInputTokenValues = runs.map(
				(r) =>
					r.session.totalInputTokens -
					r.session.editToolCallArgsTokens -
					schemaTokens -
					skillTokens,
			);
			const totalContextTokenValues = runs.map(
				(r, idx) =>
					schemaTokens +
					skillTokens +
					r.promptTokens +
					r.session.totalInputTokens +
					r.session.totalCacheRead +
					r.session.totalCacheWrite +
					r.session.editToolCallArgsTokens +
					r.session.totalOutputTokens +
					resultPayloadTokenValues[idx]!,
			);
			rows.push({
				fixture: fx.id,
				className: fx.className ?? "",
				recommendedLane: fx.recommendedLane ?? "",
				lane,
				...routeForLane(lane, fx),
				toolProfile:
					lane === "core"
						? "core"
						: lane === "router"
							? "router"
							: (laneToolSpec?.profileLabel ?? toolProfile),
				visibleToolNames:
					lane === "core"
						? ["edit"]
						: lane === "router"
							? ["pi_blitz_route_edit"]
							: (laneToolSpec?.visibleToolNames ?? []),
				toolSpecTokens: schemaTokens,
				schemaTokens,
				skillTokens,
				promptTokens: median(runs.map((r) => r.promptTokens)),
				argTokens: median(runs.map((r) => r.session.editToolCallArgsTokens)),
				outputTokens: median(runs.map((r) => r.session.totalOutputTokens)),
				cacheRead: median(runs.map((r) => r.session.totalCacheRead)),
				cacheWrite: median(runs.map((r) => r.session.totalCacheWrite)),
				resultPayloadTokens: median(resultPayloadTokenValues),
				residualInputTokens: medianNullable(residualInputTokenValues),
				totalContextTokens: median(totalContextTokenValues),
				toolName: toolNames.join(",") || "",
				wallMsMedian: median(runs.map((r) => r.wallMs)),
				inputMedian: median(runs.map((r) => r.session.totalInputTokens)),
				outputMedian: median(runs.map((r) => r.session.totalOutputTokens)),
				cacheReadMedian: median(runs.map((r) => r.session.totalCacheRead)),
				cacheWriteMedian: median(runs.map((r) => r.session.totalCacheWrite)),
				argsTokensMedian: median(
					runs.map((r) => r.session.editToolCallArgsTokens),
				),
				tokScaleInputMedian: medianNullable(runs.map((r) => r.tokScale.input)),
				tokScaleOutputMedian: medianNullable(
					runs.map((r) => r.tokScale.output),
				),
				tokScaleCacheReadMedian: medianNullable(
					runs.map((r) => r.tokScale.cacheRead),
				),
				tokScaleCacheWriteMedian: medianNullable(
					runs.map((r) => r.tokScale.cacheWrite),
				),
				tokScaleMessagesMedian: medianNullable(
					runs.map((r) => r.tokScale.messages),
				),
				tokScaleCostSum: sumNullable(runs.map((r) => r.tokScale.cost)),
				tokScaleProcessingTimeMsMedian: medianNullable(
					runs.map((r) => r.tokScale.processingTimeMs),
				),
				tokScaleTokenMatchesParser: runs.every((r) => r.tokScale.matchesParser),
				tokScaleMatchesParser: runs.every((r) => r.tokScale.matchesParser),
				tokScaleDetails,
				correctRate: runs.filter((r) => r.correct).length / runs.length,
				costSum: runs.reduce((a, r) => a + r.session.totalCost, 0),
				exitCodes: [...new Set(runs.map((r) => r.exitCode))],
				timedOut: runs.some((r) => r.timedOut),
				failure:
					runs
						.find((r) => r.exitCode !== 0)
						?.stderr.trim()
						.split("\n")
						.slice(0, 2)
						.join(" ") ?? "",
			});
		}
	}

	const lines: string[] = [];
	lines.push(
		"| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |",
	);
	lines.push(
		"|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|",
	);
	for (const r of rows) {
		const failure = [r.failure, r.tokScaleDetails]
			.filter(Boolean)
			.join("; ")
			.replaceAll("|", "\\|");
		lines.push(
			`| ${r.fixture} | ${r.className} | ${r.recommendedLane} | ${r.lane} | ${r.route} | ${r.toolProfile} | ${r.visibleToolNames.join(",")} | ${r.schemaTokens} | ${r.skillTokens} | ${r.promptTokens} | ${r.argTokens} | ${r.outputTokens} | ${r.cacheRead} | ${r.cacheWrite} | ${r.resultPayloadTokens} | ${formatNullable(r.residualInputTokens)} | ${r.totalContextTokens} | ${r.toolName} | ${r.wallMsMedian.toFixed(0)} | ${r.inputMedian} | ${formatNullable(r.tokScaleInputMedian)} | ${formatNullable(r.tokScaleOutputMedian)} | ${formatNullable(r.tokScaleCacheReadMedian)} | ${formatNullable(r.tokScaleCacheWriteMedian)} | ${formatNullable(r.tokScaleMessagesMedian)} | ${formatNullable(r.tokScaleProcessingTimeMsMedian)} | ${r.tokScaleTokenMatchesParser ? "yes" : "no"} | ${pct(r.correctRate * 100)} | ${r.exitCodes.join(",")} | ${failure} | ${r.costSum.toFixed(4)} | ${formatNullable(r.tokScaleCostSum, 4)} |`,
		);
	}

	console.log(lines.join("\n"));
	type PairwiseSummary = {
		fixture: string;
		status:
			| "both_correct"
			| "core_failed_blitz_correct"
			| "blitz_failed"
			| "incomplete";
		acceptedRoute?: "core" | "blitz" | "none";
		routeDecisionReason?: string;
		savingsCounted: boolean;
		outputSavingsPct?: number;
		argsSavingsPct?: number;
		totalContextSavingsPct?: number;
		wallSavingsPct?: number;
		costSavingsPct?: number;
		coreOutputTokens?: number;
		blitzOutputTokens?: number;
		coreArgsTokens?: number;
		blitzArgsTokens?: number;
		coreTotalContextTokens?: number;
		blitzTotalContextTokens?: number;
		coreWallMs?: number;
		blitzWallMs?: number;
		coreCost?: number;
		blitzCost?: number;
	};
	const rowSucceeded = (r: Row): boolean =>
		r.correctRate === 1 &&
		!r.timedOut &&
		r.exitCodes.every((code) => code === 0);
	const savingsPct = (before: number, after: number): number | undefined =>
		before ? 100 * (1 - after / before) : undefined;
	const formatSavings = (label: string, value: number | undefined): string => {
		if (value === undefined) return `${label} unavailable`;
		return value >= 0
			? `saved ${label} ${pct(value)}`
			: `lost ${label} ${pct(Math.abs(value))}`;
	};
	const pairwise: PairwiseSummary[] = [];
	const summaryLines: string[] = [];
	summaryLines.push("", "## Pairwise savings (correct rows only)");
	if (!rows.some((r) => r.lane === "core")) {
		summaryLines.push("Skipped; core lane not run.");
	} else {
		for (const fx of selectedFixtures) {
			const core = rows.find((r) => r.fixture === fx.id && r.lane === "core");
			const blitz = rows.find((r) => r.fixture === fx.id && r.lane === "blitz");
			if (!core || !blitz) {
				pairwise.push({
					fixture: fx.id,
					status: "incomplete",
					acceptedRoute: "none",
					routeDecisionReason: "Pair missing lane; savings not counted",
					savingsCounted: false,
				});
				continue;
			}

			const coreCorrect = rowSucceeded(core);
			const blitzCorrect = rowSucceeded(blitz);
			const basePair = {
				fixture: fx.id,
				savingsCounted: false,
				coreOutputTokens: core.outputMedian,
				blitzOutputTokens: blitz.outputMedian,
				coreArgsTokens: core.argsTokensMedian,
				blitzArgsTokens: blitz.argsTokensMedian,
				coreTotalContextTokens: core.totalContextTokens,
				blitzTotalContextTokens: blitz.totalContextTokens,
				coreWallMs: core.wallMsMedian,
				blitzWallMs: blitz.wallMsMedian,
				coreCost: core.costSum,
				blitzCost: blitz.costSum,
			};

			if (coreCorrect && blitzCorrect) {
				const outputSavingsPct = savingsPct(
					core.outputMedian,
					blitz.outputMedian,
				);
				const argsSavingsPct = savingsPct(
					core.argsTokensMedian,
					blitz.argsTokensMedian,
				);
				const wallSavingsPct = savingsPct(
					core.wallMsMedian,
					blitz.wallMsMedian,
				);
				const totalContextSavingsPct = savingsPct(
					core.totalContextTokens,
					blitz.totalContextTokens,
				);
				const costSavingsPct = savingsPct(core.costSum, blitz.costSum);
				const blitzWinsOrTiesContext =
					blitz.totalContextTokens <= core.totalContextTokens;
				pairwise.push({
					...basePair,
					status: "both_correct",
					acceptedRoute: blitzWinsOrTiesContext ? "blitz" : "core",
					routeDecisionReason: blitzWinsOrTiesContext
						? `Blitz total context ${blitz.totalContextTokens} <= core ${core.totalContextTokens}`
						: `core/apply_patch fallback: Blitz total context ${blitz.totalContextTokens} > core ${core.totalContextTokens}`,
					savingsCounted: blitzWinsOrTiesContext,
					outputSavingsPct,
					argsSavingsPct,
					totalContextSavingsPct,
					wallSavingsPct,
					costSavingsPct,
				});
				summaryLines.push(
					`${fx.id}: ${formatSavings("session output", outputSavingsPct)}, ${formatSavings("tool-call args", argsSavingsPct)}, ${formatSavings("total context", totalContextSavingsPct)}, ${formatSavings("wall time", wallSavingsPct)}, ${formatSavings("cost", costSavingsPct)}; route=${blitzWinsOrTiesContext ? "blitz" : "core/apply_patch fallback"}; savings ${blitzWinsOrTiesContext ? "counted" : "not counted"}`,
				);
			} else if (!blitzCorrect) {
				pairwise.push({
					...basePair,
					status: "blitz_failed",
					acceptedRoute: coreCorrect ? "core" : "none",
					routeDecisionReason: "Blitz failed; savings not counted",
				});
				summaryLines.push(
					`${fx.id}: Blitz failed; savings not counted (core output ${core.outputMedian}, blitz output ${blitz.outputMedian}, core args ${core.argsTokensMedian}, blitz args ${blitz.argsTokensMedian})`,
				);
			} else if (!coreCorrect) {
				pairwise.push({
					...basePair,
					status: "core_failed_blitz_correct",
					acceptedRoute: "blitz",
					routeDecisionReason:
						"Blitz correctness win; token savings not counted because core row failed",
				});
				summaryLines.push(
					`${fx.id}: correctness win; savings not counted (core output ${core.outputMedian}, blitz output ${blitz.outputMedian}, core args ${core.argsTokensMedian}, blitz args ${blitz.argsTokensMedian})`,
				);
			} else {
				pairwise.push({
					...basePair,
					status: "incomplete",
					acceptedRoute: "none",
					routeDecisionReason: "Incomplete pair; savings not counted",
				});
				summaryLines.push(`${fx.id}: incomplete; savings not counted`);
			}
		}
	}

	const coreOnlyNotes = selectedFixtures
		.filter((fx) => fx.lanePolicy === "core-only")
		.map(
			(fx) =>
				`${fx.id}: core-only cost/control smoke; no Blitz structured AST savings claim.`,
		);
	if (coreOnlyNotes.length) {
		summaryLines.push("", "## Core-only notes", ...coreOnlyNotes);
	}

	const coverageLines = [
		"",
		"## Profile coverage / skipped rows",
		...profileCoverage.map(
			(coverage) =>
				`${coverage.profile}: supported ${coverage.supportedFixtures.length}/${selectedFixtures.length}; skipped ${coverage.skippedFixtures.length}${coverage.skippedFixtures.length ? ` (${coverage.skippedFixtures.map((row) => `${row.fixture}: ${row.reason}`).join("; ")})` : ""}`,
		),
	];
	const overheadLines = [
		"",
		"## Resident overhead comparison",
		...overheadComparisons.map((row) => {
			const reduction =
				row.reductionVsFullPct === null
					? "unavailable"
					: pct(row.reductionVsFullPct);
			const target =
				row.meetsCommonLaneTarget === null
					? "unknown"
					: row.meetsCommonLaneTarget
						? "meets >=70% combined target"
						: "below >=70% combined target";
			return `${row.profile}: schema ${row.schemaTokens}, skill ${row.skillTokens}, combined ${row.combinedResidentTokens}, reduction vs full ${reduction}; ${target}`;
		}),
	];

	console.log([...coverageLines, ...overheadLines].join("\n"));

	console.log(summaryLines.join("\n"));
	const payload = {
		provider,
		model,
		iters,
		runner,
		runRoot: runner === "tmux" ? runRoot : undefined,
		tmuxSession: runner === "tmux" ? tmuxSession : undefined,
		timeoutMs,
		piBin,
		blitzBinPathPrepend: BLITZ_BIN_DIR,
		extension,
		skill,
		toolProfile,
		accountingArtifacts,
		phase0Accounting: {
			visibleTools: accountingArtifacts.toolSpec?.visibleToolNames ?? [],
			serializedToolSpecsPath:
				accountingArtifacts.toolSpec?.serializedToolSpecsPath ?? null,
			serializedToolSpecsTokens:
				accountingArtifacts.toolSpec?.serializedToolSpecsTokens ?? null,
			residentSkillSnapshotPath: accountingArtifacts.skill.snapshotPath,
			residentSkillTokens: accountingArtifacts.skill.tokens,
			tokenizerMetadataPath: accountingArtifacts.metadataPath,
			tokScaleSessionJsonPaths: runRecords
				.map((record) => record.sessionFile)
				.filter((path): path is string => Boolean(path)),
		},
		profileCoverage,
		overheadComparisons,
		tokScaleMode,
		generatedAt: new Date().toISOString(),
		rows,
		pairwise,
		runs: runRecords,
	};
	if (jsonOut) await writeFile(jsonOut, JSON.stringify(payload, null, 2));
	if (mdOut)
		await writeFile(
			mdOut,
			[
				`# Pi local matrix results`,
				``,
				`Provider: ${provider}`,
				`Model: ${model}`,
				`Iterations: ${iters}`,
				`Runner: ${runner}`,
				...(runner === "tmux"
					? [`Run root: ${runRoot}`, `Tmux session: ${tmuxSession}`]
					: []),
				`Timeout per run: ${timeoutMs}ms`,
				`Pi: ${piBin}`,
				`Blitz binary PATH prepend: ${BLITZ_BIN_DIR}`,
				`Extension: ${extension}`,
				`Skill: ${skill}`,
				`Tool profile: ${toolProfile}`,
				`Accounting artifact root: ${accountingArtifacts.artifactRoot}`,
				`Visible Blitz tools: ${accountingArtifacts.toolSpec?.visibleToolNames.join(",") ?? "unavailable"}`,
				`Serialized tool spec tokens: ${accountingArtifacts.toolSpec?.serializedToolSpecsTokens ?? "unavailable"}`,
				`Resident skill tokens: ${accountingArtifacts.skill.tokens}`,
				`Tokscale validation: ${tokScaleMode}`,
				`Generated: ${payload.generatedAt}`,
				``,
				lines.join("\n"),
				coverageLines.join("\n"),
				overheadLines.join("\n"),
				summaryLines.join("\n"),
			].join("\n"),
		);
	releaseTokenizer();
};

main().catch((e) => {
	console.error(e);
	process.exit(1);
});
