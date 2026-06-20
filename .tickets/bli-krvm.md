---
id: bli-krvm
status: closed
deps: []
links: []
created: 2026-06-20T05:09:49Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-f, tokens, route]
---
# 0.5F add simple-row route budget guard

Follow-up from bli-s7by: green provider-language rows are token-negative when tiny/simple exact rows pay fixed Blitz schema/skill/prompt tax. Add a deterministic budget/route guard so tiny/simple exact/doc/tsx rows choose core unless Blitz expected prompt/schema/result budget can beat or tie core. No hidden fallback; decision must be explicit and measurable.

## Acceptance Criteria

Guard has deterministic byte/token thresholds; tiny/simple row routing decision is logged/classified; no provider-wide claim without rerun evidence; tests cover core-choice and Blitz-choice boundaries.


## Notes

**2026-06-20T05:34:46Z**

Implemented deterministic simple-row route budget guard in bench/natural-edit.ts. Verification passed: route-budget self-check, prompt-shape self-check, bench script bundle check, LSP diagnostics clean. No model/provider runs.
