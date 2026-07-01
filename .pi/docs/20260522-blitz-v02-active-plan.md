# Blitz v0.2 active implementation plan

Date: 2026-05-22
Goal: implement v0.2 hardening/parity from `.pi/docs/specs/blitz-v0.2-hardening-and-parity.md` while treating 2.0 docs as non-authoritative checks.

## Current baseline

- Repo: `/home/kenzo/dev/blitz`
- Branch: `main`, tracking `origin/main`, clean at checkpoint.
- Current version/doctor: `0.1.0-alpha.10`; doctor reports rust/typescript/tsx/python/go grammars ok.
- `tk`: not available in shell output; continue with markdown/goal tracking.
- Baseline verification already passed in this session:
  - `zig build test`
  - `zig build`
  - `zig-out/bin/blitz doctor`
  - `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast`
- Progress since baseline:
  - Re-aligned binary/help/doctor version strings to `0.1.0-alpha.10`.
  - Added `apply --json` parse-error-before/after rejection coverage.
  - Extracted `src/apply/validate.zig` and routed apply parse-after validation through it.
  - Added `set_body` JSON snapshot coverage for success fields (`status`, `operation`, `language`).
  - Inspected companion `pi-blitz` locations: top-level `../pi-blitz` is on `0.1.0-alpha.10`, while `../pi-rig/extensions/pi-blitz` still has stale optionalDependencies pinned to `0.1.0-alpha.0` and regex-based success classification remains in `src/tools.ts`.

## Required implementation slices

1. Snapshot/golden coverage for current `blitz apply --json` behavior before refactor.
   - Cover: `replace_body_span`, `insert_body_span`, `wrap_body`, `set_body`, `multi_body`, `patch`.
   - Include rejection cases: invalid JSON/version/op, missing field/symbol, unsupported language, symbol not found, ambiguous/no match, overlapping edits, parse errors.

2. Apply engine split, behavior-preserving.
   - Target modules: `src/apply/mod.zig`, `ir.zig`, `errors.zig`, `target.zig`, `operations.zig`, `patch.zig`, `diff.zig`, `validate.zig`.
   - Update `src/main.zig` and `src/test_all.zig` imports.
   - Delete or fully retire `src/cmd_apply.zig` after migration.

3. Grammar config centralization.
   - Add `src/grammar_config.zig` with extensions, language names, comment styles, declaration kinds, body kinds, name fields, brace/Python behavior.
   - Remove language-specific declaration/comment/body lists from operation/edit code where practical.

4. AST API centralization.
   - Make `src/ast.zig` canonical for parse helpers, resolved symbols, body ranges, declaration walking, ambiguity/match counts.
   - Reduce `src/symbols.zig` to compatibility shim or remove.

5. Stable `apply --json` failure contract.
   - Output stable `status` + `code` for errors.
   - Implement v0.2 taxonomy at least for apply JSON.
   - Map file/workspace/parse/symbol/anchor/overlap/hash/backup/io/fallback errors.

6. Legacy marker fallback + marker/LCS robustness.
   - For applicable legacy marker failures, emit `needs_host_merge` JSON with no mutation.
   - Add marker tolerance and safe LCS guard/fallback rather than unbounded memory.

7. Fixture expansion.
   - Async functions, class method wraps, arrow returns, TSX components, nested returns, duplicate symbols, multi-symbol returns, parse-error baseline.

8. Wrapper alignment only after inspecting companion locations.
   - Inspect `../pi-blitz` and `../pi-rig/extensions/pi-blitz`.
   - Align operation names, schemas, and status/code classification if wrapper code changes.
   - Run wrapper `bun run typecheck`, `bun test`, `bun run build` only if wrapper changes.

9. Cross-file parity remains preview-first unless safety gates and explicit user approval exist.

## Agent routing

- Main pi agent: coordinate, verify, update this plan; no implementation edits.
- D5 builder: Zig implementation slices and CLI tests.
- Reviewer after material implementation batch.

## Verification gates per implementation batch

- Required: `zig build test`, `zig build`, `zig-out/bin/blitz doctor`.
- Release target: `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast`.
- If wrapper changed: `bun run typecheck`, `bun test`, `bun run build` in wrapper repo.

## Current next step

Delegate Slice 1-5 to D5 in the live checkout (single coding agent), with instructions to keep diffs small and preserve behavior except structured error additions.
