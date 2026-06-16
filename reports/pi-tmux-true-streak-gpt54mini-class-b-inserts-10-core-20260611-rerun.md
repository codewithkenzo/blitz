# Pi/tmux/Tokscale true sequential streak — class-b-inserts-10 core

Status: accepted
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T20-16-12-247Z
Tmux session: pi-true-streak-2026-06-11T20-16-12-247Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 1999 | 1280 | 1385 | 6656 | 0 | 500 | 4172 | 14212 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| insert-1.ts | yes | a8aa31bad04e7b26 | a8aa31bad04e7b26 |
| insert-2.ts | yes | 5fe488bec8d05d16 | 5fe488bec8d05d16 |
| insert-3.ts | yes | 62f6b9dac2c40544 | 62f6b9dac2c40544 |
| insert-4.ts | yes | 4e5f90952807d3b6 | 4e5f90952807d3b6 |
| insert-5.ts | yes | f2b9c1be5e2b2abd | f2b9c1be5e2b2abd |
| insert-6.ts | yes | ad8c82682e2d5727 | ad8c82682e2d5727 |
| insert-7.ts | yes | 4d24de26f78f1990 | 4d24de26f78f1990 |
| insert-8.ts | yes | 383ab3e6f5e049f9 | 383ab3e6f5e049f9 |
| insert-9.ts | yes | 2fda8905471ef365 | 2fda8905471ef365 |
| insert-10.ts | yes | bcc795b0ece31261 | bcc795b0ece31261 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
