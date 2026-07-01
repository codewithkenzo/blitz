# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T09-07-19-618Z
Tmux session: pi-bench-2026-06-09T09-07-19-618Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/2026-06-09T09-07-19-618Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 563
Tokscale validation: required
Generated: 2026-06-09T09:08:06.602Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | router | token_router | router | pi_blitz_route_edit | 564 | 563 | 400 | 75 | 477 | 8170 | 0 | 21 | -651 | 10821 | pi_blitz_route_edit | 46239 | 551 | 551 | 477 | 8170 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |

## Profile coverage / skipped rows
router: supported 1/1; skipped 0
full: supported 1/1; skipped 0

## Resident overhead comparison
router: schema 564, skill 563, combined 1127, reduction vs full 84.3%; meets >=70% combined target
full: schema 6595, skill 563, combined 7158, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.