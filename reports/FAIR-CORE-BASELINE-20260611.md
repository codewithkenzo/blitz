# Fair optimized-core baseline — 2026-06-11

Status: initial lane + smoke implemented.

## What changed

`bench/true-streak.ts` now supports a `core-optimized` lane. This lane still uses Pi core `edit` only, but it avoids intentionally pessimized full-file old/new payloads when a smaller exact span is safe.

Behavior:

- Existing `core`, `router`, and `blitz-edit` lanes are preserved.
- `core-optimized` uses `edit` with minimal `oldText`/`newText` spans from `exactChangedSpan`.
- For `same-file-multi`, the runner attempts one core `edit` call with an `edits` array when spans are simple.
- For other scenarios, it issues ordered core `edit` calls using minimal spans.

## Smoke row

Provider/model: `zai/glm-4.5-air`
Scenario: `tiny-10`
Lane: `core-optimized`

Report: `reports/pi-tmux-true-streak-fair-core-tiny-10-core-optimized-20260611.md`

Result:

- Status: accepted
- Correctness: 10/10
- Tool calls: core `edit` only
- Tokscale match: yes, all deltas 0
- Total context: `62,299`

For context, prior rows:

- original core tiny-10: `64,624`
- accounting-fixed blitz tiny-10: `9,502`

## Remaining work

This is not the final fair-baseline matrix. Next steps:

- run `core-optimized` for same-file multi, Class B/C/D, mixed-20, and GPT providers;
- compare against `blitz-edit` using current accounting fields;
- decide whether optimized-core should become the mandatory baseline for universal claims;
- add route-system rows for explicit fallback/decline.

## Caveated same-file multi attempt

A same-file multi `core-optimized` smoke was also preserved:

- Report: `reports/pi-tmux-true-streak-fair-core-same-file-multi-core-optimized-20260611.md`
- Correct final file: yes
- Tokscale match: yes
- Status: caveated (timeout/exit -1)
- Total context: `391,141`
- Observed behavior: the model did not complete as a single clean batched core edit; it repeatedly called `edit`.

This is useful evidence: fair-core baselines must verify actual core tool batch support/model compliance instead of assuming `edits` array batching will be obeyed. Not counted as an accepted fair baseline.
