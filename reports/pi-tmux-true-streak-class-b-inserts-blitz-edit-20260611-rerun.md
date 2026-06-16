# Pi/tmux/Tokscale true sequential streak — class-b-inserts blitz-edit

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T19-39-40-340Z
Tmux session: pi-true-streak-2026-06-11T19-39-40-340Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 166 | 136 | 157 | 7789 | 0 | 4 | 70 | 8182 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| logging.ts | yes | de07163b7b9cc7ee | de07163b7b9cc7ee |
| README.md | yes | c7c6759547df52ee | c7c6759547df52ee |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
