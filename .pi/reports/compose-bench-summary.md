# Compose-body + route-discipline bench summary

Date: 2026-04-27
Model baseline: `claude-haiku-4-5` (`bun bench/llm-pi.ts` defaults)

## Changes made

- Added fixture/case in `bench/llm-pi.ts`:
  - `medium-10k/compose-preserve-islands` (same `medium.ts` fixture)
  - Goal: multi-hunk structural update via preserved islands (`compose_body`).
- Added `lanePolicy` per fixture.
  - `small/wrap-tail` set to `core-only` to model route discipline.
  - Others default to compare lanes (`core` + `blitz`) when no `--lane` override.
- Added explicit `pi_blitz_apply` guidance for compose case, using `compose_body` segment example.
- Added expected golden for compose case:
  - insert finite check after `let total = seed;`
  - add `if (total < 0) { return 0; }` before final return.

## Route-discipline template

Use this template in report/write-up for every auth bench batch:

1. Classify cases:
   - **Structural**: wrap, insert, compose/preserved islands, large/multi-hunk changes.
   - **Core-optimal**: tiny unique oldText one-liners.
2. `small/unique` cases route to **core** lane only.
3. Compute savings only for structural rows with both lanes present.
4. Any incorrect lane run counts as `correctRate = 0%`.
5. Any row with `correctRate = 0%` contributes `0%` savings in aggregate reporting.

## Verification run notes

### `bun bench/llm-tokens.ts`

Output (5 iter):

- small/wrap-tail: blitz 62, core realistic 117, core full 79.
- huge-100k/marker-tail: blitz 70, realistic-anchor 170, full-symbol 98,232.
- huge-500k/marker-tail: blitz 70, realistic-anchor 170, full-symbol 492,102.
- Avg saved vs realistic anchor: 54.9%; avg saved vs full-symbol: 73.8%.

### `bun bench/llm-pi.ts --case medium-10k/compose-preserve-islands --iters 1`

- **latest (rtk proxy run):**
  - wall: `core 60014ms`, `blitz 60012ms`
  - tokens: all `0`
  - correct: `0.0%`
  - savings: `0.0% / 0.0%`
- previous timeout-mode 5s: `core` and `blitz` near `5008ms` with same zero rows


### `bun bench/llm-pi.ts --case small/wrap-tail --iters 1 --timeout-ms 5000`

- Lane run: `core` only (route discipline), `5014ms` wall, `0` tokens, `0.0%` correct.

### `bun bench/llm-pi.ts --case medium-10k/wrap-body --iters 1 --timeout-ms 5000`

- Lanes: `core + blitz`, both timed out at 5s, `0` tokens, `0.0%` correct.

## Notes

- `compose-preserve-islands` now runs both lanes in this environment, but wall is timeout-scale and no tool-call metrics/correctness are captured. `correctRate` remains `0.0%` for both lanes.
- Route policy and compose case are now part of `bench/llm-pi.ts` structure and can be expanded to additional `compose_body` variants.