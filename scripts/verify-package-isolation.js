#!/usr/bin/env node
import { execFileSync } from "node:child_process";

const platformPackages = [
	"./packages/blitz-darwin-arm64",
	"./packages/blitz-darwin-x64",
	"./packages/blitz-linux-arm64-musl",
	"./packages/blitz-linux-x64-musl",
	"./packages/blitz-windows-x64",
];

const attrPaths = [
	"bench/natural-edit.ts",
	"bench/fixtures/exact/tiny.ts",
	"reports/natural-edit-harness/example.md",
	"reports/natural-edit-runs/example/work/score.ts",
];

const forbiddenPackagePrefixes = [
	"bench/",
	"reports/",
	".pi/",
	".tickets/",
	"research/",
	"zig-cache/",
	"zig-out/",
	"zig-pkg/",
];

const allowedRootFiles = new Set([
	"LICENSE",
	"NOTICE.md",
	"README.md",
	"bin/blitz.js",
	"docs/blitz.md",
	"mcp/blitz-mcp.js",
	"mcp/blitz-mcp.ts",
	"package.json",
	"scripts/mcp-smoke.ts",
	"scripts/resolve-platform-bin.js",
]);

const allowedPlatformFiles = new Set([
	"bin/blitz",
	"bin/blitz.exe",
	"package.json",
]);

function run(command, args) {
	return execFileSync(command, args, {
		encoding: "utf8",
		stdio: ["ignore", "pipe", "pipe"],
	});
}

function fail(message) {
	console.error(`package isolation failed: ${message}`);
	process.exit(1);
}

function npmPackFiles(target) {
	const args = ["pack"];
	if (target) args.push(target);
	args.push("--dry-run", "--json");
	const output = run("npm", args);
	const parsed = JSON.parse(output);
	const pack = parsed[0];
	if (!pack?.files)
		fail(`npm pack returned no file list for ${target || "root"}`);
	return pack.files.map((file) => file.path).sort();
}

function verifyAttributes() {
	const output = run("git", [
		"check-attr",
		"linguist-vendored",
		"linguist-generated",
		"--",
		...attrPaths,
	]);
	const byPath = new Map();
	for (const line of output.trim().split("\n")) {
		const [path, attr, value] = line.split(": ");
		if (!byPath.has(path)) byPath.set(path, new Map());
		byPath.get(path).set(attr, value);
	}

	for (const path of attrPaths) {
		const attrs = byPath.get(path);
		const vendored = attrs?.get("linguist-vendored") === "set";
		const generated = attrs?.get("linguist-generated") === "set";
		if (!vendored && !generated)
			fail(`${path} is not excluded from language stats`);
	}

	console.log("git check-attr language-stat exclusions ok");
}

function verifyRootPack() {
	const files = npmPackFiles(undefined);
	const forbidden = files.filter((file) =>
		forbiddenPackagePrefixes.some((prefix) => file.startsWith(prefix)),
	);
	if (forbidden.length > 0)
		fail(`root pack includes forbidden dev assets: ${forbidden.join(", ")}`);

	const unexpected = files.filter((file) => !allowedRootFiles.has(file));
	if (unexpected.length > 0)
		fail(`root pack includes unexpected files: ${unexpected.join(", ")}`);

	console.log(`root npm pack isolation ok (${files.length} files)`);
}

function verifyPlatformPacks() {
	for (const target of platformPackages) {
		const files = npmPackFiles(target);
		const unexpected = files.filter((file) => !allowedPlatformFiles.has(file));
		if (unexpected.length > 0)
			fail(`${target} includes unexpected files: ${unexpected.join(", ")}`);

		const hasBinary =
			files.includes("bin/blitz") || files.includes("bin/blitz.exe");
		if (!files.includes("package.json") || !hasBinary)
			fail(`${target} missing package.json or binary payload`);

		console.log(`${target} npm pack isolation ok (${files.join(", ")})`);
	}
}

verifyAttributes();
verifyRootPack();
verifyPlatformPacks();
console.log("package isolation guard passed");
