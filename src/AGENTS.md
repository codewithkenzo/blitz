# AGENTS.md — src

Zig CLI core rules. Read `../AGENTS.md` first.

## Purpose

`src/` contains Blitz CLI commands, workspace/file safety, tree-sitter integration, AST/symbol logic, fallback edit support, metrics, daemon mode, and tests.

## Skills to load

- `kenzo-zig` — Zig 0.16 std.Io, allocators, errors, comptime.
- `kenzo-zig-build` — when source changes require `build.zig`/C interop updates.
- `.pi/skills/blitz-benchmarking` — required before changing behavior used by benchmark/token claims.

## Commands

```bash
zig build
zig build test
zig build run
zig build --watch -fincremental
```

## Architecture map

- `main.zig`, `cli.zig` — entry and CLI dispatch.
- `cmd_*.zig` — command implementations.
- `ast.zig`, `symbols.zig`, `grammar_config.zig` — parsing/language support.
- `tree_sitter/bindings.zig` — C ABI boundary.
- `workspace.zig`, `backup.zig`, `lock.zig`, `line_index.zig` — file/workspace safety.
- `apply/` — structured edit IR and validation.
- `fallback.zig`, `edit_support.zig`, `splice.zig` — fallback and low-level edit mechanics.
- `metrics.zig` — measured output; keep token-facing output compact.
- `test_all.zig` — aggregate tests.

## Zig 0.16 constraints

- Use `pub fn main(init: std.process.Init) !void` pattern at entry.
- Use `std.heap.DebugAllocator(.{}){}` and arenas as documented in root.
- Use `std.Io.*` filesystem/process APIs for new code.
- No new `@cImport`; prefer build-system C integration or extern Zig module.
- Keep tree-sitter ABI isolated to `tree_sitter/bindings.zig`.

## Edit behavior constraints

- Deterministic AST targets beat fuzzy text where possible.
- No unchanged-code replay in model-facing flows.
- Validate before write; preserve backup/atomic-write safety.
- Error output must be precise enough for agents, not verbose dumps.
- No speculative refactors outside current command/op.

## Verification

- Source changes require `zig build test` unless impossible; record reason if skipped.
- CLI behavior changes should include a focused command smoke with `zig-out/bin/blitz`.
- Token-facing output changes require benchmark report update before savings claims.
