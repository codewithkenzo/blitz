# Pi local matrix results

Provider: zai
Model: glm-4.5-air
Iterations: 1
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T05:28:53.976Z

| Fixture | Class | Recommended | Lane | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale matches parser | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | blitz | pi_blitz_replace_body_span | 19441 | 5569 | 542 | 6085 | 0 | 52 | 5569 | 542 | 6085 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0019 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | pi_blitz_replace_body_span | 13999 | 7370 | 354 | 8418 | 0 | 46 | 7370 | 354 | 8418 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0021 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | pi_blitz_wrap_body | 17964 | 4921 | 586 | 11102 | 0 | 67 | 4921 | 586 | 11102 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0000 | 0.0020 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | pi_blitz_compose_body | 21616 | 7988 | 863 | 8411 | 0 | 165 | 7988 | 863 | 8411 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0000 | 0.0028 |
| medium-10k/insert-body-span | insert_body_span | blitz | blitz | pi_blitz_insert_body_span | 11912 | 7816 | 374 | 8157 | 0 | 73 | 7816 | 374 | 8157 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0022 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | pi_blitz_multi_body | 17944 | 446 | 705 | 6903 | 0 | 145 | 446 | 705 | 6903 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0000 | 0.0011 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | pi_blitz_patch | 18607 | 7917 | 719 | 8357 | 0 | 85 | 7917 | 719 | 8357 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0000 | 0.0026 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | pi_blitz_replace_body_span | 26055 | 48902 | 409 | 55091 | 0 | 47 | 48902 | 409 | 55091 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0000 | 0.0119 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | pi_blitz_try_catch | 9971 | 3209 | 272 | 3447 | 0 | 42 | 3209 | 272 | 3447 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0000 | 0.0010 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | pi_blitz_try_catch | 19995 | 368 | 453 | 6344 | 0 | 41 | 368 | 453 | 6344 | 0 | 2 | 32 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | pi_blitz_replace_return | 10931 | 3268 | 361 | 3554 | 0 | 36 | 3268 | 361 | 3554 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0000 | 0.0012 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | pi_blitz_replace_return | 18082 | 398 | 488 | 6564 | 0 | 36 | 398 | 488 | 6564 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0000 | 0.0008 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | pi_blitz_replace_return | 11744 | 266 | 371 | 6304 | 0 | 48 | 266 | 371 | 6304 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0000 | 0.0007 |

## Pairwise savings