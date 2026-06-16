# D5 Blitz 0.4 Phase 7 report

Date: 2026-06-09
Status: partial/blocker. Harness now represents the explicit Phase 7 fixture set and router rows report as profile `router` with visible tool `pi_blitz_route_edit`. Parser fix now captures router `pi_blitz_*` tool calls for Zai/Pi JSONL; single semantic router smoke is accepted as evidence for that row only. D5 continuation added one paired proof slice for `config/key-update`: core succeeds; router fallback/no-write path remains rejected due timeout/incorrect despite observed `pi_blitz_route_edit`. Companion `pi-blitz` terminal-decline fix `2dfcf73` was benchmarked; the row still timed out/incorrect. New Blitz-side TypeScript `set_key` support now handles the exact top-level `config.ts` object-literal key update deterministically. Direct CLI smoke passes. Router `sk\tlogLevel\tdebug` tmux/Tokscale rerun is accepted for `config/key-update` only, but it does not beat existing core baseline on total context. New format-config slice adds deterministic explicit one-level YAML/TOML path support (`app.debug`) and proves JSON/YAML/TOML compact `sk` router rows executable/correct with Tokscale; all three are accepted as router rows but lose to paired core baselines on total context. No Phase 7 token-savings acceptance.

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
| 3 | small config key | `config/key-update` (`config.ts`) | added deterministic fixture | supported by narrow TS object-literal `set_key`; router guidance uses compact `sk\tlogLevel\tdebug` | core baseline accepted (correct 100%, exit 0, Tokscale match yes); earlier router fallback/terminal-decline and quoted-value attempts preserved/rejected; current unquoted `sk` router rerun accepted for this case only, but total context exceeded core |
| 4 | insert logging line | `logging/insert-timer` (`logging.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 5 | wrap function body | `medium-10k/wrap-body` | existing | supported alias `wb` through `pi_blitz_route_edit` args `f`, `r`, `s`, `fallbackContextTokensExpected` | D5 pilot rejected: timeout/incorrect |
| 6 | replace long function body section | `long-section/replace-return` (`long-section.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 7 | multi-hunk same-file edit | `multi/three-body-ops`, `multi/large-structural` | existing | no router multi alias asserted in this slice; no-write fallback where unavailable | covered by existing fixture IDs, no accepted router run |
| 8 | rename within file | `rename/function-name` (`rename.ts`) | added deterministic fixture | unsupported compact alias today; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 9 | Markdown section append | `markdown/append-section` (`markdown-append.md`) | added deterministic fixture | unsupported by AST alias; router guidance no-write `apply_patch` decline | fixture covered, no accepted run |
| 10 | TSX component prop/body tweak | `semantic/tsx-replace-return` | existing | supported alias `rr` through `pi_blitz_route_edit` args `f`, `r`, `s`, `fallbackContextTokensExpected` | fixture covered, no accepted run |
| 11 | JSON/YAML/TOML top-level/explicit path key update | `json/config-key`, `yaml/config-key`, `toml/config-key` | added deterministic fixtures | supported by compact `sk` route: JSON `sk\tdebug\ttrue`; YAML/TOML `sk\tapp.debug\ttrue` | router tmux/Tokscale rows accepted/correct for all 3; paired core baselines also correct; no savings because router total context exceeds core |
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
Completed with rejected row preserved. It observed `pi_blitz_route_edit`, arg tok 1146, output tok 3383, total context tok 98483, Tokscale token match yes, but correctness 0%, exit -1 timeout, and file stayed unmodified. This shows the terminal-decline result shape alone did not make the model stop cheaply enough; `config/key-update` needs a real compact Blitz route or a genuine external core/apply_patch lane.

Direct `set_key` support check on the exact Phase 7 fixture:

```bash
# steering-override: ztk-for-noisy-file-output — need exact CLI stdout for set_key smoke
tmp=$(mktemp -d); cp bench/fixtures-llm/config.ts "$tmp/config.ts"; python3 -c 'import sys,json; p=sys.argv[1]; print(json.dumps({"version":1,"file":p,"operation":"set_key","edit":{"key":"logLevel","value":"debug"},"options":{"requireParseClean":True,"requireSingleMatch":True}}))' "$tmp/config.ts" | ./zig-out/bin/blitz apply --edit - --json; status=$?; echo status=$status; cat "$tmp/config.ts"
```

Result: rejected with `code: "UNSUPPORTED_LANGUAGE"`, `operation: "set_key"`, `status=1`; file stayed `logLevel: "info"`. Existing pi-blitz `sk` alias translates directly to Blitz `set_key` (`edit: { key, value }`), so `sk` cannot perform the TypeScript `config/key-update` fixture today. No router-sk tmux/Tokscale rerun was produced because route support is absent; failed terminal-decline artifacts remain preserved.

## D5 continuation: TypeScript config `set_key` unblock

Implementation:
- `src/apply/mod.zig` now routes `.ts`/`.tsx` `set_key` through narrow format-text support.
- Scope is fail-closed: clean TypeScript parse before/after, existing top-level object-literal property only, two-space property indent, duplicate top-level key rejects before write, no insertion/fuzzy rewrite.
- New focused tests cover exact `bench/fixtures-llm/config.ts` shape and duplicate top-level `logLevel` rejection; existing JSON/YAML/TOML `set_key` tests remain in same suite.

Direct CLI smoke on copied fixture:

```bash
# steering-override: ztk-for-noisy-file-output — exact CLI smoke evidence
tmp=$(mktemp -d); cp bench/fixtures-llm/config.ts "$tmp/config.ts"; printf '%s' '{"version":1,"file":"'$tmp'/config.ts","operation":"set_key","edit":{"key":"logLevel","value":"debug"}}' | ./zig-out/bin/blitz apply --edit - --json; echo '---'; cat "$tmp/config.ts"; rm -rf "$tmp"
```

Result: exit 0, `routeReasonCode:"format_text_typescript_set_key"`, `language:"typescript"`, `parseBeforeClean:true`, `parseAfterClean:true`; copied file changed only `logLevel: "info"` to `logLevel: "debug"`.

Router guidance update:
- `bench/pi-matrix.ts` now gives `config/key-update` an executable router instruction only for this fixture: `pi_blitz_route_edit` args with compact script `sk\tlogLevel\tdebug`.
- First attempt using `sk\tlogLevel\t"debug"` is preserved as failed artifact because it produced `logLevel: "\\"debug\\""` and correctness 0%.

New preserved artifacts:
- Failed quoted-value router attempt: `reports/pi-tmux-phase7-config-router-sk-20260609-d5.md`, `reports/pi-tmux-phase7-config-router-sk-20260609-d5.json`, run root `reports/pi-tmux-runs/2026-06-09T15-54-26-384Z`, accounting root `reports/pi-accounting-runs/2026-06-09T15-54-26-384Z`.
- Accepted unquoted-value router attempt: `reports/pi-tmux-phase7-config-router-sk2-20260609-d5.md`, `reports/pi-tmux-phase7-config-router-sk2-20260609-d5.json`, run root `reports/pi-tmux-runs/2026-06-09T15-55-07-265Z`, accounting root `reports/pi-accounting-runs/2026-06-09T15-55-07-265Z`, tmux session `pi-bench-2026-06-09T15-55-07-265Z`.

Accepted config router result:
- `config/key-update` router: correctness 100%, exit 0, tool observed `pi_blitz_route_edit`, arg tok 67, result payload tok 24, Tokscale token match yes, total context tok 10435, wall 13882ms.
- Existing core baseline `reports/pi-tmux-phase7-config-core-20260609-d5.md`: correctness 100%, exit 0, tool observed `edit`, arg tok 73, result payload tok 3, Tokscale token match yes, total context tok 8263, wall 10115ms.
- Conclusion for this case only: blocker removed and router row accepted; no savings claim because router total context exceeded core baseline by 2172 tokens in this run.

Verification after implementation:

```bash
zig build && zig build test
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
```

Both passed before benchmark/report update; final full gate recorded in task handoff.

## D5 continuation: JSON/YAML/TOML format config `sk` unblock

Implementation:
- `src/apply/mod.zig` keeps JSON top-level `set_key` behavior intact.
- YAML/TOML now allow deterministic explicit one-level dotted keys only for existing mapping/table values: `app.debug` updates `app:` child key in YAML and `[app]` table key in TOML.
- Scope is fail-closed: no fuzzy nested search, no multi-level dotted paths, no insertion for dotted YAML/TOML keys, duplicate child keys reject before write, parse clean before/after.
- Focused tests added for YAML one-level mapping update + duplicate child no-mutation, and TOML table key update + duplicate child no-mutation.

Direct CLI smoke on copied fixtures:

```bash
# copies bench/fixtures-llm/config.{json,yaml,toml}
# JSON request: key debug, value true
# YAML request: key app.debug, value true
# TOML request: key app.debug, value true
```

Result: all exit 0 with `routeReasonCode` `format_text_json_set_key`, `format_text_yaml_set_key`, `format_text_toml_set_key`; copied files changed only expected `debug: false` / `debug = false` / `"debug": false` value to boolean true.

Router guidance update:
- `bench/pi-matrix.ts` now gives exact compact router syntax for proven rows:
  - JSON: `sk\tdebug\ttrue` (compact parser turns `true` into boolean true)
  - YAML: `sk\tapp.debug\ttrue`
  - TOML: `sk\tapp.debug\ttrue`

New preserved artifacts:
- Router Markdown report: `reports/pi-tmux-phase7-format-config-router-sk-20260609-d5.md`
- Router JSON report: `reports/pi-tmux-phase7-format-config-router-sk-20260609-d5.json`
- Router raw tmux run root: `reports/pi-tmux-runs/2026-06-09T16-09-39-628Z`
- Router accounting artifacts: `reports/pi-accounting-runs/2026-06-09T16-09-39-628Z`
- Router tmux session: `pi-bench-2026-06-09T16-09-39-628Z`
- Core Markdown report: `reports/pi-tmux-phase7-format-config-core-20260609-d5.md`
- Core JSON report: `reports/pi-tmux-phase7-format-config-core-20260609-d5.json`
- Core raw tmux run root: `reports/pi-tmux-runs/2026-06-09T16-10-58-044Z`
- Core accounting artifacts: `reports/pi-accounting-runs/2026-06-09T16-10-58-044Z`
- Core tmux session: `pi-bench-2026-06-09T16-10-58-044Z`

Accepted format-config router results:

| Case | Router result | Core baseline | Status vs core |
|---|---|---|---|
| `json/config-key` | correct 100%, exit 0, tool `pi_blitz_route_edit`, arg tok 66, result payload tok 26, total context tok 10447, Tokscale match yes | correct 100%, exit 0, tool `edit`, arg tok 70, result payload tok 51, total context tok 8484, Tokscale match yes | accepted executable row; rejected savings (router +1963 tok) |
| `yaml/config-key` | correct 100%, exit 0, tool `pi_blitz_route_edit`, arg tok 68, result payload tok 27, total context tok 10484, Tokscale match yes | correct 100%, exit 0, tool `edit`, arg tok 67, result payload tok 98, total context tok 8696, Tokscale match yes | accepted executable row; rejected savings (router +1788 tok) |
| `toml/config-key` | correct 100%, exit 0, tool `pi_blitz_route_edit`, arg tok 70, result payload tok 31, total context tok 10485, Tokscale match yes | correct 100%, exit 0, tool `edit`, arg tok 67, result payload tok 8, total context tok 8329, Tokscale match yes | accepted executable row; rejected savings (router +2156 tok) |

Conclusion for this fixture group: JSON/YAML/TOML `config-key` compact router rows are executable and accepted for correctness, but none beat/tie core on paired total context. No token savings claim.

## Acceptance

Phase7 acceptance: **NO**.

Reasons:
1. Full explicit 12-case fixture set is now represented in harness/report, but accepted tmux/Tokscale router rows remain missing.
2. Parser-fix rerun provides one accepted semantic router smoke (correctness 100%, exit 0, intended tool observed, Tokscale match `yes`), but this covers only one required case and no paired core/apply_patch/current Blitz comparison.
3. Earlier pilot failures remain preserved: one timeout/incorrect row; one correct file with exit `143` and no parsed tool before parser fix.
4. apply_patch/core baseline remains unavailable in harness; only explicit no-write declines are honest.
5. Companion pi-blitz terminal-decline fix `2dfcf73` did not make unsupported router fallback acceptable: rerun still timed out/incorrect.
6. `config/key-update` blocker is removed and the unquoted `sk` router row is accepted for this case, but router total context exceeded the accepted core baseline by 2172 tokens in this run, so it is not savings evidence.
7. JSON/YAML/TOML `config-key` compact router rows are accepted/correct, but all three exceed paired core total context in this run, so they are not savings evidence.
8. No token savings counted: full 12-case paired acceptance gates are not met.

## Next precise work

1. `config/key-update` real compact route now exists and one router row is accepted, but this single case did not beat core baseline on total context.
2. Preserve the failed terminal-decline and quoted-value router artifacts; they document why `sk\tlogLevel\tdebug` is the accepted syntax for this fixture.
3. Extend real compact aliases or genuine fallback lanes for logging/markdown/json/yaml/toml/html/css before claiming 12-case Phase 7 acceptance.
4. Add real apply_patch/core lane only if parent wants baseline comparison; do not fake via router declines.
5. Full Phase 7 still requires paired core/current Blitz/optimized router evidence across all required cases plus structural savings preservation.

## Token claim caveat

No token savings accepted or counted from Phase 7. Only resident overhead reduction evidence from serialized schema/skill artifacts is valid.


## D5 text-anchor compact alias continuation (2026-06-09)

Scope: `small/wrap-tail`, `logging/insert-timer`, `long-section/replace-return`, `rename/function-name`, `markdown/append-section`, `css/small-edit`, `html/small-edit`.

Direct Blitz CLI smokes on copied fixtures:
- `small/wrap-tail`: `replace_unique` exact return line passed; output matched golden.
- `logging/insert-timer`: `insert_after_anchor` exact `console.log` anchor + newline timer text passed; output matched golden.
- `long-section/replace-return`: `replace_unique` exact return line applied; CLI output matched intended file content for fixture goal.
- `rename/function-name`: `replace_unique` declaration prefix passed; output matched golden.
- `markdown/append-section`: `insert_after_anchor` after `<!-- append-target -->` is newline-sensitive. First smoke with leading/trailing blank drifted; exact golden needs text `\n## Configuration Reference\n\nSee the \`blitz --help\` command.` with no trailing inserted newline.
- `css/small-edit`: `replace_unique` exact background line passed; output matched golden.
- `html/small-edit`: `replace_unique` exact title line passed; output matched golden.

Harness update:
- Added fixture-specific router guidance for exact compact alias scripts only: `ru` for small/long/rename/css/html and `ia` for logging/markdown.
- No Zig changes in this slice.

New router artifacts:
- `reports/pi-tmux-phase7-text-alias-router-20260609-d5.md`
- `reports/pi-tmux-phase7-text-alias-router-20260609-d5.json`
- raw run root `reports/pi-tmux-runs/2026-06-09T16-21-17-777Z`
- accounting `reports/pi-accounting-runs/2026-06-09T16-21-17-777Z`
- tmux session `pi-bench-2026-06-09T16-21-17-777Z`

Paired core artifacts for accepted router rows:
- `reports/pi-tmux-phase7-text-alias-core-20260609-d5.md`
- `reports/pi-tmux-phase7-text-alias-core-20260609-d5.json`
- raw run root `reports/pi-tmux-runs/2026-06-09T16-29-01-030Z`
- accounting `reports/pi-accounting-runs/2026-06-09T16-29-01-030Z`
- tmux session `pi-bench-2026-06-09T16-29-01-030Z`

Accepted/rejected rows:

| Fixture | Compact route | Router status | Core status | Router total context | Core total context | Result |
|---|---|---|---|---:|---:|---|
| `small/wrap-tail` | `ru` exact return line | accepted: 100%, exit 0, `pi_blitz_route_edit`, Tokscale match yes | accepted: 100%, exit 0, `edit`, Tokscale match yes | 15,704 | 8,411 | router loses; no savings |
| `logging/insert-timer` | `ia` exact console.log anchor | rejected: 0%, exit 0, `pi_blitz_route_edit`, Tokscale match yes; newline drift after repeated declines | not run in paired slice because router not accepted | 53,690 | n/a | blocker |
| `long-section/replace-return` | `ru` exact return line | rejected: 0%, exit 0, `pi_blitz_route_edit`, Tokscale match yes | not run in paired slice because router not accepted | 30,078 | n/a | blocker |
| `rename/function-name` | `ru` declaration prefix | accepted: 100%, exit 0, `pi_blitz_route_edit`, Tokscale match yes | accepted: 100%, exit 0, `edit`, Tokscale match yes | 10,527 | 8,548 | router loses; no savings |
| `markdown/append-section` | `ia` marker anchor | rejected: 0%, exit 0, `pi_blitz_route_edit`, Tokscale match yes; lost required newline after marker | not run in paired slice because router not accepted | 52,437 | n/a | blocker |
| `css/small-edit` | `ru` exact background line | accepted: 100%, exit 0, `pi_blitz_route_edit`, Tokscale match yes | accepted: 100%, exit 0, `edit`, Tokscale match yes | 27,196 | 8,478 | router loses; no savings |
| `html/small-edit` | `ru` exact title line | accepted: 100%, exit 0, `pi_blitz_route_edit`, Tokscale match yes | accepted: 100%, exit 0, `edit`, Tokscale match yes | 10,571 | 8,492 | router loses; no savings |

Phase 7 acceptance remains **NO**:
- only 4/7 rows in this narrow text-anchor group accepted through router;
- accepted router rows lose to paired core total context;
- `ia` alias rows show newline/tuple handling blockers in real Pi router runs;
- previous config rows also remain no-savings vs core;
- no broad Phase 7 START/PLAN gate is fully proved.

## Escape-fix text-anchor rerun (2026-06-09 D5)

Date: 2026-06-09

Companion pi-blitz fix used read-only: `/home/kenzo/dev/pi-blitz` pushed commit `28085fa fix(router): decode compact script escapes`; Blitz harness extension path `/home/kenzo/dev/pi-blitz/dist/index.js`. Existing artifacts preserved; new report names used.

## Commands

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case small/wrap-tail,logging/insert-timer,long-section/replace-return,rename/function-name,markdown/append-section,css/small-edit,html/small-edit --lane router --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.json
```

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case small/wrap-tail,logging/insert-timer,long-section/replace-return,rename/function-name,markdown/append-section,css/small-edit,html/small-edit --lane core --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json
```

```bash
bun bench/pi-matrix.ts --runner tmux --provider zai --model glm-4.5-air --case markdown/append-section --lane core --tool-profile router --artifact-profiles router,full --iters 1 --timeout-ms 180000 --tokscale --md-out reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.md --json-out reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.json
```

## Artifacts

- Router report: `reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.{md,json}`
- Router run root: `reports/pi-tmux-runs/2026-06-09T16-43-10-050Z`
- Router accounting root: `reports/pi-accounting-runs/2026-06-09T16-43-10-050Z`
- Router tmux session: `pi-bench-2026-06-09T16-43-10-050Z`
- Core all-7 report: `reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.{md,json}`
- Core all-7 run root: `reports/pi-tmux-runs/2026-06-09T16-48-30-368Z`
- Core all-7 accounting root: `reports/pi-accounting-runs/2026-06-09T16-48-30-368Z`
- Core all-7 tmux session: `pi-bench-2026-06-09T16-48-30-368Z`
- Core markdown retry report: `reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.{md,json}`
- Core markdown retry run root: `reports/pi-tmux-runs/2026-06-09T16-50-36-081Z`
- Core markdown retry accounting root: `reports/pi-accounting-runs/2026-06-09T16-50-36-081Z`
- Core markdown retry tmux session: `pi-bench-2026-06-09T16-50-36-081Z`

## Row summary

Accepted router rows require correctness 100%, exit 0, no timeout, Tokscale match yes, intended tool `pi_blitz_route_edit`, and artifacts present. Accepted pairwise savings rows also require accepted paired core evidence.

| Fixture | Router status | Router total context | Paired core status | Core total context | Delta router-core | Savings status |
|---|---:|---:|---:|---:|---:|---|
| `small/wrap-tail` | accepted | 10,554 | accepted | 8,574 | +1,980 | no savings; router loses |
| `logging/insert-timer` | rejected; correctness 0% | 47,314 | accepted | 8,785 | +38,529 | excluded |
| `long-section/replace-return` | rejected; correctness 0% | 11,238 | rejected | 9,164 | +2,074 | excluded |
| `rename/function-name` | accepted | 10,515 | accepted | 8,598 | +1,917 | no savings; router loses |
| `markdown/append-section` | accepted | 10,556 | rejected in all-7 core and retry core | 8,849 / 13,779 | +1,707 / -3,223 | excluded; no accepted paired core row |
| `css/small-edit` | accepted | 10,466 | accepted | 8,559 | +1,907 | no savings; router loses |
| `html/small-edit` | accepted | 142,615 | accepted | 8,336 | +134,279 | no savings; router loses badly |

## Phase 7 status

Escape fix improved router correctness vs prior 4/7 to 5/7 accepted router rows (`small/wrap-tail`, `rename/function-name`, `markdown/append-section`, `css/small-edit`, `html/small-edit`). `logging/insert-timer` and `long-section/replace-return` still fail correctness. Of rows with accepted router and accepted core pairs, router loses total context in 4/4. `markdown/append-section` has accepted router evidence but no accepted core baseline after two new core attempts, so excluded from savings. Phase 7 acceptance remains **NO**. No router replacement/core-intercept claim; `pi_blitz_route_edit` remains runtime facade and unsupported fallback remains no-write decline.

## 2026-06-09 route-selected synthesis

D5 added benchmark-only route-selected proof artifacts from existing real tmux/Tokscale Phase 7 rows:

- Script: `bench/phase7-route-selected-synthesis.ts`
- Markdown: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.md`
- JSON: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json`
- Subagent summary: `reports/subagents/d5-phase7-route-selected-synthesis.md`

Selection rule: accepted rows only (`correctRate === 1`, Tokscale token match yes, no timeout, exit 0 when present), then lowest `totalContextTokens` per fixture. Core-selected rows are benchmark-level route selections from existing core evidence only; no claim that `pi_blitz_route_edit` invokes core/apply_patch.

Result: selected route chooses core for tiny text, config, logging, rename, JSON/YAML/TOML, CSS, and HTML where accepted core is cheaper. Router remains selected for semantic and Markdown only where accepted core baselines are absent. Phase 7/START remains incomplete due missing structural/current Blitz/apply_patch/TSX evidence and unproven runtime fallback.

## 2026-06-09 structural + semantic evidence slice

New real Pi tmux/Tokscale rows added under new report names. Old artifacts preserved.

Artifacts:
- Structural core: `reports/pi-tmux-phase7-structural-core-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-20-14-699Z`; tmux `pi-bench-2026-06-09T17-20-14-699Z`.
- Structural current Blitz/full profile: `reports/pi-tmux-phase7-structural-current-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-11-08-935Z`; tmux `pi-bench-2026-06-09T17-11-08-935Z`.
- Structural router/profile: `reports/pi-tmux-phase7-structural-router-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-13-32-066Z`; tmux `pi-bench-2026-06-09T17-13-32-066Z`.
- Semantic core: `reports/pi-tmux-phase7-semantic-core-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-18-18-155Z`; tmux `pi-bench-2026-06-09T17-18-18-155Z`.
- Semantic router: `reports/pi-tmux-phase7-semantic-router-20260609-d5.{md,json}`; run root `reports/pi-tmux-runs/2026-06-09T17-19-12-655Z`; tmux `pi-bench-2026-06-09T17-19-12-655Z`.

Rows:

| Case | Lane/tool | Correct | Exit | Timed out | Tokscale match | Total context | Accept |
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

Result:
- Semantic missing slice improved: arrow now has paired accepted current core/router evidence; TSX now has accepted core/router evidence. Benchmark route selects router for arrow and core for TSX.
- Structural preservation still not fully proven: `multi/large-structural` has accepted current Blitz row, but no accepted core baseline; `medium-10k/wrap-body` remains rejected across core/current/router attempts.
- Structural savings still not proven for Phase 7 current matrix because required wrap-body row remains red and multi lacks paired accepted baseline.
- Route selection remains benchmark-only. `pi_blitz_route_edit` still does not invoke product-real core/apply_patch.
- Phase 7 status remains **NO**.


## 2026-06-10 D5 wrap/long/apply_patch follow-up

Detailed report: `reports/subagents/d5-phase7-wrap-long-applypatch-20260610.md`.

- `medium-10k/wrap-body` root cause isolated to model/wrapper passing literal `\n` in `before`, which made Blitz `wrap_body` generate invalid TS and reject. Narrow Blitz fix in `src/apply/mod.zig` normalizes `\n` in `wrap_body` `before`/`after`. Accepted rerun: `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.{md,json}`, run root `reports/pi-tmux-runs/2026-06-10T05-39-20-199Z`, correctness 100%, Tokscale match yes, total context 30,087.
- `long-section/replace-return` root cause isolated to harness expected-file bug: JS replacement string treated `$$` specially and expected omitted `$` before interpolation. Fixed with replacement callback in `bench/pi-matrix.ts`. Accepted core rerun: `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.{md,json}` at 9,769 context. Accepted router rerun: `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.{md,json}` at 11,122 context. Synthesis chooses core.
- apply_patch-style baseline remains unavailable in current Pi/tmux harness: lanes are `core`/`blitz`/`router`; core exposes built-in `edit` find/replace only; no OpenAI-native `apply_patch` or distinct patch tool is honestly exposed as a Pi benchmark lane.
- Phase 7 remains NO: structural current rows now pass for wrap-body and multi/large-structural, but no accepted core/apply_patch baseline exists for either; router remains benchmark/runtime facade, not product-real core/apply_patch fallback.
