# Blitz token replacement gate rerun after bli-k296 — 2026-06-19

Status: **failed**. One final lock rerun after k296 stopped on a new Class C optimized-core correctness failure. No rerun performed.

## Decision

failed: optimized core Class C baseline failed correctness before corrected Blitz structural decline row could run; default-replacement gate remains open and qgz1 stays blocked.

## Failure

- Scenario: `class-c-structural-10`
- Lane: `core-optimized`
- Reason: new correctness failure in optimized core baseline; final structural-10.ts hash mismatch
- Stop rule: stop at first new correctness/route/Tokscale failure
- Note: Rerun stopped before class-c blitz-edit and class-d rows. No rerun fishing.

## Metadata

- Provider/model: `zai/glm-4.5-air`
- Runner: tmux/Pi/Tokscale
- Run root: `/home/kenzo/dev/blitz/reports/pi-accounting-runs/20260619-replacement-gate-rerun-after-k296`
- Blitz SHA: `21561015`
- pi-blitz SHA: `f38f52d`
- Profile dump: `/home/kenzo/dev/blitz/reports/profile-dumps/minimal-blitz-edit-20260619-rerun-after-k296.json` (cdf525b6c4facb2c85f54ff60992115d79e705ff991de54091101610d0eb645b)
- Resident skill: `/home/kenzo/dev/pi-blitz/skills/pi-blitz/SKILL.md` (1c7efb7f038b48826a9815655a4ed83683ad7a8401d48aa8e393251470865c94)

## Row outcomes

| Scenario | Class | Lane | Status | Correct | Declined | Tokscale match | Total context tokens | Route tools | Failed paths |
|---|---|---|---|---|---|---|---:|---|---|
| tiny-10 | A | core-optimized | accepted | yes | no | yes | 6093 | edit |  |
| tiny-10 | A | blitz-edit | accepted | yes | no | yes | 3905 | blitz_edit |  |
| mixed-20 | A/B/D | core-optimized | accepted | yes | no | yes | 10173 | edit |  |
| mixed-20 | A/B/D | blitz-edit | accepted | yes | no | yes | 6029 | blitz_edit |  |
| same-file-multi | A | core-optimized | accepted | yes | no | yes | 2008 | edit |  |
| same-file-multi | A | blitz-edit | accepted | yes | no | yes | 2289 | blitz_edit |  |
| class-b-inserts-10 | B | core-optimized | accepted | yes | no | yes | 6550 | edit |  |
| class-b-inserts-10 | B | blitz-edit | accepted | yes | no | yes | 4218 | blitz_edit |  |
| class-c-structural-10 | C | core-optimized | caveated | no | no | yes | 5560 | edit | structural-10.ts |

## Artifact manifest

- Lock JSON: `reports/REPLACEMENT-GATE-LOCK-20260619-rerun-after-k296.json`
- This report: `reports/REPLACEMENT-GATE-20260619-rerun-after-k296.md`

Each row in the JSON lock records report/session paths, byte sizes, SHA-256 hashes, route tools, Tokscale match/deltas, totals, and failed step details.

## Notes

The previous failed artifacts `reports/REPLACEMENT-GATE-LOCK-20260619.json` and `reports/REPLACEMENT-GATE-20260619.md` were not overwritten. The initial tiny core row completed before a local validation expression aborted; it is part of this single rerun attempt, not a separate rerun.
