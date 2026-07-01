# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T02-48-53-599Z
Tmux session: pi-bench-2026-06-09T02-48-53-599Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/current/pi-accounting-runs/2026-06-09T02-48-53-599Z
Visible Blitz tools: pi_blitz_op
Serialized tool spec tokens: 393
Resident skill tokens: 444
Tokscale validation: required
Generated: 2026-06-09T02:52:54.217Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | core | core_edit | core | edit | 0 | 0 | 4639 | 0 | 0 | 0 | 0 | 0 | 0 | 4639 |  | 120168 | 0 |  |  |  |  |  |  | no | 0.0% | -1 | no session jsonl (run failed/timed out) | 0.0000 |  |
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | core_edit | core | edit | 0 | 0 | 271 | 464 | 2135 | 34972 | 0 | 0 | 4822 | 43128 | edit | 120150 | 5286 | 5286 | 2135 | 34972 | 0 | 8 | 15 | yes | 0.0% | -1 |  | 0.0000 | 0.0045 |

## Profile coverage / skipped rows
minimal-v0: supported 0/2; skipped 2 (medium-10k/wrap-body: unsupported by minimal-v0 registered tool profile; semantic/arrow-replace-return: unsupported by minimal-v0 registered tool profile)

## Resident overhead comparison
minimal-v0: schema 393, skill 444, combined 837, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)