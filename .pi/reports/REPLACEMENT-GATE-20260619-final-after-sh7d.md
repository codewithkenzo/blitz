# Blitz token replacement gate final after sh7d — 2026-06-19

Status: **passed**.

## Decision

passed: final-after-sh7d lock met correctness, route, Tokscale, aggregate token, and tiny overhead gates.

## Row outcomes

| Scenario | Class | Lane | Status | Correct | Declined | Tokscale match | Total context tokens | Route tools |
|---|---|---|---|---:|---:|---:|---:|---|
| tiny-10 | A | core-optimized | accepted | yes | no | yes | 5950 | edit |
| tiny-10 | A | blitz-edit | accepted | yes | no | yes | 3890 | blitz_edit |
| mixed-20 | A/B/D | core-optimized | accepted | yes | no | yes | 10133 | edit |
| mixed-20 | A/B/D | blitz-edit | accepted | yes | no | yes | 5911 | blitz_edit |
| same-file-multi | A | core-optimized | accepted | yes | no | yes | 1982 | edit |
| same-file-multi | A | blitz-edit | accepted | yes | no | yes | 2249 | blitz_edit |
| class-b-inserts-10 | B | core-optimized | accepted | yes | no | yes | 6623 | edit |
| class-b-inserts-10 | B | blitz-edit | accepted | yes | no | yes | 4127 | blitz_edit |
| class-c-structural-10 | C | core-optimized | accepted | yes | no | yes | 5415 | edit |
| class-c-structural-10 | C | blitz-edit | accepted | yes | no | yes | 4238 | blitz_edit |
| class-d-config-docs-10 | D | core-optimized | accepted | yes | no | yes | 5991 | edit |
| class-d-config-docs-10 | D | blitz-edit | accepted | yes | no | yes | 3726 | blitz_edit |

## Token accounting

Core total context: 36094
Blitz total context: 24141
Aggregate delta: 33.12%
Tiny guard: core 5950, Blitz 3890 (pass)
Tokscale: all matched
Route truth: ok

## Class C result

class-c-structural-10/blitz-edit: accepted; correct=true; declined=false; tools=blitz_edit

## Artifact manifest

Lock JSON: .pi/reports/REPLACEMENT-GATE-LOCK-20260619-final-after-sh7d.json
Run root: .pi/reports/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/

Row JSON/MD files:
- .pi/reports/pi-tmux-true-streak-tiny-10-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-tiny-10-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-mixed-20-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-mixed-20-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-mixed-20-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-mixed-20-blitz-edit-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-same-file-multi-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-same-file-multi-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-b-inserts-10-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-b-inserts-10-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-b-inserts-10-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-b-inserts-10-blitz-edit-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-c-structural-10-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-c-structural-10-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-c-structural-10-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-c-structural-10-blitz-edit-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-d-config-docs-10-core-optimized-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-d-config-docs-10-core-optimized-20260619-final-after-sh7d.md
- .pi/reports/pi-tmux-true-streak-class-d-config-docs-10-blitz-edit-20260619-final-after-sh7d.json / .pi/reports/pi-tmux-true-streak-class-d-config-docs-10-blitz-edit-20260619-final-after-sh7d.md

Prior failed artifacts preserved and excluded from this decision:
- .pi/reports/REPLACEMENT-GATE-LOCK-20260619.json
- .pi/reports/REPLACEMENT-GATE-20260619.md
- .pi/reports/REPLACEMENT-GATE-LOCK-20260619-rerun-after-k296.json
- .pi/reports/REPLACEMENT-GATE-20260619-rerun-after-k296.md
- .pi/reports/REPLACEMENT-GATE-LOCK-20260619-final-after-ta7v.json
- .pi/reports/REPLACEMENT-GATE-20260619-final-after-ta7v.md

## Decision impact

`bli-o1pd` acceptance is met by this lock. `bli-qgz1` was not started.
