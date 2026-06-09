# D5 Blitz 0.4 Phase 7 report

Date: 2026-06-09
Status: partial/blocker. Harness now has actual `router` lane using `PI_BLITZ_TOOL_PROFILE=router` and visible tool `pi_blitz_route_edit`, but first real tmux/Tokscale router pilot timed out before tool call. No token-savings claim.

## Method

Repo branch: `feat/blitz-0.4-token-core-profile`.
Companion pi-blitz source: `/home/kenzo/dev/pi-blitz`, branch `feat/blitz-0.4-token-core-profile-canonical`, built dist used at `/home/kenzo/dev/pi-blitz/dist/index.js`.

Harness change:
- added lane `router` alongside `core` and `blitz`;
- router lane sets `PI_BLITZ_TOOL_PROFILE=router` for spawn/tmux commands;
- router lane exposes only `pi_blitz_route_edit` via `--tools pi_blitz_route_edit`;
- run records mark route `token_router` and reason `lane_router_facade`;
- default lane matrix now includes core, current Blitz, router for comparable fixtures;
- compact router guidance added for supported existing compact op cases (`wrap-body`, `medium-10k/marker-tail`, `semantic/async-try-catch`, `semantic/arrow-replace-return`).

OpenAI/apply_patch-style baseline: unavailable in this Pi harness as direct API/tool lane. `pi_blitz_route_edit` can decline to `apply_patch`, but cannot invoke OpenAI/apply_patch internally; no fake baseline row produced.

## Commands run

```bash
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
```
Passed.

```bash
git diff --check
```
Passed.

```bash
tokscale --version
```
Passed: `tokscale 2.1.3`.

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case semantic/arrow-replace-return \
  --lane router \
  --tool-profile router \
  --artifact-profiles router,full \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-router-20260609.md \
  --json-out reports/pi-tmux-phase7-router-20260609.json
```
Completed harness run with failed row preserved. Tokscale available and token match `yes`, but row timed out and was incorrect (`correct 0.0%`, exit `-1`). No tool call args captured; `stdout.log` empty, `stderr.log` only `[pi-blitz] tool profile router registered`.

## Raw artifacts

- Markdown report: `reports/pi-tmux-phase7-router-20260609.md`
- JSON report: `reports/pi-tmux-phase7-router-20260609.json`
- Raw tmux run root: `reports/pi-tmux-runs/2026-06-09T03-41-20-621Z`
- Failed row dir: `reports/pi-tmux-runs/2026-06-09T03-41-20-621Z/semantic_arrow-replace-return__router__0`
- Accounting artifacts: `reports/pi-accounting-runs/2026-06-09T03-41-20-621Z`
- Tmux session: `pi-bench-2026-06-09T03-41-20-621Z`

## Pilot result

| Case | Lane | Route/tool profile | Correct | Exit | Tokscale token match | Result |
|---|---|---|---:|---:|---|---|
| semantic/arrow-replace-return | router | `token_router` / router / `pi_blitz_route_edit` visible | 0% | -1 timeout | yes | failed before actual router tool call; no savings counted |

Router overhead from artifact dump:
- router schema tokens: 564
- resident skill tokens: 563
- combined: 1127
- full combined: 7158
- reduction vs full: 84.3%, meets >=70% target

This is overhead evidence only, not replacement benchmark proof.

## Phase 7 coverage table

| # | Required case | Existing fixture / status | Core edit | apply_patch baseline | current Blitz | optimized/minimal | router-selected path | Evidence |
|---:|---|---|---|---|---|---|---|---|
| 1 | one-line return expression | `semantic/arrow-replace-return`; router pilot attempted | not run in Phase7 pilot | unavailable/no API | not run in Phase7 pilot | not run in Phase7 pilot | attempted, timed out before tool call | raw run root above |
| 2 | tiny exact text replace | maps to `small/wrap-tail`; not run | missing | unavailable/no API | fixture is core-only | missing | missing | harness fixture exists, no Phase7 run |
| 3 | small config key | missing fixture | missing | unavailable/no API | missing | missing | missing | blocker: fixture not added yet |
| 4 | insert logging line | maps partially to insert-body-span/guard, but not logging | missing | unavailable/no API | missing | missing | missing | blocker: exact logging fixture not added yet |
| 5 | wrap function body | `medium-10k/wrap-body`; router guidance added | not run | unavailable/no API | not run | not run | not run | harness support only |
| 6 | replace long function body section | no exact Phase7 fixture; structural large partials exist | missing | unavailable/no API | missing | missing | missing | blocker: exact long-section fixture needed |
| 7 | multi-hunk same-file edit | `multi/three-body-ops` / `multi/large-structural`; no router guidance yet | not run | unavailable/no API | not run | not run | missing | blocker: router compact multi guidance needed |
| 8 | rename within file | missing fixture | missing | unavailable/no API | missing | missing | missing | blocker: fixture needed |
| 9 | Markdown section append | `readme/core-smoke` core-only prepend; append not exact | not run | unavailable/no API | unsupported by current AST lane | unsupported | missing | blocker: exact append fixture and route fallback policy needed |
| 10 | TSX component prop/body tweak | `semantic/tsx-replace-return`; no router guidance yet | not run | unavailable/no API | not run | not run | missing | blocker: router guidance needed |
| 11 | JSON/YAML/TOML top-level key update | missing fixture | missing | unavailable/no API | missing | missing | missing | blocker: fixture needed |
| 12 | HTML/CSS small edit | missing fixture | missing | unavailable/no API | missing | missing | missing | blocker: fixture needed |

## Acceptance

Phase7 acceptance: **NO**.

Reasons:
1. Real Pi/Tokscale artifacts exist for one router pilot, but row failed/timed out before actual `pi_blitz_route_edit` tool call.
2. Full 12-case Phase7 set is not covered with evidence; several exact fixtures are missing.
3. No accepted savings row: correctness not 100%, exit not 0, actual tool call not observed.
4. apply_patch baseline is unavailable in current Pi harness; must remain explicit blocker unless parent adds/directs API lane.

## Next precise work

1. Add minimal deterministic Phase7 fixture files for config, logging, long section, rename, markdown append, JSON/YAML/TOML, HTML/CSS.
2. Extend router guidance for each supported compact op; mark no-write fallback rows where router selects `core`/`apply_patch`.
3. Run bounded tmux/Tokscale matrix case-by-case, starting with one fast simple row and one structural row.
4. If Zai model continues to timeout before tool call with router-only profile, pilot another provider/model or inspect Pi/router prompt/tool schema from saved prompt/session before broader run.

## Token claim caveat

No token savings accepted or counted from this Phase7 run. Only resident overhead reduction evidence from serialized schema/skill artifacts is valid.
