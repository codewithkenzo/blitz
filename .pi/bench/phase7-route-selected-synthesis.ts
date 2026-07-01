#!/usr/bin/env bun
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";

const candidateFiles = [
	".pi/reports/archive/history/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-markdown-core-escapes-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-format-config-router-sk-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-format-config-core-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-config-router-sk2-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-config-core-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-router-semantic-parserfix-20260609.json",
	".pi/reports/archive/history/pi-tmux-phase7-router-semantic-rerun-20260609.json",
	".pi/reports/archive/history/pi-tmux-phase7-router-pilot-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-structural-core-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-structural-current-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-structural-router-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-semantic-core-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-semantic-router-20260609-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-wrapbody-rerun-20260610-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-wrapbody-rerun2-20260610-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-longsection-rerun-20260610-d5.json",
	".pi/reports/archive/history/pi-tmux-phase7-longsection-router-rerun-20260610-d5.json",
];

const outJson =
	".pi/reports/archive/history/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json";
const outMd = ".pi/reports/archive/history/pi-tmux-phase7-route-selected-synthesis-20260609-d5.md";

type Row = {
	fixture: string;
	lane: string;
	totalContextTokens: number;
	correctRate?: number;
	tokScaleTokenMatchesParser?: boolean;
	timedOut?: boolean;
	exitCodes?: number[];
	toolName?: string;
	route?: string;
	routeReasonCode?: string;
	failure?: string;
	sourceFile: string;
};

type RequiredCase = {
	id: string;
	planLabel: string;
	fixtures: string[];
	phase7Required: boolean;
};

const requiredCases: RequiredCase[] = [
	{
		id: "one-line-return-expression",
		planLabel: "one-line return expression",
		fixtures: ["semantic/arrow-replace-return"],
		phase7Required: true,
	},
	{
		id: "tiny-exact-text-replace",
		planLabel: "tiny exact text replace",
		fixtures: ["small/wrap-tail"],
		phase7Required: true,
	},
	{
		id: "small-config-key",
		planLabel: "small config key",
		fixtures: ["config/key-update"],
		phase7Required: true,
	},
	{
		id: "insert-logging-line",
		planLabel: "insert logging line",
		fixtures: ["logging/insert-timer"],
		phase7Required: true,
	},
	{
		id: "wrap-function-body",
		planLabel: "wrap function body",
		fixtures: ["medium-10k/wrap-body"],
		phase7Required: true,
	},
	{
		id: "replace-long-function-body-section",
		planLabel: "replace long function body section",
		fixtures: ["long-section/replace-return"],
		phase7Required: true,
	},
	{
		id: "multi-hunk-same-file-edit",
		planLabel: "multi-hunk same-file edit",
		fixtures: ["multi/large-structural"],
		phase7Required: true,
	},
	{
		id: "rename-within-file",
		planLabel: "rename within file",
		fixtures: ["rename/function-name"],
		phase7Required: true,
	},
	{
		id: "markdown-section-append",
		planLabel: "Markdown section append",
		fixtures: ["markdown/append-section"],
		phase7Required: true,
	},
	{
		id: "tsx-component-prop-body-tweak",
		planLabel: "TSX component prop/body tweak",
		fixtures: ["semantic/tsx-replace-return"],
		phase7Required: true,
	},
	{
		id: "json-yaml-toml-top-level-key-update",
		planLabel: "JSON/YAML/TOML top-level key update",
		fixtures: ["json/config-key", "yaml/config-key", "toml/config-key"],
		phase7Required: true,
	},
	{
		id: "html-css-small-edit",
		planLabel: "HTML/CSS small edit",
		fixtures: ["html/small-edit", "css/small-edit"],
		phase7Required: true,
	},
];

const rows: Row[] = [];
for (const file of candidateFiles) {
	const data = JSON.parse(readFileSync(file, "utf8"));
	for (const row of data.rows ?? []) {
		rows.push({ ...row, sourceFile: file });
	}
}

function accepted(row: Row): boolean {
	return (
		row.correctRate === 1 &&
		row.tokScaleTokenMatchesParser === true &&
		row.timedOut !== true &&
		(!row.exitCodes || row.exitCodes.every((code) => code === 0))
	);
}

function best(rows: Row[]): Row | undefined {
	return rows
		.filter(accepted)
		.sort((a, b) => a.totalContextTokens - b.totalContextTokens)[0];
}

function byFixture(fixture: string): Row[] {
	return rows.filter((row) => row.fixture === fixture);
}

const selections = requiredCases.map((req) => {
	const fixtureSelections = req.fixtures.map((fixture) => {
		const candidates = byFixture(fixture);
		const acceptedCandidates = candidates
			.filter(accepted)
			.sort((a, b) => a.totalContextTokens - b.totalContextTokens);
		const selected = acceptedCandidates[0];
		const coreBaseline = best(candidates.filter((row) => row.lane === "core"));
		const routerBaseline = best(
			candidates.filter((row) => row.lane === "router"),
		);
		const rejectedCandidates = candidates.filter((row) => !accepted(row));
		let status = "missing";
		if (selected) status = "accepted";
		else if (candidates.length > 0) status = "incomplete";
		let gate = "not-proven";
		if (selected && coreBaseline) {
			if (selected.lane === "core") gate = "route-selected-core-cheapest";
			else if (selected.totalContextTokens <= coreBaseline.totalContextTokens)
				gate = "blitz-router-beats-or-ties-core";
			else gate = "router-loses-to-core";
		} else if (selected && selected.lane !== "core" && !coreBaseline) {
			gate = "accepted-router-no-core-baseline";
		} else if (!selected && coreBaseline) {
			gate = "core-only-or-router-missing";
		}
		return {
			fixture,
			status,
			selected: selected ? serializeRow(selected) : null,
			coreBaseline: coreBaseline ? serializeRow(coreBaseline) : null,
			routerBaseline: routerBaseline ? serializeRow(routerBaseline) : null,
			acceptedCandidates: acceptedCandidates.map(serializeRow),
			rejectedCandidates: rejectedCandidates.map(serializeRow),
			gate,
		};
	});
	const complete = fixtureSelections.every(
		(entry) => entry.status === "accepted",
	);
	return {
		...req,
		status: complete
			? "accepted"
			: fixtureSelections.some((entry) => entry.status !== "missing")
				? "incomplete"
				: "missing",
		fixtures: fixtureSelections,
	};
});

function serializeRow(row: Row) {
	return {
		fixture: row.fixture,
		lane: row.lane,
		toolName: row.toolName || "",
		route: row.route || "",
		routeReasonCode: row.routeReasonCode || "",
		totalContextTokens: row.totalContextTokens,
		correctRate: row.correctRate,
		tokScaleTokenMatchesParser: row.tokScaleTokenMatchesParser,
		exitCodes: row.exitCodes,
		timedOut: row.timedOut,
		sourceFile: row.sourceFile,
	};
}

const gaps = [
	"Benchmark-level route selection only: selected core rows are proof choices from existing evidence, not product-real pi_blitz_route_edit core/apply_patch interception.",
	"No direct apply_patch baseline exists in current harness evidence; current harness lanes are core/edit, blitz, and router facade only.",
	"Structural preservation improved: medium-10k/wrap-body and multi/large-structural now have accepted current Blitz evidence, but neither has an accepted core/apply_patch baseline for beat/tie proof.",
	"TSX semantic row has accepted core and router rows, but selected benchmark route chooses core; this does not prove product-real core fallback.",
	"Semantic arrow row has accepted router and core rows and router is cheaper in selected evidence; current proof is still benchmark evidence, not product runtime replacement.",
	"Long-section now has accepted core and router rows after fixture escaping fix; selected benchmark route chooses core.",
	"Markdown append has accepted router evidence but accepted core baseline is absent; core attempts failed.",
	"HTML router row is accepted but extreme 142,615-token outlier; selected path chooses accepted core row for benchmark proof only.",
];

const artifact = {
	generatedAt: "2026-06-09",
	status:
		"benchmark-only route-selected synthesis; not Phase 7 completion; not product-real core interception",
	sourceFiles: candidateFiles,
	method: {
		acceptedRule:
			"correctRate === 1, Tokscale token match true, not timed out, exit codes all 0 when present",
		selectionRule:
			"per fixture, choose lowest totalContextTokens among accepted real tmux/Tokscale rows from sourceFiles",
		baselineRule:
			"baseline core total is lowest accepted core row for same fixture when present",
	},
	selections,
	gaps,
};

mkdirSync("reports", { recursive: true });
writeFileSync(outJson, `${JSON.stringify(artifact, null, 2)}\n`);

const lines: string[] = [];
lines.push("# Phase 7 route-selected synthesis — benchmark-only proof");
lines.push("");
lines.push(`Date: ${artifact.generatedAt}`);
lines.push(
	"Status: benchmark-only route-selected synthesis; not Phase 7 completion; not product-real core/apply_patch interception.",
);
lines.push("");
lines.push("## Method");
lines.push("");
lines.push(
	`- Source rows: ${candidateFiles.map((file) => `\`${file}\``).join(", ")}.`,
);
lines.push(
	"- Accepted row: correctness 100%, Tokscale token match yes, no timeout, exit code 0 when present.",
);
lines.push(
	"- Selected route: lowest `totalContextTokens` among accepted real rows per fixture.",
);
lines.push(
	"- Core baseline: lowest accepted `core` row for same fixture where present.",
);
lines.push(
	"- Core selections below are benchmark-level choices from existing core rows. They do not mean `pi_blitz_route_edit` invokes core/apply_patch at runtime.",
);
lines.push("");
lines.push("## Selected-route table");
lines.push("");
lines.push(
	"| Phase 7 case | Fixture | Status | Selected lane/tool | Selected total context | Core baseline total | Gate result | Evidence |",
);
lines.push("|---|---|---:|---|---:|---:|---|---|");
for (const selection of selections) {
	for (const entry of selection.fixtures) {
		const selected = entry.selected;
		const core = entry.coreBaseline;
		lines.push(
			`| ${selection.planLabel} | ${entry.fixture} | ${entry.status} | ${selected ? `${selected.lane}/${selected.toolName || "unknown"}` : "—"} | ${selected ? selected.totalContextTokens : "—"} | ${core ? core.totalContextTokens : "—"} | ${entry.gate} | ${selected ? basename(selected.sourceFile) : entry.rejectedCandidates.length ? `${entry.rejectedCandidates.length} rejected row(s)` : "missing"} |`,
		);
	}
}
lines.push("");
lines.push("## START gate proof/disproof");
lines.push("");
lines.push(
	"For rows with accepted core and router/core candidates, selected benchmark route chooses the lower-token accepted row. Current evidence supports benchmark-level route-to-core proof for tiny text, config, rename, JSON/YAML/TOML, CSS, HTML. It does not prove product runtime core interception.",
);
lines.push(
	"Rows without accepted paired core/router evidence remain unproven. Rows where router is accepted but core absent cannot prove beat/tie against core.",
);
lines.push("");
lines.push("## Remaining gaps");
lines.push("");
for (const gap of gaps) lines.push(`- ${gap}`);
lines.push("");
lines.push("## Candidate row caveats");
lines.push("");
lines.push(
	"Failed/incomplete rows remain preserved in source reports and raw tmux run roots. This synthesis does not fabricate, delete, or overwrite raw evidence.",
);
writeFileSync(outMd, `${lines.join("\n")}\n`);
console.log(`wrote ${outJson}`);
console.log(`wrote ${outMd}`);
