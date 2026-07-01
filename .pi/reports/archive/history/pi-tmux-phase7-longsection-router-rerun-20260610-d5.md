# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-10T05-35-40-122Z
Tmux session: pi-bench-2026-06-10T05-35-40-122Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/2026-06-10T05-35-40-122Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-10T05:36:05.954Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| long-section/replace-return | long_section_replace_return | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 495 | 104 | 470 | 4641 | 0 | 7 | 3013 | 11122 | pi_blitz_route_edit | 25197 | 4261 | 4261 | 470 | 4641 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0015 |

## Profile coverage / skipped rows
router: supported 1/1; skipped 0

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.