# Main live audit notes — Blitz 0.4 Phase 2

Date: 2026-06-09

Active D5 run: `e4f2df12-6302-407f-b7dd-b876ac0be7aa`.

## Current observed implementation

Canonical `/home/kenzo/dev/pi-blitz` live diff adds `pi_blitz_op` in `src/tools.ts`, profile registration in `src/tool-profiles.ts`, and smoke/profile tests.

## Audit findings to verify after D5 completes

1. Direct file-scoped op guard appears handled by `isFileScopedApplyOperation(...)`.
2. `as` alias currently maps to `edit: { header, text }`, but Blitz Zig `runAppendSection` requires `edit.heading` + `edit.text`. This needs fix/test.
3. `dk` alias currently maps to `edit: { start: string, end: string }`, but Blitz Zig `runDeleteRange` requires numeric `start`, numeric `end`, and string `expected`. This needs fix/test or fail-closed unsupported alias.
4. `ia` tuple shape currently means `["ia", position, anchor, text]`, while PLAN example suggested `["ia", symbolOrAnchor, text, position]`. Need documented/tested exact shape and fail-closed behavior.
5. Existing tests observed cover `rr` and `ru`; they should also cover direct op aliases with unusual shapes (`as`, `dk`, `ia`, `sk`) or explicitly reject unsupported ones.

## Post-benchmark findings

D5 run was interrupted/revived after the benchmark subprocesses had exited but the subagent remained paused/stale. The generated report `/home/kenzo/dev/blitz/reports/pi-tmux-phase2-op-blitz-20260609.md` is **not publishable** for Phase 2 acceptance:

- `medium-10k/wrap-body`: `correct=100.0%`, `tokscale token match=yes`, tool `pi_blitz_op`.
- `semantic/arrow-replace-return`: `correct=0.0%`, `tokscale token match=yes`, tool `pi_blitz_op`.
- The failed semantic row changed `export const pickLabel` to `export const last`; it did not replace the last return expression.
- Session tool calls show the model was exposed only to `pi_blitz_op` but prompt guidance still said `pi_blitz_replace_return`; the model tried malformed `rr` tuples then fell back to `ru` incorrectly.
- Benchmark report profile coverage is internally inconsistent: minimal row executed with `pi_blitz_op`, but `Profile coverage / skipped rows` says `minimal-v0: supported 0/2; skipped 2`.
- `bench/pi-matrix.ts` references `useCompactOp`; grep found no definition. That path may crash on untested fixtures.

Revived D5 run `44af8187` with explicit remediation instructions: fix alias mappings/tests, fix minimal benchmark guidance/support accounting, rerun targeted tmux/Tokscale smoke under a new report name, commit/push verified fixes.

Do not mark goal complete until these are resolved or documented as residual blockers with evidence.
