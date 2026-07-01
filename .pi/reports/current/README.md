# Blitz reports

Reports are durable summaries only. Generated run/session artifacts do not belong here unless a ticket explicitly marks a run root as evidence.

## Current sprint summaries

Keep current Sprint I / 0.5 summaries at repo root, especially:

- `SPRINT-I-WEIGHTED-TELEMETRY-GATE-20260620.md`
- `SPRINT-I-ROUTE-OPTIMIZER-TOKEN-TARGET-MATH-20260620.md`
- `SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md`
- `SPRINT-G-POSTFIX-TELEMETRY-20260620.md`
- `SPRINT-F-*.md`

## Raw artifacts

Ignored by default:

- `pi-tmux-runs/`
- `pi-accounting-runs/`
- `natural-edit-runs/`
- `natural-edit-harness/`
- `subagents/`
- `provider-matrix-logs/`
- `bench-logs/`
- `profile-dumps/`

Exception: `pi-accounting-runs/20260620-sprint-i-weighted-gate/` stays tracked because `bli-qreu` report links it as acceptance evidence.

## Historical clutter

Older root `pi-*`, `FAIR-*`, and one-off benchmark reports are historical. Move them under `.pi/reports/archive/` only with reference migration, because tickets/skills may still cite old paths.
