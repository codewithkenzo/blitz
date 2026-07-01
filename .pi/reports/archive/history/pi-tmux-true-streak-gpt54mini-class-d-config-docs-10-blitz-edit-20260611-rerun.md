# Pi/tmux/Tokscale true sequential streak — class-d-config-docs-10 blitz-edit

Status: caveated
Provider/model: openai-codex/gpt-5.4-mini
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/true-streak-2026-06-11T20-16-52-213Z
Tmux session: pi-true-streak-2026-06-11T20-16-52-213Z
Tokscale: required (exit 0)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 514 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| config-1.json | no | bf1df48649bba0e5 | fe2f793493899b42 |
| doc-2.md | no | 074c8d2f6a4bc640 | 41e14d462b56fb8d |
| config-3.json | no | bc74d2d6bf625f8c | 69d0cc117e0a7adb |
| doc-4.md | no | 12183b3893ffbf5b | 23cc61b339615e86 |
| config-5.json | no | e077ca0fbf565d2a | 022a7231bd850537 |
| doc-6.md | no | 9c1084817b45d386 | 33d5ca7923cfeb18 |
| config-7.json | no | 88d86320e9189795 | 49f1a5921ad5f9c6 |
| doc-8.md | no | cf8edb2757fedd93 | add3f0981776c0cb |
| config-9.json | no | 35a246f8240ca85b | 4218a2a778272dc3 |
| doc-10.md | no | 734b26d28109fc3f | ea2253776cb3ebfa |

## Caveats

- schemaTokens=0 unless Pi exposes serialized resident core/tool schema in session JSONL; residualInputTokens captures unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
