# Main completion audit checklist — Blitz 0.4 context/token core

Date: 2026-06-09
Goal sources:
- `docs/plans/START-0.4-context-token-core.md`
- `docs/plans/PLAN-0.4-context-token-optimization.md`

## Concrete success criteria

1. `zig build` passes in `/home/kenzo/dev/blitz`.
2. `zig build test` passes in `/home/kenzo/dev/blitz`.
3. Harness reports exact token/context breakdown: visible tools, serialized registered specs, spec tokens, resident skill text/tokens, prompt/input/cache, arg tokens, output tokens, result payload tokens, total context, correctness, route/profile.
4. Raw artifacts preserved for every accepted claim: tool-spec JSON, resident skill snapshots, tokenizer/model metadata, Tokscale/session JSON, residual analysis.
5. `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` exists and unused schemas are absent from registered tool specs.
6. Common-lane resident tool+skill overhead reduction is measured and >=70% vs full where claimed.
7. `pi_blitz_op` exists, translates aliases `rr/rb/ib/wb/tc/ru/ia/bt/as/ek/dk/sk`, emits compact success output by default, and preserves Blitz safety/preconditions.
8. Phase 2 token proof: accepted `replace_return` arg tokens are below previous 76-98 range; accepted `wrap_body` arg tokens stay near/below previous 90-120 while schema tax is much lower.
9. Phase 3 skill is <=500 resident tokens with long docs moved to references and no correctness regression in accepted rows.
10. Phase 4 compact/freeform/custom-tool exploration is either benchmarked as better or explicitly rejected with evidence and no correctness regression.
11. Phase 5 deterministic chunk-local merge spike is implemented or explicitly documented as infeasible/deferred with evidence; if implemented, it handles real small edits without repeating old code and improves previously losing semantic/simple rows.
12. Phase 6 token-first router/integration point is implemented or explicitly bounded as benchmark-only until a named follow-up phase.
13. Every selected Blitz row has token/context justification; every non-selected Blitz row explains why core/apply_patch is cheaper.
14. Simple both-correct rows either beat/tie core after overhead, or router chooses core/apply_patch with explicit token proof.
15. Structural rows preserve current large token wins (~9k representative savings).
16. Real Pi/tmux/Tokscale rows used for savings are correct=100%, exit=0, timedOut=false, token match=yes, intended tool used, raw prompt/session/logs saved.
17. Reports list failed/skipped rows and caveats; failed/caveated rows are excluded from savings.
18. Companion `/home/kenzo/dev/pi-blitz` branch/commit/checks are listed when touched.
19. Both repos are pushed at safe verified commits; no force push/history rewrite.

## Current evidence snapshot

### Passing / previously satisfied evidence

- Phase 0/1 first-slice commits are pushed in Blitz through `40bf394`/`5cc5a25` and pi-blitz profile branch through `53202df`.
- Remediation report: `reports/subagents/d5-blitz-0.4-auditor-remediation.md`.
- GPT semantic smoke v5: `reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.{json,md}`.
- Accounting root: `reports/pi-accounting-runs/2026-06-09T02-25-21-688Z/`.
- Resident overhead v5 had common reductions: minimal-v0 85.14%, semantic 73.23%, structural 70.01%, admin 82.12%.
- Current Phase 2 attempt added `pi_blitz_op` in pi-blitz commit `e9a31bf` and harness compact route in Blitz commit `684c60b`.

### Current blockers / weak evidence

- `reports/pi-tmux-phase2-op-blitz-20260609.md` is not publishable: `semantic/arrow-replace-return` has `correct=0.0%` though Tokscale matched.
- Minimal benchmark prompt guidance did not consistently instruct exact `pi_blitz_op` tuples; semantic row tool-call history shows malformed tuples and wrong fallback.
- `pi_blitz_op` alias mapping audit found likely bugs: `as` uses `header` instead of Zig-required `heading`; `dk` lacks numeric `start/end` and `expected`; `ia` shape is under-tested; `rr` tuple shape is fragile.
- `bench/pi-matrix.ts` references `useCompactOp` without a definition found by grep.
- Phase 4 freeform/custom-tool comparison has not yet been evidenced.
- Phase 5 deterministic chunk-local merge spike has not yet been evidenced.
- Phase 6 runtime router/integration point remains only partial/benchmark-side unless D5 adds explicit boundary or implementation.
- Full completion audit must be rerun after D5 revived run `44af8187` finishes.

## Active follow-up

Phase 2 remediation is now evidenced and pushed:

- pi-blitz: `b5f013e fix compact op alias translation` on `feat/blitz-0.4-token-core-profile-canonical` / `origin/feat/blitz-0.4-token-core-profile`.
- Blitz harness: `5112866 fix compact op benchmark guidance` on `feat/blitz-0.4-token-core-profile`.
- Blitz report artifacts: `f6bb3de docs: preserve phase 2 compact op benchmark evidence`.
- Accepted report: `reports/pi-tmux-phase2-op-blitz-rerun-20260609.md`.
  - `medium-10k/wrap-body`: `correct=100.0%`, `tokscale token match=yes`, `arg tok=90`, total context `23782`.
  - `semantic/arrow-replace-return`: `correct=100.0%`, `tokscale token match=yes`, `arg tok=65`, total context `10277`.
  - minimal-v0 coverage reports `supported 2/2; skipped 0`.
  - minimal combined resident schema+skill: `837`, `87.0%` reduction vs full.
- Failed/caveated attempts are preserved in:
  - `reports/pi-tmux-phase2-op-blitz-20260609.{md,json}`
  - `reports/pi-tmux-phase2-core-20260609.{md,json}`
  - raw accounting/tmux roots for `2026-06-09T02-46-18-961Z`, `2026-06-09T02-48-53-599Z`, and `2026-06-09T02-59-35-877Z`.

Independent main verification after Phase 2 remediation passed:

- `/home/kenzo/dev/pi-blitz`: `bun run typecheck && bun test && bun run build`.
- `/home/kenzo/dev/blitz`: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-phase2-main-check.js && zig build && zig build test`.

New D5 run for remaining Phase 4/5/6 work: `b5e12abe-31f2-443a-b03c-457f4ed0b8ff`.

Phase 4/5/6 D5 run completed and pushed:

- D5 run: `b5e12abe-31f2-443a-b03c-457f4ed0b8ff`.
- Report: `reports/subagents/d5-blitz-0.4-phase456-report.md`.
- pi-blitz: `8ade791 feat(op): support compact script field` pushed to `origin/feat/blitz-0.4-token-core-profile`.
  - Adds `pi_blitz_op.s` compact tab-line script field.
  - Tests cover `rr` and `dk` script translation.
  - Local tokenizer comparison only: `rr` JSON 24 tokens vs script 22; `dk` JSON 19 vs script 17.
  - No real Pi/Tokscale savings claim for script path yet.
- Blitz: `f6130b3 feat(bench): record token route decisions` and `3f84f94 style(bench): format token route decision block` pushed to `origin/feat/blitz-0.4-token-core-profile`.
  - Adds `tokenRouteDecision` fields in run records: `contextSavingsPct`, `schemaTokensExpected`, `argTokensExpected`, `outputTokensExpected`, `fallbackContextTokensExpected`, `selectedBecause`.
  - Current boundary is benchmark/report-level plus profile enforcement; no runtime core edit wrapper/facade and no core replacement claim.
- Main reran verification after D5:
  - `/home/kenzo/dev/pi-blitz`: `bun run typecheck && bun test && bun run build` passed.
  - `/home/kenzo/dev/blitz`: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-main-phase456-audit.js && zig build && zig build test` passed.

Completion status after Phase 4/5/6 audit:

- Phase 4: partially satisfied. Script field implemented and locally compared; real Pi/Tokscale script rows are still missing before any adoption/savings claim.
- Phase 5: not implemented. Deferred to named follow-up **Phase 5A — chunk-local merge IR** with concrete code blockers in D5 report.
- Phase 6: partially satisfied. Benchmark token-route fields and explicit boundary exist, but runtime edit facade/router is deferred to **Phase 6A — runtime edit facade/router**.
- Overall goal is **not complete** as a core-edit replacement proof because Phase 5A and Phase 6A remain required before default/core replacement claims survive audit.
