# Compact patch large-structural smoke — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Iterations: 1
Harness: `bench/pi-matrix.ts`
Case: `multi/large-structural`

Task:

1. Wrap `mediumCompute` 10KB body in try/catch.
2. Insert tagged audit line in `auditEvent`.
3. Replace `formatStatus` return with uppercase return.

Blitz lane guidance used `pi_blitz_patch` tuple ops:

```json
[
  ["try_catch", "mediumCompute", "console.error(error);\nthrow error;"],
  ["insert_after", "auditEvent", "const normalized = event.trim();", "\n  const tagged = `[audit] ${normalized}`;", "only"],
  ["replace_return", "formatStatus", "status.toUpperCase()", "only"]
]
```

## Result

| Lane | Correct | Provider output | Tool args | Wall | Cost |
|---|---:|---:|---:|---:|---:|
| core `edit` | no | 9,709 | 9,691 | 83,635ms | $0.0507 |
| `pi_blitz_patch` | yes | 109 | 90 | 4,764ms | $0.0075 |

## Reductions vs core attempt

| Metric | Reduction |
|---|---:|
| Provider output tokens | 98.9% |
| Tool-call arg tokens | 99.1% |
| Wall time | 94.3% faster |
| Cost | 85.2% lower |

## Interpretation

This is the first good `patch` ROI smoke. It combines two advantages:

- Core had to emit/attempt a huge edit payload and still missed golden output.
- `pi_blitz_patch` expressed the whole multi-edit as compact semantic tuples.

Because core was incorrect, this should be reported as a correctness + efficiency win against a core attempt, not a pure both-correct savings row. For public claims, rerun N>=5 and include malformed/retry rate.

## Comparison to synthetic payload estimate

Earlier synthetic payload comparison showed tuple `patch` reduces argument payloads by ~48% vs object-shaped `multi_body`. In the live Pi run, the model emitted only 90 tool-arg tokens for the full large structural multi-edit.
