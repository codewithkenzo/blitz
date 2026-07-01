# compose_body Pi bench results — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Harness: `bench/llm-pi.ts`
Tokenizer for tool args: `cl100k_base` via `tiktoken`

## Medium 10KB compose-preserve-islands

Task: update `mediumCompute` with two small changes while preserving all arithmetic statements:

1. insert a finite seed check immediately after `let total = seed;`,
2. insert an early negative-total return before the final `return total;`.

### Results

| Lane | Correct | Wall ms | Provider output tokens | Tool-call arg tokens | Cost |
|---|---:|---:|---:|---:|---:|
| core `edit` | no | 3,888 | 158 | 142 | $0.0053 |
| `pi_blitz_apply` / `compose_body` | yes | 5,324 | 281 | 247 | $0.0071 |

## Interpretation

This case is not a token-savings-vs-core win because core did not produce a correct golden output. Under the v0.2 policy, failed/incorrect runs are not counted as positive savings.

Still, this is product-relevant: structured `compose_body` gave the model a correct way to preserve large body islands without re-emitting the 10KB function. Core tried a smaller payload but failed correctness.

## Routing policy update

- Tiny unique text replacement -> route to core.
- Body wrap / structural transform -> route to `pi_blitz_apply.wrap_body` (confirmed 97.9% output-token savings vs correct core run on 10KB wrap-body).
- Preserve-island multi-hunk edits -> route to `pi_blitz_apply.compose_body` when correctness matters; current result is correctness advantage, not yet token-savings claim vs a correct core baseline.
- Do not publish aggregate savings for compose until a correct core comparator is available or benchmark class is framed as correctness/reliability improvement.
