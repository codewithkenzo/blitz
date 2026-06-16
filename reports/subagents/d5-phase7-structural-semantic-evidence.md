# D5 Phase 7 structural + semantic evidence

Date: 2026-06-09
Status: evidence slice complete; Phase 7 remains **NO**.

## Commands run

- `git status --short --branch --untracked-files=normal && git fetch --prune && git log --oneline --decorate --max-count=5 --all --simplify-by-decoration`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane blitz --iters 1 --timeout-ms 180000 --tokscale --tool-profile structural --md-out reports/pi-tmux-phase7-structural-current-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-current-20260609-d5.json` — failed before running rows; structural profile does not expose `pi_blitz_wrap_body`.
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane blitz --iters 1 --timeout-ms 180000 --tokscale --tool-profile full --md-out reports/pi-tmux-phase7-structural-current-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-current-20260609-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane router --iters 1 --timeout-ms 180000 --tokscale --tool-profile structural --md-out reports/pi-tmux-phase7-structural-router-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-router-20260609-d5.json` — failed before running rows; structural profile does not expose `pi_blitz_route_edit`.
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane router --iters 1 --timeout-ms 180000 --tokscale --tool-profile minimal --md-out reports/pi-tmux-phase7-structural-router-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-router-20260609-d5.json` — failed before running rows; minimal profile does not expose `pi_blitz_route_edit`.
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane router --iters 1 --timeout-ms 180000 --tokscale --tool-profile router --md-out reports/pi-tmux-phase7-structural-router-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-router-20260609-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case semantic/tsx-replace-return,semantic/arrow-replace-return --lane core --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-semantic-core-20260609-d5.md --json-out reports/pi-tmux-phase7-semantic-core-20260609-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case semantic/tsx-replace-return,semantic/arrow-replace-return --lane router --iters 1 --timeout-ms 180000 --tokscale --tool-profile router --md-out reports/pi-tmux-phase7-semantic-router-20260609-d5.md --json-out reports/pi-tmux-phase7-semantic-router-20260609-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body,multi/large-structural --lane core --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-structural-core-20260609-d5.md --json-out reports/pi-tmux-phase7-structural-core-20260609-d5.json`
- `bun bench/phase7-route-selected-synthesis.ts`

## New artifacts

- `reports/pi-tmux-phase7-structural-core-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-20-14-699Z`; tmux `pi-bench-2026-06-09T17-20-14-699Z`.
- `reports/pi-tmux-phase7-structural-current-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-11-08-935Z`; tmux `pi-bench-2026-06-09T17-11-08-935Z`.
- `reports/pi-tmux-phase7-structural-router-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-13-32-066Z`; tmux `pi-bench-2026-06-09T17-13-32-066Z`.
- `reports/pi-tmux-phase7-semantic-core-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-18-18-155Z`; tmux `pi-bench-2026-06-09T17-18-18-155Z`.
- `reports/pi-tmux-phase7-semantic-router-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-19-12-655Z`; tmux `pi-bench-2026-06-09T17-19-12-655Z`.
- Regenerated `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.{md,json}`.

## Row summary

| Case | Lane/tool | Correct | Exit | Timed out | Tokscale match | Total context | Decision |
|---|---|---:|---:|---:|---:|---:|---|
| `medium-10k/wrap-body` | core/(none) | 0% | -1 | yes | no | 4,639 | rejected |
| `multi/large-structural` | core/(none) | 0% | -1 | yes | no | 4,709 | rejected |
| `medium-10k/wrap-body` | blitz/`pi_blitz_wrap_body` | 0% | 0 | no | yes | 176,294 | rejected |
| `multi/large-structural` | blitz/`pi_blitz_patch` | 100% | 0 | no | yes | 30,913 | accepted |
| `medium-10k/wrap-body` | router/`pi_blitz_route_edit` | 0% | 0 | no | yes | 98,908 | rejected |
| `multi/large-structural` | router/`pi_blitz_route_edit` | 0% | -1 | yes | yes | 233,864 | rejected |
| `semantic/arrow-replace-return` | core/`edit` | 100% | 0 | no | yes | 18,845 | accepted |
| `semantic/tsx-replace-return` | core/`edit` | 100% | 0 | no | yes | 8,516 | accepted |
| `semantic/arrow-replace-return` | router/`pi_blitz_route_edit` | 100% | 0 | no | yes | 11,037 | accepted |
| `semantic/tsx-replace-return` | router/`pi_blitz_route_edit` | 100% | 0 | no | yes | 10,436 | accepted |

## Synthesis outcome

Updated `bench/phase7-route-selected-synthesis.ts` candidate list includes new structural/semantic JSON files and maps TSX required case to `semantic/tsx-replace-return`.

Current regenerated selected outcomes:
- `semantic/arrow-replace-return`: router selected at 10,821 total context vs accepted core baseline 18,845.
- `semantic/tsx-replace-return`: core selected at 8,516; router accepted at 10,436 but loses to core.
- `multi/large-structural`: current Blitz selected at 30,913; no accepted core baseline.
- `medium-10k/wrap-body`: incomplete; no accepted current row.

## Remaining gaps

- Phase 7 remains **NO**.
- Structural preservation still incomplete: `medium-10k/wrap-body` remains red across current core/Blitz/router attempts.
- Structural savings not fully proven in current matrix: `multi/large-structural` accepted for current Blitz, but lacks accepted core baseline; `wrap-body` missing.
- Route selection remains benchmark-only. `pi_blitz_route_edit` does not product-real invoke core/apply_patch.
- Direct apply_patch baseline absent.
- `long-section/replace-return` remains incomplete.

## Verification

Pending final verification and push in session final report.
