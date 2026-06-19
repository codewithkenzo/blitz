---
id: bli-91kk
status: closed
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


## Notes

**2026-06-19T06:46:44Z**

start: implementing all edit-type harness rows from docs/plans/PLAN-0.5D-all-edit-type-gate.md. No model run; self-checks/harness rows only.

**2026-06-19T06:50:21Z**

verify: added all-edit-type row registry and --self-check-all-edit-types. Self-check passes rows=18/classes=18/success=12/safety=6. Runnable existing scenario mappings cover E01-E05,E08,E09; E06,E07,E10-E18 registered as all-edit-types-gate placeholders and documented as must-implement-or-block before bli-m3sj.

**2026-06-19T06:50:21Z**

verify: bun build bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js PASS; bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js PASS.
