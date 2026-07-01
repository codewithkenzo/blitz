# Multi-body bench smoke — 2026-04-27

Model/provider: `openai-codex/gpt-5.4-mini`
Harness: `bench/pi-matrix.ts`
Case: `multi/three-body-ops`

Task edits one file with three functions:

1. `adjust`: replace `return base;` with `return base + 1;`
2. `emit`: insert `const markerUpper = value.toUpperCase();` after `const marker = value;`
3. `risky`: wrap body in try/catch and rethrow

## Blitz lane

Tool intended: `pi_blitz_multi_body`

| Lane | Correct | Provider output | Tool args | Wall | Cost |
|---|---:|---:|---:|---:|---:|
| blitz | yes | 348 | 312 | 5,613ms | $0.0052 |

## Core lane

| Lane | Correct | Provider output | Tool args | Wall | Cost |
|---|---:|---:|---:|---:|---:|
| core | no | 157 | 141 | 4,107ms | $0.0046 |

## Interpretation

This is currently a correctness/routing win, not a token-savings claim. Core emitted fewer tokens but missed the golden output. Blitz used more tokens and succeeded. Incorrect rows must count as zero savings, not a win for core.

Next useful benchmark: make a larger multi-body case where at least one edit wraps a medium/large symbol. That should test multi_body ROI, not just correctness.
