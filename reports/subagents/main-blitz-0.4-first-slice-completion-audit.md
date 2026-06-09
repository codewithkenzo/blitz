# Main completion audit — Blitz 0.4 Phase 0/1 first slice

Date: 2026-06-08
Branch: `feat/blitz-0.4-token-core-profile`
Objective sources:
- `docs/plans/START-0.4-context-token-core.md`
- `docs/plans/PLAN-0.4-context-token-optimization.md`

## Concrete deliverables / success criteria

1. Phase 0 benchmark/accounting harness records tool/profile context tax and row-level token accounting: visible tools, serialized tool specs, skill text/tokens, prompt tokens, arg tokens, output tokens, result payload tokens, input/cache/Tokscale totals, residual input, correctness, route/profile, and total model-visible context.
2. Raw accounting artifacts are durable under `reports/`: per-profile `tool-specs.<profile>.json`, `skill.<profile>.md`, tokenizer metadata, session JSONL/Tokscale evidence, and matrix JSON/MD.
3. Phase 1 `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` is implemented in `pi-blitz`; default missing/empty profile resolves to `minimal`; `full` remains available for backcompat/debug.
4. Profile registration is fail-closed: unsupported profile names fail, and unsupported tools are not registered / not available to a profile.
5. Existing Pi matrix is rerun with Tokscale/session evidence; failed/skipped rows and caveats are explicit; no failed row is counted as savings.
6. Profile variants are measured enough to compare schema tax and supported rows: full, semantic, structural, minimal-v0.
7. Verification gates pass for current branches: Blitz build/tests, harness build smoke, pi-blitz typecheck/tests/build.
8. No unsupported core-replacement or token-savings claim is made beyond measured row evidence.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| Phase 0 fields in `bench/pi-matrix.ts` | `bench/pi-matrix.ts` records `schemaTokens`, `skillTokens`, `promptTokens`, `toolCallArgTokens`, `outputTokens`, `cacheRead`, `cacheWrite`, `resultPayloadTokens`, `residualInputTokens`, `totalContextTokens`, `toolProfile`, `visibleTools`, `tokScale*`, `correct`, `route`. | PASS |
| Raw per-profile accounting artifacts | `reports/pi-accounting-runs/20260608-first-slice-full-profile-retry-071648/` contains `tool-specs.{minimal,semantic,structural,admin,full}.json`, `skill.{minimal,semantic,structural,admin,full}.md`, `tokenizer.{minimal,semantic,structural,admin,full}.json`. | PASS |
| Tokscale/session JSON preserved | Full profile matrix JSON `phase0Accounting.tokScaleSessionJsonPaths` lists 24 session JSONL files under `reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648/**/sessions/*.jsonl`. | PASS |
| Matrix JSON/MD preserved | `reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.{json,md}`. | PASS |
| Profile-variant matrix artifacts preserved | `reports/pi-tmux-matrix-20260608-profile-variants-073417-{semantic,structural,minimal}.{json,md}` plus matching `reports/pi-accounting-runs/20260608-profile-variants-073417-*` and `reports/pi-tmux-runs/20260608-profile-variants-073417-*`. | PASS |
| `PI_BLITZ_TOOL_PROFILE` implemented | `/home/kenzo/dev/pi-blitz-token-profile/src/tool-profiles.ts`, `/home/kenzo/dev/pi-blitz-token-profile/index.ts`. | PASS |
| Default profile is minimal-v0 | `bun scripts/dump-tool-specs.ts` evidence from prior run and tests; default/missing/empty resolves to `minimal`, label `minimal-v0`, visible tool `pi_blitz_patch`. | PASS |
| Full profile backcompat | Full profile matrix registered 15 tools and ran with `PI_BLITZ_TOOL_PROFILE=full`. | PASS |
| Fail-closed unsupported tools | D5/reviewer smokes: minimal/semantic with unsupported tool requested exits before Pi with `tool profile <profile> does not expose requested Blitz tools`. | PASS |
| Build/test gates | Rerun on 2026-06-08: `zig build && zig build test`; `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-final-check.js`; `/home/kenzo/dev/pi-blitz-token-profile`: `bun run typecheck && bun test && bun run build`. | PASS |
| No unsupported savings/core-replacement claims | Reports treat rows as measurement evidence only; failed rows listed below; no claim that Blitz is ready as core edit replacement. | PASS |

## Matrix evidence summary

### Full profile run

Artifact: `reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.json`

- Rows: 26
- Correct and clean exit: 20
- Failed/caveated: 6
- Tokscale token match mismatches on exit-0 rows: 0
- Session JSONL paths: 24
- Full profile schema: 15 tools, 5517 serialized tool-spec tokens
- Resident skill: 2358 tokens

Failed/caveated rows, not counted as savings:

- `medium-10k/wrap-body` core: timed out / no useful session row, incorrect.
- `medium-10k/wrap-body` blitz full: timed out, incorrect.
- `medium-10k/compose-preserve-islands` core: exited 0 but correctness mismatch.
- `medium-10k/insert-body-span` core: exited 0 but correctness mismatch.
- `medium-10k/insert-body-span` blitz full: exited 0 but correctness mismatch.
- `multi/large-structural` core: timed out / no useful session row, incorrect.

Both-correct full-profile pair deltas all show full Blitz still loses total model-visible context after schema/skill overhead:

- `medium-10k/marker-tail`: core 22181, Blitz full 40760, delta +18579.
- `multi/three-body-ops`: core 9650, Blitz full 24006, delta +14356.
- `huge-100k/marker-tail`: core 152196, Blitz full 214364, delta +62168.
- `semantic/async-try-catch`: core 9375, Blitz full 17374, delta +7999.
- `semantic/class-method-try-catch`: core 9450, Blitz full 17194, delta +7744.
- `semantic/arrow-replace-return`: core 13933, Blitz full 17329, delta +3396.
- `semantic/nested-return-occurrence`: core 13716, Blitz full 17160, delta +3444.
- `semantic/tsx-replace-return`: core 12750, Blitz full 16838, delta +4088.

Interpretation: full profile is useful as baseline/backcompat evidence only; it is not an optimized replacement route.

### Profile variants

Artifacts:
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-semantic.json`
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-structural.json`
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-minimal.json`

Schema reductions vs full:

- `minimal-v0`: 1 tool, 442 schema tokens, 92.0% reduction.
- `semantic`: 3 tools, 1152 schema tokens, 79.1% reduction.
- `structural`: 6 tools, 2551 schema tokens, 53.8% reduction.
- `admin`: 4 tools, 622 schema tokens, 88.7% reduction.
- `full`: 15 tools, 5517 schema tokens.

Variant row results:

- Semantic profile: 5/5 rows correct, exit 0, Tokscale token matches all rows.
  - Semantic profile beats the prior core totals on these measured rows: `semantic/arrow-replace-return` (12936 vs core 13933), `semantic/nested-return-occurrence` (12920 vs core 13716), `semantic/tsx-replace-return` (12615 vs core 12750). These are evidence rows only, not a runtime replacement claim.
  - Semantic profile still loses on `semantic/async-try-catch` and `semantic/class-method-try-catch` versus prior core totals.
- Structural profile: 5/7 clean rows; `medium-10k/wrap-body` timed out/incorrect and `multi/large-structural` timed out despite correctness flag. Failed/timed-out rows are not counted as savings.
  - Structural profile reduces overhead versus full but still does not meet the >=70% schema reduction target; next work should split structural further or move to compact Phase 2 IR.
- Minimal-v0 profile: 1/1 `multi/large-structural` patch row correct, exit 0; schema reduction target met. This proves registration/profile plumbing, not general replacement suitability.

## Commands verified

- `/home/kenzo/dev/blitz`: `zig build && zig build test` — passed.
- `/home/kenzo/dev/blitz`: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-final-check.js` — passed.
- `/home/kenzo/dev/pi-blitz-token-profile`: `bun run typecheck && bun test && bun run build` — passed.
- Matrix run: `bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --iters 1 --tool-profile full --artifact-profiles all --artifact-root reports/pi-accounting-runs/20260608-first-slice-full-profile-retry-071648 --run-root reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648 --timeout-ms 120000 --tokscale --md-out reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.md --json-out reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.json` — completed with caveated rows listed above.
- Profile variant run script in `reports/bench-logs/20260608-profile-variants-073417.log` — completed semantic, structural, minimal profile runs with caveats listed above.

## Completion judgment

The first slice is implemented and auditable as a measurement/profile-registration slice:

- Phase 0 harness/accounting exists and produces durable artifacts.
- Phase 1 profile registration exists and is tested.
- Full and profile-variant Pi/Tokscale artifacts exist under `reports/`.
- Failed rows and caveats are explicit.
- No failed row is counted as savings.
- No core-replacement claim is made.

Remaining product work is intentionally future-slice work: Phase 2 compact op/IR, further schema splitting for structural routes, runtime router integration, and repeated benchmark rows for publishable savings claims.

Pending before marking goal complete: final independent reviewer re-audit after the new full/profile-variant artifacts.
