#!/usr/bin/env bun
import { mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { Buffer } from "node:buffer";
import { resolve } from "node:path";

declare const Bun: {
	spawn(
		command: string[],
		options: {
			cwd?: string;
			stdin: "pipe";
			stdout: "pipe";
			stderr: "pipe";
		},
	): {
		stdin: { write(input: string): void; end(): void };
		stdout: ReadableStream;
		stderr: ReadableStream;
		exited: Promise<number>;
	};
};

const root = process.cwd();
const bin = resolve(root, "zig-out/bin/blitz");
const work = resolve(root, ".pi/tmp-daemon-smoke");
mkdirSync(work, { recursive: true });

const canonicalRoot = resolve(root);
const largeFile = resolve(work, "large.ts");
const invalidUtf8File = resolve(work, "invalid-utf8.ts");
const outsideFile = "/tmp/blitz-daemon-outside-smoke.ts";
const relativeRoot = realpathSync(mkdtempSync("/tmp/blitz-daemon-rel-"));
const relativeFile = resolve(relativeRoot, "rel.ts");
const lines = Array.from({ length: 101 }, (_, i) => `let x${i} = ${i};`).join(
	"\n",
);
writeFileSync(largeFile, `${lines}\nfunction smokeDaemon() {}\n`);
writeFileSync(
	invalidUtf8File,
	Buffer.from([
		0x63, 0x6f, 0x6e, 0x73, 0x74, 0x20, 0x78, 0x20, 0x3d, 0x20, 0x22, 0xff,
		0x22, 0x3b, 0x0a,
	]),
);
writeFileSync(outsideFile, "export const outside = true;\n");
writeFileSync(relativeFile, "function relativeProbe() {}\n");

type DaemonResponse = {
	id: string | null;
	ok: boolean;
	result?: Record<string, unknown>;
	error?: { code?: string; fallbackAllowed?: boolean };
};

async function runDaemon(args: string[], input: string, cwd = root) {
	const proc = Bun.spawn([bin, ...args], {
		cwd,
		stdin: "pipe",
		stdout: "pipe",
		stderr: "pipe",
	});

	proc.stdin.write(input);
	proc.stdin.end();

	const [stdoutBytes, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).arrayBuffer(),
		new Response(proc.stderr).text(),
		proc.exited,
	]);

	if (exitCode !== 0) throw new Error(`daemon exited ${exitCode}: ${stderr}`);
	if (stderr.trim().length > 0) throw new Error(`unexpected stderr: ${stderr}`);
	const stdout = new TextDecoder("utf-8", { fatal: true }).decode(stdoutBytes);
	return stdout
		.trim()
		.split("\n")
		.filter(Boolean)
		.map((line) => JSON.parse(line) as DaemonResponse);
}

function byId(responses: DaemonResponse[]) {
	return new Map(responses.map((res) => [res.id, res]));
}

const dotRootResponses = await runDaemon(
	["--workspace-root", ".", "daemon"],
	JSON.stringify({
		id: "dot-read-1",
		method: "read",
		workspaceRoot: canonicalRoot,
		params: { file: largeFile },
	}) + "\n",
	root,
);
if (dotRootResponses.length !== 1 || dotRootResponses[0]?.ok !== true) {
	throw new Error(
		`--workspace-root . read failed: ${JSON.stringify(dotRootResponses)}`,
	);
}
if (dotRootResponses[0]?.result?.workspaceRoot !== canonicalRoot) {
	throw new Error(
		`--workspace-root . did not report canonical cwd: ${JSON.stringify(dotRootResponses[0])}`,
	);
}

const relativeResponses = await runDaemon(
	["--workspace-root", relativeRoot, "daemon"],
	JSON.stringify({
		id: "relative-read-1",
		method: "read",
		workspaceRoot: relativeRoot,
		params: { file: "rel.ts" },
	}) + "\n",
	root,
);
if (relativeResponses.length !== 1 || relativeResponses[0]?.ok !== true) {
	throw new Error(
		`root-relative read from repo cwd failed: ${JSON.stringify(relativeResponses)}`,
	);
}
if (!String(relativeResponses[0]?.result?.output).includes("relativeProbe")) {
	throw new Error("root-relative read output missing file content");
}
if (!String(relativeResponses[0]?.result?.realPath).startsWith(`${relativeRoot}/`)) {
	throw new Error(
		`root-relative realPath escaped temp root: ${JSON.stringify(relativeResponses[0])}`,
	);
}

const oversizeResponses = await runDaemon(
	["--workspace-root", ".", "daemon"],
	`${"x".repeat(1024 * 1024 + 1)}\n`,
	root,
);
if (oversizeResponses.length !== 1) {
	throw new Error(
		`expected one oversized response, got ${oversizeResponses.length}`,
	);
}
if (oversizeResponses[0]?.error?.code !== "StreamTooLong") {
	throw new Error(
		`oversized frame was not reported as StreamTooLong: ${JSON.stringify(oversizeResponses[0])}`,
	);
}

const explicitRequests = [
	{
		id: "doctor-1",
		method: "doctor",
		workspaceRoot: canonicalRoot,
		params: { includeCache: true },
	},
	{
		id: "read-1",
		method: "read",
		workspaceRoot: canonicalRoot,
		params: { file: largeFile },
	},
	{
		id: "invalid-utf8-1",
		method: "read",
		workspaceRoot: canonicalRoot,
		params: { file: invalidUtf8File },
	},
	{
		id: "apply-1",
		method: "apply",
		workspaceRoot: canonicalRoot,
		params: { request: {} },
	},
	{ id: "wat-1", method: "wat", workspaceRoot: canonicalRoot, params: {} },
	{
		id: "mismatch-1",
		method: "read",
		workspaceRoot: `${root}-mismatch`,
		params: { file: largeFile },
	},
];

const explicitResponses = await runDaemon(
	["--workspace-root", root, "daemon"],
	explicitRequests.map((req) => JSON.stringify(req)).join("\n") + "\n",
);
if (explicitResponses.length !== explicitRequests.length) {
	throw new Error(
		`expected ${explicitRequests.length} explicit responses, got ${explicitResponses.length}`,
	);
}

const explicitById = byId(explicitResponses);
if (explicitById.get("doctor-1")?.ok !== true)
	throw new Error("doctor request failed");
const read = explicitById.get("read-1");
if (read?.ok !== true) throw new Error("read request failed");
if (!String(read.result?.output).includes("function_declaration  smokeDaemon"))
	throw new Error("read output missing structure summary");
const invalidUtf8Read = explicitById.get("invalid-utf8-1");
if (invalidUtf8Read?.ok !== true) throw new Error("invalid UTF-8 read failed");
if (!String(invalidUtf8Read.result?.output).includes('const x = "ÿ";'))
	throw new Error("invalid UTF-8 read output missing escaped byte content");
if (explicitById.get("apply-1")?.error?.code !== "MutatingMethodRejected")
	throw new Error("apply was not rejected as mutating");
if (explicitById.get("apply-1")?.error?.fallbackAllowed !== false)
	throw new Error("mutating fallbackAllowed must be false");
if (explicitById.get("wat-1")?.error?.code !== "UnsupportedMethod")
	throw new Error("unknown method was not rejected");
if (explicitById.get("mismatch-1")?.error?.code !== "WorkspaceRootMismatch")
	throw new Error("workspaceRoot mismatch was not rejected");

const cwdResponses = await runDaemon(
	["daemon"],
	JSON.stringify({
		id: "outside-1",
		method: "read",
		params: { file: outsideFile },
	}) + "\n",
	root,
);
if (cwdResponses.length !== 1)
	throw new Error("expected one cwd-default response");
if (cwdResponses[0]?.error?.code !== "PathEscapesWorkspace") {
	throw new Error(
		`cwd-default outside read was not rejected: ${JSON.stringify(cwdResponses[0])}`,
	);
}

const malformedResponses = await runDaemon(
	["--workspace-root", root, "daemon"],
	`{not json}\n${JSON.stringify({ id: "doctor-after-bad-json", method: "doctor", workspaceRoot: canonicalRoot })}\n`,
);
if (malformedResponses.length !== 2)
	throw new Error(
		`expected malformed+doctor responses, got ${malformedResponses.length}`,
	);
if (malformedResponses[0]?.error?.code !== "InvalidJson")
	throw new Error("malformed JSON was not reported as InvalidJson");
if (byId(malformedResponses).get("doctor-after-bad-json")?.ok !== true)
	throw new Error("daemon did not continue after malformed JSON");

rmSync(work, { recursive: true, force: true });
rmSync(outsideFile, { force: true });
rmSync(relativeRoot, { recursive: true, force: true });
console.log("daemon smoke passed");
