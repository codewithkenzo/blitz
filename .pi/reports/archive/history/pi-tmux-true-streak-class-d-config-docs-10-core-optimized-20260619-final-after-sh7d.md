# Pi/tmux/Tokscale true sequential streak — class-d-config-docs-10 core-optimized

Status: accepted
Provider/model: zai/glm-4.5-air
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/class-d-config-docs-10-core-optimized
Tmux session: pi-true-streak-2026-06-19T05-06-18-566Z
Tokscale: required (exit 0, match yes)

## Cumulative tokens

| schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0 | 1241 | 620 | 732 | 2560 | 0 | 520 | 1458 | 5991 |

## Tokscale match

Matched: yes

Deltas: {"input":0,"output":0,"cacheRead":0,"cacheWrite":0,"messages":0}

## Correctness

| Step/file | Correct | Expected sha | Actual sha |
|---|---|---:|---:|
| config-1.json | yes | bf1df48649bba0e5 | bf1df48649bba0e5 |
| doc-2.md | yes | 074c8d2f6a4bc640 | 074c8d2f6a4bc640 |
| config-3.json | yes | bc74d2d6bf625f8c | bc74d2d6bf625f8c |
| doc-4.md | yes | 12183b3893ffbf5b | 12183b3893ffbf5b |
| config-5.json | yes | e077ca0fbf565d2a | e077ca0fbf565d2a |
| doc-6.md | yes | 9c1084817b45d386 | 9c1084817b45d386 |
| config-7.json | yes | 88d86320e9189795 | 88d86320e9189795 |
| doc-8.md | yes | cf8edb2757fedd93 | cf8edb2757fedd93 |
| config-9.json | yes | 35a246f8240ca85b | 35a246f8240ca85b |
| doc-10.md | yes | 734b26d28109fc3f | 734b26d28109fc3f |

## Caveats

- schema/skill tokens are counted from current local artifacts when available; residualInputTokens captures remaining unclassified provider input.
- true sequential proof means one Pi command/session and ordered tool calls in one prompt, not isolated per-row synthesis.
