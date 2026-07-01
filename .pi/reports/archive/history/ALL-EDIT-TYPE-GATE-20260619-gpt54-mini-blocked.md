# Sprint D all edit-type gate — GPT-5.4-mini alternate blocked

Status: blocked
Ticket: `bli-m3sj`
Blocker: `bli-jv9q`
Zai blocker still open: `bli-t3cl`
Provider/model: `openai-codex/gpt-5.4-mini`
Suffix: `20260619-gpt54-mini`

User approved this alternate provider gate while Zai quota was blocked. This is provider-scoped GPT evidence only, not Zai replacement evidence.

## Stop reason

Stopped on first real stop-rule in alternate gate:

- row: `structural-3 / core-optimized`
- status: `caveated`
- correctness: `false`
- Tokscale match: `false`
- tools: `edit`

Core baseline made two edit calls. First failed because append anchor oldText was ambiguous; second mutated file but final hash still mismatched. Tokscale totals doubled vs parser totals, so accounting was not trustworthy for counted row.

No rerun performed. `bli-hndl` not started.

## Completed rows before stop

| Scenario | Lane | Status | Correct | Tokscale | Total ctx | Tools |
|---|---|---:|---:|---:|---:|---|
| class-c-structural-10 | blitz-edit | accepted | yes | yes | 3732 | blitz_edit |
| class-c-structural-10 | core-optimized | accepted | yes | yes | 3363 | edit |
| class-d-config-docs-10 | blitz-edit | accepted | yes | yes | 3212 | blitz_edit |
| class-d-config-docs-10 | core-optimized | accepted | yes | yes | 16578 | edit |
| mixed-20 | blitz-edit | accepted | yes | yes | 5168 | blitz_edit |
| mixed-20 | core-optimized | accepted | yes | yes | 9186 | edit |
| same-file-multi | blitz-edit | accepted | yes | yes | 1952 | blitz_edit |
| same-file-multi | core-optimized | accepted | yes | yes | 1598 | edit |
| structural-3 | core-optimized | caveated | no | no | 3386 | edit |
| tiny-10 | blitz-edit | accepted | yes | yes | 3440 | blitz_edit |
| tiny-10 | core-optimized | accepted | yes | yes | 26791 | edit |

## Failure artifacts

- `.pi/reports/archive/history/pi-tmux-true-streak-structural-3-core-optimized-20260619-gpt54-mini.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-structural-3-core-optimized-20260619-gpt54-mini.md`
- `.pi/reports/current/pi-accounting-runs/20260619-gpt54-mini/structural-3-core-optimized/`

## Run artifacts

- Row files: `.pi/reports/pi-tmux-true-streak-*-20260619-gpt54-mini.{json,md}`
- Run root: `.pi/reports/current/pi-accounting-runs/20260619-gpt54-mini/`
- Aggregate JSON: `.pi/reports/archive/history/ALL-EDIT-TYPE-GATE-LOCK-20260619-gpt54-mini-blocked.json`
