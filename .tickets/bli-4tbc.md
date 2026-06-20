---
id: bli-4tbc
status: closed
deps: [bli-9ftq, bli-j8kw, bli-h3ta]
links: []
created: 2026-06-20T06:00:43Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-g, verification, tokscale]
---
# 0.5G focused post-fix impact check

After Sprint G fixes, run only a focused post-fix check on OpenAI/Zai structural-body and tiny exact to confirm direction. This is telemetry, not claim.

## Acceptance Criteria

Max 12 raw model runs, Tokscale required, artifacts saved, no rerun fishing, no final claim. Records before/after for structural-body and tiny exact only.


## Notes

**2026-06-20T06:25:02Z**

start: deps closed. Running focused telemetry only: providers openai-codex/gpt-5.4-mini and zai/glm-4.5-air; scenarios tiny-exact and structural-body; lanes core+blitz only = 8 raw model runs max 12; Tokscale required; using merged pi-blitz canonical e94a904 and blitz sprint 6059f8ef. No final claim.

**2026-06-20T06:30:16Z**

done: focused telemetry complete. Ran 8/12 allowed raw model runs only: OpenAI/Zai x tiny-exact/structural-body x core/blitz, Tokscale required and matched 8/8, no rerun fishing. Artifacts: reports/SPRINT-G-POSTFIX-TELEMETRY-20260620.{md,json}; raw root reports/pi-accounting-runs/20260620-sprint-g-postfix/. Results: OpenAI tiny-exact both green but Blitz +2 tokens (+0.1%), Zai tiny-exact both green and Blitz -285 tokens (-13.9%), OpenAI structural-body Blitz strict red due missing final newline despite semantic shape, Zai structural-body Blitz red due incorrect old/new-ish rb shape; core structural green for both. Telemetry only, no final claim.
