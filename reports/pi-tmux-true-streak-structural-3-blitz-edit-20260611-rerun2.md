# Pi/tmux/Tokscale true sequential streak — structural-3 blitz-edit

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T19-02-40-675Z
Tmux session: pi-true-streak-2026-06-11T19-02-40-675Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 210 | 180 | 297 | 7919 | 0 | 4 | 73 | 8499 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural.ts | yes | 35851f15b9e12f02 | 35851f15b9e12f02 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
