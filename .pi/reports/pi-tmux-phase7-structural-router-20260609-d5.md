# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T17-13-32-066Z
Tmux session: pi-bench-2026-06-09T17-13-32-066Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T17-13-32-066Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T17:18:08.329Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 4798 | 656 | 2202 | 80757 | 0 | 194 | 7357 | 98908 | pi_blitz_route_edit | 95204 | 9157 | 9157 | 2202 | 80757 | 0 | 9 | 19 | yes | 0.0% | 0 |  | 0.0000 | 0.0067 |
| multi/large-structural | multi_body_large_structural | blitz | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 4897 | 1699 | 5051 | 215005 | 0 | 0 | 3225 | 233864 | pi_blitz_route_edit | 180229 | 6068 | 6068 | 5051 | 215005 | 0 | 19 | 15 | yes | 0.0% | -1 | [pi-blitz] tool profile router registered | 0.0000 | 0.0132 |

## Profile coverage / skipped rows
router: supported 2/2; skipped 0

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.