# Pi/tmux/Tokscale true sequential streak — same-file-multi blitz-edit

Status: caveated
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T18-44-17-734Z
Tmux session: pi-true-streak-2026-06-11T18-44-17-734Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 343 | 10955 | 11585 | 343976 | 0 | 245 | 606 | 356510 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| same.ts | no | 616c6c4a5520d180 | b5324c75e355f343 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
