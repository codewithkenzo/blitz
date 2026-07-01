# Blitz edit true-streak token gate summary — 2026-06-11

Status: partial D4 accepted for exact-edit and representative structural streak classes; full mandatory isolated class A-D replacement-gate report still pending.
Provider/model: `zai/glm-4.5-air`
Runner: tmux
Tokscale: required, exit 0 on listed rows

## Accepted streak comparisons

| Scenario | Core total context | Blitz `blitz_edit` total context | Savings | Correctness | Blitz report | Core report |
|---|---:|---:|---:|---|---|---|
| tiny-10 | 64,624 | 9,579 | 85.18% | 10/10 | `.pi/reports/archive/history/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-span.md` | `.pi/reports/archive/history/pi-tmux-true-streak-tiny-10-core-20260611-rerun.md` |
| mixed-20 | 17,229 | 11,540 | 33.02% | 20/20 | `.pi/reports/archive/history/pi-tmux-true-streak-mixed-20-blitz-edit-20260611-span.md` | `.pi/reports/archive/history/pi-tmux-true-streak-mixed-20-core-20260611-rerun.md` |
| same-file-multi | 17,894 | 8,015 | 55.21% | 1/1 final file | `.pi/reports/archive/history/pi-tmux-true-streak-same-file-multi-blitz-edit-20260611-span2.md` | `.pi/reports/archive/history/pi-tmux-true-streak-same-file-multi-core-20260611-rerun.md` |
| structural-3 | 18,361 | 8,499 | 53.71% | 1/1 final file | `.pi/reports/archive/history/pi-tmux-true-streak-structural-3-blitz-edit-20260611-rerun2.md` | `.pi/reports/archive/history/pi-tmux-true-streak-structural-3-core-20260611.md` |

## What changed to unlock this

- Blitz CLI exact replace `x` added in commit `82bbcd3`.
- pi-blitz default minimal profile now exposes `blitz_edit` and supports batched exact edits across files plus `rb`/`ia` structural tuples.
- `.pi/bench/true-streak.ts` supports `--lane blitz-edit`, compact changed spans for exact replacements, and a representative `structural-3` scenario.

## Caveats / not complete yet

- This is not full goal completion. The canonical replacement-gate report still needs isolated mandatory class A-D rows and reviewer audit.
- `schemaTokens=0` in true-streak reports because Pi session JSONL does not expose resident schema directly; pi-blitz serialized minimal profile dump is in `/home/kenzo/dev/pi-blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260611.json`.
- Earlier failed/caveated attempts are preserved and should stay as remediation evidence.

## Next D4 work

1. Add/lock the canonical replacement-gate report that pulls these streak rows plus isolated mandatory class A-D rows.
2. Run any missing isolated rows under product route `blitz_edit`, plus representative semantic rows if required by the final spec interpretation.
3. Add reviewer audit for raw artifacts, Tokscale token matches, correctness, and no hidden fallback.
