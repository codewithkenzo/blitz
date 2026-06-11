# Blitz edit true-streak token gate summary — 2026-06-11

Status: partial D4 accepted for exact-edit streak classes; structural/class A-D full matrix still pending.
Provider/model: `zai/glm-4.5-air`
Runner: tmux
Tokscale: required, exit 0 on listed rows

## Accepted streak comparisons

| Scenario | Core total context | Blitz `blitz_edit` total context | Savings | Correctness | Blitz report | Core report |
|---|---:|---:|---:|---|---|---|
| tiny-10 | 64,624 | 9,579 | 85.18% | 10/10 | `reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-span.md` | `reports/pi-tmux-true-streak-tiny-10-core-20260611-rerun.md` |
| mixed-20 | 17,229 | 11,540 | 33.02% | 20/20 | `reports/pi-tmux-true-streak-mixed-20-blitz-edit-20260611-span.md` | `reports/pi-tmux-true-streak-mixed-20-core-20260611-rerun.md` |
| same-file-multi | 17,894 | 8,015 | 55.21% | 1/1 final file | `reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260611-span2.md` | `reports/pi-tmux-true-streak-same-file-multi-core-20260611-rerun.md` |

## What changed to unlock this

- Blitz CLI exact replace `x` added in commit `82bbcd3`.
- pi-blitz default minimal profile now exposes `blitz_edit` and supports batched exact edits across files.
- `bench/true-streak.ts` supports `--lane blitz-edit` and computes compact changed spans for exact replacements.

## Caveats / not complete yet

- This is not full goal completion. Structural rows and the full mandatory class A-D matrix still need the replacement-gate report.
- `schemaTokens=0` in true-streak reports because Pi session JSONL does not expose resident schema directly; pi-blitz serialized minimal profile dump is in `/home/kenzo/dev/pi-blitz/reports/profile-dumps/minimal-blitz-edit-20260611.json`.
- Earlier failed/caveated attempts are preserved and should stay as remediation evidence:
  - `reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611.md`
  - `reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-rerun.md`
  - `reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260611-batch.md`
  - `reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260611-span.md`

## Next D4 work

1. Add/lock the canonical replacement-gate report that pulls these streak rows plus isolated mandatory class A-D rows.
2. Run representative structural rows under the appropriate profile (`structural`/`semantic`) and compare against core.
3. Add reviewer audit for raw artifacts, Tokscale token matches, correctness, and no hidden fallback.
