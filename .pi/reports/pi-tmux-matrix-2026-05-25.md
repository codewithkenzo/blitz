# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-05-25T06-04-14-732Z
Tmux session: pi-bench-2026-05-25T06-04-14-732Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T06:11:36.751Z

| Fixture | Class | Recommended | Lane | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | blitz | pi_blitz_replace_body_span | 39890 | 5335 | 461 | 6503 | 0 | 81 | 5335 | 461 | 6503 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0000 | 0.0018 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | pi_blitz_replace_body_span | 26904 | 7521 | 441 | 8540 | 0 | 76 | 7521 | 441 | 8540 | 0 | 2 | 34 | yes | 100.0% | 0 |  | 0.0000 | 0.0022 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | pi_blitz_wrap_body | 120163 | 5080 | 2205 | 47937 | 0 | 606 | 5080 | 2205 | 47937 | 0 | 6 | 32 | yes | 0.0% | -1 |  | 0.0000 | 0.0049 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | pi_blitz_compose_body | 37239 | 7992 | 776 | 8586 | 0 | 198 | 7992 | 776 | 8586 | 0 | 2 | 41 | yes | 100.0% | 0 |  | 0.0000 | 0.0027 |
| medium-10k/insert-body-span | insert_body_span | blitz | blitz | pi_blitz_insert_body_span | 20626 | 7964 | 419 | 8327 | 0 | 101 | 7964 | 419 | 8327 | 0 | 2 | 68 | yes | 0.0% | 0 |  | 0.0000 | 0.0023 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | pi_blitz_multi_body | 24386 | 3534 | 635 | 4121 | 0 | 176 | 3534 | 635 | 4121 | 0 | 2 | 62 | yes | 100.0% | 0 |  | 0.0000 | 0.0015 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | pi_blitz_patch | 22660 | 5218 | 709 | 11450 | 0 | 115 | 5218 | 709 | 11450 | 0 | 2 | 68 | yes | 100.0% | 0 |  | 0.0000 | 0.0022 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | pi_blitz_replace_body_span | 30849 | 49031 | 490 | 55296 | 0 | 79 | 49031 | 490 | 55296 | 0 | 2 | 35 | yes | 100.0% | 0 |  | 0.0000 | 0.0120 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | pi_blitz_try_catch | 18399 | 3383 | 427 | 3728 | 0 | 72 | 3383 | 427 | 3728 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0013 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | pi_blitz_try_catch | 19019 | 522 | 512 | 6667 | 0 | 73 | 522 | 512 | 6667 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | pi_blitz_replace_return | 25441 | 3411 | 353 | 3683 | 0 | 66 | 3411 | 353 | 3683 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0000 | 0.0012 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | pi_blitz_replace_return | 20381 | 518 | 535 | 6769 | 0 | 66 | 518 | 535 | 6769 | 0 | 2 | 33 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | pi_blitz_replace_return | 31390 | 390 | 519 | 6609 | 0 | 79 | 390 | 519 | 6609 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |

## Pairwise savings
Skipped; core lane not run.