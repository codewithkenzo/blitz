# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Generated: 2026-04-27T17:58:16.075Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| multi/large-structural | multi_body_large_structural | blitz | core | 83635 | 9709 | 9691 | 0.0% | 0.0507 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | 4764 | 109 | 90 | 100.0% | 0.0075 |

## Pairwise savings
multi/large-structural: saved session output 98.9%, saved tool-call args 99.1%