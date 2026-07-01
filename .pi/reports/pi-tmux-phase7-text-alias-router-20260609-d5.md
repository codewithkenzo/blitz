# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T16-21-17-777Z
Tmux session: pi-bench-2026-06-09T16-21-17-777Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T16-21-17-777Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:28:33.313Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 291 | 168 | 831 | 9138 | 0 | 29 | 2791 | 15704 | pi_blitz_route_edit | 21694 | 4103 | 4103 | 831 | 9138 | 0 | 3 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0020 |
| logging/insert-timer | logging_insert_timer | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 332 | 674 | 2433 | 47768 | 0 | 39 | -518 | 53690 | pi_blitz_route_edit | 96608 | 1300 | 1300 | 2433 | 47768 | 0 | 9 | 14 | yes | 0.0% | 0 |  | 0.0000 | 0.0044 |
| long-section/replace-return | long_section_replace_return | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 495 | 415 | 1796 | 25258 | 0 | 56 | -645 | 30078 | pi_blitz_route_edit | 120492 | 914 | 914 | 1796 | 25258 | 0 | 5 | 14 | yes | 0.0% | 0 |  | 0.0000 | 0.0029 |
| rename/function-name | rename_function_name | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 297 | 76 | 482 | 8016 | 0 | 74 | -782 | 10527 | pi_blitz_route_edit | 45570 | 438 | 438 | 482 | 8016 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| markdown/append-section | markdown_append_section | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 321 | 620 | 3121 | 46337 | 0 | 24 | -894 | 52437 | pi_blitz_route_edit | 95831 | 870 | 870 | 3121 | 46337 | 0 | 8 | 15 | yes | 0.0% | 0 |  | 0.0000 | 0.0050 |
| css/small-edit | css_small_edit | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 284 | 302 | 1481 | 23354 | 0 | 31 | -846 | 27196 | pi_blitz_route_edit | 36670 | 600 | 600 | 1481 | 23354 | 0 | 5 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0024 |
| html/small-edit | html_small_edit | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 300 | 80 | 514 | 8071 | 0 | 23 | -785 | 10571 | pi_blitz_route_edit | 15267 | 439 | 439 | 514 | 8071 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |

## Profile coverage / skipped rows
router: supported 4/7; skipped 3 (small/wrap-tail: core-only fixture; css/small-edit: core-only fixture; html/small-edit: core-only fixture)
full: supported 4/7; skipped 3 (small/wrap-tail: core-only fixture; css/small-edit: core-only fixture; html/small-edit: core-only fixture)

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full 84.1%; meets >=70% combined target
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.
css/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.
html/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.