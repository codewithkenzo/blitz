# Main audit — Blitz 0.4 context/token core replacement

Date: 2026-06-10
Branch: `feat/blitz-0.4-token-core-profile`
Auditor: main Pi agent

## Objective restated

Complete the work described by:

- `docs/plans/START-0.4-context-token-core.md`
- `docs/plans/PLAN-0.4-context-token-optimization.md`

Concrete completion means Blitz can be considered a candidate core-edit replacement only when real Pi/tmux/Tokscale artifacts prove the START/PLAN acceptance gates: exact token/context accounting, 100% correctness for accepted rows, >=70% resident overhead reduction for common lanes, structural savings preserved, simple rows either beat/tie core or route to core/apply_patch with explicit token proof, no hidden failed rows, and a product-real routing integration rather than benchmark-only selection.

## Prompt-to-artifact checklist

| Requirement / gate | Evidence inspected | Audit result |
|---|---|---|
| `zig build` passes | D5 report states `zig build && zig build test` passed after latest source changes; latest commits pushed. | Satisfied. |
| `zig build test` passes | Same as above; `reports/subagents/d5-phase7-wrap-long-applypatch-20260610.md` command list records pass. | Satisfied. |
| Harness reports token/context breakdown, not only wall time | `reports/pi-tmux-phase7-*.{md,json}` rows include schema, skill, prompt, arg, output, cache, residual, total context, wall time. | Satisfied for reported rows. |
| Tokscale/token accounting matches for publishable rows | Accepted rows in `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.{md,json}`, `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.{md,json}`, and synthesis report show Tokscale match yes. | Satisfied for accepted rows inspected. |
| Correctness is 100% for accepted savings rows | Accepted rows listed in synthesis use `correctRate === 1`, no timeout, exit 0 when present. | Satisfied for accepted rows. |
| Resident tool/skill overhead measured; common-lane target >=70% reduction | D5 Phase 7 report records router combined schema+skill 1127 vs full 7158, 84.3% reduction. | Satisfied as overhead evidence only. |
| Structural rows preserve current large token wins | `multi/large-structural` accepted Blitz current row total context 30,913; `medium-10k/wrap-body` now accepted Blitz row total context 30,087. | Partially satisfied: current Blitz structural rows are now correct, but no accepted core/apply_patch baseline exists for either row in Phase 7 synthesis. |
| Simple both-correct rows beat/tie core or router chooses core/apply_patch with explicit token proof | Synthesis chooses core for several rows when core is cheaper; examples: long-section core 9,769 vs router 11,122. | Not fully satisfied: selections are benchmark-level proof choices, not product-real `pi_blitz_route_edit` core/apply_patch invocation. Some accepted router rows lack paired accepted core baselines. |
| Direct apply_patch / apply_patch-style baseline included if available | `reports/subagents/d5-phase7-wrap-long-applypatch-20260610.md` documents current Pi/tmux harness lanes are `core|blitz|router`; no direct OpenAI-native apply_patch or distinct Pi built-in apply_patch lane is exposed. | Not satisfied: unavailable in current harness; absence is documented, not solved. |
| Token-first router integration point is product-real, not benchmark-only | `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.{md,json}` explicitly says benchmark-only, not Phase 7 completion, not product-real core interception. | Not satisfied. |
| Router-selected path best or within 5-10% of best for every Phase 7 case | Synthesis has 12 selections, but 8 gaps remain. | Not satisfied because of missing product-real fallback and missing paired baselines. |
| No selected route exceeds core context tokens by >10% unless core fails correctness | Core-selected rows satisfy at report-selection level; long-section selected core. | Only benchmark-level satisfied; not product-real runtime routing. |
| Failed/skipped rows and caveats listed; no hidden failures | Failed/stale wrap-body attempts and caveats are preserved in reports; synthesis has explicit gaps and candidate caveats. | Satisfied. |
| Raw tmux/Pi artifacts preserved for accepted token claims | New 2026-06-10 run roots and accounting artifacts are committed/pushed; stale run tail preserved. | Satisfied. |
| Companion `pi-blitz` branch/commit/test notes when touched | Earlier companion commits are documented, but latest D5 run did not edit `/home/kenzo/dev/pi-blitz`. | Satisfied for latest run; not sufficient for product-real router because companion runtime changes are still needed/forbidden by current constraint. |
| Final concise report with changed files, commands, pass/fail, token wins/losses, remaining risks | `reports/subagents/d5-phase7-wrap-long-applypatch-20260610.md`, `reports/subagents/d5-phase7-route-selected-synthesis.md`, and `reports/subagents/d5-blitz-0.4-phase7-report.md`. | Satisfied as progress reporting. |

## Current accepted evidence highlights

- `medium-10k/wrap-body`: accepted Blitz row after Zig fix, `pi_blitz_wrap_body`, correctness 100%, exit 0, Tokscale match yes, total context 30,087. Artifact: `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.{md,json}`.
- `long-section/replace-return`: accepted core row total 9,769 and accepted router row total 11,122; synthesis correctly selects core. Artifacts: `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.{md,json}` and `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.{md,json}`.
- `multi/large-structural`: accepted current Blitz row total 30,913 from prior structural evidence; no accepted core/apply_patch baseline.
- Route-selected synthesis: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.{md,json}` has 12 selections and 8 explicit gaps.

## Missing / incomplete / weakly verified requirements

1. Phase 7 status is still **NO** by the current synthesis and D5 reports.
2. No direct apply_patch baseline exists in current Pi/tmux harness evidence.
3. No product-real `pi_blitz_route_edit` core/apply_patch invocation is proven; route-selected core choices are benchmark report-level selections only.
4. `medium-10k/wrap-body` and `multi/large-structural` now have accepted Blitz evidence but still lack accepted core/apply_patch baselines for beat/tie proof.
5. Several rows still have caveats or missing paired baselines (`markdown/append-section`, structural rows, product-real fallback rows).
6. The current active constraint forbids editing `/home/kenzo/dev/pi-blitz` from Blitz-side proof runs, but the remaining product-real router/fallback work likely belongs in `pi-blitz` or in Pi harness/tool-surface integration.

## Audit verdict

The objective is **not achieved**. The latest D5 run materially improved evidence and fixed real Blitz/harness issues, but START/PLAN completion gates still fail. Do not call `update_goal(status="complete")`.

Recommended lifecycle state: pause for user decision/authorization, because completing the remaining gates requires either:

- authorizing companion `pi-blitz` runtime/facade work to prove product-real core/apply_patch fallback; or
- authorizing a new Pi/tmux harness/tool-surface lane that can honestly benchmark OpenAI/Pi apply_patch-style edits; or
- explicitly reducing the goal acceptance criteria to benchmark-only route-selected evidence, which would no longer match the current START/PLAN definition of done.
