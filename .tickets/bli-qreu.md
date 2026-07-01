---
id: bli-qreu
status: closed
deps: [bli-6gb1, bli-qn4t, bli-cwfj, bli-fu5w, bli-53tr]
links: []
created: 2026-06-20T07:02:09Z
type: task
priority: 2
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-i, telemetry, tokscale]
---
# 0.5I weighted telemetry gate

After Sprint I implementation/design work, run bounded weighted telemetry to measure route-optimizer savings. Not a final claim unless separately audited.

## Acceptance Criteria

Gate waits on relevant implementation tickets, caps model rows, uses Tokscale, reports green-only route-truth numbers, and computes weighted savings by edit class. No rerun fishing.


## Notes

**2026-06-20T09:05:43Z**

handoff: prompt prepared at .pi/docs/plans/current/PROMPT-0.5I-weighted-telemetry-gate.md; do not run telemetry until explicitly started; prerequisites fu5w/53tr closed

**2026-06-20T09:09:52Z**

start: weighted telemetry gate started by user. Preflight tracked dirty: only expected .tickets/bli-pg9j.md in blitz; pi-blitz tracked clean. Constraints: bounded telemetry only, no rerun fishing, preserve .pi/reports/artifacts, no advanced structural telemetry unless explicit permit.

**2026-06-20T09:11:09Z**

cap: bounded telemetry fixed before execution: provider/model zai/glm-4.5-air only; scenarios tiny-exact, same-file-multi, mixed-config-doc, docs-heading-update, structural-body; lanes core baseline + route-selected only; iters=1; timeout=120000; Tokscale validate; advanced structural telemetry skipped/not permitted. Max model runs=10. No forced-Blitz counterfactual rows.

**2026-06-20T09:15:04Z**

done: bounded weighted telemetry complete. Cap ran exactly 10 model rows (zai/glm-4.5-air; 5 scenarios; core+route; iters=1). Tokscale matched 10/10. Weighted selected-route savings -15.13%; no positive marketing claim. Advanced structural skipped/not permitted; forced-Blitz counterfactual not run. Reports: .pi/reports/SPRINT-I-WEIGHTED-TELEMETRY-GATE-20260620.{md,json}; run root .pi/reports/current/pi-accounting-runs/20260620-sprint-i-weighted-gate.
