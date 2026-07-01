---
id: bli-h70x
status: open
deps: []
links: []
created: 2026-07-01T13:45:49Z
type: task
priority: 1
assignee: Kenzo
tags: [blitz, cleanup, repo-hygiene]
---
# Repo cleanup: reports docs worktrees branches


## Notes

**2026-07-01T13:45:54Z**

start: user asked to audit and clean stale benchmark artifacts/docs/scripts/worktrees/branches. Initial facts: 968 uncommitted entries = 967 untracked + .tickets/bli-pg9j tracked dirty; reports has 8069 files/45.6MB, largest dirs pi-tmux-runs/pi-accounting-runs/natural-edit-runs/natural-edit-harness. Need audit first, no destructive deletion without explicit reviewed keep/delete list.

**2026-07-01T13:49:30Z**

phase1: read-only explorers completed. Cleaned untracked generated benchmark artifacts from reports/* generated dirs, reducing status from 968 entries to 16. Added .gitignore entries for generated benchmark/session dirs. Pruned stale git worktree metadata for missing /tmp worktrees; remaining worktrees are active main + two closed-ticket manual-review worktrees. Added docs/plans/README.md index for current vs historical plans.
