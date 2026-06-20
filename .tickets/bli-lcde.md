---
id: bli-lcde
status: open
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
