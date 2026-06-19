# Pi/tmux/Tokscale true sequential streak — structural-3 core-optimized

Status: caveated
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-gpt54-mini/structural-3-core-optimized
Tmux session: pi-true-streak-2026-06-19T08-20-56-639Z
Tokscale: required (exit 0, match no)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 316 | 218 | 246 | 1024 | 0 | 108 | 1800 | 3386 |

## Tokscale match

Matched: no

Deltas: {"input":-2116,"output":-246,"cacheRead":-1024,"cacheWrite":0,"messages":-3}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| structural.ts | no | 35851f15b9e12f02 | 5e760c9e35f2e07f |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
