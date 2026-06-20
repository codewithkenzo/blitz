---
id: bli-r9jv
status: open
deps: []
links: []
created: 2026-06-20T04:59:33Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-f, tokens, pi-blitz]
---
# 0.5F reduce minimal blitz_edit resident/output tax

Implement measured reductions to minimal blitz_edit schema, resident skill text, success output, and error text without reducing safety or route truth.

## Acceptance Criteria

Deterministic token/byte guards show reduced or unchanged resident schema/skill/output sizes; tests pass; no hidden fallback; public output remains parseable.


## Notes

**2026-06-20T05:09:49Z**

finding from bli-s7by report: fixed resident/tool tax dominates survey green rows. Current diagnostic split: schema 419 tokens, skill 268 tokens per Blitz row; survey green ALL delta +4790 tokens includes schema +5866 and skill +3752 across 14 Blitz rows. Implement byte/token guards for minimal schema, skill, success output, error output; target schema back below Sprint D lock 350 before claim work.
