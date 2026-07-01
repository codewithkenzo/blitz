# Pi matrix results

Provider: openai-codex
Model: gpt-5.4-mini
Iterations: 5
Generated: 2026-04-27T19:30:09.345Z

| Fixture | Class | Recommended | Lane | wall ms | session output tok | edit args tok (cl100k) | correct | $ |
|---|---|---|---|---:|---:|---:|---:|---:|
| semantic/async-try-catch | async_try_catch | blitz | blitz | 2603 | 61 | 40 | 100.0% | 0.0104 |
| semantic/class-method-try-catch | class_method_try_catch | blitz | blitz | 2732 | 62 | 41 | 100.0% | 0.0110 |
| semantic/arrow-replace-return | arrow_replace_return | blitz | blitz | 3324 | 55 | 35 | 100.0% | 0.0135 |
| semantic/nested-return-occurrence | nested_return_occurrence | blitz | blitz | 2431 | 56 | 36 | 100.0% | 0.0084 |
| semantic/tsx-replace-return | tsx_replace_return | blitz | blitz | 2589 | 67 | 47 | 100.0% | 0.0065 |

## Pairwise savings