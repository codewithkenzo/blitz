# Blitz token replacement gate final after ta7v — 2026-06-19

Status: **failed**.

## Decision

failed: minimal blitz_edit declined Class C structural row (unsupported_structural_op_minimal/no mutation). Route truth and Tokscale are valid, but default-replacement gate cannot count declined structural work as a replacement win under the plan.

## Row outcomes

| Scenario | Class | Lane | Status | Correct | Declined | Tokscale match | Total context tokens | Route tools |
|---|---|---|---|---:|---:|---:|---:|---|
| tiny-10 | A | core-optimized | accepted | yes | no | yes | 6019 | edit |
| tiny-10 | A | blitz-edit | accepted | yes | no | yes | 3867 | blitz_edit |
| mixed-20 | A/B/D | core-optimized | accepted | yes | no | yes | 10278 | edit |
| mixed-20 | A/B/D | blitz-edit | accepted | yes | no | yes | 5931 | blitz_edit |
| same-file-multi | A | core-optimized | accepted | yes | no | yes | 1991 | edit |
| same-file-multi | A | blitz-edit | accepted | yes | no | yes | 2282 | blitz_edit |
| class-b-inserts-10 | B | core-optimized | accepted | yes | no | yes | 6471 | edit |
| class-b-inserts-10 | B | blitz-edit | accepted | yes | no | yes | 4179 | blitz_edit |
| class-c-structural-10 | C | core-optimized | accepted | yes | no | yes | 5471 | edit |
| class-c-structural-10 | C | blitz-edit | declined | no | yes | yes | 4268 | blitz_edit |
| class-d-config-docs-10 | D | core-optimized | accepted | yes | no | yes | 6070 | edit |
| class-d-config-docs-10 | D | blitz-edit | accepted | yes | no | yes | 3783 | blitz_edit |

## Token accounting

Core total context: 36300
Blitz total context: 24310
Aggregate delta: 33.03%
Tokscale: all matched
Route truth: ok

Schema/skill accounting is recorded per row in JSON lock under `rows[].accounting`; profile dump and resident skill hashes are under `metadata`.

## Decline

- class-c-structural-10/blitz-edit: unsupported_structural_op_minimal; noMutation=true

## Artifact manifest

Lock JSON: .pi/reports/REPLACEMENT-GATE-LOCK-20260619-final-after-ta7v.json
Run root: .pi/reports/pi-accounting-runs/20260619-replacement-gate-final-after-ta7v/
Prior failed artifacts preserved and excluded from this decision:
- .pi/reports/REPLACEMENT-GATE-LOCK-20260619.json
- .pi/reports/REPLACEMENT-GATE-20260619.md
- .pi/reports/REPLACEMENT-GATE-LOCK-20260619-rerun-after-k296.json
- .pi/reports/REPLACEMENT-GATE-20260619-rerun-after-k296.md

## Decision impact

`bli-o1pd` acceptance is not met because a planned Class C Blitz row declined instead of replacing. `bli-qgz1` remains blocked.
