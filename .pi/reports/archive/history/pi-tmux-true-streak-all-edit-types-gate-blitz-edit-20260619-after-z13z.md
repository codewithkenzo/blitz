# Pi/tmux/Tokscale true sequential streak — all-edit-types-gate blitz-edit

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260619-after-z13z/all-edit-types-gate-blitz-edit
Tmux session: pi-true-streak-2026-06-20T03-09-01-561Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 350 | 268 | 471 | 441 | 485 | 1152 | 0 | 25 | 665 | 3391 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| imports.ts | yes | c4e88aadfd765590 | c4e88aadfd765590 |
| rename-local.ts | yes | f279eadd3a663a43 | f279eadd3a663a43 |
| wrap-body.ts | yes | df681d40e4c918c6 | df681d40e4c918c6 |
| delete-range.ts | yes | ac023307085c5790 | ac023307085c5790 |
| append-section.md | yes | 76b18dc3ab69a6b4 | 76b18dc3ab69a6b4 |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
