# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T15-39-51-071Z
Tmux session: pi-bench-2026-06-09T15-39-51-071Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-09T15-39-51-071Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T15:41:51.721Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| config/key-update | config_key_update | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 290 | 1146 | 3383 | 91317 | 0 | 0 | -1087 | 98483 | pi_blitz_route_edit | 120188 | 1203 | 1203 | 3383 | 91317 | 0 | 15 | 16 | yes | 0.0% | -1 | [pi-blitz] tool profile router registered | 0.0000 | 0.0067 |

## Profile coverage / skipped rows
router: supported 1/1; skipped 0
full: supported 1/1; skipped 0

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full 84.1%; meets >=70% combined target
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.