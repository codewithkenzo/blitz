# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260608-profile-variants-073417-semantic
Tmux session: pi-bench-2026-06-08T05-34-17-462Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: semantic
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/20260608-profile-variants-073417-semantic
Visible Blitz tools: pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return
Serialized tool spec tokens: 1152
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-08T05:35:45.632Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/async-try-catch | async_try_catch | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 359 | 86 | 841 | 12471 | 0 | 85 | -2978 | 17970 | pi_blitz_try_catch | 19790 | 618 | 618 | 841 | 12471 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0014 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 354 | 27 | 348 | 7702 | 0 | 23 | -3030 | 12471 | pi_blitz_try_catch | 10191 | 507 | 507 | 348 | 7702 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 356 | 62 | 543 | 7929 | 0 | 22 | -3058 | 12936 | pi_blitz_replace_return | 18796 | 514 | 514 | 543 | 7929 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 356 | 62 | 517 | 7937 | 0 | 34 | -3068 | 12920 | pi_blitz_replace_return | 22397 | 504 | 504 | 517 | 7937 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 2358 | 234 | 75 | 538 | 7851 | 0 | 31 | -3209 | 12615 | pi_blitz_replace_return | 14897 | 376 | 376 | 538 | 7851 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |

## Pairwise savings (correct rows only)
Skipped; core lane not run.