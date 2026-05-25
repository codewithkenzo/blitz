# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: reports/pi-tmux-runs/lane-g-glm-arrow-20260525-123212
Tmux session: pi-bench-2026-05-25T10-32-12-588Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T10:32:43.020Z

| Fixture | Class | Recommended | Lane | route | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | edit | 14052 | 2192 | 468 | 4664 | 0 | 71 | 2192 | 468 | 4664 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0000 | 0.0011 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | pi_blitz_replace_return | 15185 | 3394 | 521 | 3839 | 0 | 63 | 3394 | 521 | 3839 | 0 | 2 | 35 | yes | 100.0% | 0 |  | 0.0000 | 0.0014 |

## Pairwise savings (correct rows only)
semantic/arrow-replace-return: lost session output 11.3%, saved tool-call args 11.3%, lost wall time 8.1%, cost unavailable