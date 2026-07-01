# Pi/tmux/Tokscale true sequential streak — class-d-config-docs core

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/true-streak-2026-06-11T19-34-59-050Z
Tmux session: pi-true-streak-2026-06-11T19-34-59-050Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 598 | 335 | 412 | 21846 | 0 | 191 | 298 | 23154 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| config.ts | yes | bb89983b4657390d | bb89983b4657390d |
| config.json | yes | 321d90e1251421f4 | 321d90e1251421f4 |
| config.toml | yes | d6c98456eba4181d | d6c98456eba4181d |
| NOTES.md | yes | 22079ad7214b5a72 | 22079ad7214b5a72 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
