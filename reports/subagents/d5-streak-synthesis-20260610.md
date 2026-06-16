# D5 streak synthesis — 2026-06-10

Status: implemented Blitz-side cumulative streak synthesis. Not default-ready proof.

## Scope

- Repo: `/home/kenzo/dev/blitz`
- Branch: `feat/blitz-0.4-token-core-profile`
- No `/home/kenzo/dev/pi-blitz` edits.
- Baseline/fallback: Pi core `edit` only.
- Codex/OpenAI `apply_patch`: out of scope for current gate.

## Implementation

Added `bench/streak-synthesis.ts`, additive report generator that:

- reads accepted rows from `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json` and its source reports;
- loads full per-row token breakdown from real Pi/tmux/Tokscale source reports;
- filters accepted rows: correctness `100%`, Tokscale token match `yes`, no timeout, exit codes `0`;
- builds cumulative scenarios:
  - `tiny-10`: 10 tiny/core-likely edits;
  - `mixed-20`: 20 mixed language/config/markdown/code edits;
  - `same-file-multi`: one accepted same-file multi-edit scenario;
  - representative single rows where Blitz/router wins or core wins;
- writes JSON + Markdown reports under `reports/`;
- preserves source run-root provenance and does not delete raw artifacts.

Updated durable plan/start docs to reflect tweaked objective:

- primary metric is cumulative model-visible context across realistic edit streaks;
- Pi core `edit` is only required baseline/fallback;
- apply_patch/Morph/Codex parity is future optional comparison, not current acceptance gate;
- structural rows are secondary capability evidence;
- benchmark-only route-selected core choices are not product-real `pi_blitz_route_edit` fallback.

Updated `bench/pi-matrix.ts` report language from `core/apply_patch fallback` to `Pi core edit fallback`.

## Evidence report

Generated:

- `reports/pi-tmux-streak-synthesis-20260610-d5.json`
- `reports/pi-tmux-streak-synthesis-20260610-d5.md`

Key cumulative totals from generated report:

| Scenario | Edits | Core baselines | Selected total context | Core total context | Delta vs core | Savings | Correct |
|---|---:|---:|---:|---:|---:|---:|---|
| 10 tiny/core-likely edits | 10 | 10 | 85,140 | 85,140 | 0 | 0.0% | yes |
| 20 mixed language/config/markdown/code edits | 20 | 17 | 221,987 | 166,479 | -55,508 | -33.3% | yes |
| same-file multi-edit scenario | 1 | 0 | 30,913 | — | — | — | yes |

Representative single rows:

- `semantic/arrow-replace-return`: router `pi_blitz_route_edit` 10,821 vs core 18,845 → router wins by 8,024 tokens.
- `config/key-update`: core 8,263 selected; Blitz/router loses in prior evidence.
- `long-section/replace-return`: core 9,769 selected; router 11,122 loses in prior evidence.
- `medium-10k/wrap-body`: Blitz accepted 30,087; no accepted core baseline.
- `multi/large-structural`: Blitz accepted 30,913; no accepted core baseline.

## Honest limitation

True sequential same-session streak support is not implemented in this slice. Existing `bench/pi-matrix.ts` runs one edit per isolated Pi/tmux command. The new streak report is smallest honest approximation: cumulative synthesis over accepted real Pi/tmux/Tokscale rows with source artifacts preserved.

## Commands run

- `bun bench/streak-synthesis.ts` — passed; wrote streak JSON/MD.
- `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js && bun build bench/streak-synthesis.ts --target=bun --outfile=/tmp/streak-synthesis-check.js && git diff --check` — passed.

`zig build && zig build test` not run: no Zig/source behavior changes in this slice.

## Verdict

Not default-ready. Evidence says tiny/core-like cumulative path ties core only because selected route mostly picks core. Mixed 20-edit approximation loses vs available core baselines due structural/no-core-baseline rows and remaining overhead. Next slice should implement true sequential same-session streak runner or product-real route/fallback integration, then rerun accepted streaks.
