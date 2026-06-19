# d5 bli-o1pd final-after-sh7d

## Summary

Executed `bli-o1pd` exactly once after closed `bli-sh7d` with `final-after-sh7d` suffix. Did not start or touch `bli-qgz1`.

Gate passed:

- 12/12 primary rows accepted and correct.
- `class-c-structural-10` / `blitz-edit` accepted through `blitz_edit`, not declined.
- All accepted Blitz rows used `blitz_edit`; no core/apply_patch fallback counted.
- Tokscale token match recorded for every row.
- Aggregate context delta: core 36094 vs Blitz 24141 = 33.12% lower.
- Tiny guard passed: core 5950 vs Blitz 3890.

## Commands run

- `tk add-note bli-o1pd "start: final-after-sh7d ..."` — passed.
- `/home/kenzo/dev/pi-blitz`: `bun run typecheck && bun test && bun run build` — passed.
- `/home/kenzo/dev/blitz`: 12 sequential `bun bench/true-streak.ts` rows with:
  - `--provider zai`
  - `--model glm-4.5-air`
  - `--timeout-ms 600000`
  - `--tokscale`
  - `--run-root reports/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/<scenario>-<lane>`
  - row JSON/MD suffix `20260619-final-after-sh7d`
- Aggregate validation script — passed:
  - `status=passed`
  - `rows=12`
  - `acceptedCorrect=true`
  - `blitzTools=blitz_edit`
  - `tokscale=true`
  - `delta=33.12`
  - `tinyOk=true`
- `tk add-note bli-o1pd "result: final-after-sh7d lock passed ..." && tk close bli-o1pd` — passed.

## Row summary

| Scenario | Lane | Status | Correct | Tokscale | Total context | Tools |
|---|---|---|---:|---:|---:|---|
| tiny-10 | core-optimized | accepted | yes | yes | 5950 | edit |
| tiny-10 | blitz-edit | accepted | yes | yes | 3890 | blitz_edit |
| mixed-20 | core-optimized | accepted | yes | yes | 10133 | edit |
| mixed-20 | blitz-edit | accepted | yes | yes | 5911 | blitz_edit |
| same-file-multi | core-optimized | accepted | yes | yes | 1982 | edit |
| same-file-multi | blitz-edit | accepted | yes | yes | 2249 | blitz_edit |
| class-b-inserts-10 | core-optimized | accepted | yes | yes | 6623 | edit |
| class-b-inserts-10 | blitz-edit | accepted | yes | yes | 4127 | blitz_edit |
| class-c-structural-10 | core-optimized | accepted | yes | yes | 5415 | edit |
| class-c-structural-10 | blitz-edit | accepted | yes | yes | 4238 | blitz_edit |
| class-d-config-docs-10 | core-optimized | accepted | yes | yes | 5991 | edit |
| class-d-config-docs-10 | blitz-edit | accepted | yes | yes | 3726 | blitz_edit |

## Artifacts

- Aggregate lock JSON: `reports/REPLACEMENT-GATE-LOCK-20260619-final-after-sh7d.json`
- Human report: `reports/REPLACEMENT-GATE-20260619-final-after-sh7d.md`
- Row files: `reports/pi-tmux-true-streak-*-20260619-final-after-sh7d.{json,md}` (24 files)
- Run/session artifacts: `reports/pi-accounting-runs/20260619-replacement-gate-final-after-sh7d/` (188 files)

## Ticket status

- `bli-o1pd`: closed with evidence.
- `bli-qgz1`: not started/touched.

## Residual risks

- Token/accounting claim remains scoped to locked `zai/glm-4.5-air` Sprint C gate and measured A-D scenario set only.
