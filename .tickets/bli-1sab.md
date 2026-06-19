---
id: bli-1sab
status: closed
deps: []
links: []
created: 2026-06-19T06:52:47Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-d, harness, safety]
---
# 0.5D materialize safety edit-type rows

Convert Sprint D safety placeholders into runnable no-mutation gate fixtures before the focused lock run.

## Acceptance Criteria

E13 noop, E14 ambiguous, E15 no-match/stale, E16 unsupported structural, E17 path escape/symlink/traversal, and E18 rollback failure are runnable safety fixtures with expected no-mutation/decline/noop/error classifications; they cannot be counted as Blitz success.


## Notes

**2026-06-19T07:22:20Z**

start: materializing Sprint D safety rows E13-E18 in bench/true-streak.ts; no provider/model benchmark or focused lock.
