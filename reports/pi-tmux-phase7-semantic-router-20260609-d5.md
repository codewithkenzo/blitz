# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T17-19-12-655Z
Tmux session: pi-bench-2026-06-09T17-19-12-655Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-09T17-19-12-655Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T17:19:52.604Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 400 | 75 | 573 | 8256 | 0 | 33 | -663 | 11037 | pi_blitz_route_edit | 22664 | 556 | 556 | 573 | 8256 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0010 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 300 | 87 | 434 | 8023 | 0 | 7 | -790 | 10436 | pi_blitz_route_edit | 16368 | 441 | 441 | 434 | 8023 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |

## Profile coverage / skipped rows
router: supported 2/2; skipped 0

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.