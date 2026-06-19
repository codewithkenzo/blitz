---
id: bli-97se
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: bug
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-a, structural, pi-blitz]
---
# 0.5A quarantine broken structural ops in minimal blitz_edit

Make rb/ia safe before more matrices. Default path: hide or stable-decline structural ops in minimal blitz_edit; do not attempt broad multi-language AST rewrite unless separately planned.

## Acceptance Criteria

minimal profile no longer advertises broken rb/ia, or rb/ia return stable no-mutation decline; TS/Python corruption smoke cannot return ok; ia no longer leaks MISSING_FIELD; bun typecheck/test/build pass.


## Notes

**2026-06-19T01:38:37Z**

done: pi-blitz c1b6bab pushed to feat/blitz-0.4-token-core-profile-canonical. Minimal blitz_edit now no-write declines rb/ia with unsupported_structural_op_minimal; docs/schema no longer advertise structural use. Regression tests cover rb TS and ia Python unchanged, no MISSING_FIELD, no ok. Gate in /home/kenzo/dev/pi-blitz: bun run typecheck && bun test && bun run build PASS.
