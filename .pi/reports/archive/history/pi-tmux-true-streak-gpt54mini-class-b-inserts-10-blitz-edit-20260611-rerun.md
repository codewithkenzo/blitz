# Pi/tmux/Tokscale true sequential streak — class-b-inserts-10 blitz-edit

Status: caveated
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/true-streak-2026-06-11T20-16-12-239Z
Tmux session: pi-true-streak-2026-06-11T20-16-12-239Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 624 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| insert-1.ts | no | a8aa31bad04e7b26 | d0764726eac668d0 |
| insert-2.ts | no | 5fe488bec8d05d16 | 775a8a1845de0694 |
| insert-3.ts | no | 62f6b9dac2c40544 | 2fd11125c0cfdeee |
| insert-4.ts | no | 4e5f90952807d3b6 | 03836735c941a37d |
| insert-5.ts | no | f2b9c1be5e2b2abd | 334a392a4eefb5e9 |
| insert-6.ts | no | ad8c82682e2d5727 | 9b25cdd092712429 |
| insert-7.ts | no | 4d24de26f78f1990 | aa6d724f56265a44 |
| insert-8.ts | no | 383ab3e6f5e049f9 | 58ebc389ac350f8e |
| insert-9.ts | no | 2fda8905471ef365 | d7e1913fa3026ad4 |
| insert-10.ts | no | bcc795b0ece31261 | 5ba01b55d46cae73 |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
