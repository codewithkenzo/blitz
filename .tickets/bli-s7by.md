---
id: bli-s7by
status: closed
deps: []
links: []
created: 2026-06-20T04:59:33Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-f, tokens, analysis]
---
# 0.5F diagnose green-row token regression

Compare Sprint D passing lock vs provider-language survey green rows to identify why survey green rows used more tokens than core.

## Acceptance Criteria

Report identifies token deltas by component (resident schema, skill, prompt, tool args, output, cache/result payload) and creates concrete implementation tickets. No model reruns required; use existing artifacts.


## Notes

**2026-06-20T05:06:27Z**

start: diagnosing green-row token regression from existing artifacts only. Sources: Sprint D all-edit-type lock after-z13z + provider-language survey 20260620. No benchmark/model reruns.

**2026-06-20T05:09:59Z**

done: wrote .pi/reports/current/SPRINT-F-GREEN-ROW-TOKEN-REGRESSION-20260620.md/json from existing artifacts only. Compared Sprint D all-edit-type lock (-10565 Blitz delta) vs provider-language survey green rows (+4790 Blitz delta). Component split covers resident schema, resident skill, prompt, tool args, output, cache, result payload. Follow-up notes added to bli-r9jv/bli-lcde; new route-budget ticket bli-krvm created. No benchmark/model reruns.
