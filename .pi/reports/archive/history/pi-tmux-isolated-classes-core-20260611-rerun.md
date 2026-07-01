# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: spawn
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/2026-06-11T19-21-20-322Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 268
Tokscale validation: required
Generated: 2026-06-11T19:23:41.706Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| config/key-update | config_key_update | core | core | core_edit | core | edit | 0 | 0 | 135 | 45 | 67 | 7283 | 0 | 3 | 143 | 7721 | edit | 5419 | 188 | 188 | 67 | 7283 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |
| logging/insert-timer | logging_insert_timer | core | core | core_edit | core | edit | 0 | 0 | 155 | 65 | 79 | 7315 | 0 | 0 | 128 | 7807 | edit | 5382 | 193 | 193 | 79 | 7315 | 0 | 2 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |
| markdown/append-section | markdown_append_section | core | core | core_edit | core | edit | 0 | 0 | 146 | 60 | 79 | 7308 | 0 | 3 | 132 | 7788 | edit | 5835 | 192 | 192 | 79 | 7308 | 0 | 2 | 15 | yes | 0.0% | 0 |  | 0.0000 | 0.0003 |
| json/config-key | json_config_key | core | core | core_edit | core | edit | 0 | 0 | 121 | 1677 | 2262 | 215761 | 0 | 0 | 116 | 221614 | edit | 120111 | 1793 | 1793 | 2262 | 215761 | 0 | 39 | 18 | yes | 100.0% | 143 |  | 0.0000 | 0.0093 |
| toml/config-key | toml_config_key | core | core | core_edit | core | edit | 0 | 0 | 101 | 37 | 58 | 7243 | 0 | 3 | 107 | 7586 | edit | 4011 | 144 | 144 | 58 | 7243 | 0 | 2 | 23 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |

## Profile coverage / skipped rows
full: supported 5/5; skipped 0

## Resident overhead comparison
full: schema 6595, skill 268, combined 6863, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)