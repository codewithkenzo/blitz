# Blitz v0.2 hardening/parity final handoff

Date: 2026-05-24
Repo: `/home/kenzo/dev/blitz`
Goal: `mpha87vj-gkaman`

## Lifecycle / tracking state

- Branch/upstream: `main...origin/main` at final verification checkpoint.
- `tk`: binary exists, but this repo has no `.tickets` directory (`tk status` reports `no .tickets directory found`). Lifecycle/progress was therefore tracked through the active goal and this markdown handoff.
- Commit/push: not performed after the final audit fixes because the goal explicitly requires user authorization for commits/pushes.
- Current tracked dirty files: `src/apply/ir.zig`, `src/apply/mod.zig`.
- Local-only untracked artifacts: `.tmp/` verification logs.

## Implemented slices

1. Version/baseline alignment
   - Restored/verified Blitz version as `0.1.0-alpha.10`.
   - `zig-out/bin/blitz --version` prints `blitz 0.1.0-alpha.10`.
   - `zig-out/bin/blitz doctor` reports `version: 0.1.0-alpha.10`, `stage: v0.1`.

2. Apply engine split
   - Removed `src/cmd_apply.zig`.
   - `src/main.zig` dispatches apply through `src/apply/mod.zig`.
   - Apply modules exist under `src/apply/`: `mod.zig`, `ir.zig`, `errors.zig`, `target.zig`, `operations.zig`, `patch.zig`, `diff.zig`, `validate.zig`, `test_support.zig`.

3. Grammar and AST centralization
   - `src/grammar_config.zig` centralizes language extensions/names, comment styles, declaration/body kinds, name fields, and brace/Python behavior helpers.
   - `src/ast.zig` owns parse helpers, symbol resolution, body/replacement ranges, and duplicate symbol counts.
   - `src/symbols.zig` is a compatibility shim over `ast.zig`.

4. Structured apply error contract
   - `src/apply/errors.zig` maps stable `status`/`code` taxonomy for `apply --json`.
   - Fixed invalid-field panic: `src/apply/ir.zig` `requireString` now tag-checks JSON values instead of directly accessing `.string`.
   - `src/apply/mod.zig` routes operation-time `requireString` failures through `emitFailure`, so malformed fields return structured JSON.
   - Added regression coverage for integer `edit.body` and integer `target.symbol`, both returning `status:"rejected"`, `code:"INVALID_FIELD"`, with no mutation.
   - Fixed write-path structured failures: `file_lock.acquire`, `backup.defaultCacheDir`, `backup.store`, and `backup.atomicWrite` failures are caught and routed through `emitFailure`.

5. Marker fallback and LCS hardening
   - Legacy marker failures route to structured `needs_host_merge` fallback.
   - `src/splice.zig` includes bounded LCS guard (`MAX_LCS_TABLE_BYTES`, `MAX_LCS_TABLE_CELLS`, `MarkerSpliceTooLarge`) and marker robustness coverage.

6. Apply fixtures / operation coverage
   - Tests cover `replace_body_span`, `insert_body_span`, `wrap_body`, `set_body`, `multi_body`, `patch`, async/arrow/class method/TSX return cases, duplicate symbols, ambiguous/no-match/overlap, parse-error baseline, and invalid-field regressions.

7. Wrapper alignment
   - Inspected both companion wrapper locations: `../pi-blitz` and `../pi-rig/extensions/pi-blitz`.
   - Both pin Blitz `0.1.0-alpha.10`.
   - Both parse/classify `apply --json` `status`/`code` failure payloads.
   - Standalone `../pi-blitz` has extra progress/UX fields; this is non-contract UX drift, not a CLI status/code contract blocker.

8. Cross-file safety
   - No writable `rename-all`, move-to-file, delete/caller, or other cross-file write parity was promoted.
   - CLI remains single-file for writable edits (`rename` is single-file).

## Verification results

- Blitz CLI:
  - `zig build test` — pass
  - `zig build` — pass
  - `zig-out/bin/blitz --version` — `blitz 0.1.0-alpha.10`
  - `zig-out/bin/blitz doctor` — pass; reports `0.1.0-alpha.10`, `v0.1`, grammars ok
  - `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast` — pass
- Auditor repros:
  - Invalid field (`set_body` with integer `edit.body`) exits `1`, emits structured JSON `status:"rejected"`, `code:"INVALID_FIELD"`, file unchanged.
  - Write failure using temp TS file in non-writable directory exits `1`, emits structured JSON `status:"rejected"`, `code:"IO_ERROR"`, no panic/raw propagation.
- Wrapper gates already run:
  - `../pi-blitz`: `bun run typecheck`, `bun test` (30 pass), `bun run build` — pass
  - `../pi-rig/extensions/pi-blitz`: `bun run typecheck`, `bun test` (19 pass), `bun run build` — pass

## Remaining decisions / recommended next tickets

1. Decide canonical wrapper source: standalone `../pi-blitz` vs `../pi-rig/extensions/pi-blitz`, then intentionally mirror or ignore non-contract UX/progress features.
2. Decide whether writable `rename-all` belongs in a future v0.2.x or 2.0 lane; keep it gated until file hashes, all-range planning, parse validation, backups, and explicit approval are designed.
3. Add a formal golden snapshot runner if future apply refactors need byte-identical JSON fixtures beyond current Zig unit/CLI smoke coverage.
4. Clean or ignore `.tmp/` verification logs after explicit cleanup approval.
5. When user authorizes commits, commit the final tracked fix slice (`src/apply/ir.zig`, `src/apply/mod.zig`) atomically and then push only after the usual fetch/divergence check.
