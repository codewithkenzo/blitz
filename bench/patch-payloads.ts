#!/usr/bin/env bun
import { countTokens, releaseTokenizer } from "./llm-tokenizer.ts";

type Row = { name: string; payload: unknown };

const multiBodyTiny = {
	file: "bench/fixtures-llm/multi.ts",
	edits: [
		{ symbol: "adjust", op: "replace_body_span", find: "return base;", replace: "return base + 1;", occurrence: "only" },
		{ symbol: "emit", op: "insert_body_span", anchor: "const marker = value;", position: "after", text: "\n  const markerUpper = value.toUpperCase();\n", occurrence: "only" },
		{ symbol: "risky", op: "wrap_body", before: "\n  try {", keep: "body", after: "  } catch (error) {\n    throw error;\n  }\n", indentKeptBodyBy: 2 },
	],
};

const patchTiny = {
	file: "bench/fixtures-llm/multi.ts",
	ops: [
		["replace", "adjust", "return base;", "return base + 1;", "only"],
		["insert_after", "emit", "const marker = value;", "\n  const markerUpper = value.toUpperCase();\n", "only"],
		["try_catch", "risky", "throw error;"],
	],
};

const multiBodyLarge = {
	file: "bench/fixtures-llm/multi-large.ts",
	edits: [
		{ symbol: "mediumCompute", op: "wrap_body", before: "\n  try {", keep: "body", after: "  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n", indentKeptBodyBy: 2 },
		{ symbol: "auditEvent", op: "insert_body_span", anchor: "const normalized = event.trim();", position: "after", text: "\n  const tagged = `[audit] ${normalized}`;", occurrence: "only" },
		{ symbol: "formatStatus", op: "replace_body_span", find: "return status;", replace: "return status.toUpperCase();", occurrence: "only" },
	],
};

const patchLarge = {
	file: "bench/fixtures-llm/multi-large.ts",
	ops: [
		["try_catch", "mediumCompute", "console.error(error);\nthrow error;"],
		["insert_after", "auditEvent", "const normalized = event.trim();", "\n  const tagged = `[audit] ${normalized}`;", "only"],
		["replace_return", "formatStatus", "status.toUpperCase()", "only"],
	],
};

const rows: Row[] = [
	{ name: "multi_body tiny", payload: multiBodyTiny },
	{ name: "patch tiny", payload: patchTiny },
	{ name: "multi_body large", payload: multiBodyLarge },
	{ name: "patch large", payload: patchLarge },
];

console.log("| Payload | bytes | cl100k tokens |");
console.log("|---|---:|---:|");
for (const row of rows) {
	const json = JSON.stringify(row.payload);
	console.log(`| ${row.name} | ${Buffer.byteLength(json)} | ${countTokens(json)} |`);
}

const tinyMulti = countTokens(JSON.stringify(multiBodyTiny));
const tinyPatch = countTokens(JSON.stringify(patchTiny));
const largeMulti = countTokens(JSON.stringify(multiBodyLarge));
const largePatch = countTokens(JSON.stringify(patchLarge));
console.log("");
console.log(`tiny patch vs multi_body: ${(100 * (1 - tinyPatch / tinyMulti)).toFixed(1)}% arg-token reduction`);
console.log(`large patch vs multi_body: ${(100 * (1 - largePatch / largeMulti)).toFixed(1)}% arg-token reduction`);
releaseTokenizer();
