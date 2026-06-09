# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T15-29-56-978Z
Tmux session: pi-bench-2026-06-09T15-29-56-978Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-09T15-29-56-978Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 563
Tokscale validation: required
Generated: 2026-06-09T15:30:11.862Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| config/key-update | config_key_update | core | core | core_edit | core | edit | 0 | 0 | 163 | 73 | 220 | 4007 | 0 | 3 | 3724 | 8263 | edit | 10115 | 3797 | 3797 | 220 | 4007 | 0 | 2 | 3487 | yes | 100.0% | 0 |  | 0.0000 | 0.0011 |

## Profile coverage / skipped rows
full: supported 1/1; skipped 0

## Resident overhead comparison
full: schema 6595, skill 563, combined 7158, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)