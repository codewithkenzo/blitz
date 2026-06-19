# Pi/tmux/Tokscale true sequential streak — class-c-structural-10 core-optimized

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-replacement-gate/class-c-structural-10-core-optimized
Tmux session: pi-true-streak-2026-06-19T03-00-09-091Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 908 | 717 | 807 | 4992 | 0 | 554 | 1530 | 8237 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural-10.ts | yes | bf098d15725e76dd | bf098d15725e76dd |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
