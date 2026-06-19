---
id: bli-yzzg
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 2
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-b, effect, pi-blitz]
---
# 0.5B pi-blitz Effect runtime testability slice

Small Effect v4 reliability slice only: fake runner injection, soft/hard error classifier tests, scoped lock/snapshot cleanup if needed. No broad Layer rewrite.

## Acceptance Criteria

Tests can inject fake Blitz runner without schema/output changes; soft vs hard Cause classification covered; abort/timeout lock cleanup covered if touched; public output unchanged.


## Notes

**2026-06-19T02:23:03Z**

start/findings: implemented small pi-blitz runtime testability slice: injectable Blitz runner for tests plus soft/hard runTool classification coverage; no public tool schema/output expansion; abort/timeout lock cleanup not touched.
