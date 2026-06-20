---
id: bli-qn4t
status: open
deps: []
links: []
created: 2026-06-20T07:02:09Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-i, router, tokens]
---
# 0.5I implement edit route selector policy

Implement/productize route policy: core for tiny when cheaper, Blitz for tie/win simple rows, decline minimal structural, advanced route reserved. Prevent forced-Blitz token losses from being counted as product wins.

## Acceptance Criteria

Deterministic tests/guards show selected route and reason for tiny/simple/config/doc/safety rows. Tiny exact never forced through Blitz if core is cheaper. No safety weakening. Existing tax/prompt guards pass.

