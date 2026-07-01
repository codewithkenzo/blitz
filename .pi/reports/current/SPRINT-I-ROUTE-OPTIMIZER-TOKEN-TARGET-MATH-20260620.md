# Sprint I — Route optimizer token target math

Date: 2026-06-20
Ticket: `bli-6gb1`
Status: publishable architecture/report slice, no model reruns

## Inputs

Existing artifacts only:

- `.pi/reports/SPRINT-F-GREEN-ROW-TOKEN-REGRESSION-20260620.{md,json}`
- `.pi/reports/SPRINT-F-IMPACT-SURVEY-20260620.{md,json}`
- `.pi/reports/SPRINT-G-POSTFIX-TELEMETRY-20260620.{md,json}`
- `.pi/reports/archive/history/ALL-EDIT-TYPE-GATE-20260619-after-z13z.md`
- `.pi/reports/archive/history/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-z13z.json`

No provider/model benchmark loops ran for this report.

## Executive answer

60–80% savings is not credible for every edit. It is credible only for route-selected classes where core must replay large unchanged text and Blitz can use compact refs/IR.

Product target must be router savings, not forced-Blitz savings:

> Router chooses cheapest safe route. Blitz gets selected only where it ties/wins or provides required safety/capability. Core remains correct route for tiny floor rows when cheaper.

## Current evidence snapshot

| Artifact | Row/class | Core tokens | Blitz tokens | Delta | Meaning |
| --- | ---: | ---: | ---: | ---: | --- |
| Sprint G postfix | OpenAI tiny exact | 1554 | 1556 | +2 / +0.1% | tiny floor; core cheaper |
| Sprint G postfix | Zai tiny exact | 2054 | 1769 | -285 / -13.9% | provider-specific tiny win |
| Sprint F impact | Zai same-file multi | 2493 | 2321 | -172 / -6.9% | simple multi can win |
| Sprint F impact | OpenAI same-file multi | 2162 | 2124 | -38 / -1.8% | near tie/win |
| Sprint F impact | Zai doc comments | 2074 | 1808 | -266 / -12.8% | config/doc-style compact wins |
| Sprint F impact | Zai config env | 1993 | 1747 | -246 / -12.3% | config/doc-style compact wins |
| Sprint F impact | OpenAI doc comments | 1572 | 1576 | +4 / +0.3% | core/tie route |
| Sprint F impact | OpenAI config env | 1479 | 1526 | +47 / +3.2% | core route |
| All edit type gate | tiny-10 | 5581 | 3589 | -1992 / -35.7% | repeated simple edits scale |
| All edit type gate | class-d-config-docs-10 | 5627 | 3505 | -2122 / -37.7% | doc/config batch scales |
| All edit type gate | mixed-20 | 9407 | 5415 | -3992 / -42.4% | multi-edit/mixed batch strongest current green |
| All edit type gate | all-edit-types-gate | 4525 | 3391 | -1134 / -25.1% | broad green row |
| All edit type gate | structural-3 | 2703 | 2255 | -448 / -16.6% | structural evidence exists, but minimal route must not claim it |
| All edit type gate | class-c-structural-10 | 5135 | 4033 | -1102 / -21.5% | advanced-only evidence seed |

Resident floor from Sprint F regression: `schemaTokens=419`, `skillTokens=268`; Sprint D lock baseline `schemaTokens=350`, `skillTokens=268`.

## Achievable token bands by edit class

Bands below are route-selected, correctness-gated, green-row-only targets. They are not universal Blitz claims.

| Class | Current measured band | Plausible near-term band | 60–80% plausible? | Route stance |
| --- | ---: | ---: | --- | --- |
| Tiny exact | OpenAI +0.1% loss; Zai -13.9% win; Sprint F OpenAI +2.1% loss, Zai -8.3% but red | 0–15% provider-dependent; often 0% via core | No. Irreducible floor dominates. | Choose core when predicted cheaper; Blitz only tie/win. |
| Same-file multi | -6.9% Zai, -1.8% OpenAI; one gate row +11.6% loss | 0–25%; 30–50% only when N grows and args stay compact | Sometimes at high N, not small N. | Blitz if budget predicts win/tie; otherwise core. |
| Config/doc | Zai -12.3% to -12.8%; OpenAI +0.3% to +3.2% loss; config-docs-10 -37.7% | 10–45% current; 40–65% with zero resident/compact IR and batch scale | Yes for repeated config/doc batches, not one-line config. | Blitz for batched/simple doc/config wins; core for tiny singletons. |
| Large exact | Not isolated in named artifacts; mixed/tiny batch rows imply replay avoidance value | 35–70% if core replays large old/new text and Blitz args stay anchor/ref-sized | Yes when unchanged-code replay dominates. | Blitz/advanced when exact anchor is safe and budget wins. |
| Multi-file / multi-edit | mixed-20 -42.4%; tiny-10 -35.7% | 35–70%; 60–80% if many edits share one compact envelope and core repeats file/context text | Yes, strongest minimal-profile moonshot class. | Blitz selected when deterministic budget wins; keep result compact. |
| Symbol / structural advanced | structural-3 -16.6%; class-c-structural-10 -21.5%; Sprint F/G structural-body red/declined in minimal | 20–50% after advanced route; 50–80% for large body/symbol edits if correctness locks | Yes only in explicit advanced profile. | Minimal declines `rb`; advanced route separate with capability matrix. |
| Safety decline / unsupported | No savings claim | N/A | No | Decline/fallback not counted as Blitz success. |

## Where 60–80% is mathematically plausible

Rows/families from current artifacts that justify further moonshot work:

1. `mixed-20` — already -42.4% green. If compact IR v2 removes more arg/output tax and zero-resident removes schema/skill floor, same class can approach 60%.
2. `class-d-config-docs-10` — already -37.7% green. Repeated doc/config edits with stable anchors can plausibly reach 60% when core old/new replay grows.
3. `tiny-10` — already -35.7% green despite tiny individual edits. Batch envelope, not tiny singleton, creates savings.
4. Future `large exact` rows — plausible because core token cost grows with oldText/newText size while compact Blitz can grow by path + anchor + replacement only. Needs isolated fixture before claim.
5. Future advanced `symbol/body` rows — plausible because symbol refs can avoid unchanged body replay. Current structural-body evidence is not green enough for minimal claim; keep advanced-only.

Rows/families where 60–80% is not plausible now:

- OpenAI tiny exact: +2 tokens / +0.1% after Sprint G means core wins.
- Any singleton tiny exact where old/new text is already short.
- Minimal structural `rb`: currently declined/advanced-only; no minimal savings claim.
- Any red row, fallback, no-op, or safety decline.

## Route decision formula

For each edit request, compute eligible routes first, then choose cheapest safe predicted route.

```text
eligible(route, edit) =
  route.capability supports edit.class
  && route.profile allows edit.operation
  && route.safety accepts path/language/anchor
  && route.correctnessGate is green for comparable class/provider/profile

predictedTokens(route, edit) =
  residentTax(route.profile)
  + promptTax(route.promptShape, edit.class)
  + argTax(route.ir, edit.size, edit.count, edit.fileCount)
  + expectedOutputTax(route.outputShape, edit.class)
  + resultPayloadTax(route.resultShape)
  + cacheNormalizedTax(route.provider)
  + riskPenalty(route.failureRate, route.fallbackChance)

selectedRoute = min(predictedTokens(route, edit)) over eligible routes
```

Policy overlays:

```text
if edit.operation is structural and profile is minimal:
  selectedRoute = decline_advanced_only

if selectedRoute is Blitz and predictedTokens(Blitz) > predictedTokens(core):
  selectedRoute = core unless Blitz is required for safety/capability

if route fails, falls back, noops unexpectedly, or produces incorrect output:
  count as non-green; exclude from savings numerator
```

Deterministic route reasons should be one of:

- `core_cheaper_tiny_floor`
- `blitz_tie_or_win`
- `blitz_required_safety_or_capability`
- `minimal_structural_declined_advanced_only`
- `unsupported_declined`
- `non_green_excluded`

## Weighted savings target formula

Use weighted real-edit mix, not cherry-picked rows.

Per-row route savings:

```text
rowSavings_i =
  if row.correct && row.accepted && selectedRoute_i != declined:
    (coreGreenTokens_i - selectedGreenTokens_i) / coreGreenTokens_i
  else:
    0
```

Weighted portfolio savings:

```text
weightedSavings =
  sum_i(weight_i * (coreGreenTokens_i - selectedGreenTokens_i))
  / sum_i(weight_i * coreGreenTokens_i)
```

Where:

- `selectedGreenTokens_i` may be core tokens when core is cheapest;
- core-selected rows contribute `0` savings, not Blitz loss;
- red/fallback/incorrect/noop/decline rows contribute `0` savings and cannot be used as wins;
- structural rows are excluded from minimal profile weights until advanced profile is separately locked;
- weights must be declared by edit class, provider, language, and row frequency.

Suggested first telemetry weights for Gate B:

```text
tinyExact: 0.30
sameFileMulti: 0.20
configDoc: 0.20
largeExact: 0.15
multiFileMultiEdit: 0.15
structuralAdvanced: 0.00  # minimal profile only
```

Advanced-profile telemetry should run separately:

```text
symbolStructuralAdvanced: 1.00 within advanced report only
```

## Forbidden claim wording

Do not say:

- "Blitz saves 60–80% everywhere."
- "Blitz is universal core edit replacement."
- "Blitz beats core on all providers/languages."
- "Minimal profile supports structural body replacement."
- "Declines/fallbacks/noops are Blitz successes."
- "Token savings proven from wall time, byte counts, or tokenizer estimates."

Allowed wording before Gate B telemetry:

> Existing green artifacts show route-selected savings up to 42.4% on mixed multi-edit batches and 37.7% on config/doc batches. 60–80% is plausible only for scaled multi-edit, large exact, or future advanced structural rows where compact Blitz IR avoids core unchanged-code replay. Tiny exact remains floor-limited and should route to core when core is cheaper.

Allowed wording after route selector implementation, before model reruns:

> Deterministic route policy prevents forced-Blitz losses: tiny exact can select core, minimal structural declines to advanced-only, and Blitz is eligible only when predicted to tie/win or required for safety/capability.

## Next implementation implications

For `bli-qn4t`:

1. Add deterministic selector output: selected route + reason.
2. Tiny exact: core when predicted cheaper.
3. Simple multi/config/doc: allow Blitz when budget predicts tie/win.
4. Minimal structural: decline/advanced-only; never `rb` in minimal.
5. Report selected-route savings, not forced-Blitz savings.
6. Add self-checks that fail if OpenAI tiny exact is forced through Blitz despite +2 token loss.

For `bli-cwfj`:

1. Measure resident floor separately from per-call args/output.
2. Prioritize schema/skill/output tax removal before new operations.
3. Any zero-resident proposal must prove deterministic prompt-shape/token guard deltas without model reruns.

For `bli-qreu` later:

1. Run weighted telemetry only after selector is merged.
2. Report selected-route portfolio savings and forced-Blitz counterfactual separately.
3. Keep minimal and advanced structural reports separate.
