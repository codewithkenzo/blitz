# Pi/tmux/Tokscale true sequential streak — structural-3 core-optimized

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260619-after-z13z/structural-3-core-optimized
Tmux session: pi-true-streak-2026-06-20T03-11-24-708Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 330 | 212 | 238 | 1664 | 0 | 135 | 471 | 2703 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural.ts | yes | 35851f15b9e12f02 | 35851f15b9e12f02 |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
