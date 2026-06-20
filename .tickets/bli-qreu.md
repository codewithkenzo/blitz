---
id: bli-qreu
status: open
deps: [bli-6gb1, bli-qn4t, bli-cwfj, bli-fu5w, bli-53tr]
links: []
created: 2026-06-20T07:02:09Z
type: task
priority: 2
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-i, telemetry, tokscale]
---
# 0.5I weighted telemetry gate

After Sprint I implementation/design work, run bounded weighted telemetry to measure route-optimizer savings. Not a final claim unless separately audited.

## Acceptance Criteria

Gate waits on relevant implementation tickets, caps model rows, uses Tokscale, reports green-only route-truth numbers, and computes weighted savings by edit class. No rerun fishing.

