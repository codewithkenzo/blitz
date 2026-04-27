# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Generated: 2026-04-27T13:25:24.895Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| small/wrap-tail | tiny_unique_replace | core | core | 3387 | 94 | 78 | 100.0% | 0.0043 |
| medium-10k/marker-tail | medium_tail_replace | core | core | 4815 | 60 | 44 | 100.0% | 0.0050 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | 3106 | 66 | 45 | 100.0% | 0.0070 |
| medium-10k/wrap-body | medium_wrap_body | blitz | core | 85732 | 9641 | 9625 | 100.0% | 0.0501 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | 4866 | 91 | 71 | 100.0% | 0.0071 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | core | 3309 | 157 | 141 | 0.0% | 0.0069 |
| medium-10k/compose-preserve-islands | compose_preserve_islands | blitz | blitz | 6286 | 242 | 204 | 100.0% | 0.0067 |
| multi/three-body-ops | multi_body_three_ops | blitz | core | 3064 | 161 | 145 | 0.0% | 0.0030 |
| multi/three-body-ops | multi_body_three_ops | blitz | blitz | 7277 | 340 | 304 | 100.0% | 0.0051 |
| huge-100k/marker-tail | huge_tail_replace | core | core | 6377 | 63 | 47 | 100.0% | 0.0409 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | 17020 | 67 | 46 | 100.0% | 0.0415 |

## Pairwise savings
medium-10k/marker-tail: saved session output -10.0%, saved tool-call args -2.3%
medium-10k/wrap-body: saved session output 99.1%, saved tool-call args 99.3%
medium-10k/compose-preserve-islands: saved session output -54.1%, saved tool-call args -44.7%
multi/three-body-ops: saved session output -111.2%, saved tool-call args -109.7%
huge-100k/marker-tail: saved session output -6.3%, saved tool-call args 2.1%