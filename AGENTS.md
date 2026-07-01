# AGENTS.md — blitz

Cross-agent shared context for this repository.

## Purpose

`blitz` is a standalone Zig 0.16 CLI for AST-aware code edits. Ships as a single static binary per platform. Used by `@codewithkenzo/pi-blitz` (separate repo) as a subprocess backend.

## Token-savings prime directive

This project exists to save coding-agent context. Token/context savings are product truth, not a side metric.

For Blitz 0.4 and later:
- Blitz is **not core edit today**; it must become the default core-edit replacement only through measured token wins.
- Never claim token savings from wall time, byte counts, or intuition. Claims require real Pi artifacts, correctness status, and Tokscale/token accounting.
- Token metrics come first in plans/reports: resident tool schema, resident skill text, prompt/input/cache, tool args, model output, result payload, total model-visible context. Wall time is secondary.
- Simple edits matter most. Structural wins are already proven; core replacement requires tiny/simple both-correct rows to beat or tie core after overhead.
- Any route that loses tokens must either choose core/apply_patch or explain why correctness requires Blitz.
- Default design bias: fewer resident tools, compact IR, lazy/discoverable schema, tiny success output, deterministic AST targets, no unchanged-code replay.

## Stack

- Language: **Zig 0.16.0 stable** (released 2026-04-13)
- Parser: **tree-sitter** (C core, vendored under `third_party/tree-sitter/`)
- Grammars: vendored per language under `grammars/tree-sitter-<lang>/`
- Testing: `zig build test`
- No Python, no Node, no local ML model.

## Skills to load

- `kenzo-zig` — Zig 0.16 patterns (std.Io, allocators, error handling)
- `kenzo-zig-build` — build.zig, build.zig.zon, cross-compile, C interop
- `.pi/skills/blitz-benchmarking` — repo-local Pi/tmux/Tokscale benchmark method; load before benchmark reports, token-savings claims, or `.pi/bench/pi-matrix.ts` changes

## Nested AGENTS.md map

Read nearest nested `AGENTS.md` before work in these subtrees:
- `src/` — Zig CLI core, command architecture, tree-sitter bindings, file safety.
- `src/apply/` — structured edit IR, target resolution, validation, token-facing op behavior.
- `.pi/bench/` — Bun/TypeScript benchmark harness, Pi/tmux/Tokscale artifacts, token accounting.
- `mcp/` — standalone Blitz MCP server and schema/token-tax guardrails.
- `packages/` — platform npm package metadata and binary distribution constraints.
- `grammars/` — vendored tree-sitter grammar guardrails.
- `third_party/` — vendored tree-sitter C source guardrails.

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
1. read `.pi/docs/product/blitz.md` (full spec, mirrored from pi-rig)
2. for token work, read `.pi/docs/plans/current/` first, then `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md` and `.pi/research/archive/20260605-*` only when older 0.4 history matters
3. check current sprint in the companion `pi-rig` tickets (`d1o-*` ids) when available; this repo may not have local `.tickets`
4. implement the smallest safe diff
5. `zig build && zig build test` before claiming done; token claims additionally require the benchmark workflow below

## Benchmark workflow

Load `.pi/skills/blitz-benchmarking` before any Blitz/pi-blitz benchmark or token claim.

Rules:
- benchmark claims require real Pi session artifacts, correctness status, wall time, and token accounting;
- locked runs require Tokscale validation with `--tokscale`; `tokscale token match` means input/output/cache/message totals match, not cost parity;
- tmux runner is preferred for method-locking and interactive/piloted rows: `bun .pi/bench/pi-matrix.ts --runner tmux ...`;
- keep existing baseline reports unless user explicitly asks to regenerate or replace them;
- push benchmark work after method is locked, artifacts are preserved, and the diff is verified; no extra user confirmation needed for safe task branches;
- if model variance causes newline drift, retries, or timeouts, preserve tmux run dirs and report failed attempts separately from accepted rows.

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

- `.pi/docs/product/blitz.md` — durable product/architecture spec; 0.4 token-first doctrine is authoritative for future edit surfaces
- `.pi/docs/plans/current/` — active 0.5 plans/prompts/gates; specs/PRDs/plans live together here
- `.pi/docs/plans/archive/` — 0.2/0.3/0.4/2.0 historical plans/specs
- `.pi/research/archive/20260605-tool-schema-context-tax.md` — provider/MCP/schema-tax research
- `.pi/research/archive/20260605-token-efficient-edit-repos.md` — edit-format/repo research
- `NOTICE.md` — third-party attribution

## Constraints

- Commit/push at each safe verified diff and healthy phase boundary on owned task branches; ask only before force-push, history rewrite, secrets exposure, or ambiguous/destructive branch publication
- No `@cImport` for new code (use build-system C integration)
- Tests must pass before PR
- Stay Zig 0.16.0 stable; no nightly-only APIs without a guard
- Keep per-call wall time honest — all latency claims measured, never assumed
