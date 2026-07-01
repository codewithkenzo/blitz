# Blitz universal accounting fix — 2026-06-11

Status: first remediation slice complete.

Addresses reviewer findings from `.pi/reports/UNIVERSAL-BLITZ-BLIND-SPOT-AUDIT-20260611.md`:

- Regenerated current pi-blitz minimal profile dump after OpenAI-compatible schema fix: `/home/kenzo/dev/pi-blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260611.json`.
- `bench/true-streak.ts` now records extension, skill, and profile dump provenance for `blitz-edit` rows.
- `bench/true-streak.ts` now counts schema tokens from the current profile dump and skill tokens from the current resident skill for `blitz-edit` rows.
- `bench/true-streak.ts` now parses Tokscale JSON and records `tokScaleMatch` with totals and deltas for input/output/cacheRead/cacheWrite/messages.
- `--tokscale` rows are accepted only if Tokscale exits 0 and token totals match parser totals.

Smoke evidence:

- Report: `.pi/reports/pi-tmux-true-streak-accounting-fix-tiny-10-blitz-edit-20260611-rerun.md`
- Status: accepted
- Correctness: 10/10
- Tool: `blitz_edit`
- Schema tokens: `350`
- Skill tokens: `268`
- Tokscale match: yes, all deltas 0
- Extension: `/home/kenzo/dev/pi-blitz/dist/index.js`
- Skill: `/home/kenzo/dev/pi-blitz/skills/pi-blitz`
- Profile dump: `/home/kenzo/dev/pi-blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260611.json`

Remaining reviewer blockers not addressed in this slice:

- fair optimized-core baseline;
- natural unscripted route proof;
- adversarial safety matrix;
- atomic product `blitz_edit` batch semantics;
- full universal provider matrix rerun.
