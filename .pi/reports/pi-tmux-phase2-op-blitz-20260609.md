# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T02-46-18-961Z
Tmux session: pi-bench-2026-06-09T02-46-18-961Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T02-46-18-961Z
Visible Blitz tools: pi_blitz_op
Serialized tool spec tokens: 393
Resident skill tokens: 444
Tokscale validation: required
Generated: 2026-06-09T02:48:47.842Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | ast_narrow | minimal-v0 | pi_blitz_op | 393 | 444 | 4784 | 90 | 622 | 9003 | 0 | 29 | 7612 | 23904 | pi_blitz_op | 72740 | 8539 | 8539 | 622 | 9003 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0027 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | minimal-v0 | pi_blitz_op | 393 | 444 | 369 | 193 | 1193 | 18079 | 0 | 50 | -467 | 21284 | pi_blitz_op | 75000 | 563 | 563 | 1193 | 18079 | 0 | 4 | 16 | yes | 0.0% | 0 |  | 0.0000 | 0.0020 |

## Profile coverage / skipped rows
minimal-v0: supported 0/2; skipped 2 (medium-10k/wrap-body: unsupported by minimal-v0 registered tool profile; semantic/arrow-replace-return: unsupported by minimal-v0 registered tool profile)
semantic: supported 1/2; skipped 1 (medium-10k/wrap-body: unsupported by semantic registered tool profile)
structural: supported 1/2; skipped 1 (semantic/arrow-replace-return: unsupported by structural registered tool profile)
full: supported 2/2; skipped 0

## Resident overhead comparison
minimal-v0: schema 393, skill 444, combined 837, reduction vs full 87.0%; meets >=70% combined target
semantic: schema 1497, skill 444, combined 1941, reduction vs full 70.0%; below >=70% combined target
structural: schema 1689, skill 444, combined 2133, reduction vs full 67.0%; below >=70% combined target
full: schema 6016, skill 444, combined 6460, reduction vs full 0.0%; below >=70% combined target

## Pairwise savings (correct rows only)
Skipped; core lane not run.