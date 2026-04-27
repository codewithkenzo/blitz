# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Generated: 2026-04-27T12:47:16.256Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| medium-10k/marker-tail | medium_tail_replace | core | core | 3727 | 63 | 47 | 100.0% | 0.0062 |
| medium-10k/marker-tail | medium_tail_replace | core | blitz | 3507 | 66 | 45 | 100.0% | 0.0051 |
| huge-100k/marker-tail | huge_tail_replace | core | core | 4714 | 63 | 47 | 100.0% | 0.0407 |
| huge-100k/marker-tail | huge_tail_replace | core | blitz | 4449 | 67 | 46 | 100.0% | 0.0396 |

## Pairwise savings
medium-10k/marker-tail: saved session output -4.8%, saved tool-call args 4.3%
huge-100k/marker-tail: saved session output -6.3%, saved tool-call args 2.1%