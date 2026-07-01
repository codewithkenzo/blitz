# Pi local matrix results

Provider: openai-codex
Model: gpt-5.5
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260609-gpt-profile-supported-035842-structural
Tmux session: pi-bench-2026-06-09T02-00-23-376Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: structural
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/20260609-gpt-profile-supported-035842-structural
Visible Blitz tools: pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch
Serialized tool spec tokens: 1344
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-09T02:01:37.277Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/marker-tail | medium_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 4620 | 67 | 83 | 10752 | 0 | 1 | 5444 | 21034 | edit | 8905 | 5511 | 5511 | 83 | 10752 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0354 | 0.0354 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 4687 | 65 | 86 | 7680 | 0 | 1 | 5061 | 25049 | pi_blitz_replace_body_span | 6993 | 8828 | 8828 | 86 | 7680 | 0 | 2 | 13 | yes | 0.0% | 0 |  | 0.0506 | 0.0506 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | core_edit | core | edit | 0 | 0 | 213 | 220 | 236 | 0 | 0 | 1 | 7377 | 8267 | edit | 9718 | 7597 | 7597 | 236 | 0 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0451 | 0.0451 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 427 | 165 | 185 | 0 | 0 | 1 | 4231 | 12578 | pi_blitz_multi_body | 10432 | 8098 | 8098 | 185 | 0 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0460 | 0.0460 |
| multi/large-structural | multi_body_large_structural | blitz | core | core_edit | core | edit | 0 | 0 | 4698 | 184 | 200 | 7680 | 0 | 1 | 8668 | 21615 | edit | 8977 | 8852 | 8852 | 200 | 7680 | 0 | 2 | 15 | yes | 0.0% | 0 |  | 0.0541 | 0.0541 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 4869 | 104 | 123 | 8192 | 0 | 1 | 4914 | 25711 | pi_blitz_patch | 7379 | 8720 | 8720 | 123 | 8192 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.0514 | 0.0514 |
| huge-100k/marker-tail | huge_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 46544 | 74 | 90 | 49664 | 0 | 1 | 50391 | 146838 | edit | 7992 | 50465 | 50465 | 90 | 49664 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.2799 | 0.2799 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 46612 | 68 | 89 | 49664 | 0 | 1 | 46934 | 150840 | pi_blitz_replace_body_span | 9937 | 50704 | 50704 | 89 | 49664 | 0 | 2 | 14 | yes | 0.0% | 0 |  | 0.2810 | 0.2810 |

## Pairwise savings (correct rows only)
medium-10k/marker-tail: Blitz failed; savings not counted (core output 83, blitz output 86, core args 67, blitz args 65)
multi/three-body-ops: Blitz failed; savings not counted (core output 236, blitz output 185, core args 220, blitz args 165)
multi/large-structural: Blitz failed; savings not counted (core output 200, blitz output 123, core args 184, blitz args 104)
huge-100k/marker-tail: Blitz failed; savings not counted (core output 90, blitz output 89, core args 74, blitz args 68)