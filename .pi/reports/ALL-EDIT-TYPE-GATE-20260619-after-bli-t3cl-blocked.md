# Sprint D all edit-type gate — Zai after bli-t3cl blocked

Status: blocked
Ticket: `bli-m3sj`
Blocker: `bli-z13z`
Provider/model: `zai/glm-4.5-air`
Suffix: `20260619-after-bli-t3cl`

## Stop reason

Zai provider quota was back and rows ran, but gate validation found a harness/scenario mismatch:

- requested row files: `all-edit-types-gate / core-optimized`, `all-edit-types-gate / blitz-edit`
- reported scenario in both JSON files: `tiny-10`

This means materialized Sprint D rows E06/E07/E10/E11/E12 were not proven by the focused lock. Existing successful artifacts are preserved, but this is not a valid all edit-type pass. No rerun performed. `bli-hndl` not started.

## Aggregate if scenario mismatch ignored (not pass evidence)

- Row files: 14
- All row files accepted/correct/Tokscale-matched: yes
- Core total context: 37026
- Blitz total context: 25262
- Delta: 11764 (31.77%)

## Rows

| Requested scenario | Reported scenario | Lane | Status | Correct | Tokscale | Total ctx | Tools |
|---|---|---|---:|---:|---:|---:|---|
| all-edit-types-gate | tiny-10 | blitz-edit | accepted | yes | yes | 3789 | blitz_edit |
| all-edit-types-gate | tiny-10 | core-optimized | accepted | yes | yes | 5877 | edit |
| class-c-structural-10 | class-c-structural-10 | blitz-edit | accepted | yes | yes | 4112 | blitz_edit |
| class-c-structural-10 | class-c-structural-10 | core-optimized | accepted | yes | yes | 5247 | edit |
| class-d-config-docs-10 | class-d-config-docs-10 | blitz-edit | accepted | yes | yes | 3599 | blitz_edit |
| class-d-config-docs-10 | class-d-config-docs-10 | core-optimized | accepted | yes | yes | 5769 | edit |
| mixed-20 | mixed-20 | blitz-edit | accepted | yes | yes | 5583 | blitz_edit |
| mixed-20 | mixed-20 | core-optimized | accepted | yes | yes | 9700 | edit |
| same-file-multi | same-file-multi | blitz-edit | accepted | yes | yes | 2202 | blitz_edit |
| same-file-multi | same-file-multi | core-optimized | accepted | yes | yes | 1960 | edit |
| structural-3 | structural-3 | blitz-edit | accepted | yes | yes | 2290 | blitz_edit |
| structural-3 | structural-3 | core-optimized | accepted | yes | yes | 2750 | edit |
| tiny-10 | tiny-10 | blitz-edit | accepted | yes | yes | 3687 | blitz_edit |
| tiny-10 | tiny-10 | core-optimized | accepted | yes | yes | 5723 | edit |

## Artifacts

- Aggregate JSON: `.pi/reports/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-bli-t3cl-blocked.json`
- Row JSON/MD files: `.pi/reports/pi-tmux-true-streak-*-20260619-after-bli-t3cl.{json,md}`
- Run root: `.pi/reports/pi-accounting-runs/20260619-after-bli-t3cl/`
