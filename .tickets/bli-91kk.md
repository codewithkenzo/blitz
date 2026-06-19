---
id: bli-91kk
status: open
deps: [bli-cca2]
links: []
created: 2026-06-19T06:41:57Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-d, harness]
---
# 0.5D all edit-type harness rows

Add/verify deterministic rows for all edit types in final gate harness, using one provider/model first.

## Acceptance Criteria

Rows cover exact tiny, same-file multi, cross-file, config set, doc/comment, import, rename/local usage, structural replace, structural insert-after, wrap/try-catch if supported, delete range, append section, noop, ambiguous/no-match decline, unsupported structural decline, path escape, rollback failure. Self-checks pass; no model run required.

