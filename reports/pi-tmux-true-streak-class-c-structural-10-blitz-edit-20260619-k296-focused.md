# Pi/tmux/Tokscale true sequential streak — class-c-structural-10 blitz-edit

Status: declined
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-k296-focused-class-c
Tmux session: pi-true-streak-2026-06-19T03-15-49-873Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 350 | 268 | 534 | 504 | 582 | 1152 | 0 | 32 | 811 | 3697 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural-10.ts | no | bf098d15725e76dd | f641a38b60761f57 |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
- minimal blitz_edit declined unsupported structural rb with no_mutation=true; this row is an explicit decline, not a correctness pass or hidden fallback.
