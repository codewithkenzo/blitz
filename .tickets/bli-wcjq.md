---
id: bli-wcjq
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-a, safety, pi-blitz]
---
# 0.5A exact edit safety suite

Turn live exact/filetype/path/rollback smoke into durable tests for minimal blitz_edit exact x path.

## Acceptance Criteria

Tests cover supported-ish and plain extensions, NO_MATCH, AMBIGUOUS_MATCH, old==new canonical noop/already_present, symlink escape, outside/traversal, stale content, cross-file rollback; no partial mutation on failure; bun tests pass.


## Notes

**2026-06-19T01:49:30Z**

verify: pi-blitz exact safety suite added in /home/kenzo/dev/pi-blitz test/tool-profiles.test.ts; covers supported-ish/plain extensions, NO_MATCH, AMBIGUOUS_MATCH, old==new already_present noop, symlink/outside/traversal path safety, stale content, cross-file rollback/no partial mutation. Gate PASS: bun run typecheck && bun test && bun run build.
