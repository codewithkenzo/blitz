---
id: bli-42f3
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-a, taxonomy, tokens]
---
# 0.5A route result taxonomy and output guard

Normalize route/tool result outcomes and keep public output compact.

## Acceptance Criteria

Outcomes are blitz_success/core_fallback/needs_host_merge/decline/noop/incorrect/error; fallback/noop/decline never count as Blitz wins; public success/error text size has regression guard; sample parser tests pass.


## Notes

**2026-06-19T01:54:14Z**

verify: route taxonomy self-check PASS; parser self-check PASS; natural-edit harness build PASS. Outcomes normalized to blitz_success/core_fallback/needs_host_merge/decline/noop/incorrect/error; Blitz wins counted only for accepted blitz_success.
