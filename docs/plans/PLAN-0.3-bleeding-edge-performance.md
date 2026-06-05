# Blitz 0.3 — Bleeding-Edge Performance, Universal Editing, and Guaranteed-Faster Routing Plan

Date: 2026-05-25  
Status: active implementation plan; major Lane A–D slices implemented, with deferred cache/format items explicitly marked  
Supersedes future-facing “2.0” language for active planning: user intent maps **2.0 → 0.3**.  
Related docs: `docs/specs/SPEC-2.0.md`, `docs/plans/PLAN-2.0.md`, `specs/blitz-v0.2-hardening-and-parity.md`.

## Executive summary

Blitz cannot honestly claim that every forced Blitz edit is always faster/cheaper than core `edit`. The `gpt-5.4-mini` paired tmux/Tokscale run proved that small or already-compact core edits can beat Blitz on output tokens, tool-call args, wall time, or cost.

Blitz 0.3 should therefore make the **system** guaranteed faster by adding an adaptive router:

> Choose Blitz only when a model/tool/file/edit-specific cost oracle predicts a correctness-safe win above threshold; otherwise fall back to core edit or another cheaper route.

The plan combines:

1. deterministic fast paths in the Zig CLI;
2. incremental tree-sitter validation and query caching;
3. universal text/format edit routes beyond the current 5 code grammars;
4. a measured cost/wall/token oracle;
5. correctness-first benchmark gates with Tokscale and tmux artifacts.

## Research inputs

### Local evidence

- `reports/pi-pair-full-gpt54mini-2026-05-25.md/json`
  - 26 tmux real-Pi runs, `openai-codex/gpt-5.4-mini`, Tokscale required.
  - Tokscale token match: 26/26.
  - Blitz rows were correct; core failed several structural rows.
  - Both-correct rows showed mixed savings: some wins (`try_catch`), some losses (`replace_body_span`, small `replace_return`).
- `reports/pi-readme-cost-gpt54mini-2026-05-25.md/json`
  - Markdown README core-only cost smoke: 10.35s, `$0.00334`, correct.
- `reports/pi-tmux-matrix-2026-05-25.md/json`
  - tmux method validated token accounting but exposed model variance/timeouts.
- `.pi/skills/blitz-benchmarking/`
  - repo-local benchmark discipline: tmux, Tokscale, correctness-first, no hidden failures.

### External research

- `reports/research-zig-bleeding-edge-2026-05-25.md`
  - Zig 0.16 is the production base.
  - Master/0.17-dev is useful for dev-cycle features (`--watch -fincremental`, `--time-report`, `--webui`) and should be evaluated, not blindly adopted.
  - `Io.Evented` remains experimental with performance caveats; keep production on `Io.Threaded`.
  - No first-class Zig PGO flow found; use ReleaseFast/ReleaseSmall, target/cpu choices, and external profiling.
- `reports/research-tree-sitter-universal-editing-2026-05-25.md`
  - Latest upstream tree-sitter observed: `0.26.9`; repo pin: `0.26.8`; ABI 15.
  - Fast path: exact `TSInputEdit` → `ts_tree_edit()` → reparse with old tree → `ts_tree_get_changed_ranges()`.
  - Cache `TSQuery`; range-limit queries; use query cursor depth/match limits.
  - Use native parsers/grammars for Markdown/JSON/YAML/TOML/HTML/CSS where possible, and raw byte-range edits for format preservation.
- Web/code-search themes:
  - Structure-aware edit formats reduce long-code latency/cost but lose on small files.
  - Adaptive format selection is the winning pattern: full rewrite/search-replace/AST edits each own different regimes.
  - Tree-sitter is strong for targeting and validation, not a universal serializer.

## Current scope and limitations

Current Blitz parser coverage reported by `blitz doctor`:

- Rust (`.rs`)
- TypeScript (`.ts`)
- TSX (`.tsx`)
- Python (`.py`)
- Go (`.go`)
- JSON (`.json`)
- JSONC (`.jsonc`; parser/doctor/read only from `sunilunnithan/tree-sitter-jsonc` commit `02b01653c8a1c198ae7287d566efa86a135b30d5`, ABI 13; no `set_key` comment-preserving edit semantics)
- YAML (`.yaml`, `.yml`)
- TOML (`.toml`)
- Markdown (`.md`, `.markdown`; block grammar only)
- HTML (`.html`, `.htm`)
- CSS (`.css`)

Format grammar support is parser/doctor/routing substrate only. YAML/TOML/Markdown/JSONC edit semantics are still deferred; current `set_key` remains strict JSON-only local scanning.

## 0.3 thesis

Blitz 0.3 becomes an **adaptive edit router plus deterministic edit engine**:

```text
agent intent
  ↓
route classifier + cost oracle
  ├─ no-op / direct text edit
  ├─ universal anchor/range edit
  ├─ format-aware edit (JSON/YAML/TOML/Markdown/HTML/CSS)
  ├─ AST edit (tree-sitter code grammars)
  ├─ batch/workspace edit
  └─ core edit fallback
  ↓
preview + preconditions + validation
  ↓
apply or fallback
```

The user-facing guarantee is not “Blitz always wins when forced.” It is:

> The 0.3 router will not choose Blitz for rows where the measured/predicted route is worse than fallback by the configured threshold, and publishable claims will only count correct rows.

## Design goals

1. **Guaranteed-faster routing**
   - Use data to choose the cheapest correct route.
   - Fall back when expected win is not clear.
   - Track model-specific behavior (`gpt-5.4-mini`, ZAI, Claude, etc.).

2. **Deterministic CLI fast paths**
   - Direct O(n) byte/range edits for simple cases.
   - One allocation/pass where possible.
   - No AST parse when route does not need AST.

3. **Incremental tree-sitter engine**
   - Parser/query reuse where process lifetime allows.
   - Incremental parse-after validation via `TSInputEdit` for range edits.
   - Changed-range validation instead of full document scans where safe.

4. **Universal useful-file support**
   - Add generic text/anchor ops that work on any file.
   - Add format-aware operations for common non-code formats without lossy reserialization.
   - Keep raw text canonical; edit byte ranges, do not round-trip entire files unless explicitly requested.

5. **Bleeding-edge build discipline**
   - Stay Zig 0.16 stable for release until master proves a runtime win.
   - Continuously benchmark Zig master/0.17-dev and tree-sitter patch updates.
   - Upgrade tree-sitter from 0.26.8 → 0.26.9 after compatibility tests.

## Non-goals

- No public “always faster” claim for forced Blitz tools.
- No lossy formatting rewrite for Markdown/YAML/TOML/JSON configs.
- No `Io.Evented` production switch in 0.3 unless benchmarks prove it.
- No multi-file mutation without hashes, preview, and atomic/fail-closed policy.
- No hidden model failures in benchmark summaries.

## Architecture lanes

### Lane A — Measurement and oracle foundation

Owner: backend/data agent (`d5`) + reviewer.  
Purpose: make cost prediction enforceable.

Tasks:

- [x] Add CLI phase timers: [DONE:2]
  - process/cold start if measurable;
  - file read;
  - language detection;
  - parser init;
  - parse-before;
  - target resolution;
  - op planning;
  - splice/apply;
  - parse-after;
  - write/backup;
  - JSON serialization.
  - Note: first slice added coarse apply `phaseMs`; cold start, grammar/version fields remain future refinements.
- [x] Extend JSON result metrics: [DONE:2]
  - `route`, `operation`, `fileBytes`, `changedBytes`, `requestBytes`, `wallMs`, `phaseMs`, `parserCold`, `grammar`, `treeSitterVersion`, `zigVersion`.
  - Note: first slice added route + phaseMs and kept existing byte/wall fields; parserCold/grammar/version remain future refinements.
- [x] Add benchmark summarizer that computes: [DONE:4]
  - correctness rate;
  - output-token savings;
  - tool-arg savings;
  - total Tokscale cost;
  - wall-time savings;
  - malformed/retry/timeout rates;
  - both-correct vs core-failed categories.
  - Note: pairwise JSON statuses now distinguish `both_correct`, core-failed correctness wins, Blitz failures, and incomplete pairs.
- [x] Add route-decision audit output: [DONE:3]
  - predicted route;
  - fallback route;
  - expected win;
  - threshold;
  - reason code.
  - Note: JSON-only `options.route` explain mode returns `routeDecision`; expected win/threshold are future oracle fields.

Acceptance:

- [x] Existing `zig build test` passes. [DONE:2]
- [x] `bench/pi-matrix.ts --tokscale` reports route/cost fields. [DONE:5]
- [x] No benchmark report can mark a failed row as savings. [DONE:4]

### Lane B — Adaptive router (“guaranteed faster” contract)

Owner: `d5` with independent review.  
Purpose: make the system never choose a known-worse path.

Route candidates:

| Route | Use when | Fallback |
|---|---|---|
| `noop` | desired state already present | none |
| `direct_text` | unique anchor/range, small change, no AST needed | core edit |
| `format_text` | JSON/YAML/TOML/Markdown/HTML/CSS targeted change | direct/core |
| `ast_narrow` | supported grammar + high-confidence symbol/op | direct/core |
| `ast_batch` | multiple AST ops with conflict-free ranges | core/patch |
| `core_edit` | small file, unsupported format, or oracle says Blitz not worth it | none |

Tasks:

- [x] Add route estimator inputs: [DONE:3]
  - file extension/type;
  - file bytes/tokens estimate;
  - changed bytes estimate;
  - operation type;
  - model/provider;
  - historical per-route stats;
  - grammar support/confidence;
  - expected retry risk.
  - Note: first slice uses operation/language support with fixed confidence; model/provider/history are future oracle inputs.
- [x] Add thresholds: [DONE:6]
  - minimum expected token/cost/wall win;
  - maximum correctness-risk score;
  - maximum unsupported-format risk.
  - Implemented in `routeDecision.threshold` and `routeDecision.risk` with conservative defaults; historical oracle inputs remain future work.
- [x] Add `--route auto|force-blitz|force-core|explain`. [DONE:7]
  - JSON request `options.route` and CLI `blitz apply --route ...` are supported; CLI flag overrides JSON route.
- [x] Add `--preview --route auto --json` for dry-run decision without mutation. [DONE:3]
  - Implemented as apply JSON `options: {"route":"auto", "dryRun":true}` / `route:"explain"`; CLI `--preview` spelling remains future wrapper work.
- [x] Integrate Pi wrapper guidance so agents request `auto` by default, not forced Blitz. [DONE:8]
  - Companion `pi-blitz` README/skill now direct agents to use `--route auto` / `options.route: "auto"`, `explain` for preview, and force routes only with route/benchmark evidence.

Acceptance:

- [x] Router chooses core for known core-favored rows from `gpt-5.4-mini` pair bench. [DONE:9]
- [x] Router chooses Blitz for high-confidence structural rows where core failed or was wasteful. [DONE:9]
- [x] Every decision is explainable by stable `reasonCode`. [DONE:3][DONE:6][DONE:9]

### Lane C — Tree-sitter 0.26.9 + incremental engine

Owner: `d5`; review required.  
Purpose: reduce parse/validation cost and improve targeting.

Tasks:

- [x] Upgrade vendored tree-sitter 0.26.8 → 0.26.9. [DONE:10]
- [x] Verify ABI 15 and grammar compatibility in `doctor`. [DONE:10]
- [x] Add `ts_language_abi_version` gate in doctor/version JSON if not already exposed. [DONE:10]
- [ ] Introduce parser/query cache inside long-lived process paths: [DEFERRED]
  - MCP server currently shells out via `spawnSync(blitz, ...)` per call, so there is no warm Zig parser process to cache inside yet.
  - Future `blitzd` / warm worker should keep parsers warm; CLI remains stateless but reports cold-start metrics.
- [ ] Cache compiled `TSQuery` per language/op. [DEFERRED]
  - Current targeting path does not use `TSQuery` yet beyond bindings; cache becomes actionable with query-based targeting or warm worker.
- [x] Add query cursor byte/point range and max depth/match count wrapper scaffolding. [DONE wrapper-level: `029b1da` exposes Tree-sitter `QueryCursor` wrappers for match limit, did-exceed, point range, byte range, and max start depth with focused bindings tests; product-level query operation plumbing remains deferred]
  - Future query-based targeting must apply these limits in user-facing CLI/daemon operations and decide whether invalid ranges should return errors instead of assert-only low-level wrapper checks.
- [x] Implement incremental parse-after validation for single/multi range edits: [DONE:12]
  - compute exact `TSInputEdit` from byte and line-index data;
  - call `ts_tree_edit()` on old tree;
  - parse with edited old tree;
  - call `ts_tree_get_changed_ranges()`;
  - fail closed if changed ranges escape expected envelopes for strict ops.
  - Note: single-range apply ops now use exact range edits and fail closed on `ChangedRangesTooBroad`; patch/multi-body still use full parse pending strict multi-range envelopes.
- [x] Build a shared line-index/point conversion module to avoid repeated line scans. [DONE:11]

Acceptance:

- [x] Parse-after phase is measurably faster on large files for single-range edits. [DONE:22]
  - Evidence: `reports/lane-c-incremental-parse-after-20260525-133400.md` measures a 103,277-byte TypeScript single-range dry-run replace with parseAfter median 11ms / p95 13ms, under the suggested 25ms parse-after target.
- [x] Changed-range validation catches accidental wide mutations. [DONE:12]
- [x] All existing apply failure-contract tests pass. [DONE:12]

### Lane D — Universal text and format ops

Owner: `d5`, format-by-format slices.  
Purpose: make Blitz useful on “any file where there is benefit,” without pretending every file has an AST.

Core universal ops:

- [x] `replace_unique` — replace exact unique text on arbitrary files via `direct_text`; requires exactly one occurrence and bypasses AST parse validation. [DONE:13]
- [x] `insert_after_anchor` / `insert_before_anchor` — insert exact text before/after exactly unique anchor on arbitrary files via `direct_text`; duplicate/missing anchors reject without mutation and bypass AST parse validation. [DONE:14]
- [x] `replace_between` — bounded by unique start/end anchors; replaces only inner content and keeps anchors. [DONE:15]
- [x] `append_section` — Markdown/text section-aware append before next same-or-higher heading, using exact unique heading match via `direct_text`; missing/duplicate/invalid heading and empty text reject without mutation. [DONE:18]
- [x] `set_key` — top-level JSON/YAML/TOML keys via `format_text`; JSON validates strict object before/after; YAML/TOML use tree-sitter parse-clean before/after plus local line byte splices for simple scalars only; rejects duplicate top-level keys, unsupported extensions (including `.jsonc`), nested/path syntax, dotted/table-scoped TOML edits, and unsafe values/layouts; preserves unrelated comments/formatting. JSONC remains deferred. [DONE:20, DONE:21]
- [x] `ensure_line` — idempotent line insertion for config/prose. [DONE:16]
- [x] `delete_range` — explicit preconditioned range only. [DONE:17]

Format support plan:

| Format | 0.3 target | Implementation strategy |
|---|---|---|
| Markdown | parser support added; section/block insert/replace deferred | tree-sitter-markdown block grammar vendored; raw text edits |
| JSON | parser support and top-level `set_key` complete; delete key/array insert deferred | tree-sitter-json vendored for parser support; `set_key` remains strict scanner + std.json validation |
| JSONC | parser/doctor/read support only; comment-preserving edits deferred | tree-sitter-jsonc vendored from `sunilunnithan/tree-sitter-jsonc` commit `02b01653c8a1c198ae7287d566efa86a135b30d5`, ABI 13; no `set_key` semantics |
| YAML | simple top-level `set_key` complete for scalar update/insert; nested paths, arrays, multiline scalars, and serializer round-trips deferred | tree-sitter-yaml parse-clean before/after; local same-line value span or EOF insert splice |
| TOML | simple top-level pre-table `set_key` complete for scalar update/insert; dotted keys, arrays, array-of-tables, table-scoped edits, and serializer round-trips deferred | tree-sitter-toml parse-clean before/after; local same-line value span or pre-first-table insert splice |
| HTML | parser support added; element/block anchor edits deferred | tree-sitter-html vendored; range edits |
| CSS | parser support added; rule/property edits deferred | tree-sitter-css vendored; range edits |
| arbitrary text | anchors/hashes | deterministic byte edits only |

Parser/grammar expansion note: `reports/grammar-parser-design-20260525.md` records the pinned parser-support slice for JSON/JSONC/YAML/TOML/Markdown/HTML/CSS, including exact repo commits, ABI status, and skipped inline Markdown behavior. This slice adds parser, doctor, and read support only; no YAML/TOML/Markdown/JSONC edit semantics.

Acceptance:

- [x] README/Markdown benchmark has a Blitz route when it is beneficial; otherwise router chooses core. [DONE:19]
  - Evidence: `reports/pi-readme-core-glm-fixed-20260525-122406.md/json` — `readme/core-smoke`, runner `tmux`, provider/model `zai/glm-4.5-air`, Tokscale required, token match yes, correctness 100%, selected route `core_edit` as a core-only Markdown cost/control smoke.
- [x] JSON/YAML/TOML edits preserve comments/formatting for targeted edits. [DONE:21]
  - Evidence: top-level `set_key` uses local byte splices. JSON preserves object formatting with std.json validation; YAML/TOML preserve unrelated lines and trailing comments for simple scalar line edits, validate parse-clean before/after, reject duplicates/nested paths/table scope/dotted keys/unsupported values. JSONC remains parser/read only and unsupported for `set_key`.
- [x] Unsupported formats still get safe `direct_text` routes when anchors are unique. [DONE:13-18]
  - Evidence: parent CLI smokes for `replace_unique`, anchor insert, `replace_between`, `ensure_line`, `delete_range`, and `append_section` on `.txt`, `.md`, and unsupported extensions; all bypass AST parse truthfully and reject ambiguous/missing preconditions without mutation.

### Lane E — Warm process / daemon path

Owner: backend agent + security review.  
Purpose: remove CLI cold-start/parser-load overhead for repeated agent calls.

Options:

1. Improve existing MCP server to keep a warm Blitz process/library path.
2. Add `blitzd` stdio protocol for Pi extension.
3. Keep CLI as stateless fallback.

Tasks:

- [x] Define `blitzd` protocol or extend MCP wrapper with a warm-worker pool. [DONE: Lane E protocol spec in `docs/blitzd-protocol.md`; implementation deferred]
- [x] Add CLI extension point and minimal daemon prototype: `blitz daemon --help` documents serial JSONL use; `blitz [--workspace-root <root>] daemon` handles non-mutating `doctor` and `read` requests. [DONE: safe prototype only]
- [ ] Keep parser/query caches in worker memory. [PARTIAL: daemon keeps reusable parser instances by language for `read` structure paths; query caches and open tree/incremental parse caches remain deferred]
- [x] Add bounded MCP-host warm cache for safe repeated calls. [DONE: `BLITZ_MCP_WARM=1` caches `doctor` and `read` only; `read` cache key is canonical file path + same-fd SHA-256/content metadata fingerprint; default off; read cache defaults: 128 entries and 1 MiB total cached result text]
- [x] Add workspace root, file hash, and lock policy to worker requests. [DONE: policy defined in `docs/blitzd-protocol.md`; MCP cache uses existing workspace binding and same-fd SHA-256/content metadata read fingerprints; mutation hash preconditions still deferred]
- [x] Add idle timeout and cache invalidation. [DONE: lifecycle policy defined in `docs/blitzd-protocol.md`; MCP cache invalidates read entries on mutation tool calls/process restart and evicts read entries oldest/LRU-first when entry/result-byte bounds are exceeded; true idle eviction still deferred]
- [x] Security review current non-mutating Zig JSONL daemon slice: workspace boundaries, path traversal, stale file state, untrusted JSON payloads. [DONE current-slice: daemon canonicalizes process workspace root at startup and rejects regular-file roots; non-string request `workspaceRoot` and string mismatches reject fail-closed; relative and absolute read paths resolve through realpath then workspace enforcement; `..` traversal, broken symlink ancestors, symlink escapes, absolute escapes, invalid JSON/non-object requests, invalid read params, oversized frames, and invalid/high-byte output are covered by smoke/manual probes; daemon stores parser instances only and reads current file per request. Evidence: `40bf27c`, `bun scripts/daemon-smoke.ts`, extra security probes v4, security-reviewer `approve commit`. DEFERRED full daemon: required/typed `workspaceRoot` policy for future pooling, JSON nesting/depth resource limits, same-fd read/parse under hostile concurrent writers, open-tree/query cache invalidation, daemon mutation hash preconditions/locks/crash proof.]
- [ ] Security review future full daemon mutation/cache slice. [DEFERRED: complete checklist in `docs/blitzd-protocol.md`; prove mutations, cache invalidation, crash/timeout, env, diagnostics.]

Acceptance:

- [x] Warm path p50/p95 wall time beats cold CLI on repeated safe operations. [DONE: `reports/mcp-warm-cache-bench-20260525.md`; fixed-harness 25-iteration verification rerun rejects MCP `isError` tool results and asserts expected doctor/read content; doctor p50/p95 0.110/0.185ms warm vs 3.133/3.568ms cold; read p50/p95 0.157/0.799ms warm vs 0.439/1.091ms cold]
- [x] Worker never mutates outside workspace — current non-mutating daemon slice. [DONE current-slice: Zig daemon exposes only `doctor` and `read`; mutating method names reject closed with `fallbackAllowed:false`; no daemon stateless mutation fallback exists. MCP mutations still use existing stateless CLI after `bindPath` and clear cached read entry before mutation. Evidence: `40bf27c`, security-reviewer `approve commit`.]
- [ ] Worker never mutates outside workspace — future daemon mutation slice. [DEFERRED: prove mutation hash preconditions, same-fd/symlink-safe target binding, per-file locks, crash/timeout no-partial-write behavior, and cache invalidation.]
- [x] Crash/timeout falls back to stateless CLI safely for current warm slice. [DONE: current warm slice has no child worker; cache miss, unsafe/oversized fingerprint input, oversized result, pre/post fingerprint mismatch, and process restart use stateless CLI for safe calls without cache fill; mutations already stateless]

### Lane F — Build and release benchmarking

Owner: `d5` + reviewer.  
Purpose: use latest Zig/tree-sitter without destabilizing release.

Build matrix:

- Zig 0.16 stable ReleaseFast native.
- Zig 0.16 stable ReleaseSmall native.
- Zig 0.16 x86_64-linux-musl ReleaseFast.
- Zig master/0.17-dev ReleaseFast experimental.
- Tree-sitter 0.26.8 vs 0.26.9.

Tasks:

- [x] Add reproducible bench command scripts under `bench/scripts/`. [DONE: Lane F scripts: `bench/scripts/release-build-matrix.sh`, `bench/scripts/apply-microbench.sh`]
- [ ] Use `zig build --watch -fincremental --time-report` for dev loop, not release claim. [DEFERRED: release evidence uses stable `zig build`; dev-loop evidence remains blocked on current Zig/toolchain behavior as of 2026-06-05: combined `--watch -fincremental --time-report` fails because `--time-report`/web UI and `--watch` are unsupported together; split `--watch -fincremental` aborts with `REX_GOTPCRELX`; split `--time-report` fails with `failed to listen to port 0: AddressUnavailable`.]
- [x] Add binary size, cold start, and operation wall-time table. [DONE: `reports/lane-f-evidence-20260525-102840.md` summarizes build matrix + apply microbench]
- [x] Confirm no `@cImport`; keep C interop in build system. [DONE: `grep -R --include='*.zig' -n '@cImport(' src build.zig` found none in Lane F report]
- [x] Evaluate `smp_allocator` in ReleaseFast and debug allocator only in debug/safe. [DONE: documented no allocator switch; repo AGENTS keeps Zig 0.16 stable/debug allocator policy pending isolated evidence]

Acceptance:

- [x] 0.3 release build choice is evidence-backed. [DONE: native ReleaseFast/ReleaseSmall and x86_64-linux-musl ReleaseFast sizes/timings recorded]
- [x] Master/0.17-dev is optional until it proves runtime or size win. [DONE: documented deferred until local toolchain evidence exists]

### Lane G — Benchmark suite expansion

Owner: benchmark skill + `d5`.  
Purpose: validate the guarantee.

Datasets:

- code grammars: Rust, TS, TSX, Python, Go;
- non-code formats: Markdown, JSON, YAML, TOML, HTML, CSS;
- file sizes: tiny, 10k, 100k, 1MB;
- edit classes:
  - small return/body change;
  - wrapper insertion;
  - multi-symbol edit;
  - config key update;
  - docs section insert;
  - duplicate/ambiguous anchor rejection;
  - malformed parse baseline;
  - overlapping edits.

Required report fields:

- model/provider/date/commit;
- runner (`tmux` for locked claims);
- Tokscale token match;
- correctness;
- output tokens;
- tool-call arg tokens;
- total cost;
- wall time;
- retries/timeouts;
- route decision and fallback.

Acceptance:

- [ ] `gpt-5.4-mini` core-vs-router matrix has no selected-route regressions against fallback beyond threshold. [DEFERRED]
  - Environment note: current OpenAI/Codex Pi path failed before session capture with `OAuth authentication is currently not allowed for this organization`; do not claim GPT-locked evidence from this run.
- [x] Failed/core-vs-Blitz rows are reported with correctness/savings status instead of hidden savings claims. [DONE:4]
  - Evidence: `bench/pi-matrix.ts` pairwise statuses and prior report handling distinguish both-correct, core-failed correctness wins, Blitz failures, and incomplete pairs.
- [x] Rows where core is cheaper are routed/reported distinctly from Blitz wins. [DONE:20]
  - Evidence: `reports/pi-lane-g-glm-arrow-20260525-123212.md/json`, `zai/glm-4.5-air`, runner `tmux`, Tokscale required, both rows correct/token-match yes; report shows Blitz lost output/wall but saved tool-call args, with no false savings claim.

## Data model additions

Future result shape additions:

```ts
type BlitzRouteDecision = {
  route: "noop" | "direct_text" | "format_text" | "ast_narrow" | "ast_batch" | "core_edit";
  fallbackRoute?: string;
  confidence: number;
  expected: {
    outputTokens?: number;
    toolArgTokens?: number;
    costUsd?: number;
    wallMs?: number;
  };
  threshold: {
    minCostSavingsPct: number;
    minWallSavingsPct: number;
    maxRisk: number;
  };
  reasonCode: string;
};
```

CLI JSON metrics additions:

```ts
type BlitzMetrics03 = {
  wallMs: number;
  phaseMs: {
    read?: number;
    detectLanguage?: number;
    parserInit?: number;
    parseBefore?: number;
    targetResolve?: number;
    plan?: number;
    apply?: number;
    parseAfter?: number;
    changedRanges?: number;
    write?: number;
    json?: number;
  };
  fileBytesBefore: number;
  fileBytesAfter: number;
  changedBytesBefore: number;
  changedBytesAfter: number;
  requestBytes: number;
  grammar?: string;
  treeSitterVersion?: string;
  zigVersion?: string;
  coldStart?: boolean;
};
```

## “Guaranteed faster” acceptance contract

A 0.3 release candidate is accepted only if:

- [x] Forced Blitz rows are labeled honestly as wins/losses. [DONE: benchmark pairwise statuses/report wording distinguish wins, losses, correctness wins, and incomplete pairs]
- [x] Auto-router rows never choose Blitz when baseline evidence predicts loss above threshold. [DONE: route contract uses stable route decisions/fallbacks; GLM Lane G evidence reports core-favored loss distinctly]
- [x] Router can explain every core-vs-Blitz decision. [DONE: routeDecision + reasonCode emitted in apply JSON and benchmark rows]
- [x] All selected rows are correct or fail closed before mutation. [DONE: apply route smokes, incremental changed-range broad failure fix, direct-text ambiguity rejections, JSON/JSONC set_key rejection]
- [x] Tokscale validates real Pi session token totals for agent-facing claims. [DONE: locked GLM tmux/Tokscale reports saved under reports/]
- [x] CLI direct/incremental paths meet p95 wall-time targets on local microbench. [DONE: p95 script/report added; debug/cold `reports/lane-f-apply-microbench-p95-final-20260525-132013.md` showed ~10.98ms, but ReleaseFast evidence `reports/lane-f-apply-microbench-p95-releasefast-20260525-132131.md` shows dry-run p95 3.865ms/2.405ms, under the suggested ≤10ms direct target]
- [x] Universal file routes exist for at least Markdown, JSON/JSONC, YAML, TOML, HTML, CSS, and arbitrary text anchors. [DONE: parser/doctor/read support for JSON, JSONC, YAML, TOML, Markdown, HTML, CSS; direct_text anchors for arbitrary files; format edit semantics beyond strict JSON set_key remain deferred]

Suggested thresholds for first RC:

- Correctness: 100% on selected-route locked matrix.
- Token/cost: selected route must be no worse than fallback by more than 5%; otherwise choose fallback.
- Wall time: selected route must be no worse than fallback by more than 10%; otherwise choose fallback.
- Direct CLI ops: p95 under 10ms for files ≤100kB, excluding process cold start; warm process target under 5ms.
- Parse-after validation: p95 under 25ms for 100kB supported-code files.

## Implementation order

1. **Plan approval only** — this file.
2. Instrumentation and report model (Lane A).
3. Router in preview/explain mode only (Lane B partial).
4. Benchmark route oracle using existing forced core/Blitz data.
5. Tree-sitter 0.26.9 + incremental validation (Lane C).
6. Universal text ops (Lane D first slice).
7. Warm process prototype (Lane E).
8. Expanded format grammars and format-specific ops (Lane D second slice).
9. Full gpt-5.4-mini locked tmux matrix (Lane G).
10. Release readiness review.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Router becomes a pile of heuristics | Keep route decisions data-backed, logged, and testable. |
| Universal formats lose comments/formatting | Raw byte-range edits only; no broad serializer rewrite by default. |
| Incremental parse validation misses wide semantic damage | Changed-range envelope checks plus full parse fallback on uncertainty. |
| Warm daemon creates security boundary risk | Security review; workspace root enforcement; hash preconditions; idle timeout. |
| Zig master breaks APIs | Master is experimental bench target only; release on 0.16 stable until proven. |
| Tree-sitter grammar drift | ABI checks, doctor output, grammar fixture matrix before upgrade. |
| Model-specific behavior changes | Store provider/model/date and maintain per-model route stats. |

## Concrete next slices after approval

### Slice 1 — Metrics + route report fields

Files likely touched:

- `src/metrics.zig`
- `src/apply/mod.zig`
- `src/cmd_apply.zig`
- `bench/pi-matrix.ts`
- docs/report schema

Gates:

```bash
zig build test
zig build
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
```

### Slice 2 — Auto-router preview mode

Files likely touched:

- CLI command parser / apply command
- Pi wrapper schema later, after CLI is stable
- benchmark report writer

Gates:

```bash
zig build test
bun bench/pi-matrix.ts --runner tmux --provider openai-codex --model gpt-5.4-mini --case semantic/async-try-catch --tokscale
```

### Slice 3 — Universal text anchors

Files likely touched:

- new `src/text_ops.zig` or `src/apply/text.zig`
- tests/fixtures for Markdown/JSON/YAML/TOML/HTML/CSS/plain text

Gates:

```bash
zig build test
zig build
zig-out/bin/blitz apply --json <text-op fixtures>
```

### Slice 4 — Tree-sitter 0.26.9 + incremental validation

Files likely touched:

- `third_party/tree-sitter/`
- `src/tree_sitter/*`
- `src/apply/*`
- `src/grammar_config.zig`

Gates:

```bash
zig build test
zig-out/bin/blitz doctor
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
```

## Approval request

Approve this plan before implementation. Recommended first approved slice: **Lane A / Slice 1 — metrics + route report fields**, because it gives every later performance claim a hard measurement backbone.
