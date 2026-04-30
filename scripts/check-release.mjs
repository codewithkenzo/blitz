#!/usr/bin/env node
import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { findBlitzBinary } from "./resolve-platform-bin.js";

const root = fileURLToPath(new URL("..", import.meta.url));
const readJson = (path) => JSON.parse(readFileSync(new URL(path, import.meta.url), "utf8"));
const fail = (message) => {
  console.error(`release check failed: ${message}`);
  process.exitCode = 1;
};

const main = readJson("../package.json");
const version = main.version;
const platformPackages = [
  "blitz-linux-x64-musl",
  "blitz-linux-arm64-musl",
  "blitz-darwin-arm64",
  "blitz-darwin-x64",
  "blitz-windows-x64",
];

for (const shortName of platformPackages) {
  const packageName = `@codewithkenzo/${shortName}`;
  const optionalVersion = main.optionalDependencies?.[packageName];
  if (optionalVersion !== version) {
    fail(`${packageName} optionalDependency is ${optionalVersion ?? "missing"}, expected ${version}`);
  }
  const platformPkg = readJson(`../packages/${shortName}/package.json`);
  if (platformPkg.name !== packageName) {
    fail(`packages/${shortName}/package.json name is ${platformPkg.name}, expected ${packageName}`);
  }
  if (platformPkg.version !== version) {
    fail(`${packageName} package version is ${platformPkg.version}, expected ${version}`);
  }
}

const blitz = findBlitzBinary();
if (blitz) {
  const result = spawnSync(blitz, ["--version"], { cwd: root, encoding: "utf8" });
  const output = `${result.stdout ?? ""}${result.stderr ?? ""}`.trim();
  if (result.status !== 0) {
    fail(`blitz --version exited ${result.status}: ${output}`);
  } else if (!output.includes(version)) {
    fail(`blitz --version output ${JSON.stringify(output)} does not include package version ${version}`);
  }
} else {
  console.warn("release check warning: no local blitz binary found; skipped --version check");
}

const tmpDir = mkdtempSync(join(tmpdir(), "blitz-release-check-"));
try {
  const generated = join(tmpDir, "blitz-mcp.js");
  execFileSync("bun", ["build", "mcp/blitz-mcp.ts", "--outfile", generated, "--target", "node"], {
    cwd: root,
    stdio: "ignore",
  });
  let generatedText = readFileSync(generated, "utf8");
  generatedText = generatedText.replace("#!/usr/bin/env bun\n// @bun\n\n", "#!/usr/bin/env node\n");
  const committedText = readFileSync(new URL("../mcp/blitz-mcp.js", import.meta.url), "utf8");
  if (generatedText !== committedText) {
    fail("mcp/blitz-mcp.js is stale; regenerate from mcp/blitz-mcp.ts");
  }
} finally {
  rmSync(tmpDir, { recursive: true, force: true });
}

const pack = spawnSync("npm", ["pack", "--dry-run", "--json"], { cwd: root, encoding: "utf8" });
if (pack.status !== 0) {
  fail(`npm pack --dry-run failed: ${(pack.stderr ?? pack.stdout ?? "").trim()}`);
} else {
  try {
    const parsed = JSON.parse(pack.stdout);
    const files = new Set(parsed[0]?.files?.map((file) => file.path));
    for (const required of ["bin/blitz.js", "mcp/blitz-mcp.js", "mcp/blitz-mcp.ts", "scripts/resolve-platform-bin.js"]) {
      if (!files.has(required)) fail(`npm pack missing ${required}`);
    }
  } catch (error) {
    fail(`npm pack --json parse failed: ${error instanceof Error ? error.message : String(error)}`);
  }
}

if (process.exitCode === undefined || process.exitCode === 0) {
  console.log(`release check ok: ${main.name}@${version}`);
}
