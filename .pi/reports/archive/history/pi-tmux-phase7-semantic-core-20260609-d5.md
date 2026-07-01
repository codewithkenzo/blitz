# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T17-18-18-155Z
Tmux session: pi-bench-2026-06-09T17-18-18-155Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/2026-06-09T17-18-18-155Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T17:19:05.105Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 271 | 354 | 771 | 13351 | 0 | 32 | 3712 | 18845 | edit | 28983 | 4066 | 4066 | 771 | 13351 | 0 | 4 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0021 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 159 | 92 | 344 | 7630 | 0 | 11 | 188 | 8516 | edit | 17159 | 280 | 280 | 344 | 7630 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |

## Profile coverage / skipped rows
full: supported 2/2; skipped 0

## Resident overhead comparison
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)