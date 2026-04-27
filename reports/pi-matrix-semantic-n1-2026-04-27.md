# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 1
Generated: 2026-04-27T19:28:33.609Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| semantic/async-try-catch | async_try_catch | blitz | blitz | 6013 | 61 | 40 | 100.0% | 0.0028 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | 3213 | 62 | 41 | 100.0% | 0.0014 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | 2761 | 55 | 35 | 100.0% | 0.0014 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | 3282 | 55 | 35 | 100.0% | 0.0014 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | 3124 | 69 | 49 | 100.0% | 0.0013 |

## Pairwise savings