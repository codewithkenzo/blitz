# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Generated: 2026-04-27T20:20:22.068Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | 3166 | 93 | 77 | 100.0% | 0.0027 |
| medium-10k/marker-tail | medium_tail_replace | core | core | 3614 | 62 | 46 | 100.0% | 0.0065 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | 3091 | 65 | 44 | 100.0% | 0.0076 |
| medium-10k/wrap-body | medium_wrap_body | blitz | core | 61244 | 9640 | 9624 | 100.0% | 0.0488 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | 4605 | 85 | 65 | 100.0% | 0.0053 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | core | 3734 | 157 | 141 | 0.0% | 0.0067 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | 4299 | 244 | 206 | 100.0% | 0.0096 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | 7355 | 157 | 141 | 0.0% | 0.0018 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | 3194 | 108 | 89 | 0.0% | 0.0068 |
| multi/large-structural | multi_body_large_structural | blitz | core | 61378 | 9708 | 9692 | 0.0% | 0.0507 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | 3956 | 107 | 88 | 100.0% | 0.0067 |
| huge-100k/marker-tail | huge_tail_replace | core | core | 6605 | 64 | 48 | 100.0% | 0.0397 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | 5492 | 67 | 46 | 100.0% | 0.0422 |
| semantic/async-try-catch | async_try_catch | blitz | core | 4434 | 165 | 149 | 100.0% | 0.0019 |
| semantic/async-try-catch | async_try_catch | blitz | blitz | 2484 | 63 | 42 | 100.0% | 0.0015 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | core | 3638 | 134 | 118 | 100.0% | 0.0031 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | 2580 | 61 | 40 | 100.0% | 0.0014 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | core | 4582 | 62 | 46 | 100.0% | 0.0013 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | 4276 | 56 | 36 | 100.0% | 0.0014 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | core | 3593 | 62 | 46 | 100.0% | 0.0027 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | 3149 | 56 | 36 | 100.0% | 0.0014 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | core | 3433 | 83 | 67 | 100.0% | 0.0013 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | 2881 | 68 | 48 | 100.0% | 0.0030 |

## Pairwise savings
medium-10k/marker-tail: saved session output -4.8%, saved tool-call args 4.3%
medium-10k/wrap-body: saved session output 99.1%, saved tool-call args 99.3%
medium-10k/compose-preserve-islands: saved session output -55.4%, saved tool-call args -46.1%
multi/three-body-ops: saved session output 31.2%, saved tool-call args 36.9%
multi/large-structural: saved session output 98.9%, saved tool-call args 99.1%
huge-100k/marker-tail: saved session output -4.7%, saved tool-call args 4.2%
semantic/async-try-catch: saved session output 61.8%, saved tool-call args 71.8%
semantic/class-method-try-catch: saved session output 54.5%, saved tool-call args 66.1%
semantic/arrow-replace-return: saved session output 9.7%, saved tool-call args 21.7%
semantic/nested-return-occurrence: saved session output 9.7%, saved tool-call args 21.7%
semantic/tsx-replace-return: saved session output 18.1%, saved tool-call args 28.4%