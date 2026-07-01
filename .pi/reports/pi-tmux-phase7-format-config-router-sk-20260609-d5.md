# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T16-09-39-628Z
Tmux session: pi-bench-2026-06-09T16-09-39-628Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T16-09-39-628Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:10:48.830Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| json/config-key | json_config_key | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 271 | 66 | 500 | 8023 | 0 | 26 | -793 | 10447 | pi_blitz_route_edit | 15594 | 417 | 417 | 500 | 8023 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| yaml/config-key | yaml_config_key | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 268 | 68 | 504 | 8064 | 0 | 27 | -803 | 10484 | pi_blitz_route_edit | 25136 | 409 | 409 | 504 | 8064 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| toml/config-key | toml_config_key | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 259 | 70 | 537 | 8040 | 0 | 31 | -810 | 10485 | pi_blitz_route_edit | 26480 | 404 | 404 | 537 | 8040 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |

## Profile coverage / skipped rows
router: supported 3/3; skipped 0
full: supported 3/3; skipped 0

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full 84.1%; meets >=70% combined target
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.