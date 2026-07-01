# Pi/tmux/Tokscale true sequential streak — tiny-10 blitz-edit

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/tiny-10-blitz-edit
Tmux session: pi-true-streak-2026-06-19T05-04-03-564Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 350 | 268 | 604 | 613 | 603 | 1280 | 0 | 25 | 785 | 3890 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| tiny-01.ts | yes | f879209f4275cd8a | f879209f4275cd8a |
| tiny-02.ts | yes | 3bbcf24ccaf46861 | 3bbcf24ccaf46861 |
| tiny-03.ts | yes | 9b1a9192034529cc | 9b1a9192034529cc |
| tiny-04.ts | yes | e72559f979ba163f | e72559f979ba163f |
| tiny-05.ts | yes | 838a5e478ba077d3 | 838a5e478ba077d3 |
| tiny-06.ts | yes | 6cd6e775c9eab1bf | 6cd6e775c9eab1bf |
| tiny-07.ts | yes | 7a901eb623e22c14 | 7a901eb623e22c14 |
| tiny-08.ts | yes | 11d1e00f19651fdf | 11d1e00f19651fdf |
| tiny-09.ts | yes | 9fd3e993ccfafb8d | 9fd3e993ccfafb8d |
| tiny-10.ts | yes | e7fef6f4d6e05769 | e7fef6f4d6e05769 |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
