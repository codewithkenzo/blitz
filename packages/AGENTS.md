# AGENTS.md — packages

Platform package rules. Read `../AGENTS.md` first.

## Purpose

`packages/` contains per-platform npm packages that ship prebuilt Blitz binaries consumed by root `optionalDependencies`.

## Package dirs

- `blitz-darwin-arm64/`
- `blitz-darwin-x64/`
- `blitz-linux-arm64-musl/`
- `blitz-linux-x64-musl/`
- `blitz-windows-x64/`

## Skills to load

- `kenzo-zig-build` — cross-compile/package artifact changes.
- `.pi/skills/blitz-benchmarking` — only when package/install path affects benchmark reports.

## Commands

From repo root:

```bash
zig build -Dtarget=aarch64-macos
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-windows-gnu
npm pack --dry-run --json
npm pack ./packages/blitz-linux-x64-musl --json
```

## Version/package rules

- Keep platform package versions aligned with root `package.json`.
- Keep binary paths and `bin/` layout compatible with `scripts/resolve-platform-bin.js` and `bin/blitz.js`.
- Do not publish or change package visibility as part of unrelated source work.
- Benchmark reports must state install path: local source, linked package, `npm install -g .`, or published package.

## Anti-patterns

- No editing generated/prebuilt binaries by hand.
- No package version bump without release intent.
- No platform package drift from root metadata.
