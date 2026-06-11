# Universal Blitz blind-spot audit — 2026-06-11

Scope: `reports/REPLACEMENT-GATE-20260611.md`, `reports/REPLACEMENT-GATE-LOCK-20260611.json`, `reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md`, current `bench/true-streak.ts`, and companion `/home/kenzo/dev/pi-blitz` schema/profile/runtime files.

## Verdict

**Block universal/exodia claim.** Current evidence is a useful scripted regression gate for `blitz_edit`, not proof that default edit route is universally better than core-only `edit`.

Scripted Zai + GPT-5.4-mini rows are good capability evidence for exact precomputed tuples. They do not yet prove natural tool choice, fair core baseline, provider portability, fallback accounting, or atomic route behavior.

## Spec Compliance

- Universal spec says route system must use Blitz only when safe/cheaper and explicitly decline/fallback otherwise (`specs/20260611-universal-blitz-edit-exodia-spec.md:8-15`). Current locked rows prove no hidden core fallback for accepted Blitz rows, but do not test default route fallback/decline.
- Spec requires Tokscale token match recorded for accepted rows (`specs/20260611-universal-blitz-edit-exodia-spec.md:52-60`). Current reports record Tokscale exit/status, not a token-match boolean or mismatch details.
- Spec requires GPT-5.5 low/reasoning-low as mandatory if auth/model works (`specs/20260611-universal-blitz-edit-exodia-spec.md:62-75`). Evidence covers Zai + GPT-5.4-mini only.
- Spec requires natural unscripted prompts, not exact JSON/tool-call instructions (`specs/20260611-universal-blitz-edit-exodia-spec.md:92-113`). Current gate is explicitly exact-JSON scripted.
- Spec requires adversarial safety rows (`specs/20260611-universal-blitz-edit-exodia-spec.md:115-133`). Current accepted matrix lacks no-op, ambiguous/multi-match natural prompts, generated/minified, unsupported refactor, conflicting-span rows.
- Spec requires default visible schemas avoid tuple-form `items: [schema...]` (`specs/20260611-universal-blitz-edit-exodia-spec.md:137-141`). Current source does; locked profile dump does not.
- Spec requires all ops fail-closed and atomic (`specs/20260611-universal-blitz-edit-exodia-spec.md:180-195`). CLI compact batch has tests, but product `blitz_edit` applies jobs sequentially after preview.

## Findings

### P0 — Locked profile dump is stale and OpenAI-incompatible

- `reports/REPLACEMENT-GATE-LOCK-20260611.json:4-10` locks `/home/kenzo/dev/pi-blitz/reports/profile-dumps/minimal-blitz-edit-20260611.json` hash as product profile evidence.
- `/home/kenzo/dev/pi-blitz/reports/profile-dumps/minimal-blitz-edit-20260611.json:21-47` still uses tuple-array schema (`items: [...]`) for `x` tuples.
- `reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md:11-17` says OpenAI rejected that schema shape and schema fix commit `21ed3f3` made it pass.
- `/home/kenzo/dev/pi-blitz/src/tools.ts:174-184` now uses homogeneous array item schema, so current source no longer matches locked dump.

Impact: Zai replacement lock and GPT-5.4-mini pass are not tied to one current visible-schema artifact. Universal gate cannot use this lock as provider-compatible proof.

Fix direction: regenerate profile dump after `21ed3f3`/`4d2528e`, update lock hash, include provider-specific schema acceptance evidence, and make GPT-5.4-mini rows part of same lock format.

### P0 — Benchmark prompts are scripted exact JSON, not natural route proof

- `bench/true-streak.ts:463-509` builds Blitz prompts that say: “Call blitz_edit exactly once with this exact JSON”.
- `bench/true-streak.ts:521-528` builds core/router prompts that say to call exact JSON per step.
- `reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md:39-41` correctly caveats that GPT-5.4-mini proof is scripted, not universal.

Impact: evidence proves model can copy precomputed tool args and runtime can execute them. It does not prove agents can infer `x`/`rb`/`ia`, choose Blitz over core, or decline unsupported natural requests.

Fix direction: add natural unscripted gate where prompt is normal user intent plus file context, model chooses default route, and reports separate tool-choice failures from runtime failures.

### P0 — Core baseline is pessimized for same-file and structural rows

- Blitz lane computes changed spans and passes compact tuples (`bench/true-streak.ts:498-504`), then one exact `blitz_edit` call (`bench/true-streak.ts:505-509`).
- Core lane is forced to use full `step.before`/`step.after` in exact JSON per step (`bench/true-streak.ts:521-524`).
- Same-file core lock shows three separate full-file edit calls (`reports/REPLACEMENT-GATE-LOCK-20260611.json:921-936`), while Blitz uses one compact call (`reports/REPLACEMENT-GATE-LOCK-20260611.json:992-1003`).

Impact: same-file/multi/class rows partly measure “bad scripted core args vs optimized precomputed Blitz args,” not default route superiority. Token deltas are inflated until core gets smallest valid old/new spans and same-file batched `edits` where supported.

Fix direction: add optimized-core baseline using minimal old/new spans, same-file multi-edit batching, and natural core-only prompt; keep current scripted gate only as regression guard.

### P1 — Tokscale status is recorded, token match is not

- `bench/true-streak.ts:759-761` only checks Tokscale process status.
- `bench/true-streak.ts:762-783` records parser totals but never compares them to Tokscale `totalInput`, `totalOutput`, cache, or message count.
- Accepted report says `Tokscale: required (exit 0)` (`reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-span.md:1-14`), but no “token match: yes/no” field appears.

Impact: accounting can drift while reports stay green. Spec requires token match summary, not just Tokscale command success.

Fix direction: compute and store per-row `tokscaleTokenMatch`, deltas, message-count match, and fail accepted rows on mismatch.

### P1 — Resident skill/schema accounting is incomplete and misleading

- Blitz-edit commands include `--skill /home/kenzo/dev/pi-blitz/skills/pi-blitz` (`bench/true-streak.ts:565-575`).
- Harness counts skill text only for `lane === "router"` (`bench/true-streak.ts:755-758`).
- Harness hardcodes `schemaTokens: 0` (`bench/true-streak.ts:762-764`).
- Accepted reports show `schema=0` and `skill=0` for Blitz rows (`reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-span.md:10-14`).

Impact: total context likely includes provider input/cache, but category breakdown is wrong. This weakens overhead attribution and makes provider residuals harder to explain, especially GPT-5.4-mini tiny where residual input is high (`reports/pi-tmux-true-streak-gpt54mini-tiny-10-blitz-edit-20260611-schemafix.md:10-14`).

Fix direction: count current skill for blitz-edit, tokenize serialized visible tool schema, record both separately, and reconcile residual input after prompt+skill+schema.

### P1 — Per-row provenance hides extension/skill path for Blitz rows

- `bench/true-streak.ts:799-800` writes `extension: null` and `skill: null` unless lane is `router`.
- Command actually uses extension and skill for Blitz-edit (`bench/true-streak.ts:565-575`; example command in `reports/pi-tmux-runs/true-streak-2026-06-11T20-22-38-146Z/command.sh:1-9`).

Impact: raw command files preserve truth, but JSON report/lock fields hide exact extension/skill provenance for accepted product rows. Auditors must chase command files.

Fix direction: always record extension path, skill path, `PI_BLITZ_TOOL_PROFILE`, pi-blitz git commit, Blitz git commit, and profile dump hash in every row.

### P1 — `blitz_edit` product route is sequential, not atomic across jobs

- `blitz_edit` previews every job (`/home/kenzo/dev/pi-blitz/src/tools.ts:1892-1899`) and then applies each job one at a time (`/home/kenzo/dev/pi-blitz/src/tools.ts:1901-1907`).
- It returns one compact success after all sequential calls (`/home/kenzo/dev/pi-blitz/src/tools.ts:1908`).
- Universal spec says all ops must be atomic (`specs/20260611-universal-blitz-edit-exodia-spec.md:180-195`).

Impact: if a later apply fails after an earlier apply succeeds, product route can leave partial edits. Bench rows do not cover this because all accepted jobs are stable synthetic files.

Fix direction: group same-file jobs into one compact apply `ops` request, define multi-file atomicity boundary explicitly, and add tests/bench rows for second-op failure after first-op preview success.

### P1 — Current default route has no product fallback/decline behavior

- Minimal profile exposes only `blitz_edit` (`/home/kenzo/dev/pi-blitz/src/tool-profiles.ts:29-31`).
- Replacement lock states no accepted Blitz row counts core fallback (`reports/REPLACEMENT-GATE-20260611.md:74-88`). That is correct for scripted Blitz-success rows, but it is not route-system proof.
- Universal spec requires explicit fallback/decline accounting (`specs/20260611-universal-blitz-edit-exodia-spec.md:10-15`, `specs/20260611-universal-blitz-edit-exodia-spec.md:168-178`).

Impact: current evidence proves “always force Blitz tuples” for supported cases, not “default edit route chooses Blitz/core/decline correctly”.

Fix direction: make default route a product surface or profile, run route-system rows, and report Blitz-success vs explicit fallback totals separately.

### P2 — GPT-5.4-mini evidence lacks unified measurement lock

- Only `reports/REPLACEMENT-GATE-LOCK-20260611.json` exists as lock file; it covers Zai rows (`reports/REPLACEMENT-GATE-LOCK-20260611.json:35-36` shows `provider: zai` in locked row Tokscale stdout).
- GPT-5.4-mini report is summary-only Markdown (`reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md:19-37`) with per-row JSON files, but no combined lock/hash/profile artifact.

Impact: GPT pass is less audit-friendly than Zai lock and cannot be mechanically compared in one universal gate.

Fix direction: add `GPT54MINI-...LOCK.json` or one `UNIVERSAL-...LOCK.json` with rows keyed by provider/model/scenario.

### P2 — Provider matrix remains too narrow

- GPT-5.4-mini pass exists (`reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md:5-7`), but OpenAI schema rejection already proved provider behavior differs (`reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md:11-17`).
- Universal spec makes GPT-5.5 low/reasoning-low mandatory if auth/model works (`specs/20260611-universal-blitz-edit-exodia-spec.md:62-75`).

Impact: “universal” cannot rest on Zai + one OpenAI model, especially after schema compatibility already failed once.

Fix direction: run scripted regression on GPT-5.5 low first, then natural/adversarial gates on Zai + GPT-5.4-mini + GPT-5.5; add optional Anthropic/Gemini only after mandatory pass.

### P2 — Accepted classes omit several high-risk real edit categories

- Current accepted gate covers synthetic exact, insert, structural body, config/docs rows (`reports/REPLACEMENT-GATE-20260611.md:55-64`).
- Universal spec requires TSX/JSX, imports, rename/refactor, no-op, ambiguous/multi-match natural groups (`specs/20260611-universal-blitz-edit-exodia-spec.md:92-107`) and more ops like import insertion, config key update, rename, JSX, markdown, no-op detection (`specs/20260611-universal-blitz-edit-exodia-spec.md:180-193`).

Impact: route can still fail common coding-agent edits outside `x`/`rb`/`ia` while gate remains green.

Fix direction: expand scenario groups before any universal claim; require per-group aggregate/median/p75 plus correctness.

### P2 — Report prose overstates completion relative to current universal plan

- Replacement report says “Remaining work before goal completion: None” (`reports/REPLACEMENT-GATE-20260611.md:117-119`).
- Same report also says earlier text “does not claim full goal complete” (`reports/REPLACEMENT-GATE-20260611.md:3-6`), creating mixed signal.
- Universal plan/spec now correctly says current proof is scripted baseline and broader natural/adversarial coverage remains (`docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md:1-24`; `specs/20260611-universal-blitz-edit-exodia-spec.md:17-49`).

Impact: future readers may promote scripted gate to universal proof by accident.

Fix direction: mark replacement gate as “0.4 scripted replacement gate shipped”, not “universal complete”; keep 0.5 spec as active source for exodia/universal.

## Required Fixes

Before true universal/exodia gate:

1. Regenerate `minimal-blitz-edit-20260611.json` after OpenAI schema fix; update replacement/universal lock hashes.
2. Add Tokscale token-match verification, not only status 0.
3. Count resident skill + visible tool schema tokens for blitz-edit rows; stop reporting `skill=0` when `--skill` is passed.
4. Add fair optimized core baselines: minimal spans, same-file batched `edits`, natural core-only prompt.
5. Add natural unscripted gate where model chooses default route without exact JSON.
6. Add adversarial/no-op/ambiguous/generated/conflict rows.
7. Add provider matrix lock: Zai, GPT-5.4-mini, GPT-5.5 low if auth works.
8. Make route fallback/decline product-real and account route-system totals separately from Blitz primitive success.
9. Fix or document `blitz_edit` atomicity boundary; add partial-failure tests.

## Verification Gaps

- No fresh benchmark rerun performed for this audit; this is artifact/source review only.
- Current reports say `zig build`, `zig build test`, `bun run typecheck`, `bun test`, and `bun run build` passed (`reports/REPLACEMENT-GATE-20260611.md:27-46`), but this audit did not rerun them.
- `tk` unavailable in this repo: `tk list` reports no `.tickets` directory.
- Current working tree had untracked `docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md` before this audit; this report is another untracked artifact until staged/committed.
- pi-blitz local branch `feat/blitz-0.4-token-core-profile-canonical` tracks `origin/feat/blitz-0.4-token-core-profile` despite schema-fix commits living on canonical branch; branch provenance should be cleaned before final lock.

## Spec/TK/Memory Notes

- Active universal source: `specs/20260611-universal-blitz-edit-exodia-spec.md` plus `docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md`.
- No `tk` notes updated; repo has no `.tickets`.
- No memory updates needed; findings are report-local and may change after next lock.

## Anything Missed / Review Next

Review next after fixes:

1. New unified lock JSON with current schema dump and all providers.
2. Natural prompt suite implementation and raw prompts.
3. Fair-core baseline implementation.
4. Route fallback accounting, especially rows where Blitz declines.
5. Atomicity tests for `blitz_edit` multi-job failure.
6. GPT-5.5 low run and any Anthropic/Gemini schema failures.
