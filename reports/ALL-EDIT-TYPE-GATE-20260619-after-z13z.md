# Sprint D all edit-type gate — Zai after bli-z13z

Status: pass
Ticket: `bli-m3sj`
Provider/model: `zai/glm-4.5-air`
Suffix: `20260619-after-z13z`
Run root: `reports/pi-accounting-runs/20260619-after-z13z/`

## Evidence

- Preflight self-check: `all-edit-type self-check passed: rows=18 classes=18 success=12 safety=6`
- Row files: 14
- All row files accepted/correct/Tokscale-matched: yes
- Scenario mismatch fixed for `all-edit-types-gate`: yes
- Hidden fallback in Blitz rows: no
- Schema/skill accounting present in Blitz rows: yes
- Safety rows E13-E18: registry/materialization self-check green; no separate claim audit started.

## Token totals for this lock only

- Core total context: 34923
- Blitz total context: 24358
- Delta: 10565 (30.25%)

## Rows

| Requested scenario | Reported scenario | Lane | Status | Correct | Tokscale | Total ctx | Schema | Skill | Tools |
|---|---|---|---:|---:|---:|---:|---:|---:|---|
| all-edit-types-gate | all-edit-types-gate | core-optimized | accepted | yes | yes | 4525 | 0 | 0 | edit |
| all-edit-types-gate | all-edit-types-gate | blitz-edit | accepted | yes | yes | 3391 | 350 | 268 | blitz_edit |
| tiny-10 | tiny-10 | core-optimized | accepted | yes | yes | 5581 | 0 | 0 | edit |
| tiny-10 | tiny-10 | blitz-edit | accepted | yes | yes | 3589 | 350 | 268 | blitz_edit |
| same-file-multi | same-file-multi | core-optimized | accepted | yes | yes | 1945 | 0 | 0 | edit |
| same-file-multi | same-file-multi | blitz-edit | accepted | yes | yes | 2170 | 350 | 268 | blitz_edit |
| mixed-20 | mixed-20 | core-optimized | accepted | yes | yes | 9407 | 0 | 0 | edit |
| mixed-20 | mixed-20 | blitz-edit | accepted | yes | yes | 5415 | 350 | 268 | blitz_edit |
| class-d-config-docs-10 | class-d-config-docs-10 | core-optimized | accepted | yes | yes | 5627 | 0 | 0 | edit |
| class-d-config-docs-10 | class-d-config-docs-10 | blitz-edit | accepted | yes | yes | 3505 | 350 | 268 | blitz_edit |
| class-c-structural-10 | class-c-structural-10 | core-optimized | accepted | yes | yes | 5135 | 0 | 0 | edit |
| class-c-structural-10 | class-c-structural-10 | blitz-edit | accepted | yes | yes | 4033 | 350 | 268 | blitz_edit |
| structural-3 | structural-3 | core-optimized | accepted | yes | yes | 2703 | 0 | 0 | edit |
| structural-3 | structural-3 | blitz-edit | accepted | yes | yes | 2255 | 350 | 268 | blitz_edit |

## Artifacts

- Aggregate JSON: `reports/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-z13z.json`
- Row JSON/MD files: `reports/pi-tmux-true-streak-*-20260619-after-z13z.{json,md}`
- Run root: `reports/pi-accounting-runs/20260619-after-z13z/`

## Boundaries

- Does not use invalid `20260619-after-bli-t3cl` run for token claims.
- Does not start `bli-hndl` claim audit.
