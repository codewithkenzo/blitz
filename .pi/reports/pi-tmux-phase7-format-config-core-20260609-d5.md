# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T16-10-58-044Z
Tmux session: pi-bench-2026-06-09T16-10-58-044Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T16-10-58-044Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:11:49.094Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| json/config-key | json_config_key | core | core | core_edit | core | edit | 0 | 0 | 148 | 70 | 362 | 4067 | 0 | 51 | 3716 | 8484 | edit | 14035 | 3786 | 3786 | 362 | 4067 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0013 |
| yaml/config-key | yaml_config_key | core | core | core_edit | core | edit | 0 | 0 | 143 | 67 | 477 | 7647 | 0 | 98 | 197 | 8696 | edit | 17685 | 264 | 264 | 477 | 7647 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| toml/config-key | toml_config_key | core | core | core_edit | core | edit | 0 | 0 | 131 | 67 | 303 | 7564 | 0 | 8 | 189 | 8329 | edit | 17701 | 256 | 256 | 303 | 7564 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0006 |

## Profile coverage / skipped rows
full: supported 3/3; skipped 0

## Resident overhead comparison
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)