# Blitz token replacement gate — 2026-06-19

Status: **failed**. Stop-rule triggered on Class C Blitz structural row. No rerun performed.

## Failure

- Scenario: `class-c-structural-10`
- Lane: `blitz-edit`
- Route: `blitz_edit`
- Tokscale: matched, zero deltas
- Correctness: failed; `structural-10.ts` hash mismatch
- Stop rule: any primary row has incorrect final content
- Note: due shell validation bug, planned Class D rows ran after failure. They are preserved but no pass claim uses them.

## Metadata

- Provider/model: `zai/glm-4.5-air`
- Runner: tmux true-streak
- Blitz commit: `5a67059a3656079edfff9086055bf32dce365f46`
- pi-blitz commit: `0bf291896e6476940fcbde6338633b5aa494b4b1`
- Minimal profile dump: `/home/kenzo/dev/blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260619.json`
  - bytes: 1802
  - tokens: 419
  - sha256: `5445b8d15f2990a9c953e66847d7710f1a7ff7eadeba9ed0e8ab9df236423726`
- Resident skill: `/home/kenzo/dev/pi-blitz/skills/pi-blitz/SKILL.md`
  - bytes: 973
  - tokens: 268
  - sha256: `1c7efb7f038b48826a9815655a4ed83683ad7a8401d48aa8e393251470865c94`

## Row outcomes

| Scenario | Class | Lane | Status | Correct | Tokscale match | Total context tokens | Route tools | Failed paths |
|---|---|---|---|---|---|---:|---|---|
| tiny-10 | A | core-optimized | accepted | yes | yes | 5575 | edit |  |
| tiny-10 | A | blitz-edit | accepted | yes | yes | 3603 | blitz_edit |  |
| mixed-20 | A/B/D | core-optimized | accepted | yes | yes | 9412 | edit |  |
| mixed-20 | A/B/D | blitz-edit | accepted | yes | yes | 5418 | blitz_edit |  |
| same-file-multi | A | core-optimized | accepted | yes | yes | 1937 | edit |  |
| same-file-multi | A | blitz-edit | accepted | yes | yes | 2177 | blitz_edit |  |
| class-b-inserts-10 | B | core-optimized | accepted | yes | yes | 6247 | edit |  |
| class-b-inserts-10 | B | blitz-edit | accepted | yes | yes | 3910 | blitz_edit |  |
| class-c-structural-10 | C | core-optimized | accepted | yes | yes | 8237 | edit |  |
| class-c-structural-10 | C | blitz-edit | caveated | no | yes | 3976 | blitz_edit | structural-10.ts |
| class-d-config-docs-10 | D | core-optimized | accepted | yes | yes | 5621 | edit |  |
| class-d-config-docs-10 | D | blitz-edit | accepted | yes | yes | 3513 | blitz_edit |  |

## Token accounting

- Core total context tokens: 37029
- Blitz total context tokens: 22597
- Apparent aggregate delta: 38.97%
- Accounting is **not accepted as replacement proof** because correctness failed.

Schema and skill token counts are recorded separately in lock JSON under `metadata.profileDump.tokens` and `metadata.residentSkill.tokens`. Each row records prompt/input/cache/tool/output/result payload totals plus Tokscale match booleans/deltas.

## Artifact manifest

Full manifest with JSON/MD/session paths, byte sizes, and sha256 hashes: `.pi/reports/archive/history/REPLACEMENT-GATE-LOCK-20260619.json`.

## Excluded artifact

- `/home/kenzo/dev/blitz/.pi/reports/pi-tmux-true-streak-tiny-10-core-2026-06-19T02-55-43-351Z.json` — accidental default --help inspection row before delegated task; excluded from primary gate

## Decision

`bli-o1pd` acceptance not met. Ticket remains open; follow-up product failure ticket tracks Class C structural Blitz correctness.
