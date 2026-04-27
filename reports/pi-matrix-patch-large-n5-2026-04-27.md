# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 5
Generated: 2026-04-27T18:14:59.560Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| multi/large-structural | multi_body_large_structural | blitz | core | 86839 | 9739 | 9689 | 0.0% | 0.2972 |
| multi/large-structural | multi_body_large_structural | blitz | blitz | 3142 | 104 | 85 | 60.0% | 0.0312 |

## Pairwise savings
multi/large-structural: saved session output 98.9%, saved tool-call args 99.1%