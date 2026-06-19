---
id: bli-o1pd
status: open
deps: [bli-wwly, bli-97se, bli-wcjq, bli-42f3, bli-7x68, bli-bbnw, bli-09ru, bli-mj6a, bli-7kz8, bli-sh7d]
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-c, benchmark, tokscale]
---
# 0.5C focused final lock run

Run one bounded final proof after implementation gates, preserving artifacts and classifying failures instead of rerun fishing.

## Acceptance Criteria

Paired core vs Blitz rows for agreed classes have Tokscale match, route truth, correctness, mutation safety, resident schema+skill accounting, artifact hash manifest; systemic failure creates tickets, not looped reruns.


## Notes

**2026-06-19T02:57:27Z**

start: focused final token replacement lock. Following docs/plans/PLAN-0.5C-token-replacement-gate.md exactly; stop at first correctness/route/Tokscale failure; no rerun fishing.

**2026-06-19T03:03:17Z**

finding: final lock failed stop-rule on class-c-structural-10 blitz-edit. Route=blitz_edit, Tokscale matched zero deltas, but final structural-10.ts hash mismatched. No rerun performed. Planned class-d rows also ran after failure due local validation-script bug; preserved but not counted as pass claim. Reports: reports/REPLACEMENT-GATE-LOCK-20260619.json and reports/REPLACEMENT-GATE-20260619.md. Ticket remains open.

**2026-06-19T03:19:28Z**

start: bli-k296 closed; starting exactly one final lock rerun after k296 with same planned settings. Prior failed artifacts preserved; rerun artifacts use -rerun-after-k296 suffix. No broad matrix/rerun fishing.

**2026-06-19T03:24:58Z**

finding: rerun-after-k296 stopped on first new failure before class-c blitz/class-d rows. class-c-structural-10 core-optimized returned status=caveated, Tokscale matched, route edit, failed structural-10.ts final hash. Rerun artifacts use -rerun-after-k296 suffix; prior failed lock preserved. No rerun fishing.

**2026-06-19T03:51:50Z**

start: bli-ta7v closed; starting exactly one final replacement lock after ta7v with final-after-ta7v artifact suffix. No rerun fishing.

**2026-06-19T03:56:11Z**

finding: final-after-ta7v lock ran once after ta7v. All core rows and A/B/D blitz rows accepted with Tokscale match. Class C blitz-edit declined with unsupported_structural_op_minimal/no mutation; route truth ok, no hidden fallback. Gate decision failed under current plan because declined structural work cannot count as default replacement. Artifacts: reports/REPLACEMENT-GATE-LOCK-20260619-final-after-ta7v.json and reports/REPLACEMENT-GATE-20260619-final-after-ta7v.md. Created blocker bli-7kz8; qgz1 remains blocked.

**2026-06-19T04:43:10Z**

policy: bli-7kz8 chose strict default replacement for Exodia 0.5. Class C structural decline is safety, not edit success. o1pd now waits on bli-sh7d for default/minimal blitz_edit structural success before another final lock.
