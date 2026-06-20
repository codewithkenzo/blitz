---
id: bli-r9jv
status: closed
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

**2026-06-20T05:10:31Z**

start: implementing minimal blitz_edit resident/output tax reductions after bli-s7by diagnosis. Scope: deterministic byte/token guards, no safety weakening, no benchmark/model reruns.

**2026-06-20T05:16:41Z**

done: pi-blitz commit 565b607 adds minimal blitz_edit tax reductions and deterministic byte guards. Guard output: minimal-schema 690/760 bytes, resident-skill 781/850, success-output 29/32, decline-output 71/80. Verification: bun run check:tax && bun run typecheck && bun test && bun run build passed; git diff --check passed. No benchmark/model reruns; untracked pi-blitz research/ preserved.
