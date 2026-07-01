# Pi local matrix results

Provider: openai-codex
Model: gpt-5.5
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260609-gpt-full-profile-035706
Tmux session: pi-bench-2026-06-09T01-57-06-499Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: full
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260609-gpt-full-profile-035706
Visible Blitz tools: pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor
Serialized tool spec tokens: 5517
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-09T02:01:42.716Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | core_edit | core | edit | 0 | 0 | 134 | 99 | 115 | 3072 | 0 | 1 | 4127 | 7647 | edit | 8112 | 4226 | 4226 | 115 | 3072 | 0 | 2 | 18 | yes | 100.0% | 0 |  | 0.0261 | 0.0261 |
| medium-10k/marker-tail | medium_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 4617 | 69 | 85 | 7680 | 0 | 1 | 8500 | 21021 | edit | 6209 | 8569 | 8569 | 85 | 7680 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0492 | 0.0492 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 4684 | 133 | 216 | 15872 | 0 | 1 | 1151 | 37940 | pi_blitz_replace_body_span | 12173 | 9159 | 9159 | 216 | 15872 | 0 | 3 | 13 | yes | 100.0% | 0 |  | 0.0602 | 0.0602 |
| medium-10k/wrap-body | medium_wrap_body | blitz | core | core_edit | core | edit | 0 | 0 | 4625 | 263 | 397 | 15872 | 0 | 1 | 8753 | 30174 | edit | 13645 | 9016 | 9016 | 397 | 15872 | 0 | 3 | 13 | yes | 0.0% | 0 |  | 0.0649 | 0.0649 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 4770 | 135 | 229 | 15872 | 0 | 1 | 1381 | 38273 | pi_blitz_wrap_body | 11663 | 9391 | 9391 | 229 | 15872 | 0 | 3 | 15 | yes | 100.0% | 0 |  | 0.0618 | 0.0618 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | core | core_edit | core | edit | 0 | 0 | 4640 | 262 | 278 | 0 | 0 | 1 | 16246 | 21689 | edit | 10139 | 16508 | 16508 | 278 | 0 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0909 | 0.0909 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 4848 | 184 | 205 | 0 | 0 | 1 | 8802 | 29974 | pi_blitz_compose_body | 8812 | 16861 | 16861 | 205 | 0 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0905 | 0.0905 |
| medium-10k/insert-body-span | insert_body_span | blitz | core | core_edit | core | edit | 0 | 0 | 4625 | 86 | 102 | 7680 | 0 | 1 | 8516 | 21096 | edit | 8069 | 8602 | 8602 | 102 | 7680 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0499 | 0.0499 |
| medium-10k/insert-body-span | insert_body_span | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 4719 | 91 | 112 | 0 | 0 | 1 | 8630 | 29394 | pi_blitz_insert_body_span | 9679 | 16596 | 16596 | 112 | 0 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0863 | 0.0863 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | core_edit | core | edit | 0 | 0 | 210 | 226 | 242 | 3584 | 0 | 1 | 3777 | 8266 | edit | 9396 | 4003 | 4003 | 242 | 3584 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0291 | 0.0291 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | ast_batch | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 424 | 162 | 182 | 0 | 0 | 1 | 34 | 16715 | pi_blitz_multi_body | 8788 | 8071 | 8071 | 182 | 0 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0458 | 0.0458 |
| multi/large-structural | multi_body_large_structural | blitz | core | core_edit | core | edit | 0 | 0 | 4695 | 395 | 620 | 10752 | 0 | 1 | 14234 | 31092 | edit | 17418 | 14629 | 14629 | 620 | 10752 | 0 | 3 | 15 | yes | 0.0% | 0 |  | 0.0971 | 0.0971 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 4863 | 101 | 120 | 8192 | 0 | 1 | 711 | 29839 | pi_blitz_patch | 8664 | 8687 | 8687 | 120 | 8192 | 0 | 2 | 16 | yes | 0.0% | 0 |  | 0.0511 | 0.0511 |
| huge-100k/marker-tail | huge_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 46541 | 62 | 78 | 49664 | 0 | 1 | 50365 | 146773 | edit | 8274 | 50427 | 50427 | 78 | 49664 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.2793 | 0.2793 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 46609 | 65 | 86 | 49664 | 0 | 1 | 42789 | 155029 | pi_blitz_replace_body_span | 8172 | 50729 | 50729 | 86 | 49664 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.2811 | 0.2811 |
| semantic/async-try-catch | async_try_catch | blitz | core | core_edit | core | edit | 0 | 0 | 271 | 174 | 190 | 0 | 0 | 1 | 7488 | 8298 | edit | 11023 | 7662 | 7662 | 190 | 0 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0440 | 0.0440 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 358 | 58 | 79 | 0 | 0 | 1 | -194 | 16110 | pi_blitz_try_catch | 6417 | 7739 | 7739 | 79 | 0 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0411 | 0.0411 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | core | core_edit | core | edit | 0 | 0 | 266 | 145 | 161 | 0 | 0 | 1 | 7483 | 8201 | edit | 7779 | 7628 | 7628 | 161 | 0 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0430 | 0.0430 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 353 | 59 | 80 | 3584 | 0 | 1 | -3782 | 16104 | pi_blitz_try_catch | 26113 | 4152 | 4152 | 80 | 3584 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0250 | 0.0250 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 257 | 60 | 76 | 0 | 0 | 1 | 7450 | 7904 | edit | 6273 | 7510 | 7510 | 76 | 0 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0398 | 0.0398 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 355 | 52 | 72 | 0 | 0 | 1 | -144 | 16138 | pi_blitz_replace_return | 7156 | 7783 | 7783 | 72 | 0 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0411 | 0.0411 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | core | core_edit | core | edit | 0 | 0 | 257 | 60 | 76 | 0 | 0 | 1 | 7450 | 7904 | edit | 8724 | 7510 | 7510 | 76 | 0 | 0 | 2 | 15 | yes | 0.0% | 0 |  | 0.0398 | 0.0398 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 355 | 52 | 72 | 3584 | 0 | 1 | -3780 | 16086 | pi_blitz_replace_return | 7521 | 4147 | 4147 | 72 | 3584 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0247 | 0.0247 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 145 | 165 | 445 | 6656 | 0 | 1 | 4626 | 12203 | edit | 17134 | 4791 | 4791 | 445 | 6656 | 0 | 3 | 21 | yes | 100.0% | 0 |  | 0.0406 | 0.0406 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | ast_narrow | full | pi_blitz_read,pi_blitz_edit,pi_blitz_batch,pi_blitz_apply,pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return,pi_blitz_rename,pi_blitz_undo,pi_blitz_doctor | 5517 | 2358 | 233 | 100 | 136 | 3584 | 0 | 1 | -75 | 19829 | pi_blitz_replace_return | 8375 | 7900 | 7900 | 136 | 3584 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0454 | 0.0454 |
| readme/core-smoke | markdown_core_only | core | core | core_edit | core | edit | 0 | 0 | 150 | 96 | 112 | 6144 | 0 | 1 | 1092 | 7691 | edit | 9423 | 1188 | 1188 | 112 | 6144 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0124 | 0.0124 |

## Pairwise savings (correct rows only)
medium-10k/marker-tail: lost session output 154.1%, lost tool-call args 92.8%, lost wall time 96.1%, lost cost 22.3%
medium-10k/wrap-body: correctness win; savings not counted (core output 397, blitz output 229, core args 263, blitz args 135)
medium-10k/compose-preserve-islands: Blitz failed; savings not counted (core output 278, blitz output 205, core args 262, blitz args 184)
medium-10k/insert-body-span: Blitz failed; savings not counted (core output 102, blitz output 112, core args 86, blitz args 91)
multi/three-body-ops: Blitz failed; savings not counted (core output 242, blitz output 182, core args 226, blitz args 162)
multi/large-structural: Blitz failed; savings not counted (core output 620, blitz output 120, core args 395, blitz args 101)
huge-100k/marker-tail: Blitz failed; savings not counted (core output 78, blitz output 86, core args 62, blitz args 65)
semantic/async-try-catch: Blitz failed; savings not counted (core output 190, blitz output 79, core args 174, blitz args 58)
semantic/class-method-try-catch: Blitz failed; savings not counted (core output 161, blitz output 80, core args 145, blitz args 59)
semantic/arrow-replace-return: Blitz failed; savings not counted (core output 76, blitz output 72, core args 60, blitz args 52)
semantic/nested-return-occurrence: Blitz failed; savings not counted (core output 76, blitz output 72, core args 60, blitz args 52)
semantic/tsx-replace-return: saved session output 69.4%, saved tool-call args 39.4%, saved wall time 51.1%, lost cost 11.7%

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.
readme/core-smoke: core-only cost/control smoke; no Blitz structured AST savings claim.