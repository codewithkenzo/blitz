#!/usr/bin/env node
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const here = dirname(fileURLToPath(import.meta.url));
const root = dirname(here);
const exe = process.platform === "win32" ? "blitz.exe" : "blitz";
const candidates = [
  process.env.BLITZ_BIN,
  join(root, "zig-out", "bin", exe),
  join(root, "bin", exe),
].filter((candidate) => typeof candidate === "string" && candidate.length > 0);

const tried = [];
for (const candidate of candidates) {
  if (!existsSync(candidate)) continue;
  tried.push(candidate);
  const result = spawnSync(candidate, process.argv.slice(2), { stdio: "inherit" });
  if (!result.error) process.exit(result.status ?? 1);
  if (!["ENOEXEC", "EBADARCH", "EACCES", "ENOENT"].includes(result.error.code ?? "")) {
    console.error(result.error.message);
    process.exit(1);
  }
}

console.error(`blitz binary not found or not executable. Tried: ${tried.length ? tried.join(", ") : candidates.join(", ")}. Set BLITZ_BIN or install a platform package.`);
process.exit(1);
