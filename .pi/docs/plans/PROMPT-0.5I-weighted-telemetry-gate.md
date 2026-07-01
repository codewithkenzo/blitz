# PROMPT — Sprint I weighted telemetry gate (`bli-qreu`)

Status: prompt only. Do not run telemetry until explicitly started.

## Context

Sprint I prerequisite tickets closed:

- `bli-6gb1` — route optimizer token target math
- `bli-qn4t` — natural edit route selector
- `bli-cwfj` — zero-resident/minimal surface investigation
- `bli-fu5w` — compact IR v2 design
- `bli-53tr` — advanced structural profile plan

Primary source files:

- `.pi/docs/plans/PLAN-0.5I-token-moonshot.md`
- `.pi/reports/SPRINT-I-ROUTE-OPTIMIZER-TOKEN-TARGET-MATH-20260620.md`
- `.pi/reports/SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md`
- `.pi/docs/plans/PLAN-0.5I-compact-ir-v2.md`
- `.pi/docs/plans/PLAN-0.5I-advanced-structural-profile.md`

Dirty-state constraint:

- Preserve `.tickets/bli-pg9j.md` dirty state.
- Preserve existing report farm and untracked run artifacts.
- Do not clean or overwrite existing benchmark reports unless explicitly instructed.

## Mission

Design and run bounded weighted telemetry only after user explicitly starts `bli-qreu`.

Goal: report route-truth selected-route portfolio savings, not forced-Blitz marketing numbers.

## Preflight

Run before any telemetry:

```bash
git status --short --branch --untracked-files=normal
git -C /home/kenzo/dev/pi-blitz status --short --branch --untracked-files=normal
tk show bli-qreu
tk ready
```

If preflight reveals new tracked dirty files outside expected ticket docs/report artifacts, pause and report.

## Scope

Telemetry must:

1. wait on prerequisite implementation/design tickets;
2. use route selector as shipped, not manually forced rows except counterfactual sections;
3. cap model/provider rows before running;
4. use Tokscale validation where benchmark method requires it;
5. compute weighted savings by edit class;
6. include only green/correct rows in selected-route savings;
7. preserve failed attempts separately;
8. keep minimal/default and advanced structural reports separate.

## Explicit non-goals

- No rerun fishing.
- No universal claim.
- No provider/model loop explosion.
- No structural `rb` in minimal profile.
- No claim from byte counts alone.
- No overwriting baseline reports.

## Suggested bounded matrix

Keep first run small enough to audit:

| Class | Purpose | Route expectation |
| --- | --- | --- |
| tiny singleton exact | prove selector routes to core/tie when Blitz loses | core or tie |
| tiny batched exact | prove batch envelope can win | route-selected |
| config/doc batch | validate class-D-ish repeated edits | route-selected |
| mixed 20 subset | portfolio approximation | route-selected |
| minimal structural attempt | must decline/advanced-only | decline/no mutation |
| advanced structural subset | only if advanced implementation exists and user permits | separate report |

Do not run advanced structural telemetry unless implementation exists and user explicitly includes it in `bli-qreu` start instruction.

## Metrics required

Report per row:

- provider/model;
- fixture/edit class;
- selected route;
- selector reason;
- correctness status;
- input tokens;
- output tokens;
- cache tokens;
- tool-call arg tokens;
- result payload tokens/bytes if available;
- resident schema/skill context tax if measurable;
- Tokscale token-match status;
- wall time secondarily;
- decline/fallback reason if not mutated.

Portfolio math:

```text
selected_route_savings = (core_tokens_baseline - selected_route_tokens) / core_tokens_baseline
weighted_savings = sum(class_weight * class_savings_green_only)
```

Keep forced-Blitz savings separate:

```text
forced_blitz_counterfactual != selected_route_product_truth
```

## Acceptance criteria

- Gate waits on prerequisites and starts from clean/understood dirty state.
- Model/provider rows are capped before execution.
- Tokscale validation used for locked/reportable rows.
- Green-only route-truth numbers are reported.
- Weighted savings by edit class is computed.
- Red rows, fallbacks, declines, no-ops, and failed attempts are visible but excluded from green savings.
- Minimal and advanced structural results are reported separately.
- No rerun fishing or universal claim.

## Suggested final report path

Use new timestamped report names, for example:

- `.pi/reports/SPRINT-I-WEIGHTED-TELEMETRY-GATE-20260620.md`
- `.pi/reports/SPRINT-I-WEIGHTED-TELEMETRY-GATE-20260620.json`

If a run root is produced, preserve it under the existing benchmark artifact convention and link it from the report.

## Start prompt for future agent

```text
Load AGENTS and kenzo-execution-preferences. Load blitz-benchmarking before any telemetry/token claim.
Start tk ticket bli-qreu only. Do not touch .tickets/bli-pg9j.md. Preserve report farm.

Read:
- .pi/docs/plans/PLAN-0.5I-token-moonshot.md
- .pi/reports/SPRINT-I-ROUTE-OPTIMIZER-TOKEN-TARGET-MATH-20260620.md
- .pi/reports/SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md
- .pi/docs/plans/PLAN-0.5I-compact-ir-v2.md
- .pi/docs/plans/PLAN-0.5I-advanced-structural-profile.md
- .pi/docs/plans/PROMPT-0.5I-weighted-telemetry-gate.md

Mission: run bounded weighted telemetry for selected-route product truth only. Cap rows first. No rerun fishing. Tokscale for locked rows. Green-only selected-route savings. Forced-Blitz counterfactual separate. Minimal/default and advanced structural separate. No universal claim. Commit/push final report and close bli-qreu only if acceptance passes.
```
