# Structured apply Pi bench results — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Harness: `bench/llm-pi.ts`
Tokenizer for tool args: `cl100k_base` via `tiktoken`

## Medium 10KB wrap-body

Task: wrap `mediumCompute` body in `try/catch`, preserving every existing statement.

| Lane | Correct | Wall ms | Provider output tokens | Tool-call arg tokens | Cost |
|---|---:|---:|---:|---:|---:|
| core `edit` | yes | 61,545 | 9,640 | 9,624 | $0.0485 |
| `pi_blitz_apply` / `wrap_body` | yes | 9,348 | 202 | 168 | $0.0065 |

Savings vs core:

- provider output tokens: 97.9%
- tool-call argument tokens: 98.3%
- wall time: 84.8%
- cost: 86.6%

This is the first authentic result showing the structured IR doing what the freeform marker API did not: the model emits a tiny semantic operation instead of a 10KB body rewrite.

## Small body rewrite

| Lane | Correct | Wall ms | Provider output tokens | Tool-call arg tokens |
|---|---:|---:|---:|---:|
| core `edit` | yes | 5,266 | 93 | 77 |
| `pi_blitz_apply` / `replace_body_span` | yes | 3,270 | 108 | 89 |

Result: structured apply loses small unique/local edits due to JSON operation overhead. This is expected; core edit is already near-optimal for small exact text replacements.

## Medium 10KB one-line tail edit

| Lane | Correct | Wall ms | Provider output tokens | Tool-call arg tokens |
|---|---:|---:|---:|---:|
| core `edit` | yes | 2,908 | 60 | 44 |
| `pi_blitz_apply` / `replace_body_span` | yes | 3,403 | 101 | 82 |

Result: core edit wins when an exact unique line can be patched with tiny `oldText/newText`. Do not claim blitz wins this class.

## Interpretation

`pi_blitz_apply` should target structural operations where core must re-emit large spans: body wraps, preserved-island rewrites, multi-hunk same-symbol edits, safe insert/move/delete/rename. It should not replace core `edit` for tiny unique text patches.

Failed or incorrect runs should remain in aggregate tables as zero savings.
