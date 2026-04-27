# Research: Effect 4 beta boundary patterns, Zig 0.16 file/env/path/lock IO, MCP packaging configs

## Question
What Effect 4 beta boundary patterns fit Pi-extension style code, what Zig 0.16 file/env/path/lock best practices fit this repo, and what current MCP server packaging config examples should we mirror? Compare repo choices to docs and give actionable recs.

## Findings
1. **Effect boundary should stay at edges, with typed errors/services inside.** Effect docs say `Effect.runPromise` / `runPromiseExit` are edge-only runtime entry points, `Effect.provide` scopes runtime config locally, `ManagedRuntime.make` is for app-wide runtime wiring, and `Effect.Tag` / `Data.TaggedError` are the idiomatic way to model services and expected errors. The docs also show `catchTag` / `catchTags` for typed recovery, not raw `try/catch`. Repo docs already say `@codewithkenzo/pi-blitz` is intended as a thin Effect v4 wrapper around the native binary, so current repo direction matches the docs. Sources: https://www.effect.website/docs/runtime/ , https://www.effect.website/docs/error-management/expected-errors/ , `docs/blitz.md:5,17`.

2. **Zig 0.16 choices in repo mostly match upstream, especially `std.process.Init` + `std.Io`.** Zig 0.16 docs/release notes moved file/process APIs onto `std.Io`, recommend `main(init: std.process.Init)` for CLIs, and show `init.io`, `init.arena`, and `init.minimal.args` as the normal setup. This repo already uses `pub fn main(init: std.process.Init) !void`, streams stdout/stderr via `std.Io.File.*().writerStreaming(io, ...)`, resolves paths with `std.Io.Dir.realPathFileAlloc`, and uses `createDirPathOpen` / `createDir` / `createFileAtomic` for cache and backup writes. Sources: https://ziglang.org/documentation/0.16.0/ , https://ziglang.org/download/0.16.0/release-notes.html , `src/main.zig:3-4,20-34`, `src/backup.zig:43-45,61-75,90-121`, `src/lock.zig:3-5,44-69`.

3. **MCP packaging shape is aligned with current spec/examples.** MCP build docs show stdio servers launched by `command` + `args`, often with an env block and absolute paths; logging for stdio must go to stderr, not stdout. Repo README uses the same stdio shape for `mcpServers.blitz` via `npx --yes --package=@codewithkenzo/blitz -- blitz-mcp` or `bunx -p @codewithkenzo/blitz blitz-mcp`, with `BLITZ_WORKSPACE` in env. Root `package.json` also matches current package-manager packaging patterns with `bin`, `files`, and platform `optionalDependencies`. Sources: https://modelcontextprotocol.io/docs/develop/build-server , `README.md:135-191`, `package.json:8-29`.

## Sources
- Effect runtime docs: https://www.effect.website/docs/runtime/
- Effect expected errors docs: https://www.effect.website/docs/error-management/expected-errors/
- Zig 0.16 docs: https://ziglang.org/documentation/0.16.0/
- Zig 0.16 release notes: https://ziglang.org/download/0.16.0/release-notes.html
- MCP build-server docs: https://modelcontextprotocol.io/docs/develop/build-server
- Repo files: `README.md`, `package.json`, `src/main.zig`, `src/backup.zig`, `src/lock.zig`, `mcp/blitz-mcp.js`, `docs/blitz.md`

## Version / Date Notes
- Zig docs/release notes fetched for **0.16.0**; release notes are dated **2026-04-14** and mention `std.Io` / `std.process.Init` changes.
- Effect docs fetched on **2026-04-27**; Effect site is current docs, not version-pinned here, so API drift possible.
- MCP build docs fetched on **2026-04-27**; config examples are current docs, not package-specific.
- Repo package version in current tree is **0.1.0-alpha.7** (`package.json`, `src/main.zig`).

## Open Questions
- No `@codewithkenzo/pi-blitz` implementation exists in this repo; should its actual Effect boundary be reviewed in the separate extension repo before finalizing patterns?
- Should env lookup in Zig stay on libc `std.c.getenv`, or switch to `init.environ_map` / another non-libc path to reduce dependency surface?
- Do any target MCP clients need an explicit `cwd` field in config, or is `BLITZ_WORKSPACE` env enough for all supported hosts?

## Recommendation
- Keep current repo direction: **thin wrapper at Effect edge, native Zig core below**.
- In Effect code, prefer: `Data.TaggedError` for domain errors, `Effect.Tag`/`Layer` for services, `Effect.runPromiseExit` only at boundary, `Effect.provide` for local scoping, `ManagedRuntime` only if whole-extension lifecycle needs it.
- In Zig, keep `std.process.Init` + `std.Io` path/IO style, keep canonical-path locking, and keep atomic backup writes. Consider replacing libc env lookup only if extra portability matters more than current simplicity.
- For MCP packaging, keep current `npx`/`bunx` stdio examples and `BLITZ_WORKSPACE` env. Add `cwd` only if a specific client/doc wants it; do not add stdout logging.
