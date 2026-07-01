# Pi local matrix results

Provider: openai-codex
Model: gpt-5.5
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T02-25-21-688Z
Tmux session: pi-bench-2026-06-09T02-25-21-688Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: semantic
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T02-25-21-688Z
Visible Blitz tools: pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return
Serialized tool spec tokens: 1152
Resident skill tokens: 444
Tokscale validation: required
Generated: 2026-06-09T02:25:38.435Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 271 | 74 | 90 | 3584 | 0 | 1 | 3924 | 8018 | edit | 6486 | 3998 | 3998 | 90 | 3584 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0245 | 0.0245 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | semantic | pi_blitz_patch,pi_blitz_try_catch,pi_blitz_replace_return | 1152 | 444 | 369 | 66 | 86 | 0 | 0 | 1 | 6125 | 9905 | pi_blitz_replace_return | 8581 | 7787 | 7787 | 86 | 0 | 0 | 2 | 13 | yes | 100.0% | 0 |  | 0.0415 | 0.0415 |

## Profile coverage / skipped rows
minimal-v0: supported 0/1; skipped 1 (semantic/arrow-replace-return: unsupported by minimal-v0 registered tool profile)
semantic: supported 1/1; skipped 0
structural: supported 0/1; skipped 1 (semantic/arrow-replace-return: unsupported by structural registered tool profile)
admin: supported 0/1; skipped 1 (semantic/arrow-replace-return: unsupported by admin registered tool profile)
full: supported 1/1; skipped 0

## Resident overhead comparison
minimal-v0: schema 442, skill 444, combined 886, reduction vs full 85.1%; meets >=70% combined target
semantic: schema 1152, skill 444, combined 1596, reduction vs full 73.2%; meets >=70% combined target
structural: schema 1344, skill 444, combined 1788, reduction vs full 70.0%; meets >=70% combined target
admin: schema 622, skill 444, combined 1066, reduction vs full 82.1%; meets >=70% combined target
full: schema 5517, skill 444, combined 5961, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
semantic/arrow-replace-return: saved session output 4.4%, saved tool-call args 10.8%, lost total context 23.5%, lost wall time 32.3%, lost cost 69.6%; route=core/apply_patch fallback; savings not counted