# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T16-48-30-368Z
Tmux session: pi-bench-2026-06-09T16-48-30-368Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: router
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T16-48-30-368Z
Visible Blitz tools: pi_blitz_route_edit
Serialized tool spec tokens: 564
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-09T16:50:11.522Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | core_edit | core | edit | 0 | 0 | 148 | 79 | 406 | 4130 | 0 | 24 | 3708 | 8574 | edit | 10751 | 3787 | 3787 | 406 | 4130 | 0 | 2 | 18 | yes | 100.0% | 0 |  | 0.0000 | 0.0013 |
| logging/insert-timer | logging_insert_timer | core | core | core_edit | core | edit | 0 | 0 | 185 | 95 | 445 | 7752 | 0 | 8 | 205 | 8785 | edit | 11127 | 300 | 300 | 445 | 7752 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| long-section/replace-return | long_section_replace_return | core | core | core_edit | core | edit | 0 | 0 | 331 | 97 | 410 | 7864 | 0 | 6 | 359 | 9164 | edit | 9181 | 456 | 456 | 410 | 7864 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0000 | 0.0008 |
| rename/function-name | rename_function_name | core | core | core_edit | core | edit | 0 | 0 | 165 | 80 | 378 | 7670 | 0 | 18 | 207 | 8598 | edit | 12513 | 287 | 287 | 378 | 7670 | 0 | 2 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |
| markdown/append-section | markdown_append_section | core | core | core_edit | core | edit | 0 | 0 | 174 | 88 | 480 | 7780 | 0 | 31 | 208 | 8849 | edit | 17161 | 296 | 296 | 480 | 7780 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0000 | 0.0008 |
| css/small-edit | css_small_edit | core | core | core_edit | core | edit | 0 | 0 | 151 | 68 | 383 | 7665 | 0 | 23 | 201 | 8559 | edit | 22119 | 269 | 269 | 383 | 7665 | 0 | 2 | 17 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |
| html/small-edit | html_small_edit | core | core | core_edit | core | edit | 0 | 0 | 159 | 76 | 261 | 7563 | 0 | 0 | 201 | 8336 | edit | 14728 | 277 | 277 | 261 | 7563 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0006 |

## Profile coverage / skipped rows
router: supported 4/7; skipped 3 (small/wrap-tail: core-only fixture; css/small-edit: core-only fixture; html/small-edit: core-only fixture)
full: supported 4/7; skipped 3 (small/wrap-tail: core-only fixture; css/small-edit: core-only fixture; html/small-edit: core-only fixture)

## Resident overhead comparison
router: schema 564, skill 580, combined 1144, reduction vs full 84.1%; meets >=70% combined target
full: schema 6595, skill 580, combined 7175, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.
css/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.
html/small-edit: core-only cost/control smoke; no Blitz structured AST savings claim.