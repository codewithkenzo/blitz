# Pi/tmux/Tokscale true sequential streak — class-b-inserts core

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/true-streak-2026-06-11T19-35-56-903Z
Tmux session: pi-true-streak-2026-06-11T19-35-56-903Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 385 | 224 | 261 | 12021 | 0 | 96 | 172 | 12839 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| logging.ts | yes | de07163b7b9cc7ee | de07163b7b9cc7ee |
| README.md | yes | c7c6759547df52ee | c7c6759547df52ee |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
