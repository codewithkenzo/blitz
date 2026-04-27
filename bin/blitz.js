#!/usr/bin/env node
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const root = dirname(here);
const candidates = [
  join(root, "bin", process.platform === "win32" ? "blitz.exe" : "blitz"),
  join(root, "zig-out", "bin", process.platform === "win32" ? "blitz.exe" : "blitz"),
  process.env.BLITZ_BIN,
].filter(Boolean);

const binary = candidates.find((candidate) => existsSync(candidate));

if (!binary) {
  console.error("blitz binary not found. Set BLITZ_BIN or install a platform package.");
  process.exit(1);
}

const result = spawnSync(binary, process.argv.slice(2), { stdio: "inherit" });
if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status ?? 1);
