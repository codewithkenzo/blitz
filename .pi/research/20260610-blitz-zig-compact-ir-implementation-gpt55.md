# Research: Blitz/Zig compact-IR implementation (GPT-5.5 medium rerun)

## Question
What is smallest safe Zig-side compact edit slice for Blitz 0.4, using current repo state, Zig 0.16.0 stable, vendored tree-sitter, existing apply/splice architecture, and current Pi/tmux/Tokscale losses?

## Findings

### Zig 0.16.0/tree-sitter validation; stale docs/skill caveats
- Repo source of truth says Zig **0.16.0 stable**, not nightly/dev: `AGENTS.md`; `build.zig.zon` pins `.minimum_zig_version = "0.16.0"`.
- Entry/runtime already uses Zig 0.16 `pub fn main(init: std.process.Init) !void`, `init.gpa`, `init.io`: `src/main.zig::main`.
- Build uses module-level C integration and vendored tree-sitter/grammars, no `@cImport`: `build.zig` links `third_party/tree-sitter/lib/src/lib.c` plus grammar `parser.c`/`scanner.c` on `root_module`; `src/tree_sitter/bindings.zig` owns extern ABI.
- Tree-sitter runtime is `v0.26.9`, ABI 15/min 13: `src/tree_sitter/bindings.zig`, `src/cli.zig::runDoctor`.
- Existing C API covers enough for first compact IR: parser, parse string, tree edit/changed ranges, node byte/point ranges, query cursor range/match controls: `src/tree_sitter/bindings.zig`.
- Caveat: inherited `kenzo-zig` skill text mentions 0.16-dev/stable-imminent and GPA-era patterns in places. Repo `AGENTS.md` + `build.zig.zon` are newer and must override: use stable 0.16, `std.process.Init`, no new `@cImport`.

### Smallest meaningful Zig-side compact edit slice
Smallest useful slice: **extend existing `blitz apply --edit - --json` to accept compact aliases + snippet-only body/symbol ops**, not new daemon, not new MCP, not pi-blitz edits.

Why:
- `src/main.zig` already dispatches `apply`; help calls it “Structured JSON edit IR”: `src/cli.zig::printHelp`.
- `src/apply/ir.zig` already parses `ApplyRequest` and operation strings.
- `src/apply/mod.zig::run` already performs read → language detect → parse-before → AST target resolve → plan → parse-after validation → lock/backup/atomic write → JSON output.
- Existing ops already include high-value primitives: `set_body`, `insert_after_symbol`, `merge_body_chunk`, `multi_body`, `patch`: `src/apply/ir.zig::ApplyOperation`, `src/apply/mod.zig` switch.

Minimal v1 should add **model-facing compact syntax only where it maps to existing ops**:
1. aliases: `rb`/`replace_body` → `set_body`; `ia`/`insert_after` → `insert_after_symbol`; `mb` → `merge_body_chunk`; `mas` → `multi_body` same-file batch;
2. compact fields: `f` → `file`, `op` or `o` → `operation`, `t` → target, `s` → snippet/body/code;
3. target shape supports old `target.symbol` plus new `{kind,name,parent,occurrence,range}` without changing old requests;
4. tiny JSON success optional (`--compact-json` or request option) after correctness tests, because current `ApplyResult` is verbose.

Avoid first: new `edit-ir` top-level command, warm daemon mutation, MCP/profile work, Rust/apply_patch parity, full CEDARScript grammar.

### Exact files/symbols likely touched
Likely touched for v1:
- `src/apply/ir.zig`
  - `ApplyTarget`: add `name`, `parent`, `occurrence`/selector fields; preserve `symbol` for compat.
  - `ApplyOptions`: add `compactOutput` maybe `preconditionHash` later.
  - `parseOperation`: aliases: `rb`, `ia`, `mb`, `mas`, maybe `rn`.
  - `parseRequest`, `parseTargetField`: accept compact top-level fields and compact target.
- `src/apply/target.zig`
  - add `TargetSpec`/`resolveTargetSpec` wrapper over `ast.resolveEditableSymbol` initially.
  - enforce deterministic ambiguity behavior; return count/candidates metadata later.
- `src/ast.zig`
  - extend symbol matching from bare name to kind/name/parent/occurrence only if needed for v1 ambiguity tests.
  - current functions: `resolveEditableSymbol`, `countEditableSymbolMatches`, `bodyRangeFor`, `replacementRangeFor`.
- `src/apply/mod.zig`
  - normalize compact request into current `ApplyRequest` early in `run`.
  - route aliases to existing `set_body` / `insert_after_symbol` / `merge_body_chunk` / `multi_body` planning branches.
  - add compact success/failure output path after existing `ApplyResult` is stable.
  - keep existing no-partial-write flow: validation before `backup.atomicWrite`.
- `src/splice.zig`
  - only if v1 includes `merge_body_chunk`; expose stronger FastEdit-style marker/anchor errors and tests around `maybeSplice`.
- `src/grammar_config.zig`
  - likely no first-change needed; existing `languageForExtension`, `commentStylesFor`, `isDeclarationKind`, `isBodyKind` are enough.
- `src/cli.zig`
  - help examples for compact apply, not behavior.
- `src/test_all.zig`
  - no direct change if tests live in imported modules; aggregate already imports `apply/mod.zig`, `splice.zig`, `ast.zig`, `symbols.zig`, bindings.

Likely not touched first:
- `build.zig`, `build.zig.zon` (tree-sitter + Zig stable already valid).
- `src/tree_sitter/bindings.zig` (API enough for v1).
- `/home/kenzo/dev/pi-blitz` (explicitly out of scope).

### Compact IR shape examples
Verbose current-compatible baseline:
```json
{"version":1,"file":"src/apply/mod.zig","operation":"set_body","target":{"symbol":"run"},"edit":{"body":"// new body\n"},"options":{"requireSingleMatch":true}}
```

Compact JSON v1, same op:
```json
{"v":1,"f":"src/apply/mod.zig","o":"rb","t":"run","s":"// new body\n"}
```

Compact target object, deterministic disambiguation:
```json
{"v":1,"f":"src/apply/mod.zig","o":"ia","t":{"kind":"function","name":"run","parent":"apply/mod","occurrence":"only"},"s":"\nfn helper() void {}\n"}
```

Marker/chunk body merge:
```json
{"v":1,"f":"src/foo.ts","o":"mb","t":"handleRequest","s":"const user = auth(req)\n// ... existing code ...\nreturn res\n"}
```

Same-file batch candidate:
```json
{"v":1,"f":"src/foo.ts","o":"mas","edits":[["rb","login","const u = tryAuth()\nreturn u\n"],["ia","login","\nfunction health() { return 'ok' }\n"]]}
```

Important: compact IR should remain JSON first. Freeform DSL can wait until Pi/provider tool path supports grammar/freeform. JSON parsing, errors, and tests already exist.

### Target resolver rules and ambiguity behavior
Current behavior:
- `src/apply/mod.zig::run` requires target for most AST ops and calls `apply_target.resolveEditableSymbol(original, root, req.target.?.symbol)`.
- `src/ast.zig::resolveEditableSymbol` counts declaration matches; 0 → `SymbolNotFound`; >1 → `AmbiguousSymbol`; exact 1 → node.
- `src/ast.zig::findBodyNode` searches `body` field, then known body node kinds; `bodyRangeFor` returns brace interiors for TS/TSX/Rust/Go, whole body node for Python.
- `src/apply/target.zig::parseMatchSelector` supports `first`, `last`, `only`, positive integer index for text matches, but AST symbol resolution currently ignores this selector.

Recommended v1 target semantics:
1. `t:"name"` = `{name:"name", occurrence:"only"}`.
2. `{name,kind}` filters declaration kind if feasible; if kind unsupported for language, fail `UnsupportedTargetKind`, not fuzzy fallback.
3. `{parent}` narrows by nearest enclosing declaration name. Do not implement broad path/module heuristics first.
4. `{occurrence:"only"}` default: fail if duplicate.
5. `{occurrence:1}` allowed only with explicit user-provided number; response must include total matches to make fragility visible.
6. No fuzzy target names, no “first match” default for model convenience.
7. Ambiguity error should be deterministic and actionable: code `SymbolAmbiguous`, include compact candidates later (`name`, `kind`, byte range, parent). Current `emitFailure` can carry code but not rich candidate list.

### Splice/validation/no-partial-write design
Existing safety path is good and should be reused:
- Parse before write: `src/apply/mod.zig::run` initializes parser, `parser.setLanguage`, parses original, rejects root error.
- Plan in memory: all op branches build `op_result.contents` before mutation.
- Parse after plan: `src/apply/validate.zig::parseAfterEdit` uses incremental single-range validation when possible, full parse for `multi_body`/`patch`, rejects parse errors.
- Write after parse: only after `parse_after == true`, acquire `file_lock`, store backup, `backup.atomicWrite`: `src/apply/mod.zig` write block.
- So v1 can guarantee no **planned invalid parse** writes for supported languages and no partial direct writes from apply engine. It cannot guarantee semantic correctness or token savings.

FastEdit splice gap:
- `.pi/docs/fastedit-splice-algorithm.md` describes anchor classification, marker modes, unsafe gap rejection, indentation preservation, parse validation.
- Current `src/splice.zig::maybeSplice` has marker parsing, LCS diff merge, max LCS budget, `AnchorNotFound`/`AmbiguousAnchor`, trailing newline preservation; it is useful but **not full documented FastEdit algorithm** (no full context/new classification rules, no max-drop-gap anchor pair policy as documented, no target-aware parse wrapper in the file itself).
- First v1 should use direct `set_body`/`insert_after_symbol`; use `merge_body_chunk` only where `maybeSplice` confidence is high and parse-after catches bad merges.

### Tests and benchmark rows
Zig tests:
- `zig build test` full gate.
- Add focused `src/apply/ir.zig` tests: alias parsing, compact top-level fields, compact target string/object, bad field types.
- Add `src/apply/target.zig` or `src/ast.zig` tests: duplicate symbol fails by default; parent/occurrence narrows; unsupported kind fails.
- Add `src/apply/mod.zig` integration tests using temp files for:
  - compact `rb` replaces body and parse validates;
  - compact `ia` inserts after symbol;
  - compact duplicate target no mutation;
  - parse-after failure no mutation;
  - compact success output shape if added.
- Add `src/splice.zig` tests only if `mb` becomes accepted public path in v1: marker preserve, ambiguous marker failure, parse-fail rejection via apply.

Bench rows after Zig slice:
- Single symbol/body rows: `semantic/arrow-replace-return`, `long-section/replace-return`, target new `replace_body` fixture, target `insert_after_symbol` fixture.
- Streaks required by goal: `tiny-10`, `mixed-20`, `same-file-multi` via true same-session runner.
- Structural capability rows still useful but secondary: `medium-10k/wrap-body`, `multi/large-structural`.
- Compare lanes: Pi core edit vs current router vs compact Zig op exposed through existing harness. If compact op is not product-real Pi route, label it benchmark-only.

### Guaranteed-by-design vs only measurable via Pi/tmux/Tokscale
Guaranteed by design after v1 if implemented as above:
- no new tree-sitter dependency/API required;
- old verbose apply requests keep working;
- unsupported/ambiguous targets fail closed;
- plan/parse validation happens before write for supported parsed languages;
- mutation path uses existing lock/backup/atomic write;
- compact request payload is fewer bytes than verbose JSON for same op.

Only measurable, never guaranteed:
- model emits compact IR reliably;
- model-visible input/cache/output/token totals fall;
- resident schema/skill overhead falls;
- old-code echo reduction beats Pi core edit in real sessions;
- cumulative streak savings vs core;
- default-readiness as Pi edit path.

Token claims require real Pi/tmux/Tokscale + correctness, per `AGENTS.md` and `.pi/reports/*`.

### Current benchmark losses and likely core gaps
Current true same-session evidence says router/Blitz loses to core:
- `tiny-10`: router `81,720` vs core `75,042`, delta `-6,678` / `-8.9%`: `.pi/reports/pi-tmux-true-streak-summary-20260610-d5.md`.
- `mixed-20`: router `247,024` vs core `176,422`, delta `-70,602` / `-40.0%`: same report.
- `same-file multi`: router `25,374` vs core `18,429`, delta `-6,945` / `-37.7%`: same report.
- Router rows are benchmark-only `pi_blitz_route_edit`, not product-real default fallback: same report and `.pi/reports/subagents/main-blitz-0.4-final-audit-20260610.md`.

Likely gaps:
1. Compact Zig IR not exposed as single tiny model-facing surface yet.
2. Current router still pays skill/cache/prompt/result overhead; `mixed-20` cache read balloon dominates.
3. Targeted structural wins exist, but simple/streak rows need route-to-core or compact op proof.
4. Product-real fallback belongs partly in pi-blitz/Pi runtime; out of scope for this report.
5. Current `ApplyResult` is verbose for token-facing success; tiny result path likely needed after correctness.

### Recommended NEW goal wording/criteria
Recommended goal:

> Implement Blitz compact apply IR v1 in `/home/kenzo/dev/blitz` only by extending `blitz apply --edit - --json` with compact aliases/fields for snippet-only `replace_body`, `insert_after_symbol`, and optional same-file batch. Preserve current verbose IR compatibility. Add deterministic AST target rules with fail-closed ambiguity, parse-before/parse-after validation, backup/atomic no-partial-write safety, and compact success output behind an option. Prove behavior with `zig build test` plus focused CLI tests. Then benchmark Pi core `edit` vs compact Blitz route on representative symbol/body rows and true same-session tiny/mixed/same-file streaks with Pi/tmux/Tokscale; claim savings only for 100%-correct rows.

Acceptance:
- no `/home/kenzo/dev/pi-blitz` edits unless separately authorized;
- no build/tree-sitter version changes;
- old apply JSON tests pass;
- compact aliases pass tests and reject malformed/ambiguous targets;
- parse failure and duplicate symbols leave file unchanged;
- `zig build && zig build test` pass;
- benchmark report states product-real vs benchmark-only route status;
- if streaks still lose, report next core gap instead of claiming replacement.

### Corrections/disagreements with `.pi/.pi/research/20260610-blitz-zig-compact-ir-implementation.md`
Mostly agree with existing replacement report. Corrections/sharpening:
- Prefer **extend existing `apply` first**, not introduce `blitz edit-ir apply` as first command. Current CLI/help/engine already names `apply` as structured IR, so new command adds surface area before token proof.
- Treat `src/splice.zig` as partial marker/LCS merge, not full FastEdit deterministic splice. Existing report says “close”; this rerun marks FastEdit parity as not yet implemented.
- Do not add `replace_node` in v1 unless tests prove target/body range semantics per language. `set_body` + `insert_after_symbol` are smaller and already wired.
- Candidate-rich ambiguity output is recommended but not needed before initial alias/target tests; fail-closed code is enough for first safe slice.
- Tiny success payload should be gated/optioned first to avoid breaking current .pi/reports/tools expecting `ApplyResult` shape.

## Sources
- Repo instructions: `AGENTS.md`, `src/AGENTS.md`, `src/apply/AGENTS.md`.
- Goal seed: `.pi/goals/archived/goal_2026061009045393_mq4q3jay-98lea0.md`.
- Existing local replacement context: `.pi/.pi/research/20260610-blitz-zig-compact-ir-implementation.md`.
- Competitor lessons boundary: `.pi/.pi/research/20260610-pi-codex-conversion-competitor.md`.
- Plans/research: `.pi/docs/plans/PLAN-0.4-context-token-optimization.md`, `.pi/docs/plans/START-0.4-context-token-core.md`, `.pi/.pi/research/20260605-token-efficient-edit-repos.md`, `.pi/.pi/research/20260605-tool-schema-context-tax.md`.
- Design docs: `.pi/docs/fastedit-splice-algorithm.md`, `.pi/docs/blitzd-protocol.md`, `.pi/docs/tree-sitter-c-api-subset.md`, `.pi/docs/blitz.md`.
- Benchmark/audit: `.pi/reports/pi-tmux-true-streak-summary-20260610-d5.md`, `.pi/reports/subagents/d5-true-streak-20260610.md`, `.pi/reports/pi-tmux-streak-synthesis-20260610-d5.md`, `.pi/reports/subagents/main-blitz-0.4-final-audit-20260610.md`.
- Architecture evidence: `build.zig`, `build.zig.zon`, `src/main.zig`, `src/cli.zig`, `src/apply/ir.zig`, `src/apply/target.zig`, `src/apply/operations.zig`, `src/apply/validate.zig`, `src/apply/mod.zig`, `src/splice.zig`, `src/symbols.zig`, `src/ast.zig`, `src/tree_sitter/bindings.zig`, `src/test_all.zig`.

## Version / Date Notes
- Date: 2026-06-10.
- Repo state inspected by targeted excerpts only; no whole large files read.
- Zig/tree-sitter assumptions validated against repo files, not external latest docs.
- Provider/tool-tax docs from 2026-06-05 mention future/beta provider names; treat API names as drift-prone.
- No source/config edits performed; only this research artifact written.

## Open Questions
- Should compact success output be a request option, CLI flag, or default for compact requests?
- How much parent/kind target filtering can be implemented safely without language-specific query tables?
- Should occurrence indexes be allowed for AST targets, or banned until candidate-rich ambiguity output exists?
- What exact Pi harness lane can expose compact Blitz IR without touching `pi-blitz`?
- Does `merge_body_chunk` produce enough correct deterministic wins to include in v1, or should it wait behind `rb`/`ia` proof?

## Recommendation
Implement compact aliases/fields on existing `blitz apply` first. Keep v1 narrow: `rb` + `ia`, optional `mas` if same-file batch can reuse existing `multi_body` safely. Reuse current parse/backup/atomic write path. Add deterministic target tests before adding richer target syntax. Benchmark only after Zig tests pass; if true-streak rows still lose, report measured core gap and route core honestly.
