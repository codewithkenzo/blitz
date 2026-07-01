# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: .pi/reports/pi-tmux-runs/20260608-profile-variants-073417-structural
Tmux session: pi-bench-2026-06-08T05-35-45-686Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz-token-profile/dist/index.js
Skill: /home/kenzo/dev/pi-blitz-token-profile/skills/pi-blitz
Tool profile: structural
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/20260608-profile-variants-073417-structural
Visible Blitz tools: pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch
Serialized tool spec tokens: 2551
Resident skill tokens: 2358
Tokscale validation: required
Generated: 2026-06-08T05:42:33.039Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/marker-tail | medium_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 4686 | 73 | 369 | 12337 | 0 | 35 | -29 | 27362 | pi_blitz_replace_body_span | 41693 | 4953 | 4953 | 369 | 12337 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0018 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 4772 | 803 | 1822 | 97771 | 0 | 0 | 3045 | 118834 | pi_blitz_wrap_body | 120143 | 8757 | 8757 | 1822 | 97771 | 0 | 11 | 14 | yes | 0.0% | -1 | [pi-blitz] tool profile structural registered | 0.0000 | 0.0067 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 4850 | 195 | 903 | 9325 | 0 | 74 | 3505 | 28865 | pi_blitz_compose_body | 27194 | 8609 | 8609 | 903 | 9325 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0030 |
| medium-10k/insert-body-span | insert_body_span | blitz | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 4721 | 152 | 671 | 18121 | 0 | 25 | 3619 | 37279 | pi_blitz_insert_body_span | 35180 | 8680 | 8680 | 671 | 18121 | 0 | 3 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0030 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 426 | 173 | 754 | 4778 | 0 | 11 | -931 | 15202 | pi_blitz_multi_body | 18086 | 4151 | 4151 | 754 | 4778 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0018 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | ast_batch | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 4867 | 174 | 729 | 9073 | 0 | 0 | 3650 | 28485 | pi_blitz_patch | 120159 | 8733 | 8733 | 729 | 9073 | 0 | 2 | 16 | yes | 100.0% | -1 | [pi-blitz] tool profile structural registered | 0.0000 | 0.0028 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | ast_narrow | structural | pi_blitz_replace_body_span,pi_blitz_insert_body_span,pi_blitz_wrap_body,pi_blitz_compose_body,pi_blitz_multi_body,pi_blitz_patch | 2551 | 2358 | 46611 | 100 | 626 | 109595 | 0 | 38 | 44110 | 210998 | pi_blitz_replace_body_span | 41550 | 49119 | 49119 | 626 | 109595 | 0 | 3 | 13 | yes | 100.0% | 0 |  | 0.0000 | 0.0138 |

## Pairwise savings (correct rows only)
Skipped; core lane not run.