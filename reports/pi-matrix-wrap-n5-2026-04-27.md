# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 5
Generated: 2026-04-27T18:06:35.029Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| medium-10k/wrap-body | medium_wrap_body | blitz | core | 61699 | 9639 | 9624 | 100.0% | 0.2453 |
| medium-10k/wrap-body | medium_wrap_body | blitz | blitz | 3919 | 85 | 65 | 100.0% | 0.0321 |

## Pairwise savings
medium-10k/wrap-body: saved session output 99.1%, saved tool-call args 99.3%