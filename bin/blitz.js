#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { candidateBinaries } from "../scripts/resolve-platform-bin.js";

const candidates = candidateBinaries();
const tried = [];
for (const candidate of candidates) {
  const result = spawnSync(candidate, process.argv.slice(2), { stdio: "inherit" });
  if (!result.error) process.exit(result.status ?? 1);
  if (!["ENOEXEC", "EBADARCH", "EACCES", "ENOENT"].includes(result.error.code ?? "")) {
    console.error(result.error.message);
    process.exit(1);
  }
  tried.push(candidate);
}

console.error(`blitz binary not found or not executable. Searched: ${tried.join(", ")}. Set BLITZ_BIN or install the matching @codewithkenzo/blitz platform package.`);
process.exit(1);
