# Pi local matrix results

Provider: anthropic
Model: claude-haiku-4-5
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-06-10T08-35-55-730Z
Tmux session: pi-bench-2026-06-10T08-35-55-730Z
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-10T08-35-55-730Z
Visible Blitz tools: pi_blitz_op
Serialized tool spec tokens: 454
Resident skill tokens: 580
Tokscale validation: required
Generated: 2026-06-10T08:35:57.579Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| medium-10k/marker-tail | medium_tail_replace | core | blitz | ast_narrow | minimal-v0 | pi_blitz_op | 454 | 580 | 4745 | 0 | 0 | 0 | 0 | 0 | -1034 | 5779 |  | 1210 | 0 | 0 | 0 | 0 | 0 | 1 | 15 | yes | 0.0% | 1 | [pi-blitz] tool profile minimal-v0 registered 403 {"type":"error","error":{"type":"permission_error","message":"OAuth authentication is currently not allowed for this organization."},"request_id":"req_011CbuGphnRj2CZHoy4mCrkN"} | 0.0000 | 0.0000 |

## Profile coverage / skipped rows
minimal-v0: supported 1/1; skipped 0

## Resident overhead comparison
minimal-v0: schema 454, skill 580, combined 1034, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.