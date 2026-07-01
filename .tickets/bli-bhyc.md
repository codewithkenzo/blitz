---
id: bli-bhyc
status: closed
deps: [bli-l415]
links: []
created: 2026-06-20T04:10:22Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-e, survey, tokscale]
---
# 0.5E quick provider-language survey run

Run the bounded survey once after plan approval; collect token deltas and failures across selected providers/languages.

## Acceptance Criteria

Survey artifacts summarize per provider/language/edit class: correctness, route truth, Tokscale/accounting status, token delta, and failure reason. No rerun fishing; blockers created for systemic product/harness/provider issues.


## Notes

**2026-06-20T04:36:05Z**

start: provider-language quick survey. Preflight: dirty .tickets/bli-pg9j.md preserved; report farm untracked preserved; no implementation changes planned.

**2026-06-20T04:47:31Z**

survey complete: 32 raw model runs (2 providers x 8 scenarios x core/blitz), Tokscale ok+matched 32/32, no timeouts/side effects/systemic stop. Final artifacts: .pi/reports/current/PROVIDER-LANGUAGE-SURVEY-20260620.md and .json; raw artifacts under .pi/reports/current/pi-accounting-runs/20260620-provider-language-survey/. Results: 14 survey_green, 2 survey_red_product (structural-body blitz mismatch on Zai and OpenAI/Codex).
