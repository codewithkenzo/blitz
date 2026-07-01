# Research: Post-0.4 plan for token-context replacement of Pi edit

## Question
How should the codebase proceed to make `@codewithkenzo/pi-blitz` the default-cheaper Pi edit path (token/context-first), while preserving explicit route telemetry, no hidden fallback behavior, and benchmark proof quality?

## Answer / recommendation (high-level)
Keep the scope where it already has hard infrastructure:
1. **Freeze routing semantics first** (explicit decline semantics already exist): use `pi_blitz_route_edit` as a strict gate that never silently falls back internally.
2. **Use one evidence loop for acceptance** (bench + tokscale + artifacts): route/profile variants must be judged in the same pipeline that already computes resident/token overhead and residuals.
3. **Avoid claiming default-replacement status until streak + pairwise proof is done** with Pi core as baseline/fallback, in the exact order requested by the 0.4 goal.

## Findings (claim-audit)

### Claim 1 — Tool profile surfaces are already implemented, selectable, and test-covered.
- `/home/kenzo/dev/pi-blitz/src/tool-profiles.ts` maps `PI_BLITZ_TOOL_PROFILE` to explicit tool sets, including `minimal`, `router`, `semantic`, `structural`, `admin`, `full`, and validates unknown values.
- `index.ts` reads `PI_BLITZ_TOOL_PROFILE` and registers only selected tools, defaulting to profile resolution default `minimal` when env is unset.
- `/home/kenzo/dev/pi-blitz/test/tool-profiles.test.ts` explicitly asserts profile outputs (e.g., minimal registers only `blitz_edit`, router only `pi_blitz_route_edit`, structural/full/admin sets).

### Claim 2 — No hidden fallback is already encoded in the route tool.
- `/home/kenzo/dev/pi-blitz/src/tools.ts` builds route decisions from fixed token estimates and explicit `selectedBecause` reasons; if route is unsupported/declined it calls `routeDeclineResult` with `{status:"declined", terminal:true, noWrite:true, actionRequired:"use_external_core_or_apply_patch"}`.
- `routeDeclineResult` always returns a no-write terminal error path; selected reason strings include **"no internal core/apply_patch fallback"**.
- Route tests in `/home/kenzo/dev/pi-blitz/test/apply-runtime.test.ts` confirm that unsupported snippets/aliases/ambiguous payloads result in no-spawn calls and content containing `pi-blitz route declined` with `selected === "apply_patch"`.

### Claim 3 — Compact/compact-ish edit semantics and tiny success contracts already exist in CLI layer.
- `/home/kenzo/dev/blitz/src/apply/ir.zig` already parses compact JSON IR (`v`, `f`, `ops`) with compact op aliases (`rb`/`replace_body`, `ia`/`insert_after_symbol`, `mn` alias support) and validates malformed aliases/targets with fail-closed behavior.
- `/home/kenzo/dev/blitz/src/apply/mod.zig` emits compact JSON success output in JSON mode (`ok c=1`) for compact requests.
- `mod.zig` also defines route metadata (`routeDecision`) and route fields that match the benchmark-facing `contextSavingsPct/schemaTokensExpected/...` contract.

### Claim 4 — Benchmark infrastructure for token/context accounting is already wired for source-backed claims.
- `/home/kenzo/dev/blitz/bench/pi-matrix.ts` persists artifact profiles, captures token fields (tool-spec, skill, prompt, args, output, cache, result payload), computes residuals and total context, and includes pairwise compare logic that only counts savings when core is not better.
- `/home/kenzo/dev/blitz/bench/pi-matrix.ts` also runs tokscale when enabled and enforces parser-match checks (`matchesParser`), with required mode handling for mode=`required`.
- `/home/kenzo/dev/blitz/bench/natural-edit.ts` defines an explicit route outcome taxonomy and classification rule: **do not infer fallback as blitz**; includes route probe parsing that labels decline/fallback/no-write.

### Claim 5 — External tool-call token policy aligns with the plan’s direction.
- OpenAI function-calling docs confirm tool schemas are injected as input context and can dominate token budget; `tool_search` and `defer_loading` are first-class mitigations for large surfaces.
- OpenAI custom tools support plain-text input and optional CFG (`grammar`) for compact DSL-style tooling, which supports the planned `pi_blitz_op` experiment if provider path supports it.
- Anthropic MCP analysis confirms large MCP/tool surfaces increase context and advocate progressive loading/composition patterns (tool discovery/filtering, stable narrow interfaces).

### Claim 6 — Some token-accounting artifacts are still incomplete in selected historical runs.
- `reports/pi-tmux-true-streak-blitz-edit-summary-20260611.md` flags `schemaTokens=0` in that run because Pi session JSONL lacked resident schema exposure, with schema dump noted as external side-channel. This is an evidence gap for those older runs; it should be closed for final proof.

## Source notes
### Kept
- Repo source files and tests: `pi-blitz/src/tool-profiles.ts`, `pi-blitz/index.ts`, `pi-blitz/src/tools.ts`, `pi-blitz/test/tool-profiles.test.ts`, `pi-blitz/test/apply-runtime.test.ts`.
- Blitz CLI/benchmark source: `blitz/src/apply/ir.zig`, `blitz/src/apply/mod.zig`, `blitz/bench/pi-matrix.ts`, `blitz/bench/natural-edit.ts`, `blitz/scripts/dump-tool-specs.ts`, `blitz/bench/AGENTS.md`, `blitz/.github/workflows/ci.yml`.
- Official docs used for strategy context: OpenAI function-calling/tool-search/custom tool pages and Anthropic code-execution-with-MCP page (fetched via `fetch_content`).

### Dropped
- Older narrative benchmark claims that cannot be reconciled with full current artifact set in one place were used only as directional context, not as acceptance evidence.

### Quality
- High confidence for internal repo behavior (tests + direct code).
- Medium-high confidence for external provider behavior (official docs fetched from maintainers).
- Moderate caution on older reports with mixed methodology and missing schema-token capture.

## Version / date notes
- Primary baseline files are post-`0.4` scoped (`docs/plans/PLAN-0.4-context-token-optimization.md`, `docs/plans/START-0.4-context-token-core.md`, `docs/blitz.md:1.0.1 token-first doctrine`, `2026-06-18`).
- `web_search` via `web_search` lane failed due Exa credit exhaustion (`402`), so web discovery fallback used was `fetch_content` directly on primary docs.

## Open questions
1. Should OpenAI-only experiments (`tool_search`, `custom + grammar`) be implementation-gated by model/runtime capability, or should router/profile mode remain uniform across providers with a fallback path?
2. What exact profile should be considered “default” for production in the next slice (`minimal-v0` via `blitz_edit` vs `pi_blitz_op`) without conflating product claims?
3. Which benchmark slice is the definitive “replacement gate”: strict isolated-class rows + true-streak rows + pairwise rows, and what minimum acceptance threshold per row class is required?
4. Can all benchmark report rows in future runs populate `schemaTokens + skillTokens` directly from PI session artifacts (no side-channel-only schema accounting)?

## Builder-ready implications

### Immediate implementation slice (recommended)
- **pi-blitz (wrapper layer):**
  - Keep existing profile + route behavior intact while auditing/locking no-hidden-fallback invariants.
  - Ensure CI/validation keeps route decline reason strings stable and covered.
  - Verify `PI_BLITZ_TOOL_PROFILE` behavior and minimal-v0 serialization artifacts in `bench`-backed test paths.

- **blitz (CLI layer):**
  - Retain existing compact IR path; harden edge-cases around object/tuple parse + same-file batching in `src/apply/ir.zig` and `src/apply/mod.zig`.
  - Keep compact output/tiny route fields machine-parseable and low verbosity.

- **Benchmark/research layer:**
  - Re-run paired core/blitz/route matrices for required classes with tokscale required and artifact preservation.
  - Enforce route taxonomy rules so `decline/no-write` is never counted as blitz success.
  - Close any schema-token capture gaps by ensuring each row carries explicit serialized tool-spec + skill snapshot data.

### Suggested commands before any token claim
- `/home/kenzo/dev/pi-blitz`: `bun test`
- `/home/kenzo/dev/blitz`: `zig build` and `zig build test`
- `/home/kenzo/dev/blitz`: `bun bench/run.ts` (CI parity)
- `/home/kenzo/dev/blitz`: `bun bench/pi-matrix.ts --tokscale` (or equivalent locked mode)

### What to declare as done for this phase
- Route/fallback contract remains explicit and no-write on unsupported/ambiguous decisions.
- Profile slices show measurable reduction in resident tax where intended.
- Replacement-gate rows include tokscale match, raw artifacts, and failure modes preserved.

## Final recommendation
The most important path to post-0.4 progress is **not new feature surface area**, but **tightening evidence and explicit route-first behavior** already present. Treat router and accounting as the product contract, and only claim default replacement after class-coverage criteria (tiny, mixed, streak) show correct behavior and non-regression against Pi core edit with full token-context accounting.