---
id: bli-cwfj
status: closed
deps: []
links: []
created: 2026-06-20T07:02:09Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-i, tokens, pi-blitz]
---
# 0.5I zero-resident minimal surface investigation

Find next resident schema/skill/tool-description reductions or Pi profile strategy to avoid resident tax for simple edits.

## Acceptance Criteria

Implementation or report quantifies current resident tax floor and proposes/implements at least one safe reduction. Guards updated. If Pi/tooling limitation blocks more savings, document exact limitation and workaround.


## Notes

**2026-06-20T07:17:02Z**

Started after qn4t commit 6b379a7d. Scope: deterministic zero-resident/minimal surface investigation only; no model/provider runs; implement only if safe/small.

**2026-06-20T07:20:25Z**

Investigated zero-resident/minimal surface. Implemented safe pi-blitz resident skill trim 637B -> 569B with tightened guards. Wrote .pi/reports/SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md documenting current token floor and zero-resident limitation/workaround. No model/provider runs.

**2026-06-20T07:22:50Z**

Main verification passed. pi-blitz: check:tax/typecheck/test/build, diff check, and LSP diagnostics clean. Blitz report diff check clean. No model/provider loops. pi-blitz .pi/research/ and .tickets/bli-pg9j.md preserved.
