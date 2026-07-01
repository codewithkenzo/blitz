# Pi local matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-05-25T06-26-14-597Z
Tmux session: pi-bench-2026-05-25T06-26-14-597Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T06:26:25.391Z

| Fixture | Class | Recommended | Lane | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| readme/core-smoke | markdown_core_only | core | core | edit | 10350 | 3481 | 120 | 2560 | 0 | 104 | 3481 | 120 | 2560 | 0 | 2 | 79 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |

## Pairwise savings

## Core-only notes
readme/core-smoke: core-only cost/control smoke; no Blitz structured AST savings claim.