# Pi/tmux/Tokscale true sequential streak — same-file-multi router

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-10T06-25-11-305Z
Tmux session: pi-true-streak-2026-06-10T06-25-11-305Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 580 | 516 | 366 | 1019 | 19895 | 0 | 250 | 3364 | 25374 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| same.ts | yes | 616c6c4a5520d180 | 616c6c4a5520d180 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
