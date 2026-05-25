# Pi local matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Runner: tmux
Run root: /home/kenzo/dev/blitz/reports/pi-tmux-runs/2026-05-25T06-27-37-311Z
Tmux session: pi-bench-2026-05-25T06-27-37-311Z
Timeout per run: 120000ms
Pi: /home/kenzo/.local/bin/pi
Blitz binary PATH prepend: /home/kenzo/dev/blitz/zig-out/bin
Extension: /home/kenzo/dev/pi-blitz/dist/index.js
Skill: /home/kenzo/dev/pi-blitz/skills/pi-blitz
Tokscale validation: required
Generated: 2026-05-25T06:33:05.673Z

| Fixture | Class | Recommended | Lane | tool | wall ms | input tok | output tok | cache read | cache write | edit args tok (cl100k) | tokscale input | tokscale output | tokscale cache read | tokscale cache write | tokscale messages | tokscale ms | tokscale token match | correct | exit | failure | $ | tokscale $ |
|---|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|---|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | edit | 4800 | 886 | 122 | 5120 | 0 | 106 | 886 | 122 | 5120 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0016 | 0.0016 |
| medium-10k/marker-tail | medium_tail_replace | core | core | edit | 4848 | 7789 | 92 | 7168 | 0 | 76 | 7789 | 92 | 7168 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0068 | 0.0068 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | pi_blitz_replace_body_span | 5426 | 8089 | 112 | 7168 | 0 | 91 | 8089 | 112 | 7168 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0071 | 0.0071 |
| medium-10k/wrap-body | medium_wrap_body | blitz | core | edit | 86474 | 7657 | 9672 | 16896 | 0 | 9656 | 7657 | 9672 | 16896 | 0 | 2 | 37 | yes | 0.0% | 0 |  | 0.0505 | 0.0505 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | pi_blitz_wrap_body | 5129 | 8240 | 117 | 7168 | 0 | 97 | 8240 | 117 | 7168 | 0 | 2 | 42 | yes | 100.0% | 0 |  | 0.0072 | 0.0072 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | core | edit | 7306 | 5396 | 193 | 9728 | 0 | 177 | 5396 | 193 | 9728 | 0 | 2 | 29 | yes | 0.0% | 0 |  | 0.0056 | 0.0056 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | pi_blitz_compose_body | 6685 | 7951 | 219 | 7680 | 0 | 198 | 7951 | 219 | 7680 | 0 | 2 | 37 | yes | 100.0% | 0 |  | 0.0075 | 0.0075 |
| medium-10k/insert-body-span | insert_body_span | blitz | core | edit | 7151 | 7834 | 116 | 7168 | 0 | 100 | 7834 | 116 | 7168 | 0 | 2 | 29 | yes | 0.0% | 0 |  | 0.0069 | 0.0069 |
| medium-10k/insert-body-span | insert_body_span | blitz | blitz | pi_blitz_insert_body_span | 8116 | 8182 | 126 | 7168 | 0 | 105 | 8182 | 126 | 7168 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0072 | 0.0072 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | edit | 6764 | 3233 | 259 | 3072 | 0 | 243 | 3233 | 259 | 3072 | 0 | 2 | 34 | yes | 100.0% | 0 |  | 0.0038 | 0.0038 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | pi_blitz_multi_body | 9047 | 6941 | 384 | 3584 | 0 | 348 | 6941 | 384 | 3584 | 0 | 3 | 29 | yes | 100.0% | 0 |  | 0.0072 | 0.0072 |
| multi/large-structural | multi_body_large_structural | blitz | core | edit | 74344 | 5332 | 9773 | 19456 | 0 | 9755 | 5332 | 9773 | 19456 | 0 | 2 | 33 | yes | 0.0% | 0 |  | 0.0494 | 0.0494 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | pi_blitz_patch | 5470 | 8014 | 134 | 7680 | 0 | 115 | 8014 | 134 | 7680 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0072 | 0.0072 |
| huge-100k/marker-tail | huge_tail_replace | core | core | edit | 8474 | 49663 | 96 | 49152 | 0 | 80 | 49663 | 96 | 49152 | 0 | 2 | 36 | yes | 100.0% | 0 |  | 0.0414 | 0.0414 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | pi_blitz_replace_body_span | 8541 | 49965 | 115 | 49152 | 0 | 94 | 49965 | 115 | 49152 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0417 | 0.0417 |
| semantic/async-try-catch | async_try_catch | blitz | core | edit | 11523 | 3298 | 197 | 3072 | 0 | 181 | 3298 | 197 | 3072 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0036 | 0.0036 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | pi_blitz_try_catch | 5014 | 3456 | 108 | 3072 | 0 | 87 | 3456 | 108 | 3072 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | core | edit | 5460 | 702 | 166 | 5632 | 0 | 150 | 702 | 166 | 5632 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0017 | 0.0017 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | pi_blitz_try_catch | 5429 | 3437 | 94 | 3072 | 0 | 73 | 3437 | 94 | 3072 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0032 | 0.0032 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | edit | 4737 | 3672 | 92 | 2560 | 0 | 76 | 3672 | 92 | 2560 | 0 | 2 | 30 | yes | 100.0% | 0 |  | 0.0034 | 0.0034 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | pi_blitz_replace_return | 4893 | 3437 | 101 | 3072 | 0 | 81 | 3437 | 101 | 3072 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | core | edit | 4865 | 1112 | 92 | 5120 | 0 | 76 | 1112 | 92 | 5120 | 0 | 2 | 28 | yes | 100.0% | 0 |  | 0.0016 | 0.0016 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | pi_blitz_replace_return | 6294 | 3436 | 101 | 3072 | 0 | 81 | 3436 | 101 | 3072 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | core | edit | 10018 | 915 | 114 | 5120 | 0 | 98 | 915 | 114 | 5120 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0016 | 0.0016 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | pi_blitz_replace_return | 4835 | 3707 | 99 | 2560 | 0 | 79 | 3707 | 99 | 2560 | 0 | 2 | 31 | yes | 100.0% | 0 |  | 0.0034 | 0.0034 |
| readme/core-smoke | markdown_core_only | core | core | edit | 5123 | 3481 | 120 | 2560 | 0 | 104 | 3481 | 120 | 2560 | 0 | 2 | 29 | yes | 100.0% | 0 |  | 0.0033 | 0.0033 |

## Pairwise savings
medium-10k/marker-tail: saved session output -21.7%, saved tool-call args -19.7%
medium-10k/wrap-body: saved session output 98.8%, saved tool-call args 99.0%
medium-10k/compose-preserve-islands: saved session output -13.5%, saved tool-call args -11.9%
medium-10k/insert-body-span: saved session output -8.6%, saved tool-call args -5.0%
multi/three-body-ops: saved session output -48.3%, saved tool-call args -43.2%
multi/large-structural: saved session output 98.6%, saved tool-call args 98.8%
huge-100k/marker-tail: saved session output -19.8%, saved tool-call args -17.5%
semantic/async-try-catch: saved session output 45.2%, saved tool-call args 51.9%
semantic/class-method-try-catch: saved session output 43.4%, saved tool-call args 51.3%
semantic/arrow-replace-return: saved session output -9.8%, saved tool-call args -6.6%
semantic/nested-return-occurrence: saved session output -9.8%, saved tool-call args -6.6%
semantic/tsx-replace-return: saved session output 13.2%, saved tool-call args 19.4%

## Core-only notes
small/wrap-tail: core-only cost/control smoke; no Blitz structured AST savings claim.
readme/core-smoke: core-only cost/control smoke; no Blitz structured AST savings claim.