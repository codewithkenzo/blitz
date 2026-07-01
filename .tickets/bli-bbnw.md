---
id: bli-bbnw
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-b, providers]
---
# 0.5B provider preflight and smoke harness

Implement provider-aware smoke/preflight matrix for OpenAI/Codex, Anthropic, Gemini, Zai/GLM, xAI/Grok as mandatory set is chosen.

## Acceptance Criteria

Rows record provider/model, attempted vs completed tool call, profile/tool, route/fallback, malformed-call/provider-shape failures, retry/timeout, auth/rate-limit vs product failure, Tokscale/cache status; no provider hidden fallback is counted as success.


## Notes

**2026-06-19T02:12:53Z**

start: implementing deterministic provider preflight/smoke harness; preserving unrelated dirty files; no live provider loops.

**2026-06-19T02:15:06Z**

finding: added deterministic --self-check-provider-preflight guard in .pi/bench/natural-edit.ts; mandatory providers explicit; hidden fallback rows classify non-success; no live provider loop.

**2026-06-19T02:15:06Z**

verify: bun .pi/bench/natural-edit.ts --self-check-provider-preflight plus route taxonomy self-check plus bun build .pi/bench/natural-edit.ts PASS.
