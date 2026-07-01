# Sprint I — Weighted telemetry gate

Date: 2026-06-20
Ticket: `bli-qreu`
Status: bounded route-truth telemetry, no rerun fishing

## Cap fixed before execution

- Provider/model: `zai / glm-4.5-air`
- Scenarios: `tiny-exact`, `same-file-multi`, `mixed-config-doc`, `docs-heading-update`, `structural-body`
- Lanes: `core` baseline + `route` selected-route only
- Iterations: 1
- Timeout: 120000 ms
- Max model runs: 10
- Tokscale: validate
- Forced-Blitz counterfactual: not run
- Advanced structural telemetry: skipped; user did not explicitly permit it
- Run root: `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate`

## Result

Weighted selected-route savings: **-15.13%**.

This bounded run is not publishable as a positive savings claim. Route-truth portfolio was token-negative because Zai `tiny-exact` selected Blitz and actual session tokens exceeded core. Green rows remain visible; failed/declined structural row excluded from green savings.

## Per-row telemetry

| Scenario | Lane | Selected route | Reason | Correct | Accepted | Route outcome | Input | Output | Cache read | Cache write | Total | Tokscale | Wall ms |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: |
| tiny-exact | core | blitz | blitz_tie_or_win | true | true | core_fallback | 1105 | 72 | 768 | 0 | 1945 | ok/true | 5742 |
| tiny-exact | route | blitz | blitz_tie_or_win | true | true | blitz_success | 1224 | 118 | 2432 | 0 | 3774 | ok/true | 10234 |
| same-file-multi | core | blitz | blitz_tie_or_win | true | true | core_fallback | 749 | 267 | 1664 | 0 | 2680 | ok/true | 34234 |
| same-file-multi | route | blitz | blitz_tie_or_win | true | true | blitz_success | 701 | 194 | 1408 | 0 | 2303 | ok/true | 7110 |
| mixed-config-doc | core | blitz | blitz_tie_or_win | true | true | core_fallback | 610 | 94 | 1536 | 0 | 2240 | ok/true | 6319 |
| mixed-config-doc | route | blitz | blitz_tie_or_win | true | true | blitz_success | 554 | 82 | 1408 | 0 | 2044 | ok/true | 5519 |
| docs-heading-update | core | core | core_cheaper_tiny_floor | true | true | core_fallback | 394 | 67 | 1408 | 0 | 1869 | ok/true | 5325 |
| docs-heading-update | route | core | core_cheaper_tiny_floor | true | true | core_fallback | 384 | 57 | 1408 | 0 | 1849 | ok/true | 7569 |
| structural-body | core | decline | minimal_structural_declined_advanced_only | true | true | core_fallback | 2893 | 1734 | 2304 | 0 | 6931 | ok/true | 25452 |
| structural-body | route | decline | minimal_structural_declined_advanced_only | false | false | decline | 2139 | 82 | 3712 | 0 | 5933 | ok/true | 8417 |

## Weighted savings math

Weights declared before analysis for executed bounded portfolio: tiny exact 0.30, same-file multi 0.20, config/doc total 0.35 split across two rows, minimal structural decline 0.15. Declined/non-green rows contribute zero savings.

| Scenario | Weight | Core tokens | Selected tokens | Selected route | Green included | Savings |
| --- | ---: | ---: | ---: | --- | --- | ---: |
| tiny-exact | 0.3 | 1945 | 3774 | blitz | true | -94.0% |
| same-file-multi | 0.2 | 2680 | 2303 | blitz | true | 14.1% |
| mixed-config-doc | 0.175 | 2240 | 2044 | blitz | true | 8.8% |
| docs-heading-update | 0.175 | 1869 | 1849 | core | true | 1.1% |
| structural-body | 0.15 | 6931 | 5933 | decline | false | 0.0% |

Formula: `sum(weight * (core_tokens - selected_route_tokens_green_only)) / sum(weight * core_tokens)`

- Numerator: -435.50
- Denominator: 2878.22
- Weighted savings: -15.13%

## Required notes

- Selected-route product truth only; no forced-Blitz marketing number.
- Tokscale matched every row.
- Minimal/default structural result separate: `structural-body` selected `decline`, route row non-green, no mutation success claim.
- Advanced structural report: not run, not permitted by start instruction.
- Red/fallback/decline/no-op visibility preserved in JSON row artifacts and run dirs.
- Existing .pi/reports/artifacts preserved; new timestamped harness outputs only.

## Source artifact reports

- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-11-17-533Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-11-26-014Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-11-36-359Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-10-704Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-17-928Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-24-371Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-30-004Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-35-442Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-12-43-115Z.json`
- `.pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate/natural-edit-harness/natural-edit-2026-06-20T09-13-08-669Z.json`
