# AGENTS.md — blitz

Cross-agent shared context for this repository.

## Purpose

`blitz` is a standalone Zig 0.16 CLI for AST-aware code edits. Ships as a single static binary per platform. Used by `@codewithkenzo/pi-blitz` (separate repo) as a subprocess backend.

## Stack

- Language: **Zig 0.16.0 stable** (released 2026-04-13)
- Parser: **tree-sitter** (C core, vendored under `third_party/tree-sitter/`)
- Grammars: vendored per language under `grammars/tree-sitter-<lang>/`
- Testing: `zig build test`
- No Python, no Node, no local ML model.

## Skills to load

- `kenzo-zig` — Zig 0.16 patterns (std.Io, allocators, error handling)
- `kenzo-zig-build` — build.zig, build.zig.zon, cross-compile, C interop

## Zig 0.16 rules (verified against stable release)

- **Entry:** `pub fn main(init: std.process.Init) !void { ... }` (Juicy Main). `init.gpa`, `init.arena`, `init.io` are provided. Use `std.process.Init.Minimal` only when bootstrapping runtime state manually.
- **Allocators:** `std.heap.DebugAllocator(.{}){}` root (GPA is removed). `std.heap.ArenaAllocator` per tool call.
- **I/O:** `std.Io.Threaded` stable (`Io.Evented` experimental). Filesystem + process operations live under `std.Io.*` (`std.Io.Dir`, `std.Io.File`). Atomic writes: `dir.createFileAtomic(io, path, .{ .replace = true })` + `File.Writer` + `atomic.replace(io)` + `defer atomic.deinit(io)`.
- **build.zig:** all module-level calls (`addCSourceFile`, `linkLibrary`, `addIncludePath`, `link_libc = true`) happen on `root_module` from `b.createModule(...)`, not on the `Compile` step.
- **C interop:** prefer build-system integration + a small `extern` Zig module or `addTranslateC`. `@cImport` is flagged as future-deprecated in 0.16 release notes.
- **Cross-compile:** `zig build -Dtarget=<target>` native. Targets: `aarch64-macos`, `x86_64-macos`, `x86_64-linux-musl`, `aarch64-linux-musl`, `x86_64-windows-gnu`.
- **Dev loop:** `zig build --watch -fincremental`.

## Working workflow

For non-trivial work:
1. read `docs/blitz.md` (full spec, mirrored from pi-rig)
2. check current sprint in the companion `pi-rig` tickets (`d1o-*` ids)
3. implement the smallest safe diff
4. `zig build && zig build test` before claiming done

## Commands

```bash
zig build              # native build → zig-out/bin/blitz
zig build run          # build + run
zig build test         # unit tests
zig build --watch -fincremental  # hot-rebuild dev loop

# cross-compile
zig build -Dtarget=aarch64-macos
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-windows-gnu
```

## Spec

- `docs/blitz.md` — mirrors `pi-rig/docs/architecture/blitz.md` (single source of truth)
- `NOTICE.md` — third-party attribution

## Constraints

- No committing/pushing unless explicitly requested
- No `@cImport` for new code (use build-system C integration)
- Tests must pass before PR
- Stay Zig 0.16.0 stable; no nightly-only APIs without a guard
- Keep per-call wall time honest — all latency claims measured, never assumed
