# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T16-29-01-030Z
Tmux session: pi-bench-2026-06-09T16-29-01-030Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T16-29-01-030Z
Visible Blitz tools: pi_blitz_route_edit,pi_blitz_op,pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 6595
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:30:19.585Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | core_edit | core | edit | 0 | 0 | 148 | 104 | 299 | 4070 | 0 | 3 | 3683 | 8411 | edit | 18695 | 3787 | 3787 | 299 | 4070 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0012 |
| rename/function-name | rename_function_name | core | core | core_edit | core | edit | 0 | 0 | 165 | 80 | 353 | 7660 | 0 | 3 | 207 | 8548 | edit | 10392 | 287 | 287 | 353 | 7660 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |
| css/small-edit | css_small_edit | core | core | core_edit | core | edit | 0 | 0 | 151 | 70 | 343 | 7617 | 0 | 28 | 199 | 8478 | edit | 33332 | 269 | 269 | 343 | 7617 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |
| html/small-edit | html_small_edit | core | core | core_edit | core | edit | 0 | 0 | 159 | 78 | 342 | 7606 | 0 | 30 | 199 | 8492 | edit | 11399 | 277 | 277 | 342 | 7606 | 0 | 2 | 3350 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |

## Profile coverage / skipped rows
full: supported 1/4; skipped 3 (small/wrap-tail: core-only fixture; css/small-edit: core-only fixture; html/small-edit: core-only fixture)

## Resident overhead comparison
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.
css/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.
html/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.