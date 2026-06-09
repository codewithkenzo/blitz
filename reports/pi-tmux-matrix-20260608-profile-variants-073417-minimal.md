# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: reports/pi-tmux-runs/20260608-profile-variants-073417-minimal
Tmux session: pi-bench-2026-06-08T05-42-33-101Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/20260608-profile-variants-073417-minimal
Visible Blitz tools: pi_blitz_patch
Serialized tool spec tokens: 442
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-08T05:43:22.865Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | minimal-v0 | pi_blitz_patch | 442 | 2358 | 4865 | 173 | 783 | 21894 | 0 | 4 | 2297 | 35789 | pi_blitz_patch | 48649 | 5270 | 5270 | 783 | 21894 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0026 |

## Pairwise savings (correct rows only)
Skipped; core lane not run.