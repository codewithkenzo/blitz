# Strong Blitz edit classes N=5 — 2026-04-27

Provider/model: `openai-codex/gpt-5.4-mini`
Harness: `bench/pi-matrix.ts`
Iterations: 5

## Case 1: `medium-10k/wrap-body`

Both lanes correct in all 5 runs.

| Lane | Correct | Median output | Median args | Median wall | Cost sum |
|---|---:|---:|---:|---:|---:|
| core `edit` | 100% | 9,639 | 9,624 | 61,699ms | $0.2453 |
| `pi_blitz_wrap_body` | 100% | 85 | 65 | 3,919ms | $0.0321 |

Reductions:

- Provider output: 99.1%
- Tool args: 99.3%
- Wall time: 93.6%
- Cost sum: 86.9%

This is the clean both-correct proof class.

## Case 2: `multi/large-structural`

Task:

1. Wrap `mediumCompute` 10KB body in try/catch.
2. Insert tagged audit line in `auditEvent`.
3. Replace `formatStatus` return with uppercase.

Core lane from N=5 attempt:

| Lane | Correct | Median output | Median args | Median wall | Cost sum |
|---|---:|---:|---:|---:|---:|
| core `edit` | 0% | 9,739 | 9,689 | 86,839ms | $0.2972 |

Failures were semantic, not just formatting:

- changed requested variable name/string (`tagged` → `auditTag`, uppercase variants)
- duplicated functions in some runs
- one timeout/exit 143 with huge output

Initial unrestricted Blitz run exposed two issues:

- model sometimes indented catch body itself, producing over-indented catch body
- model sometimes included a semicolon in `replace_return`, producing `;;`
- broader tool set let the model retry with multiple tools after a bad tuple

Fixes applied:

- `replace_return` trims one trailing semicolon from expr before adding language suffix
- `try_catch` trims each catch body line before applying deterministic indentation
- matrix restricts `multi/large-structural` Blitz lane to `pi_blitz_patch` to test the compact patch tool directly
- expected golden now matches deterministic `try_catch` body indentation

Restricted `pi_blitz_patch` N=5 after fixes:

| Lane | Correct | Median output | Median args | Median wall | Cost sum |
|---|---:|---:|---:|---:|---:|
| `pi_blitz_patch` | 100% | 108 | 89 | 3,211ms | $0.0310 |

Reductions vs core attempt:

- Provider output: 98.9%
- Tool args: 99.1%
- Wall time: 96.3%
- Cost sum: 89.6%

This is a correctness + efficiency proof class, not a both-correct savings class, because core never matched the golden output.

## Product conclusion

Blitz saves real provider output tokens when edit has large preserved structure and compact semantic intent:

- large body wrap: proven both-correct N=5
- large structural multi-edit: proven patch-correct N=5, core failed N=5

Blitz should not claim universal replacement for core edit. Strong lane policy remains:

- tiny exact edit → core
- simple unique marker/tail replacement → core
- large body wrap → Blitz
- semantic structural patch → Blitz
- preserve-island/multi-hunk edits → Blitz for correctness first, then benchmark token ROI

Public claims should separate:

- provider output tokens
- tool-call arg tokens
- correctness
- retry/malformed rate
- wall time
- cost
