---
id: bli-m3sj
status: open
deps: [bli-cca2, bli-91kk, bli-4aff, bli-1sab, bli-t3cl]
links: []
created: 2026-06-19T06:41:57Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-d, benchmark, tokscale]
---
# 0.5D focused all edit-type lock run

Run one bounded all edit-type proof on zai/glm-4.5-air after plan and harness rows are ready.

## Acceptance Criteria

Paired core vs Blitz rows for all agreed edit classes have correctness, route truth, Tokscale match, resident schema/skill accounting, artifact manifest, and token deltas. Stop on systemic failure; no rerun fishing.


## Notes

**2026-06-19T06:52:47Z**

blocker: D5 closed bli-91kk with E06,E07,E10-E18 placeholders. Added deps bli-4aff and bli-1sab; do not run focused lock until placeholders are runnable or explicitly policy-blocked.

**2026-06-19T07:52:12Z**

start: focused Sprint D all edit-type lock run. One bounded run only; no rerun fishing. Preflight green; preserving preexisting .tickets/bli-pg9j.md/report farm.

**2026-06-19T07:54:46Z**

blocked: one bounded focused lock attempt stopped at first row tiny-10/core-optimized due provider usage limit before tool calls. No rerun. Created blocker bli-t3cl. Artifacts under reports/pi-accounting-runs/20260619-all-edit-type-lock/tiny-10-core-optimized and reports/pi-tmux-true-streak-tiny-10-core-optimized-20260619-all-edit-type-lock.{json,md}.
