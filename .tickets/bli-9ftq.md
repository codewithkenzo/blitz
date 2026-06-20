---
id: bli-9ftq
status: open
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

