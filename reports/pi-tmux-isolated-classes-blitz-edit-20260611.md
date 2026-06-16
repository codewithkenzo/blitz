# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: spawn
Timeout per run: 180000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/reports/pi-accounting-runs/2026-06-11T19-06-20-839Z
Visible Blitz tools: blitz_edit
Serialized tool spec tokens: 653
Resident skill tokens: 268
Tokscale validation: required
Generated: 2026-06-11T19:15:26.471Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 209 | 0 | 67 | 7624 | 0 | 6 | -658 | 9090 |  | 4755 | 263 | 263 | 67 | 7624 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0004 |
| config/key-update | config_key_update | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 202 | 0 | 3055 | 410866 | 0 | 0 | 1399 | 417364 |  | 180110 | 2320 | 2320 | 3055 | 410866 | 0 | 64 | 15 | yes | 0.0% | 143 | [pi-blitz] tool profile minimal-v0 registered | 0.0000 | 0.0162 |
| logging/insert-timer | logging_insert_timer | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 244 | 0 | 4599 | 426473 | 0 | 0 | 2201 | 435359 |  | 180106 | 3122 | 3122 | 4599 | 426473 | 0 | 53 | 17 | yes | 0.0% | 143 | [pi-blitz] tool profile minimal-v0 registered | 0.0000 | 0.0185 |
| markdown/append-section | markdown_append_section | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 235 | 0 | 3829 | 564560 | 0 | 0 | 8487 | 578953 |  | 180109 | 9408 | 9408 | 3829 | 564560 | 0 | 56 | 15 | yes | 0.0% | 143 | [pi-blitz] tool profile minimal-v0 registered | 0.0000 | 0.0230 |

## Profile coverage / skipped rows
minimal-v0: supported 3/4; skipped 1 (small/wrap-tail: core-only fixture)

## Resident overhead comparison
minimal-v0: schema 653, skill 268, combined 921, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.