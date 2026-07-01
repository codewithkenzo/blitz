---
id: bli-qn4t
status: closed
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


## Notes

**2026-06-20T07:09:07Z**

Started after bli-6gb1 report e62c2dfd. Delegating implementation to d5. Constraints: no model/provider benchmark loops; preserve .tickets/bli-pg9j.md/report farm; minimal structural remains declined/advanced-only.

**2026-06-20T07:16:34Z**

Main verification passed after one small LSP fix in .pi/bench/natural-edit.ts: route budget self-check, prompt-shape self-check, Bun build, git diff --check, and LSP diagnostics clean. No provider/model benchmark loops; pi-blitz untouched.
