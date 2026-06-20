---
id: bli-lcde
status: closed
deps: []
links: []
created: 2026-06-20T04:59:33Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-f, tokens, bench]
---
# 0.5F optimize survey prompts and row shapes

Reduce benchmark/harness prompt and fixture overhead where it is not part of product behavior, while preserving fairness against core.

## Acceptance Criteria

Survey/true-streak prompts avoid repeated irrelevant context, avoid unchanged-code replay, and keep core/Blitz comparable; self-checks/build pass; no claim from changed prompts until re-measured.


## Notes

**2026-06-20T05:09:49Z**

finding from bli-s7by report: provider-language survey prompt delta is +1414 tokens across 14 green rows (+101 per Blitz row). Optimize row prompt shapes so Blitz-specific instruction/context is not larger than core for tiny/doc/tsx/exact rows. No claim until re-measured.

**2026-06-20T05:17:18Z**

start: optimizing provider-language survey prompts/row shapes. Scope: harness/report prompt shaping only, no model/provider benchmark reruns, no savings claim until remeasured.

**2026-06-20T05:20:51Z**

done: optimized natural/provider-language Blitz preamble and centralized prompt builder. Static guard --self-check-prompt-shapes passes: legacy preamble 887 bytes -> current 440; tiny-exact Blitz prompt 1342 -> 895 (-447). Safety/no-fallback phrases retained. Verification: self-check, bun build bench/natural-edit.ts, git diff --check passed. No benchmark/model/provider reruns; no token-savings claim.

**2026-06-20T05:21:39Z**

done: blitz commit f32b56fb compacts provider-language/natural Blitz prompt shape. Static guard: legacy preamble 887 bytes -> current 440; tiny-exact Blitz prompt 1342 -> 895 (-447). Verification: bun bench/natural-edit.ts --self-check-prompt-shapes passed; bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js passed; git diff --check passed. No model/provider benchmark reruns; no savings claim.
