# Pi/tmux/Tokscale true sequential streak — class-c-structural-10 core

Status: accepted
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/true-streak-2026-06-11T20-16-52-208Z
Tmux session: pi-true-streak-2026-06-11T20-16-52-208Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 5283 | 4990 | 5114 | 114688 | 0 | 510 | 7365 | 132450 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural-10.ts | yes | bf098d15725e76dd | bf098d15725e76dd |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
