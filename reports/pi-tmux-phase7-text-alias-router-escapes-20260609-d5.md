# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-09T16-43-10-050Z
Tmux session: pi-bench-2026-06-09T16-43-10-050Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-09T16-43-10-050Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:48:11.972Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 291 | 85 | 505 | 4419 | 0 | 25 | 2856 | 10554 | pi_blitz_route_edit | 12673 | 4085 | 4085 | 505 | 4419 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0015 |
| logging/insert-timer | logging_insert_timer | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 332 | 591 | 2222 | 42226 | 0 | 30 | -966 | 47314 | pi_blitz_route_edit | 54817 | 769 | 769 | 2222 | 42226 | 0 | 8 | 14 | yes | 0.0% | 0 |  | 0.0000 | 0.0039 |
| long-section/replace-return | long_section_replace_return | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 495 | 104 | 523 | 8327 | 0 | 5 | -608 | 11238 | pi_blitz_route_edit | 17004 | 640 | 640 | 523 | 8327 | 0 | 2 | 15 | yes | 0.0% | 0 |  | 0.0000 | 0.0010 |
| rename/function-name | rename_function_name | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 297 | 76 | 482 | 8061 | 0 | 17 | -782 | 10515 | pi_blitz_route_edit | 14606 | 438 | 438 | 482 | 8061 | 0 | 2 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| markdown/append-section | markdown_append_section | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 321 | 91 | 448 | 8064 | 0 | 24 | -771 | 10556 | pi_blitz_route_edit | 13668 | 464 | 464 | 448 | 8064 | 0 | 2 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| css/small-edit | css_small_edit | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 284 | 74 | 471 | 8047 | 0 | 23 | -795 | 10466 | pi_blitz_route_edit | 14826 | 423 | 423 | 471 | 8047 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| html/small-edit | html_small_edit | core | router | token_router | router | pi_blitz_route_edit | 564 | 580 | 300 | 1352 | 4717 | 133583 | 0 | 45 | -1022 | 142615 | pi_blitz_route_edit | 170837 | 1474 | 1474 | 4717 | 133583 | 0 | 19 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0095 |

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