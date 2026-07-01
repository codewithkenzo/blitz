# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/readme-core-glm-fixed-20260525-122406
Tmux session: pi-bench-2026-05-25T10-24-06-592Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T10:24:25.355Z

| Fixture | Class | Recommended | Lane | route | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| readme/core-smoke | markdown_core_only | core | core | core_edit | edit | 14743 | 3121 | 356 | 3446 | 0 | 98 | 3121 | 356 | 3446 | 0 | 2 | 3514 | yes | 100.0% | 0 |  | 0.0000 | 0.0011 |

## Pairwise savings (correct rows only)

## Core-only notes
readme/core-smoke: core-only cost/control smoke; no Blitz structured AST savings claim.