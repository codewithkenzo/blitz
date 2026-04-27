# Narrow pi_blitz_* tool bench results — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Harness: `bench/llm-pi.ts` updated to allow only narrow structured tools in Blitz lane:

- `pi_blitz_replace_body_span`
- `pi_blitz_insert_body_span`
- `pi_blitz_wrap_body`
- `pi_blitz_compose_body`

Tokenizer for tool args: `cl100k_base` via `tiktoken`.

## Key result: narrow tools reduce overhead significantly

### Medium 10KB wrap-body

Previous generic `pi_blitz_apply` result:

| Tool | Correct | Provider output tokens | Tool arg tokens | Wall ms |
|---|---:|---:|---:|---:|
| generic `pi_blitz_apply.wrap_body` | yes | 202 | 168 | 9,348 |

New narrow tool result:

| Tool | Correct | Provider output tokens | Tool arg tokens | Wall ms |
|---|---:|---:|---:|---:|
| `pi_blitz_wrap_body` | yes | 85 | 65 | 5,502 |

Improvement vs generic apply:

- output tokens: 57.9% less
- arg tokens: 61.3% less

Compared to previous correct core run for same task:

| Lane | Correct | Provider output tokens | Tool arg tokens | Wall ms |
|---|---:|---:|---:|---:|
| core `edit` | yes | 9,640 | 9,624 | 61,545 |
| `pi_blitz_wrap_body` | yes | 85 | 65 | 5,502 |

Savings vs core:

- provider output tokens: 99.1%
- tool-call arg tokens: 99.3%
- wall time: 91.1%

## Compose preserve-islands

Previous generic `pi_blitz_apply.compose_body` result:

| Tool | Correct | Provider output tokens | Tool arg tokens | Wall ms |
|---|---:|---:|---:|---:|
| generic `pi_blitz_apply.compose_body` | yes | 281 | 247 | 5,324 |

New narrow tool result:

| Tool | Correct | Provider output tokens | Tool arg tokens | Wall ms |
|---|---:|---:|---:|---:|
| `pi_blitz_compose_body` | yes | 246 | 208 | 6,127 |

Improvement vs generic apply:

- output tokens: 12.5% less
- arg tokens: 15.8% less

Core comparator for this case was incorrect, so do not publish a savings-vs-core claim yet. This remains a correctness/reliability advantage case.

## Medium 10KB one-line tail edit

Previous generic `pi_blitz_apply.replace_body_span` result:

| Tool | Correct | Provider output tokens | Tool arg tokens |
|---|---:|---:|---:|
| generic `pi_blitz_apply.replace_body_span` | yes | 101 | 82 |

New narrow tool result:

| Tool | Correct | Provider output tokens | Tool arg tokens |
|---|---:|---:|---:|
| `pi_blitz_replace_body_span` | yes | 67 | 46 |

Previous correct core result for same class:

| Lane | Correct | Provider output tokens | Tool arg tokens |
|---|---:|---:|---:|
| core `edit` | yes | 60 | 44 |

Interpretation: narrow `replace_body_span` nearly matches core on this tiny exact-span class, but core still wins slightly. Route tiny/unique oldText edits to core; use Blitz when exact anchors are structural, large, or correctness-sensitive.

## Product conclusion

Narrow tools solve a real issue: generic apply JSON overhead and model confusion. `pi_blitz_wrap_body` is now the strongest token-saving path: 85 output tokens vs core's 9,640 on a correct 10KB structural edit.
