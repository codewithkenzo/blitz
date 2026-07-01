# Pi local matrix results

Provider: openai-codex
Model: gpt-5.5
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260609-gpt-profile-supported-035842-minimal
Tmux session: pi-bench-2026-06-09T02-01-37-328Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/20260609-gpt-profile-supported-035842-minimal
Visible Blitz tools: pi_blitz_patch
Serialized tool spec tokens: 442
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-09T02:01:56.578Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| multi/large-structural | multi_body_large_structural | blitz | core | core_edit | core | edit | 0 | 0 | 4697 | 193 | 209 | 6144 | 0 | 1 | 10202 | 21639 | edit | 9928 | 10395 | 10395 | 209 | 6144 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0613 | 0.0613 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | minimal-v0 | pi_blitz_patch | 442 | 2358 | 4867 | 103 | 122 | 8192 | 0 | 1 | 5852 | 24840 | pi_blitz_patch | 8367 | 8755 | 8755 | 122 | 8192 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0515 | 0.0515 |

## Pairwise savings (correct rows only)
multi/large-structural: Blitz failed; savings not counted (core output 209, blitz output 122, core args 193, blitz args 103)