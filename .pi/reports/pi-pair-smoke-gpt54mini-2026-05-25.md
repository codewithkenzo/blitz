# Pi local matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-05-25T06-26-58-086Z
Tmux session: pi-bench-2026-05-25T06-26-58-086Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T06:27:13.033Z

| Fixture | Class | Recommended | Lane | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | edit | 8181 | 6232 | 92 | 0 | 0 | 76 | 6232 | 92 | 0 | 0 | 2 | 70 | yes | 100.0% | 0 |  | 0.0051 | 0.0051 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | pi_blitz_replace_return | 5825 | 3437 | 101 | 3072 | 0 | 81 | 3437 | 101 | 3072 | 0 | 2 | 67 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |

## Pairwise savings
semantic/arrow-replace-return: saved session output -9.8%, saved tool-call args -6.6%