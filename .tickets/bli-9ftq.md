---
id: bli-9ftq
status: closed
deps: []
links: []
created: 2026-06-20T06:00:43Z
type: bug
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-g, openai, structural, pi-blitz]
---
# 0.5G OpenAI structural-body minimal route fix

Sprint F impact survey still shows OpenAI/Codex structural-body Blitz red. Inspect reports/SPRINT-F-IMPACT-SURVEY-20260620.* and raw runs; normalize provider old/new shape safely or tighten prompt/schema guard so default minimal route handles/declines with correct classification.

## Acceptance Criteria

Focused tests cover OpenAI-emitted structural-body shape. Supported shape mutates correctly with expected formatting; unsupported shape fails closed with clear classification; no core/apply_patch fallback counted as Blitz. pi-blitz gates pass if touched.


## Notes

**2026-06-20T06:04:16Z**

start: preflight done. pi-blitz implementation isolated in /home/kenzo/dev/pi-blitz-bli-9ftq on tk/bli-9ftq-openai-structural. Preserve existing blitz .tickets/bli-pg9j.md dirty/report farm and pi-blitz research/ untracked.

**2026-06-20T06:08:21Z**

done: pi-blitz branch tk/bli-9ftq-openai-structural commit 2f5f5a9 supports OpenAI 4-tuple braced rb shape for TS/JS by stripping one outer body brace pair and routing compact rb function op; non-TS braced rb declines no-write with unsupported_structural_op_minimal; no core/apply_patch fallback. Verify pass: bun run check:tax, bun run typecheck, bun test (97 pass), bun run build.
