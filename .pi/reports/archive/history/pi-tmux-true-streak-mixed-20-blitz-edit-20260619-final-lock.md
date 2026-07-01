# Pi/tmux/Tokscale true sequential streak — mixed-20 blitz-edit

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260619-replacement-gate/mixed-20-blitz-edit
Tmux session: pi-true-streak-2026-06-19T02-59-04-777Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 419 | 268 | 986 | 956 | 979 | 2304 | 0 | 25 | 462 | 5418 |

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
| package.json | yes | 5aeb5ba5a304478c | 5aeb5ba5a304478c |
| README.md | yes | 377552fb2855170f | 377552fb2855170f |
| style.css | yes | 78c3e7ec66f1ec8b | 78c3e7ec66f1ec8b |
| index.html | yes | 313365a286c089ca | 313365a286c089ca |
| config.yml | yes | dd2b21cdbbef7335 | dd2b21cdbbef7335 |
| settings.toml | yes | 915d5e84ec62383e | 915d5e84ec62383e |
| util.js | yes | 6512b1c1a66da9d5 | 6512b1c1a66da9d5 |
| types.ts | yes | 1bfc1a86531561c1 | 1bfc1a86531561c1 |
| notes.txt | yes | 71d2511426d09c9b | 71d2511426d09c9b |
| .env.example | yes | 13ed393ebf7d6b4a | 13ed393ebf7d6b4a |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
