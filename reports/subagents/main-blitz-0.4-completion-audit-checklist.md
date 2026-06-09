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

Revived D5 run: `44af8187`.

Expected next artifacts:
- fixed pi-blitz compact alias implementation/tests and pushed commit;
- fixed Blitz harness guidance/support accounting and pushed commit;
- new targeted report `reports/pi-tmux-phase2-op-blitz-rerun-20260609.{md,json}` or clearly named equivalent;
- final D5 report with verification commands and residual gaps.
