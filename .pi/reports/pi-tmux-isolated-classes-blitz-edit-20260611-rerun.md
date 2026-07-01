# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Runner: spawn
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tool profile: minimal
Accounting artifact root: /home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-11T19-17-43-149Z
Visible Blitz tools: blitz_edit
Serialized tool spec tokens: 653
Resident skill tokens: 268
Tokscale validation: required
Generated: 2026-06-11T19:20:16.928Z

| Fixture | Class | Recommended | Lane | route | profile | visible tools | schema tok | skill tok | prompt tok | arg tok | output tok | cache read | cache write | result payload tok | residual input tok | total context tok | tool | wall ms | input tok | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| config/key-update | config_key_update | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 215 | 0 | 56 | 7653 | 0 | 0 | -682 | 9084 |  | 4983 | 239 | 239 | 56 | 7653 | 0 | 2 | 21 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |
| logging/insert-timer | logging_insert_timer | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 254 | 0 | 73 | 7664 | 0 | 0 | -612 | 9221 |  | 6264 | 309 | 309 | 73 | 7664 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0004 |
| markdown/append-section | markdown_append_section | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 239 | 0 | 70 | 7660 | 0 | 0 | -625 | 9186 |  | 5835 | 296 | 296 | 70 | 7660 | 0 | 2 | 14 | yes | 100.0% | 0 |  | 0.0000 | 0.0004 |
| json/config-key | json_config_key | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 193 | 0 | 56 | 7629 | 0 | 6 | -701 | 9025 |  | 5266 | 220 | 220 | 56 | 7629 | 0 | 2 | 15 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |
| yaml/config-key | yaml_config_key | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 189 | 0 | 2181 | 220477 | 0 | 0 | -33 | 224656 |  | 120012 | 888 | 888 | 2181 | 220477 | 0 | 42 | 16 | yes | 100.0% | 143 | [pi-blitz] tool profile minimal-v0 registered | 0.0000 | 0.0092 |
| toml/config-key | toml_config_key | core | blitz | ast_narrow | minimal-v0 | blitz_edit | 653 | 268 | 174 | 0 | 51 | 7608 | 0 | 0 | -722 | 8953 |  | 10743 | 199 | 199 | 51 | 7608 | 0 | 2 | 16 | yes | 100.0% | 0 |  | 0.0000 | 0.0003 |

## Profile coverage / skipped rows
minimal-v0: supported 6/6; skipped 0

## Resident overhead comparison
minimal-v0: schema 653, skill 268, combined 921, reduction vs full unavailable; unknown

## Pairwise savings (correct rows only)
Skipped; core lane not run.