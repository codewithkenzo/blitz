# Pi/tmux/Tokscale true sequential streak — mixed-20 blitz-edit

Status: caveated
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/true-streak-2026-06-11T20-15-34-827Z
Tmux session: pi-true-streak-2026-06-11T20-15-34-827Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 1086 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

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
| package.json | no | 5aeb5ba5a304478c | c65c254bd5185776 |
| README.md | no | 377552fb2855170f | 565e9b2a8ec41a60 |
| style.css | no | 78c3e7ec66f1ec8b | 2d2d35c89f395a51 |
| index.html | no | 313365a286c089ca | 640b74ed5198ac78 |
| config.yml | no | dd2b21cdbbef7335 | b0ca40cbfa3e1b4b |
| settings.toml | no | 915d5e84ec62383e | 4ddaf7b63170a13e |
| util.js | no | 6512b1c1a66da9d5 | 7570ca6ee3f86c95 |
| types.ts | no | 1bfc1a86531561c1 | 95a9115d63e937d6 |
| notes.txt | no | 71d2511426d09c9b | adf7157c8a5bbb4b |
| .env.example | no | 13ed393ebf7d6b4a | 01010e13ada3732d |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
