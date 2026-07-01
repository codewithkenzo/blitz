---
id: bli-fu5w
status: closed
deps: []
links: []
created: 2026-06-20T07:02:09Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-i, ir, tokens]
---
# 0.5I compact IR v2 design

Design compact edit IR v2 for large/multi/symbol edits that can plausibly deliver 50-80% savings by avoiding unchanged-code replay.

## Acceptance Criteria

Design covers op aliases, file defaults, dictionaries/anchors, multi-edit batching, output taxonomy, safety validation, backwards compatibility, and deterministic byte/token budget estimates. No implementation required unless small and safe.


## Notes

**2026-06-20T08:49:19Z**

start: compact IR v2 design slice; using PLAN-0.5I, zero-resident report, route target math; no model/provider runs

**2026-06-20T08:50:29Z**

done: design saved .pi/docs/plans/PLAN-0.5I-compact-ir-v2.md; no model/provider runs; structural rb remains advanced-only
