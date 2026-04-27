# Semantic narrow tools N=5 — 2026-04-27

Provider/model: `openai-codex/gpt-5.4-mini`
Lane: Blitz only, tool-restricted per case.
Iterations: 5 per fixture.
Raw reports:

- `reports/pi-matrix-semantic-n1-2026-04-27.{json,md}`
- `reports/pi-matrix-semantic-n5-2026-04-27.{json,md}`

## Result

| Fixture | Tool | Correct | Median output tokens | Median arg tokens | Median wall |
|---|---|---:|---:|---:|---:|
| `semantic/async-try-catch` | `pi_blitz_try_catch` | 100% | 61 | 40 | 2,603ms |
| `semantic/class-method-try-catch` | `pi_blitz_try_catch` | 100% | 62 | 41 | 2,732ms |
| `semantic/arrow-replace-return` | `pi_blitz_replace_return` | 100% | 55 | 35 | 3,324ms |
| `semantic/nested-return-occurrence` | `pi_blitz_replace_return` | 100% | 56 | 36 | 2,431ms |
| `semantic/tsx-replace-return` | `pi_blitz_replace_return` | 100% | 67 | 47 | 2,589ms |

## Notes

- Initial N=1 exposed two real gaps: method body wrapping indentation and arrow-function return replacement.
- Fixes added:
  - `try_catch` now infers body base indentation and preserves outer closing indentation.
  - body lookup can recurse into nested declaration children, enabling `const name = (...) => {}` arrow bodies.
- These rows are reliability/coverage evidence for the semantic tools, not core-vs-Blitz savings claims.
