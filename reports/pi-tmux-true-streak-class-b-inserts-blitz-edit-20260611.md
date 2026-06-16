# Pi/tmux/Tokscale true sequential streak — class-b-inserts blitz-edit

Status: caveated
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T19-35-56-892Z
Tmux session: pi-true-streak-2026-06-11T19-35-56-892Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 153 | 2934 | 3855 | 255394 | 0 | 675 | 1102 | 260504 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| logging.ts | yes | de07163b7b9cc7ee | de07163b7b9cc7ee |
| README.md | no | c7c6759547df52ee | 95cd8560ca0385a5 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
