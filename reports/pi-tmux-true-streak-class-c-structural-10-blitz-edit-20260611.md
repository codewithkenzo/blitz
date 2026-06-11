# Pi/tmux/Tokscale true sequential streak — tiny-10 blitz-edit

Status: caveated
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T19-45-18-171Z
Tmux session: pi-true-streak-2026-06-11T19-45-18-171Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 644 | 7789 | 8464 | 178187 | 0 | 3702 | 3458 | 190753 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| tiny-01.ts | no | f879209f4275cd8a | 619b038f2629e179 |
| tiny-02.ts | no | 3bbcf24ccaf46861 | 20a53b55cdbfd8b8 |
| tiny-03.ts | no | 9b1a9192034529cc | bb0610d8c2a122ba |
| tiny-04.ts | no | e72559f979ba163f | fe914c768e1a6e68 |
| tiny-05.ts | no | 838a5e478ba077d3 | ee77adaa49f8bff9 |
| tiny-06.ts | no | 6cd6e775c9eab1bf | 0460188b1ec5019c |
| tiny-07.ts | no | 7a901eb623e22c14 | 205dd4d797f2a771 |
| tiny-08.ts | no | 11d1e00f19651fdf | cb343f2db749e6a7 |
| tiny-09.ts | no | 9fd3e993ccfafb8d | ab476705a08f80e4 |
| tiny-10.ts | no | e7fef6f4d6e05769 | 3b9b65d033665910 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
