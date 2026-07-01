# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-09T02-59-35-877Z
Tmux session: pi-bench-2026-06-09T02-59-35-877Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-09T02-59-35-877Z
Visible Blitz tools: pi_blitz_op
Serialized tool spec tokens: 393
Resident skill tokens: 444
Tokscale validation: required
Generated: 2026-06-09T03:01:04.310Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | ast_narrow | minimal-v0 | pi_blitz_op | 393 | 444 | 4770 | 90 | 555 | 8981 | 0 | 22 | 7600 | 23782 | pi_blitz_op | 40561 | 8527 | 8527 | 555 | 8981 | 0 | 2 | 3033 | yes | 100.0% | 0 |  | 0.0000 | 0.0026 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | ast_narrow | minimal-v0 | pi_blitz_op | 393 | 444 | 377 | 65 | 527 | 7937 | 0 | 7 | -375 | 10277 | pi_blitz_op | 43099 | 527 | 527 | 527 | 7937 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0009 |

## Profile coverage / skipped rows
minimal-v0: supported 2/2; skipped 0
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