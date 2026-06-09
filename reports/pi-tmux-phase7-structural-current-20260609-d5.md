# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T17-11-08-935Z
Tmux session: pi-bench-2026-06-09T17-11-08-935Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-09T17-11-08-935Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T17:13:11.522Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | ast_narrow | full | pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 6595 | 580 | 4784 | 1088 | 3433 | 150974 | 0 | 169 | 408 | 176294 | pi_blitz_wrap_body | 101193 | 8671 | 8671 | 3433 | 150974 | 0 | 16 | 13 | yes | 0.0% | 0 |  | 0.0000 | 0.0100 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | full | pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 6595 | 580 | 4891 | 115 | 754 | 9170 | 0 | 59 | 1459 | 30913 | pi_blitz_patch | 20193 | 8749 | 8749 | 754 | 9170 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0029 |

## Profile coverage / skipped rows
full: supported 2/2; skipped 0

## Resident overhead comparison
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.