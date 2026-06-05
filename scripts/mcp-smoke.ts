#!/usr/bin/env bun
import { mkdtemp, readFile, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { spawn } from "node:child_process";

const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const server = join(root, "mcp/blitz-mcp.js");
const blitz = resolve(process.env.BLITZ_BIN ?? join(root, "zig-out/bin/blitz"));
const tmp = await mkdtemp(join(tmpdir(), "blitz-mcp-smoke-"));
const file = join(tmp, "a.ts");
await writeFile(
	file,
	`function handle(value: number): number {\n  const doubled = value * 2;\n  return doubled;\n}\n`,
);
await symlink("/etc", join(tmp, "leak"));

type Frame = {
	id?: number | null;
	result?: unknown;
	error?: { message?: string };
};

const readFrames = (stdout: Buffer): Frame[] => {
	const frames: Frame[] = [];
	let rest = stdout.toString("utf8");
	while (rest.length > 0) {
		const headerEnd = rest.indexOf("\r\n\r\n");
		if (headerEnd < 0) break;
		const header = rest.slice(0, headerEnd);
		const match = /Content-Length:\s*(\d+)/i.exec(header);
		if (!match) throw new Error(`missing Content-Length in ${header}`);
		const len = Number(match[1]);
		const start = headerEnd + 4;
		const body = rest.slice(start, start + len);
		frames.push(JSON.parse(body));
		rest = rest.slice(start + len);
	}
	return frames;
};

const spawnServer = (env: Record<string, string> = {}) => {
	const child = spawn("node", [server], {
		env: { ...process.env, BLITZ_BIN: blitz, BLITZ_WORKSPACE: tmp, ...env },
		stdio: ["pipe", "pipe", "pipe"],
	});
	let stdout = Buffer.alloc(0);
	let stderr = "";
	child.stdout.on("data", (chunk) => {
		stdout = Buffer.concat([stdout, chunk]);
	});
	child.stderr.on("data", (chunk) => {
		stderr += String(chunk);
	});
	return { child, stdout: () => stdout, stderr: () => stderr };
};

const host = spawnServer();

const send = (id: number, method: string, params: unknown) => {
	const body = JSON.stringify({ jsonrpc: "2.0", id, method, params });
	host.child.stdin.write(
		`Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`,
	);
};

send(1, "initialize", {
	protocolVersion: "2025-06-18",
	capabilities: {},
	clientInfo: { name: "smoke", version: "0" },
});
send(2, "tools/list", {});
send(3, "tools/call", {
	name: "blitz_try_catch",
	arguments: {
		file: "a.ts",
		symbol: "handle",
		catchBody: "console.error(error);\nthrow error;",
	},
});
send(4, "tools/call", {
	name: "blitz_read",
	arguments: { file: "/etc/passwd" },
});
send(5, "tools/call", {
	name: "blitz_read",
	arguments: { file: "leak/passwd" },
});

await new Promise((resolve) => setTimeout(resolve, 750));
host.child.kill();

const frames = readFrames(host.stdout());
const stderr = host.stderr();

const finalFile = await readFile(file, "utf8");
const hasTry =
	finalFile.includes("try {") &&
	finalFile.includes("console.error(error);") &&
	finalFile.includes("throw error;");
const listOk = frames.some(
	(f) => f.id === 2 && JSON.stringify(f.result).includes("blitz_try_catch"),
);
const mutateOk =
	frames.some(
		(f) =>
			f.id === 3 &&
			JSON.stringify(f.result).includes("status") &&
			JSON.stringify(f.result).includes("applied"),
	) && hasTry;
const escapeRejected = frames.some(
	(f) => f.id === 4 && f.error?.message?.includes("path escapes workspace"),
);
const symlinkRejected = frames.some(
	(f) => f.id === 5 && f.error?.message?.includes("path escapes workspace"),
);

if (
	!listOk ||
	!mutateOk ||
	!escapeRejected ||
	!symlinkRejected ||
	stderr.length > 0
) {
	console.error(
		JSON.stringify(
			{
				listOk,
				mutateOk,
				escapeRejected,
				symlinkRejected,
				stderr,
				frames,
				finalFile,
			},
			null,
			2,
		),
	);
	process.exit(1);
}

const fake = JSON.stringify({
	jsonrpc: "2.0",
	id: 6,
	method: "tools/list",
	params: {},
});
const hostileCase = async (
	raw: string,
	expectedMessage: string,
	env: Record<string, string> = {},
) => {
	const hostileHost = spawnServer(env);
	hostileHost.child.stdin.write(raw);
	await new Promise((resolve) => setTimeout(resolve, 250));
	hostileHost.child.kill();
	const hostileFrames = readFrames(hostileHost.stdout());
	const rejected = hostileFrames.some(
		(f) => f.id === null && f.error?.message === expectedMessage,
	);
	const fakeNotProcessed = !hostileFrames.some((f) => f.id === 6);
	const clean = hostileHost.stderr().length === 0;
	if (!rejected || !fakeNotProcessed || !clean) {
		console.error(
			JSON.stringify(
				{
					expectedMessage,
					rejected,
					fakeNotProcessed,
					clean,
					hostileFrames,
					stderr: hostileHost.stderr(),
				},
				null,
				2,
			),
		);
		process.exit(1);
	}
};

await hostileCase(
	`Content-Length: ${Buffer.byteLength(fake)}\r\nContent-Length: ${Buffer.byteLength(fake)}\r\n\r\n${fake}`,
	"duplicate Content-Length",
);
await hostileCase(
	`Bad Header\r\nContent-Length: ${Buffer.byteLength(fake)}\r\n\r\n${fake}`,
	"malformed frame header",
);
await hostileCase(`${"X".repeat(5000)}`, "frame header too large", {
	BLITZ_MCP_MAX_FRAME_BYTES: "128",
});

console.log(
	JSON.stringify(
		{
			ok: true,
			frames: frames.length,
			workspace: tmp,
			symlinkRejected,
			duplicateRejected: true,
			malformedRejected: true,
			oversizedHeaderRejected: true,
		},
		null,
		2,
	),
);
