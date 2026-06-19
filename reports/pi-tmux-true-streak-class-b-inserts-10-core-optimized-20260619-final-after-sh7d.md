# Pi/tmux/Tokscale true sequential streak — class-b-inserts-10 core-optimized

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/class-b-inserts-10-core-optimized
Tmux session: pi-true-streak-2026-06-19T05-05-22-838Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 1456 | 720 | 838 | 2816 | 0 | 520 | 1513 | 6623 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

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

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
