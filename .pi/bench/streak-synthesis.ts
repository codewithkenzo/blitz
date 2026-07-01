#!/usr/bin/env bun
/**
 * Build cumulative edit-streak evidence from accepted real Pi/tmux/Tokscale rows.
 *
 * This is intentionally additive: it does not pretend existing independent rows are
 * one continuous Pi session. It aggregates accepted row accounting to answer the
 * default-cheaper question across realistic edit streaks while preserving source
 * report/run-root provenance for every row.
 */

import { readFile, writeFile, mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";

const REPO_ROOT = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const DEFAULT_SYNTHESIS = join(
	REPO_ROOT,
	".pi/reports/archive/history/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json",
);
const DEFAULT_JSON_OUT = join(
	REPO_ROOT,
	".pi/reports/archive/history/pi-tmux-streak-synthesis-20260610-d5.json",
);
const DEFAULT_MD_OUT = join(
	REPO_ROOT,
	".pi/reports/archive/history/pi-tmux-streak-synthesis-20260610-d5.md",
);

type TokenRow = {
	fixture: string;
	lane: string;
	toolName: string;
	route?: string;
	routeReasonCode?: string;
	toolProfile?: string;
	visibleToolNames?: string[];
	toolSpecTokens?: number;
	schemaTokens?: number;
	skillTokens?: number;
	promptTokens?: number;
	argTokens?: number;
	outputTokens?: number;
	cacheRead?: number;
	cacheWrite?: number;
	resultPayloadTokens?: number;
	residualInputTokens?: number;
	totalContextTokens: number;
	correctRate: number;
	tokScaleTokenMatchesParser: boolean;
	exitCodes?: number[];
	timedOut: boolean;
	sourceFile?: string;
	runRoot?: string;
	failure?: string;
};

type FixtureChoice = {
	fixture: string;
	status: string;
	selected?: Pick<
		TokenRow,
		| "fixture"
		| "lane"
		| "toolName"
		| "totalContextTokens"
		| "correctRate"
		| "tokScaleTokenMatchesParser"
		| "exitCodes"
		| "timedOut"
		| "sourceFile"
	>;
	coreBaseline?: Pick<
		TokenRow,
		| "fixture"
		| "lane"
		| "toolName"
		| "totalContextTokens"
		| "correctRate"
		| "tokScaleTokenMatchesParser"
		| "exitCodes"
		| "timedOut"
		| "sourceFile"
	>;
};

type SourceReport = {
	provider?: string;
	model?: string;
	runner?: string;
	runRoot?: string;
	tmuxSession?: string;
	tokScaleMode?: string;
	rows?: TokenRow[];
};

type Synthesis = {
	generatedAt: string;
	status: string;
	sourceFiles: string[];
	selections: Array<{
		id: string;
		planLabel: string;
		fixtures: FixtureChoice[];
	}>;
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

const sourcePath = argFlag("--source", DEFAULT_SYNTHESIS);
const jsonOut = argFlag("--json-out", DEFAULT_JSON_OUT);
const mdOut = argFlag("--md-out", DEFAULT_MD_OUT);

const num = (value: unknown): number =>
	typeof value === "number" && Number.isFinite(value) ? value : 0;

const tokenKeys = [
	"schemaTokens",
	"skillTokens",
	"promptTokens",
	"argTokens",
	"outputTokens",
	"cacheRead",
	"cacheWrite",
	"resultPayloadTokens",
	"residualInputTokens",
	"totalContextTokens",
] as const;

type Totals = Record<(typeof tokenKeys)[number], number>;

const emptyTotals = (): Totals => ({
	schemaTokens: 0,
	skillTokens: 0,
	promptTokens: 0,
	argTokens: 0,
	outputTokens: 0,
	cacheRead: 0,
	cacheWrite: 0,
	resultPayloadTokens: 0,
	residualInputTokens: 0,
	totalContextTokens: 0,
});

const addRow = (totals: Totals, row: TokenRow) => {
	for (const key of tokenKeys) totals[key] += num(row[key]);
};

const rowKey = (fixture: string, lane: string) => `${fixture}\u0000${lane}`;

const readJson = async <T>(path: string): Promise<T> =>
	JSON.parse(await readFile(path, "utf8")) as T;

const source = await readJson<Synthesis>(sourcePath);
const fullRows = new Map<string, TokenRow>();
const sourceReports: Array<
	Pick<
		SourceReport,
		"provider" | "model" | "runner" | "runRoot" | "tmuxSession" | "tokScaleMode"
	> & { sourceFile: string }
> = [];

for (const sourceFile of source.sourceFiles) {
	const report = await readJson<SourceReport>(join(REPO_ROOT, sourceFile));
	sourceReports.push({
		sourceFile,
		provider: report.provider,
		model: report.model,
		runner: report.runner,
		runRoot: report.runRoot,
		tmuxSession: report.tmuxSession,
		tokScaleMode: report.tokScaleMode,
	});
	for (const row of report.rows ?? []) {
		if (
			row.correctRate !== 1 ||
			!row.tokScaleTokenMatchesParser ||
			row.timedOut
		)
			continue;
		if ((row.exitCodes ?? []).some((code) => code !== 0)) continue;
		const key = rowKey(row.fixture, row.lane);
		const existing = fullRows.get(key);
		if (!existing || row.totalContextTokens < existing.totalContextTokens) {
			fullRows.set(key, { ...row, sourceFile, runRoot: report.runRoot });
		}
	}
}

const selectedByFixture = new Map<string, TokenRow>();
const coreByFixture = new Map<string, TokenRow>();
for (const selection of source.selections) {
	for (const choice of selection.fixtures) {
		if (choice.selected) {
			const full = fullRows.get(rowKey(choice.fixture, choice.selected.lane));
			if (full) selectedByFixture.set(choice.fixture, full);
		}
		const core = fullRows.get(rowKey(choice.fixture, "core"));
		if (core) coreByFixture.set(choice.fixture, core);
	}
}

const fixture = (
	id: string,
	lane: "selected" | "core" = "selected",
): TokenRow => {
	const row =
		lane === "core" ? coreByFixture.get(id) : selectedByFixture.get(id);
	if (!row) throw new Error(`missing ${lane} row for ${id}`);
	return row;
};

const tiny10 = [
	"small/wrap-tail",
	"config/key-update",
	"logging/insert-timer",
	"rename/function-name",
	"semantic/tsx-replace-return",
	"json/config-key",
	"yaml/config-key",
	"toml/config-key",
	"html/small-edit",
	"css/small-edit",
];

const mixed20 = [
	"small/wrap-tail",
	"config/key-update",
	"logging/insert-timer",
	"rename/function-name",
	"semantic/tsx-replace-return",
	"json/config-key",
	"yaml/config-key",
	"toml/config-key",
	"html/small-edit",
	"css/small-edit",
	"semantic/arrow-replace-return",
	"long-section/replace-return",
	"markdown/append-section",
	"medium-10k/wrap-body",
	"multi/large-structural",
	"small/wrap-tail",
	"config/key-update",
	"semantic/arrow-replace-return",
	"json/config-key",
	"css/small-edit",
];

const sameFileMulti = ["multi/large-structural"];
const representativeSingles = [
	"semantic/arrow-replace-return",
	"config/key-update",
	"long-section/replace-return",
	"medium-10k/wrap-body",
	"multi/large-structural",
];

const buildScenario = (id: string, label: string, fixtureIds: string[]) => {
	const selectedTotals = emptyTotals();
	const coreTotals = emptyTotals();
	const rows = fixtureIds.map((fixtureId, index) => {
		const selected = fixture(fixtureId);
		addRow(selectedTotals, selected);
		const core = coreByFixture.get(fixtureId);
		if (core) addRow(coreTotals, core);
		return {
			index: index + 1,
			fixture: fixtureId,
			selected: summarizeRow(selected),
			coreBaseline: core ? summarizeRow(core) : null,
			decision: core
				? selected.totalContextTokens <= core.totalContextTokens
					? "selected-beats-or-ties-core"
					: "core-cheaper"
				: "no-accepted-core-baseline",
			deltaVsCore: core
				? core.totalContextTokens - selected.totalContextTokens
				: null,
		};
	});
	const comparedCount = rows.filter((row) => row.coreBaseline).length;
	const totalDeltaVsCore =
		coreTotals.totalContextTokens - selectedTotals.totalContextTokens;
	return {
		id,
		label,
		method:
			"cumulative synthesis from accepted independent Pi/tmux/Tokscale rows; not a true sequential same-session run",
		editCount: fixtureIds.length,
		comparedCount,
		selectedTotals,
		coreTotals: comparedCount > 0 ? coreTotals : null,
		totalContextDeltaVsCore: comparedCount > 0 ? totalDeltaVsCore : null,
		totalContextSavingsPctVsCore:
			comparedCount > 0 && coreTotals.totalContextTokens > 0
				? (totalDeltaVsCore / coreTotals.totalContextTokens) * 100
				: null,
		allRowsCorrect: rows.every(
			(row) =>
				row.selected.correctRate === 1 &&
				row.selected.tokScaleTokenMatchesParser,
		),
		rows,
	};
};

function summarizeRow(row: TokenRow) {
	return {
		fixture: row.fixture,
		lane: row.lane,
		toolName: row.toolName,
		route: row.route,
		routeReasonCode: row.routeReasonCode,
		toolProfile: row.toolProfile,
		visibleToolNames: row.visibleToolNames,
		schemaTokens: num(row.schemaTokens),
		skillTokens: num(row.skillTokens),
		promptTokens: num(row.promptTokens),
		argTokens: num(row.argTokens),
		outputTokens: num(row.outputTokens),
		cacheRead: num(row.cacheRead),
		cacheWrite: num(row.cacheWrite),
		resultPayloadTokens: num(row.resultPayloadTokens),
		residualInputTokens: num(row.residualInputTokens),
		totalContextTokens: row.totalContextTokens,
		correctRate: row.correctRate,
		tokScaleTokenMatchesParser: row.tokScaleTokenMatchesParser,
		exitCodes: row.exitCodes ?? [],
		timedOut: row.timedOut,
		sourceFile: row.sourceFile,
		runRoot: row.runRoot,
	};
}

const scenarios = [
	buildScenario("tiny-10", "10 tiny/core-likely edits", tiny10),
	buildScenario(
		"mixed-20",
		"20 mixed language/config/markdown/code edits",
		mixed20,
	),
	buildScenario(
		"same-file-multi",
		"same-file multi-edit scenario",
		sameFileMulti,
	),
];

const singles = representativeSingles.map((id) =>
	buildScenario(`single-${id.replace(/[^a-z0-9]+/gi, "-")}`, `single ${id}`, [
		id,
	]),
);

const output = {
	generatedAt: new Date().toISOString(),
	status:
		"exploratory cumulative streak synthesis; not default-ready proof; Pi core edit baseline only; apply_patch out of scope",
	baseline: "Pi core edit",
	applyPatch:
		"out of scope by current goal; no Codex/OpenAI apply_patch gate required",
	method: {
		source: sourcePath.replace(`${REPO_ROOT}/`, ""),
		acceptedRule:
			"correctRate === 1, Tokscale token match true, not timed out, exit codes all 0",
		streakSupport:
			"Existing harness runs one edit per isolated Pi/tmux command. This report aggregates accepted real rows as smallest honest approximation; true same-session sequential streak runner remains next slice.",
		artifactPreservation:
			"Source reports and .pi/reports/pi-tmux-runs/* raw run roots remain referenced; this script does not delete or overwrite them.",
	},
	sourceReports,
	scenarios,
	representativeSingles: singles,
	verdict: {
		defaultReady: false,
		reason:
			"Cumulative tiny streak mostly selects Pi core because core remains cheaper on many tiny/config/text edits. Router/Blitz wins representative semantic arrow row, but structural rows still lack accepted core baselines and same-session streak runner is not implemented.",
	},
};

const pct = (value: number | null) =>
	value === null ? "—" : `${value.toFixed(1)}%`;
const delta = (value: number | null) => (value === null ? "—" : `${value}`);
const mdLines: string[] = [];
mdLines.push("# Pi/tmux/Tokscale cumulative edit-streak synthesis");
mdLines.push("");
mdLines.push(`Date: ${output.generatedAt.slice(0, 10)}`);
mdLines.push("Status: exploratory; not default-ready proof");
mdLines.push(
	"Baseline/fallback: Pi core `edit` only. Codex/OpenAI `apply_patch` is out of scope.",
);
mdLines.push("");
mdLines.push("## Method");
mdLines.push("");
mdLines.push(`- Source synthesis: \`${output.method.source}\`.`);
mdLines.push(
	"- Rows are accepted only when correctness is 100%, Tokscale token match is yes, no timeout, and exit codes are 0.",
);
mdLines.push(
	"- This is cumulative synthesis from independent real Pi/tmux/Tokscale rows, not true same-session sequential execution.",
);
mdLines.push(
	"- Raw artifacts remain in source report run roots under `.pi/reports/pi-tmux-runs/`.",
);
mdLines.push("");
mdLines.push("## Cumulative scenarios");
mdLines.push("");
mdLines.push(
	"| Scenario | Edits | Rows with core baseline | Selected total context | Core total context | Delta vs core | Savings vs core | Correct | Verdict |",
);
mdLines.push("|---|---:|---:|---:|---:|---:|---:|---|---|");
for (const scenario of scenarios) {
	mdLines.push(
		`| ${scenario.label} | ${scenario.editCount} | ${scenario.comparedCount} | ${scenario.selectedTotals.totalContextTokens} | ${scenario.coreTotals?.totalContextTokens ?? "—"} | ${delta(scenario.totalContextDeltaVsCore)} | ${pct(scenario.totalContextSavingsPctVsCore)} | ${scenario.allRowsCorrect ? "yes" : "no"} | ${scenario.totalContextDeltaVsCore !== null && scenario.totalContextDeltaVsCore >= 0 ? "selected <= core" : "not proven"} |`,
	);
}
mdLines.push("");
mdLines.push("### Token breakdown by scenario");
mdLines.push("");
mdLines.push(
	"| Scenario | schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |",
);
mdLines.push("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|");
for (const scenario of scenarios) {
	const t = scenario.selectedTotals;
	mdLines.push(
		`| ${scenario.label} | ${t.schemaTokens} | ${t.skillTokens} | ${t.promptTokens} | ${t.argTokens} | ${t.outputTokens} | ${t.cacheRead} | ${t.cacheWrite} | ${t.resultPayloadTokens} | ${t.residualInputTokens} | ${t.totalContextTokens} |`,
	);
}
mdLines.push("");
mdLines.push("## Representative single edits");
mdLines.push("");
mdLines.push(
	"| Fixture | Selected lane/tool | Selected context | Core context | Delta vs core | Correct | Source |",
);
mdLines.push("|---|---|---:|---:|---:|---|---|");
for (const single of singles) {
	const row = single.rows[0]!;
	mdLines.push(
		`| ${row.fixture} | ${row.selected.lane}/${row.selected.toolName} | ${row.selected.totalContextTokens} | ${row.coreBaseline?.totalContextTokens ?? "—"} | ${delta(row.deltaVsCore)} | ${row.selected.correctRate === 1 && row.selected.tokScaleTokenMatchesParser ? "yes" : "no"} | ${row.selected.sourceFile} |`,
	);
}
mdLines.push("");
mdLines.push("## Verdict");
mdLines.push("");
mdLines.push(
	"Not default-ready. Tiny/config/text cumulative route mostly proves Pi core remains default-cheaper. Blitz/router has targeted wins, especially semantic arrow replace, and structural capability remains useful, but default-cheaper streak proof needs true sequential same-session harness plus more accepted paired baselines.",
);

await mkdir(dirname(jsonOut), { recursive: true });
await mkdir(dirname(mdOut), { recursive: true });
await writeFile(jsonOut, `${JSON.stringify(output, null, 2)}\n`);
await writeFile(mdOut, `${mdLines.join("\n")}\n`);
console.log(`wrote ${jsonOut}`);
console.log(`wrote ${mdOut}`);
