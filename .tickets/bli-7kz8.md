---
id: bli-7kz8
status: closed
deps: []
links: []
created: 2026-06-19T03:56:02Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-c, benchmark]
---
# Decide Class C structural decline gate policy


## Notes

**2026-06-19T03:56:11Z**

source: bli-o1pd final-after-ta7v. Planned class-c-structural-10 blitz-edit row returned status=declined, route=blitz_edit, Tokscale matched, unsupported_structural_op_minimal/no mutation. This is honest route truth but not a default replacement success under current plan; decide whether Class C is excluded, requires structural profile, or fails Sprint C gate.

**2026-06-19T04:42:24Z**

decision: policy A strict default replacement. For universal/exodia 0.5, Class C structural cannot be counted as success when minimal blitz_edit declines. Decline is safety, not edit success. bli-o1pd must wait for explicit Class C structural support in default route or a deliberate non-universal rescope.

**2026-06-19T04:43:10Z**

verify: docs/plans/PLAN-0.5C-token-replacement-gate.md and .pi/sprints/SPRINT-0.5-exodia-implementation.md updated with strict Class C policy. Opened bli-sh7d and added as o1pd dependency. No lock rerun; qgz1 remains blocked.
