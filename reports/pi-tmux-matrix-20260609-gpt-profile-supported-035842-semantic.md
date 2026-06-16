# Pi local matrix results

Provider: openai-codex
Model: gpt-5.5
Iterations: 1
Runner: tmux
Run root: reports/pi-tmux-runs/20260609-gpt-profile-supported-035842-semantic
Tmux session: pi-bench-2026-06-09T01-58-42-704Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: semantic
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260609-gpt-profile-supported-035842-semantic
Visible Blitz tools: pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return
Serialized tool spec tokens: 1152
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-09T02:00:23.323Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/async-try-catch | async_try_catch | blitz | core | core_edit | core | edit | 0 | 0 | 273 | 167 | 183 | 3584 | 0 | 1 | 3913 | 8288 | edit | 8936 | 4080 | 4080 | 183 | 3584 | 0 | 2 | 16 | yes | 0.0% | 0 |  | 0.0277 | 0.0277 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 360 | 60 | 81 | 3584 | 0 | 1 | 641 | 11807 | pi_blitz_try_catch | 6702 | 4211 | 4211 | 81 | 3584 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0253 | 0.0253 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | core | core_edit | core | edit | 0 | 0 | 268 | 285 | 351 | 0 | 0 | 1 | 11524 | 12714 | edit | 13053 | 11809 | 11809 | 351 | 0 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0696 | 0.0696 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 355 | 61 | 82 | 0 | 0 | 1 | 4183 | 11763 | pi_blitz_try_catch | 7262 | 7754 | 7754 | 82 | 0 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0412 | 0.0412 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 259 | 62 | 78 | 3584 | 0 | 1 | 3880 | 7926 | edit | 8783 | 3942 | 3942 | 78 | 3584 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0238 | 0.0238 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 357 | 54 | 74 | 3584 | 0 | 1 | 601 | 11745 | pi_blitz_replace_return | 7235 | 4165 | 4165 | 74 | 3584 | 0 | 2 | 15 | yes | 0.0% | 0 |  | 0.0248 | 0.0248 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | core | core_edit | core | edit | 0 | 0 | 259 | 71 | 87 | 3584 | 0 | 1 | 3885 | 7958 | edit | 7599 | 3956 | 3956 | 87 | 3584 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0242 | 0.0242 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 357 | 117 | 201 | 3584 | 0 | 1 | 4710 | 16107 | pi_blitz_replace_return | 15320 | 8337 | 8337 | 201 | 3584 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0495 | 0.0495 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 147 | 169 | 316 | 6656 | 0 | 1 | 4539 | 11997 | edit | 11167 | 4708 | 4708 | 316 | 6656 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0363 | 0.0363 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 235 | 102 | 184 | 0 | 0 | 1 | 8028 | 15672 | pi_blitz_replace_return | 9961 | 11640 | 11640 | 184 | 0 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0637 | 0.0637 |

## Pairwise savings (correct rows only)
semantic/async-try-catch: Blitz failed; savings not counted (core output 183, blitz output 81, core args 167, blitz args 60)
semantic/class-method-try-catch: Blitz failed; savings not counted (core output 351, blitz output 82, core args 285, blitz args 61)
semantic/arrow-replace-return: Blitz failed; savings not counted (core output 78, blitz output 74, core args 62, blitz args 54)
semantic/nested-return-occurrence: lost session output 131.0%, lost tool-call args 64.8%, lost wall time 101.6%, lost cost 104.7%
semantic/tsx-replace-return: saved session output 41.8%, saved tool-call args 39.6%, saved wall time 10.8%, lost cost 75.3%