# D5 Blitz 0.4 Phase 7 report

Date: 2026-06-09
Status: partial/blocker. Harness now represents the explicit Phase 7 fixture set and router rows report as profile `router` with visible tool `pi_blitz_route_edit`. Parser fix now captures router `pi_blitz_*` tool calls for Zai/Pi JSONL; single semantic router smoke is accepted as evidence for that row only. D5 continuation added one paired proof slice for `config/key-update`: core succeeds; router fallback/no-write path remains rejected due timeout/incorrect despite observed `pi_blitz_route_edit`. Companion `pi-blitz` terminal-decline fix `2dfcf73` was benchmarked; the row still timed out/incorrect, so this remains blocker evidence only. No Phase 7 token-savings acceptance.

## Method

Repo branch: `feat/blitz-0.4-token-core-profile`.
Companion pi-blitz source: `/home/kenzo/dev/pi-blitz`; earlier Phase 7 rows used clean/pushed `b23dd65`, while the terminal-decline rerun used clean/pushed `2dfcf73 fix(router): make fallback declines terminal`; built dist used at `/home/kenzo/dev/pi-blitz/dist/index.js`.

Reviewed earlier cmd-created work:
- kept deterministic fixture files under `bench/fixtures-llm/`;
- fixed harness so router prompts are actually emitted for router lane (old condition only added guidance for `blitz` lane);
- fixed router accounting/report fields to use router profile/spec even when full profile artifacts are also captured;
- added `router` to accounting artifact profile list;
- kept unsupported rows honest as no-write `apply_patch` declines through `pi_blitz_route_edit`, because pi-blitz cannot call core/apply_patch internally.

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
bun bench/pi-matrix.ts --dump-accounting-only --tool-profile router --artifact-profiles router,full --no-tokscale
```
Passed; wrote accounting artifacts under `reports/pi-accounting-runs/2026-06-09T08-54-17-606Z/`.

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case semantic/arrow-replace-return,medium-10k/wrap-body \
  --lane router \
  --tool-profile router \
  --artifact-profiles router,full \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-router-pilot-20260609-d5.md \
  --json-out reports/pi-tmux-phase7-router-pilot-20260609-d5.json
```
Completed with failed/caveated rows preserved. Tokscale token match `yes` for both rows, but no accepted savings row: `wrap-body` timed out/incorrect; `arrow-replace-return` edited correctly but exit was `143` and intended tool was not observed by parser.

Main rerun before parser fix:

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
  --timeout-ms 180000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-router-semantic-rerun-20260609.md \
  --json-out reports/pi-tmux-phase7-router-semantic-rerun-20260609.json
```
Completed correct/exit 0/Tokscale match `yes`, but report still showed empty tool and `arg tok` 0. Raw session JSONL contains `toolCall` `name: "pi_blitz_route_edit"` with compact args; parser bug was lane filter excluding `router` from `pi_blitz_*` tool-call accounting.

Parser-fix rerun:

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
  --timeout-ms 180000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-router-semantic-parserfix-20260609.md \
  --json-out reports/pi-tmux-phase7-router-semantic-parserfix-20260609.json
```
Accepted semantic router smoke: correctness 100%, exit 0, intended tool observed `pi_blitz_route_edit`, `arg tok` 75, result payload tok 21, Tokscale token match `yes`. This validates parser/tool evidence for the one semantic row only; it is not a Phase 7 replacement benchmark acceptance or savings claim.

## Raw artifacts

Previous failed pilot preserved/excluded:
- `reports/pi-tmux-phase7-router-20260609.md`
- `reports/pi-tmux-phase7-router-20260609.json`
- `reports/pi-tmux-runs/2026-06-09T03-41-20-621Z`
- `reports/pi-accounting-runs/2026-06-09T03-41-20-621Z`

New D5 pilot:
- Markdown report: `reports/pi-tmux-phase7-router-pilot-20260609-d5.md`
- JSON report: `reports/pi-tmux-phase7-router-pilot-20260609-d5.json`
- Raw tmux run root: `reports/pi-tmux-runs/2026-06-09T08-54-25-712Z`
- Accounting artifacts: `reports/pi-accounting-runs/2026-06-09T08-54-25-712Z`
- Tmux session: `pi-bench-2026-06-09T08-54-25-712Z`

Main pre-fix semantic rerun:
- Markdown report: `reports/pi-tmux-phase7-router-semantic-rerun-20260609.md`
- JSON report: `reports/pi-tmux-phase7-router-semantic-rerun-20260609.json`
- Raw tmux run root: `reports/pi-tmux-runs/2026-06-09T09-02-56-974Z`
- Accounting artifacts: `reports/pi-accounting-runs/2026-06-09T09-02-56-974Z`
- Tmux session: `pi-bench-2026-06-09T09-02-56-974Z`

Parser-fix semantic rerun:
- Markdown report: `reports/pi-tmux-phase7-router-semantic-parserfix-20260609.md`
- JSON report: `reports/pi-tmux-phase7-router-semantic-parserfix-20260609.json`
- Raw tmux run root: `reports/pi-tmux-runs/2026-06-09T09-07-19-618Z`
- Accounting artifacts: `reports/pi-accounting-runs/2026-06-09T09-07-19-618Z`
- Tmux session: `pi-bench-2026-06-09T09-07-19-618Z`

D5 continuation paired config proof slice:
- Core Markdown report: `reports/pi-tmux-phase7-config-core-20260609-d5.md`
- Core JSON report: `reports/pi-tmux-phase7-config-core-20260609-d5.json`
- Core raw tmux run root: `reports/pi-tmux-runs/2026-06-09T15-29-56-978Z`
- Core accounting artifacts: `reports/pi-accounting-runs/2026-06-09T15-29-56-978Z`
- Core tmux session: `pi-bench-2026-06-09T15-29-56-978Z`
- Router fallback Markdown report: `reports/pi-tmux-phase7-config-router-fallback-20260609-d5.md`
- Router fallback JSON report: `reports/pi-tmux-phase7-config-router-fallback-20260609-d5.json`
- Router fallback raw tmux run root: `reports/pi-tmux-runs/2026-06-09T15-30-17-425Z`
- Router fallback accounting artifacts: `reports/pi-accounting-runs/2026-06-09T15-30-17-425Z`
- Router fallback tmux session: `pi-bench-2026-06-09T15-30-17-425Z`

Companion pi-blitz terminal-decline rerun after `2dfcf73`:
- Markdown report: `reports/pi-tmux-phase7-config-router-terminal-20260609.md`
- JSON report: `reports/pi-tmux-phase7-config-router-terminal-20260609.json`
- Raw tmux run root: `reports/pi-tmux-runs/2026-06-09T15-39-51-071Z`
- Accounting artifacts: `reports/pi-accounting-runs/2026-06-09T15-39-51-071Z`
- Tmux session: `pi-bench-2026-06-09T15-39-51-071Z`

## New pilot result

| Case | Lane | Route/tool profile | Correct | Exit | Tool observed | Tokscale token match | Result |
|---|---|---|---:|---:|---|---|---|
| medium-10k/wrap-body | router | `token_router` / `router` / `pi_blitz_route_edit` visible | 0% | -1 timeout | none parsed | yes | rejected; timed out/incorrect |
| semantic/arrow-replace-return | router | `token_router` / `router` / `pi_blitz_route_edit` visible | 100% | 143 | none parsed | yes | rejected; correct file but nonzero exit and intended tool not observed |
| semantic/arrow-replace-return | router parser-fix rerun | `token_router` / `router` / `pi_blitz_route_edit` visible | 100% | 0 | `pi_blitz_route_edit`; arg tok 75; result payload tok 21 | yes | accepted semantic router smoke only; no Phase 7 savings claim |
| config/key-update | core continuation slice | `core_edit` / `core` / `edit` visible | 100% | 0 | `edit`; arg tok 73; result payload tok 3 | yes | accepted core baseline for this required case only; no paired savings |
| config/key-update | router fallback continuation slice | `token_router` / `router` / `pi_blitz_route_edit` visible | 0% | -1 timeout | `pi_blitz_route_edit`; arg tok 1341; result payload tok 0 | yes | rejected; intended no-write fallback path timed out and file stayed unmodified |
| config/key-update | router terminal-decline rerun after pi-blitz `2dfcf73` | `token_router` / `router` / `pi_blitz_route_edit` visible | 0% | -1 timeout | `pi_blitz_route_edit`; arg tok 1146; result payload tok 0 | yes | rejected; terminal decline text reduced output/context somewhat but still timed out and file stayed unmodified |

Router overhead from D5 pilot:
- router schema tokens: 564
- resident skill tokens: 563
- combined: 1127
- full combined: 7158
- reduction vs full: 84.3%, meets >=70% target

This is overhead evidence only, not replacement benchmark proof.

## Phase 7 coverage table

| # | Required PLAN case | Fixture(s) | Fixture status | Router guidance/status | Evidence/status |
|---:|---|---|---|---|---|
| 1 | one-line return expression | `semantic/arrow-replace-return` | existing | supported alias `rr` through `pi_blitz_route_edit` args `f`, `r`, `s`, `fallbackContextTokensExpected` | Parser-fix rerun accepted as semantic router smoke: correctness 100%, exit 0, `pi_blitz_route_edit`, arg tok 75, Tokscale match yes; no Phase 7 savings |
| 2 | tiny exact text replace | `small/wrap-tail` | existing | unsupported by Blitz alias; router guidance says no-write `apply_patch` decline | covered as honest fallback only; no accepted run |
| 3 | small config key | `config/key-update` (`config.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | continuation slice: core baseline accepted (correct 100%, exit 0, Tokscale match yes); router fallback rejected before and after pi-blitz terminal-decline fix (timeout/incorrect despite `pi_blitz_route_edit` observed, Tokscale match yes) |
| 4 | insert logging line | `logging/insert-timer` (`logging.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 5 | wrap function body | `medium-10k/wrap-body` | existing | supported alias `wb` through `pi_blitz_route_edit` args `f`, `r`, `s`, `fallbackContextTokensExpected` | D5 pilot rejected: timeout/incorrect |
| 6 | replace long function body section | `long-section/replace-return` (`long-section.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 7 | multi-hunk same-file edit | `multi/three-body-ops`, `multi/large-structural` | existing | no router multi alias asserted in this slice; no-write fallback where unavailable | covered by existing fixture IDs, no accepted router run |
| 8 | rename within file | `rename/function-name` (`rename.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 9 | Markdown section append | `markdown/append-section` (`markdown-append.md`) | added deterministic fixture | unsupported by AST alias; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 10 | TSX component prop/body tweak | `semantic/tsx-replace-return` | existing | supported alias `rr` through `pi_blitz_route_edit` args `f`, `r`, `s`, `fallbackContextTokensExpected` | fixture covered, no accepted run |
| 11 | JSON/YAML/TOML top-level key update | `json/config-key`, `yaml/config-key`, `toml/config-key` | added deterministic fixtures | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixtures covered, no accepted run |
| 12 | HTML/CSS small edit | `html/small-edit`, `css/small-edit` | added deterministic fixtures | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixtures covered, no accepted run |

## D5 continuation audit/proof step (2026-06-09)

Harness audit:
- Current lanes: `core`, `blitz`, `router`; no direct OpenAI/apply_patch baseline lane.
- Current 12-case Phase 7 fixture representation exists across `small/wrap-tail`, `config/key-update`, `logging/insert-timer`, `medium-10k/wrap-body`, `long-section/replace-return`, `multi/*`, `rename/function-name`, `markdown/append-section`, `semantic/tsx-replace-return`, `json|yaml|toml/config-key`, `html|css/small-edit`.
- Current router facade rows are distinguishable as lane/profile `router` with visible tool `pi_blitz_route_edit`.
- Benchmark-level router-selected fallback is only represented as a no-write `pi_blitz_route_edit` decline with `r: "apply_patch"`; it is not a real core/apply_patch invocation and must stay excluded from savings claims.
- No-write decline rows are still compared to changed golden files, so they are rejected correctness rows by design unless a separate decline/unsupported expected outcome is added.

New commands:

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case config/key-update \
  --lane core \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-config-core-20260609-d5.md \
  --json-out reports/pi-tmux-phase7-config-core-20260609-d5.json
```
Passed. Accepted core baseline for `config/key-update`: correct 100%, exit 0, tool `edit`, arg tok 73, output tok 220, result payload tok 3, total context tok 8263, Tokscale token match yes.

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case config/key-update \
  --lane router \
  --tool-profile router \
  --artifact-profiles router,full \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-config-router-fallback-20260609-d5.md \
  --json-out reports/pi-tmux-phase7-config-router-fallback-20260609-d5.json
```
Completed with rejected row preserved. Router fallback/no-write path observed intended tool `pi_blitz_route_edit`, arg tok 1341, output tok 4410, Tokscale token match yes, but correctness 0%, exit -1 timeout. Excluded from savings and acceptance.

Conclusion from proof step: harness can identify real core success and router-fallback failure separately. Phase 7 remains blocked because unsupported fallback handling is not product-real core/apply_patch and current no-write decline behavior can still consume many tokens/time out.

Companion pi-blitz rerun after terminal-decline fix `2dfcf73`:

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case config/key-update \
  --lane router \
  --tool-profile router \
  --artifact-profiles router,full \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-phase7-config-router-terminal-20260609.md \
  --json-out reports/pi-tmux-phase7-config-router-terminal-20260609.json
```
Completed with rejected row preserved. It observed `pi_blitz_route_edit`, arg tok 1146, output tok 3383, total context tok 98483, Tokscale token match yes, but correctness 0%, exit -1 timeout, and file stayed unmodified. This shows the terminal-decline result shape alone did not make the model stop cheaply enough; `config/key-update` needs a real compact Blitz route (for example an `sk`/`set_key` router path) or a genuine external core/apply_patch lane.

## Acceptance

Phase7 acceptance: **NO**.

Reasons:
1. Full explicit 12-case fixture set is now represented in harness/report, but accepted tmux/Tokscale router rows remain missing.
2. Parser-fix rerun provides one accepted semantic router smoke (correctness 100%, exit 0, intended tool observed, Tokscale match `yes`), but this covers only one required case and no paired core/apply_patch/current Blitz comparison.
3. Earlier pilot failures remain preserved: one timeout/incorrect row; one correct file with exit `143` and no parsed tool before parser fix.
4. apply_patch/core baseline remains unavailable in harness; only explicit no-write declines are honest.
5. Companion pi-blitz terminal-decline fix `2dfcf73` did not make unsupported router fallback acceptable: rerun still timed out/incorrect.
6. No token savings counted: full 12-case paired acceptance gates are not met.

## Next precise work

1. Add a real compact config route for `config/key-update` instead of no-write decline (likely router guidance to `sk`/`set_key` if Blitz CLI support is sufficient, otherwise a Blitz-side fix).
2. Rerun `config/key-update` router after the real route exists and compare against the accepted core baseline; preserve the failed terminal-decline artifacts.
3. Extend real compact aliases or genuine fallback lanes for logging/markdown/json/yaml/toml/html/css before claiming 12-case Phase 7 acceptance.
4. Add real apply_patch/core lane only if parent wants baseline comparison; do not fake via router declines.
5. Full Phase 7 still requires paired core/current Blitz/optimized router evidence across all required cases plus structural savings preservation.

## Token claim caveat

No token savings accepted or counted from Phase 7. Only resident overhead reduction evidence from serialized schema/skill artifacts is valid.
