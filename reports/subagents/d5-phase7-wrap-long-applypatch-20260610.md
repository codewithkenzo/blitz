# D5 Phase 7 wrap/long/apply_patch evidence — 2026-06-10

Status: Phase 7 remains **NO**. Hard gaps reduced, not closed.

## Root causes

### `medium-10k/wrap-body`

Artifact-backed cause:
- Failed 2026-06-09 row: `reports/pi-tmux-runs/2026-06-09T17-11-08-935Z/medium-10k_wrap-body__blitz__0/`.
- Stale/failed 2026-06-10 attempt: `reports/pi-tmux-runs/2026-06-10T05-31-04-536Z/medium-10k_wrap-body__blitz__0/` and `reports/pi-tmux-phase7-wrapbody-rerun-20260610-d5.{md,json}`.
- Fresh pre-fix attempt after harness guidance change: `reports/pi-tmux-runs/2026-06-10T05-36-28-114Z/medium-10k_wrap-body__blitz__0/` and `reports/pi-tmux-phase7-wrapbody-rerun2-20260610-d5.{md,json}`.

Diagnosis:
- Pi/model repeatedly passed `before` as literal backslash-n (`'\\n  try {'`) instead of newline char, despite prompt guidance.
- Blitz CLI rejected resulting file with `PARSE_ERROR_AFTER` when `wrap_body.before` contained literal `\\n`.
- Direct CLI proof: `blitz apply --edit - --json` with actual newline applied; same request with literal `\\n` rejected before fix.
- Narrow Blitz-side fix landed in `src/apply/mod.zig`: `wrap_body` now normalizes `\\n` escape sequences in `before`/`after` before applying.

Accepted evidence after fix:
- `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.{md,json}`
- Run root: `reports/pi-tmux-runs/2026-06-10T05-39-20-199Z`
- Row: `medium-10k/wrap-body`, lane `blitz`, tool `pi_blitz_wrap_body`, correctness `100.0%`, exit `0`, Tokscale token match `yes`, total context `30,087`.

### `long-section/replace-return`

Artifact-backed cause:
- Failed earlier core/router rows edited file to ``$${total.toFixed(2)}`` while expected fixture was missing dollar sign.
- Root cause was JS replacement string semantics in harness: replacement string `"$${total.toFixed(2)}"` treated `$$` as a literal `$`, producing expected output without `$` before interpolation.
- Fix landed in `bench/pi-matrix.ts`: `longSectionExpected` now uses replacement callback so `$${...}` is preserved literally.

Accepted evidence after fix:
- Core: `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-10T05-35-09-188Z`; correctness `100.0%`, exit `0`, Tokscale match `yes`, total context `9,769`.
- Router: `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-10T05-35-40-122Z`; correctness `100.0%`, exit `0`, Tokscale match `yes`, total context `11,122`.
- Synthesis chooses core for this fixture.

## apply_patch-style baseline investigation

Result: not available as honest current harness lane.

Evidence/semantics:
- Current `bench/pi-matrix.ts` lane type is `core | blitz | router`.
- Core lane invokes Pi with `--no-skills --no-extensions --tools edit`; Pi help describes built-in `edit` as `Edit files with find/replace`.
- No current harness lane exposes OpenAI-native `apply_patch`, nor a distinct Pi built-in `apply_patch` tool.
- The parent-session API tool has an `edit` tool with `patch` parameter, but that is not the Pi binary/tmux benchmark harness tool surface and cannot be counted as real Pi/Tokscale row without a custom harness lane/tool registration.
- Therefore no direct apply_patch/apply_patch-style baseline was added. OpenAI-native apply_patch remains absent; adding a real lane would be new harness/tool-surface work and must not be faked.

## New/updated artifacts

| Fixture | Lane/tool | Artifact | Run root | Correct | Exit | Tokscale match | Total context | Decision |
|---|---|---|---|---:|---:|---:|---:|---|
| `medium-10k/wrap-body` | blitz/`pi_blitz_wrap_body` | `reports/pi-tmux-phase7-wrapbody-rerun-20260610-d5.{md,json}` | `reports/pi-tmux-runs/2026-06-10T05-31-04-536Z` | 0% | -1 | yes | 136,931 | stale/failed preserved |
| `medium-10k/wrap-body` | blitz/`pi_blitz_wrap_body` | `reports/pi-tmux-phase7-wrapbody-rerun2-20260610-d5.{md,json}` | `reports/pi-tmux-runs/2026-06-10T05-36-28-114Z` | 0% | 0 | yes | 59,419 | rejected pre-fix |
| `medium-10k/wrap-body` | blitz/`pi_blitz_wrap_body` | `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.{md,json}` | `reports/pi-tmux-runs/2026-06-10T05-39-20-199Z` | 100% | 0 | yes | 30,087 | accepted |
| `long-section/replace-return` | core/`edit` | `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.{md,json}` | `reports/pi-tmux-runs/2026-06-10T05-35-09-188Z` | 100% | 0 | yes | 9,769 | accepted |
| `long-section/replace-return` | router/`pi_blitz_route_edit` | `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.{md,json}` | `reports/pi-tmux-runs/2026-06-10T05-35-40-122Z` | 100% | 0 | yes | 11,122 | accepted but loses to core |

## Synthesis outcome

Regenerated:
- `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.{md,json}`

Selected changes:
- `medium-10k/wrap-body`: accepted Blitz row selected at `30,087`; still no accepted core/apply_patch baseline.
- `long-section/replace-return`: core selected at `9,769`; router accepted but more expensive.
- `multi/large-structural`: unchanged accepted Blitz row at `30,913`; still no accepted core/apply_patch baseline.

Remaining gaps:
- Phase 7 remains **NO**.
- No direct apply_patch baseline.
- `wrap-body` and `multi/large-structural` still lack accepted core/apply_patch baselines.
- `pi_blitz_route_edit` remains benchmark/runtime facade only; it does not product-real call core/apply_patch.
- Some rows are accepted without paired baselines, so no full core-replacement claim.

## Commands run

- `git fetch --prune`
- `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js`
- `zig build && zig build test`
- Direct CLI smoke: `blitz apply --edit - --json` with literal `\\n` in wrap_body before (rejected before fix, applied after fix)
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case long-section/replace-return --lane core --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-longsection-rerun-20260610-d5.md --json-out reports/pi-tmux-phase7-longsection-rerun-20260610-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case long-section/replace-return --lane router --iters 1 --timeout-ms 180000 --tokscale --tool-profile router --md-out reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.md --json-out reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.json`
- `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case medium-10k/wrap-body --lane blitz --iters 1 --timeout-ms 180000 --tokscale --tool-profile full --md-out reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.md --json-out reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json`
- `bun bench/phase7-route-selected-synthesis.ts`

## Manual notes

Stale/failed run preserved. No old Phase 7 artifacts deleted or overwritten. No `/home/kenzo/dev/pi-blitz` edits made.
