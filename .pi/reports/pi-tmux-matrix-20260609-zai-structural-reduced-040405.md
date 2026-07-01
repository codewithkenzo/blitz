# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260609-zai-structural-reduced-040405
Tmux session: pi-bench-2026-06-09T02-04-05-857Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: structural
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/20260609-zai-structural-reduced-040405
Visible Blitz tools: pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch
Serialized tool spec tokens: 1344
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-09T02:12:14.289Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/marker-tail | medium_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 4620 | 72 | 389 | 8700 | 0 | 35 | 8302 | 22190 | edit | 33348 | 8374 | 8374 | 389 | 8700 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0024 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 4687 | 74 | 376 | 8796 | 0 | 5 | 4745 | 26161 | pi_blitz_replace_body_span | 49572 | 8521 | 8521 | 376 | 8796 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0024 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | core_edit | core | edit | 0 | 0 | 213 | 173 | 618 | 7901 | 0 | 3 | 165 | 9246 | edit | 41632 | 338 | 338 | 618 | 7901 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0010 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 427 | 297 | 1113 | 9907 | 0 | 11 | 257 | 19713 | pi_blitz_multi_body | 43421 | 4256 | 4256 | 1113 | 9907 | 0 | 3 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0024 |
| multi/large-structural | multi_body_large_structural | blitz | core | core_edit | core | edit | 0 | 0 | 4698 | 0 | 0 | 0 | 0 | 0 | 0 | 4698 |  | 180235 | 0 |  |  |  |  |  |  | no | 0.0% | -1 | no session jsonl (run failed/timed out) | 0.0000 |  |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 4869 | 175 | 1100 | 18797 | 0 | 22 | 4947 | 37489 | pi_blitz_patch | 71796 | 8824 | 8824 | 1100 | 18797 | 0 | 3 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0035 |
| huge-100k/marker-tail | huge_tail_replace | core | core | core_edit | core | edit | 0 | 0 | 46544 | 74 | 135 | 56087 | 0 | 38 | 48856 | 151808 | edit | 25838 | 48930 | 48930 | 135 | 56087 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0116 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_multi_body,pi_blitz_patch | 1344 | 2358 | 46612 | 213 | 355 | 162194 | 0 | 41 | 45309 | 262341 | pi_blitz_replace_body_span | 39225 | 49224 | 49224 | 355 | 162194 | 0 | 4 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0151 |

## Pairwise savings (correct rows only)
medium-10k/marker-tail: saved session output 3.3%, lost tool-call args 2.8%, lost wall time 48.7%, cost unavailable
multi/three-body-ops: lost session output 80.1%, lost tool-call args 71.7%, lost wall time 4.3%, cost unavailable
multi/large-structural: correctness win; savings not counted (core output 0, blitz output 1100, core args 0, blitz args 175)
huge-100k/marker-tail: lost session output 163.0%, lost tool-call args 187.8%, lost wall time 51.8%, cost unavailable