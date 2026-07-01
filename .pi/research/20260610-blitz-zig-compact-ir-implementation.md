# Blitz/Zig Compact-IR Implementation Research

Date: 2026-06-10
Status: main-agent replacement report after the second lean researcher exceeded context twice; source evidence is repo-local targeted reads plus existing reports.
Scope: `/home/kenzo/dev/blitz` only. No source/config edits.

## Executive summary

The cleanest next Blitz slice is **not more wrapper trimming** and not an apply_patch clone. The smallest meaningful core slice is a Zig-native compact edit protocol layered on the existing `apply` engine:

1. accept compact op aliases / tuple IR in Blitz (`rr`, `rb`, `ia`, `sb`/`set_body`, `mas`/same-file batch),
2. resolve targets by AST symbol with deterministic ambiguity failures,
3. apply snippet-only edits through existing operation machinery where possible,
4. add/centralize guard + parse validation before write,
5. emit a tiny success payload,
6. benchmark the resulting tool-call payload against Pi core `edit` before any product claim.

This gives Blitz a real core-engine path toward token savings: the model emits file + target + new snippet, not old-code echo. Pi core `edit` remains required fallback and the benchmark baseline.

## Evidence inspected

### Repo policy / Zig constraints

- `AGENTS.md` says Blitz is Zig **0.16.0 stable**, tree-sitter C core is vendored, `zig build test` is the gate, and token/context savings are product truth.
- `AGENTS.md` and `src/AGENTS.md` require `pub fn main(init: std.process.Init) !void`, `std.heap.DebugAllocator(.{})`, `std.Io.*`, build-system C interop / extern bindings, and no new `@cImport`.
- `src/apply/AGENTS.md` says `src/apply/` owns structured edit IR, target selection, operations, validation, and tests; compact IR must reduce model-visible tokens and ambiguity must fail with actionable candidates.
- `kenzo-zig-build` skill text still mentions 0.16-dev/stable-imminent patterns in places. Repo `AGENTS.md` is newer and authoritative: stay on Zig 0.16.0 stable.

### Existing Blitz architecture

- `src/main.zig` imports and dispatches `cmd_apply = @import("apply/mod.zig")` beside `cmd_read`, `cmd_edit`, `cmd_batch`, `cmd_rename`, `cmd_undo`, `cmd_daemon`.
- `src/apply/ir.zig` already defines `ApplyRequest`, `ApplyOptions`, `ApplyTarget`, parse helpers, metrics structs, and `ApplyOperation` enum.
- Existing `ApplyOperation` values include `replace_unique`, `insert_after_anchor`, `insert_before_anchor`, `replace_between`, `append_section`, `ensure_line`, `delete_range`, `replace_body_span`, `insert_body_span`, `wrap_body`, `multi_body`, `compose_body`, `merge_body_chunk`, `insert_after_symbol`, `set_body`, `set_key`, and `patch`/`compact_patch`.
- `src/apply/mod.zig` is the current large apply engine. It parses JSON via `std.json.parseFromSlice`, maps operation strings, requires a symbol target for most structural ops, emits failure JSON, and applies operations through existing workspace/file safety.
- `src/apply/target.zig` exposes `TargetRange`, `MatchKind`, `MatchSelector`, `resolveEditableSymbol`, `countEditableSymbolMatches`, `findBodyNode`, `bodyRangeFor`, `replacementRangeFor`, `selectMatch`, and keep-slice helpers. Today it is symbol-centric, not full `{kind,name,parent,signature}` target resolution.
- `src/ast.zig` exposes `parseStrict`, `findEditableSymbolNode`, `resolveEditableSymbol`, `countEditableSymbolMatches`, body/range helpers, and byte ranges.
- `src/symbols.zig` is currently a thin alias/re-export over `ast.zig` helpers.
- `src/splice.zig` already has `maybeSplice`, marker parsing, diff/LCS based merge machinery, newline preservation, and error types. It is close to FastEdit-style deterministic splice but should be made explicit for symbol-body snippet edits.
- `src/tree_sitter/bindings.zig` isolates the tree-sitter C ABI boundary.
- `src/test_all.zig` imports `apply/mod.zig`, `splice.zig`, `ast.zig`, `symbols.zig`, `tree_sitter/bindings.zig`, etc.; new tests should plug into the existing aggregate.

### Existing docs / reports

- `.pi/docs/plans/PLAN-0.4-context-token-optimization.md` says current Blitz wins structural rows but loses simple both-correct rows due to schema/skill/input overhead; it proposes one resident compact op, profiles, compact success output, route proof, and realistic streaks.
- `.pi/docs/plans/START-0.4-context-token-core.md` says Pi core `edit` is the only required baseline/fallback for this slice and `pi_blitz_route_edit` must not be called product-real if only benchmark-synthesized.
- `.pi/.pi/research/20260605-token-efficient-edit-repos.md` recommends `blitz edit-ir apply` with AST-first targets, snippet-only edits, guard checks, parse/rollback, deterministic chunk-local merge, and old-code echo measurement.
- `.pi/.pi/research/20260605-tool-schema-context-tax.md` recommends progressive disclosure, a tiny stable surface, custom/freeform compact DSL where supported, and exact schema/skill/token accounting.
- `.pi/docs/fastedit-splice-algorithm.md` defines the desired deterministic splice: split original/snippet lines, classify snippet lines as context/new/marker, require anchors or marker mode, reject unsafe gaps, preserve indentation/trailing newline, parse-validate merged output.
- `.pi/docs/tree-sitter-c-api-subset.md` documents the C API subset needed: parser create/delete, set language, parse string, tree delete/edit, node child/range/field helpers, query cursor byte/point ranges and capture iteration.
- `.pi/docs/blitzd-protocol.md` keeps warm-daemon/protocol work relevant but later; first slice should be CLI-safe and benchmarkable before daemon defaulting.

### Current benchmark facts to preserve

From the current session / reports:

- `tiny-10`: router `81,720` vs core `75,042`, loses `6,678` / `-8.9%`.
- `mixed-20`: router `247,024` vs core `176,422`, loses `70,602` / `-40.0%`.
- `same-file multi`: router `25,374` vs core `18,429`, loses `6,945` / `-37.7%`.

Interpretation: current Blitz/router is not default-ready. The likely core gap is still missing compact model-facing IR + too much resident/schema/skill overhead + insufficient product-real routing, not Zig runtime speed.

## Zig 0.16 / tree-sitter validation

Use current repo constraints:

- Stay on Zig 0.16.0 stable.
- Use `std.process.Init`, `std.Io.*`, `std.heap.DebugAllocator(.{})`, arenas for per-call allocations.
- Do not add `@cImport`; keep tree-sitter behind `src/tree_sitter/bindings.zig` or build-system C integration.
- Tree-sitter target work should use existing parser/root/node byte ranges and query cursor range/limit capabilities; no new tree-sitter version is needed for the first slice.
- Incremental parsing / daemon parser cache is useful later, but not required for the first compact IR slice.

## Smallest meaningful Zig-side slice

### Slice name

`blitz apply` compact IR v1: AST-targeted snippet-only body/symbol edits.

### Why this slice

It is small enough to fit current architecture and large enough to attack the real token problem:

- leverages `src/apply/ir.zig`, `src/apply/mod.zig`, `src/apply/operations.zig`, `src/apply/target.zig`, `src/ast.zig`, `src/splice.zig`;
- avoids companion `/home/kenzo/dev/pi-blitz` edits until explicitly authorized;
- can be benchmarked immediately as model-visible tool payload shape;
- focuses on old-code echo removal rather than wrapper-only trimming.

### Initial op set

Start with four operations, not the whole alias universe:

1. `ia` — insert after symbol/node (`insert_after_symbol` backend).
2. `rb` / `sb` — replace/set symbol body (`set_body` or `replace_body_span` backend).
3. `mn` — merge body chunk using keep markers (`merge_body_chunk` + `splice.zig`).
4. `batch` — same-file array of the above with rebasing and one write.

Do **not** start with rename/move/cross-file operations. They add correctness risk without proving the core token thesis.

## Proposed compact IR shape

Support both JSON-object and compact tuple form, with one canonical internal representation.

### Compact JSON object

```json
{"v":1,"f":"src/auth.ts","ops":[{"op":"rb","t":{"k":"function","n":"login"},"s":"const user = try db.find(email);\nreturn createSession(user);\n","g":{"h":"abc123","single":true,"parse":true}}]}
```

### Tuple shorthand for Pi/tool payload tests

```json
{"v":1,"f":"src/auth.ts","ops":[["rb","function","login","const user = try db.find(email);\nreturn createSession(user);\n"]]}
{"v":1,"f":"src/app.ts","ops":[["ia","function","handleRequest","fn healthCheck() !Status {\n    return .ok;\n}\n"]]}
{"v":1,"f":"src/a.ts","ops":[["mn","function","loadUser","const cached = cache.get(id);\n// ... existing code ...\nreturn user;\n"]]}
```

Key choices:

- `f` file path once per same-file batch.
- `ops` array allows same-file rebasing in one call.
- `t` target object or tuple fields carry kind/name; parent/signature/occurrence are optional.
- `s` snippet is new code only; old code appears only as tiny context anchors/markers when needed.
- `g` guards contain hash/single/parse flags.
- Default success output should be `ok f=<file> ops=<n> ranges=<...> parse=ok` or JSON equivalent when requested.

## Target resolver rules

Minimum target model:

```json
{"k":"function|method|class|object|section|any","n":"name","p":"optional parent","sig":"optional signature prefix/hash","occ":0,"range":"body|node"}
```

Resolution order:

1. Parse source with existing tree-sitter language detection.
2. Enumerate editable symbols with kind, name, byte range, body range, parent chain, and signature preview/hash.
3. Filter by `kind` + `name`.
4. If `parent` provided, filter by nearest ancestor symbol name.
5. If `sig` provided, filter by normalized declaration/signature preview or hash.
6. If `occ` provided, select stable occurrence after all filters.
7. If one match remains, resolve to `body` or `node` byte range.
8. If zero matches, fail with compact candidates near name/kind.
9. If multiple matches and no occurrence/signature, fail with compact candidate list; no fuzzy fallback.

This extends today’s `resolveEditableSymbol(source, root, symbol)` behavior without throwing away current helpers.

## Splice / validation / no-partial-write design

### Deterministic splice

Use `src/splice.zig` + `.pi/docs/fastedit-splice-algorithm.md` as the rulebook:

- split target body/node into lines;
- split snippet into lines;
- classify snippet lines as context/new/marker (`// ...`, `# ...`, language-aware variants later);
- marker-only shapes can mean insert/keep-rest;
- otherwise require enough anchors;
- reject large unmarked deletion gaps;
- preserve indentation relative to target body;
- preserve trailing newline behavior;
- produce merged target text only when confidence is deterministic.

### Validation gate

Before write:

1. parse IR and reject unknown aliases;
2. validate path and file size cap;
3. parse source cleanly unless opt-out;
4. resolve exact target;
5. compute replacement in memory;
6. parse merged file cleanly;
7. verify guard hash/range hash if supplied;
8. only then write via existing workspace/backup/atomic path.

After write:

- emit tiny success payload;
- preserve undo/backup id if already available;
- on failure, no partial writes for same-file batch; if future multi-file partials exist, report exact partial state like competitor does.

## Exact files/symbols likely touched by builder

First implementation slice likely touches:

- `src/apply/ir.zig`
  - add compact request structs / alias parsing helpers, or extend parse path without breaking current JSON.
- `src/apply/operations.zig`
  - add alias mapping and tuple helper parsing if not kept in `ir.zig`.
- `src/apply/target.zig`
  - add target descriptor `{kind,name,parent,signature,occurrence,range}` and deterministic candidate selection.
- `src/ast.zig`
  - add symbol enumeration metadata if `target.zig` cannot infer kind/parent/signature from existing node helpers.
- `src/apply/mod.zig`
  - add compact request entry path, same-file batch rebasing, validation gate integration, compact output mode.
- `src/splice.zig`
  - tighten/rename FastEdit-style marker/context merge behavior for `merge_body_chunk` and add focused tests.
- `src/test_all.zig`
  - ensure new tests are imported if split into new test files.
- Existing tests under `src/apply/*` or new focused tests near `test_support.zig`.
- Benchmark harness later: `bench/pi-matrix.ts` only after the CLI protocol is stable.

Avoid touching `/home/kenzo/dev/pi-blitz` until user authorizes exposing the new protocol in Pi runtime.

## Tests

Add focused Zig tests before broad benchmarks:

1. Parse compact JSON object into canonical internal op.
2. Parse tuple alias `rb`/`ia`/`mn`.
3. Unknown alias fails with compact error.
4. Duplicate symbol without `occ`/signature fails with candidates.
5. `occ` selects deterministic duplicate.
6. `parent` disambiguates nested/duplicate names.
7. `rb` replaces body without old-code echo.
8. `ia` inserts after symbol and preserves indentation/newline.
9. `mn` keep-marker splice preserves untouched body and rejects unsafe gaps.
10. Same-file batch rebases later op ranges after earlier edit.
11. Parse-failing snippet/source causes no write.
12. Hash/range guard mismatch causes no write.

Minimum checks after implementation:

```bash
zig build
zig build test
zig-out/bin/blitz apply --json <compact fixture>
```

## Benchmark rows after implementation

Do not claim savings until real Pi/tmux/Tokscale evidence exists. After CLI compact IR exists and Pi exposure is authorized or emulated honestly, run:

- 10+ tiny-edit streak: core vs compact IR; expect core may still win some isolated rows.
- 20+ mixed language/config/markdown/code streak.
- Same-file multi-edit scenario: compact batch should reduce repeated file/tool tax.
- Symbol-body edits: `replace_body` / `insert_after_symbol` where old-code echo reduction should be visible.
- Marker merge edit: snippet with `// ... existing code ...` compared to core/search-replace/apply_patch-style output.

Required metrics:

- correctness 100% for accepted rows;
- resident schema/skill tax;
- prompt/input/cache;
- tool args;
- model output;
- result payload;
- old-code echo removed;
- total model-visible context;
- explicit core fallback rows.

## What can be guaranteed vs measured

### Guaranteed by design

- The model no longer needs to restate old code for supported symbol-targeted ops.
- Ambiguous targets fail closed instead of fuzzily mutating the wrong symbol.
- Hash/parse/target gates can prevent writes before validation passes.
- Same-file batch can perform one parse/one write after range rebasing.
- Success payload can be made tiny.

### Only proven by Pi/tmux/Tokscale

- Net token/context savings vs Pi core `edit`.
- Whether alias/tuple DSL improves real model behavior or causes retries.
- Whether schema/skill overhead is low enough in Pi runtime.
- Whether route-selected cumulative streaks beat core.
- Whether Blitz is default-ready.

## Risks / rejected alternatives

- **Rejected:** making patch text/apply_patch parity the Blitz center. That still repeats old code/location context.
- **Rejected:** wrapper-only profile/skill trimming as the next main slice. It helps, but does not create a token-saving edit engine.
- **Rejected:** local ML/apply-model fallback in first slice. Deterministic splice must prove the easy path first.
- **Risk:** kind/parent/signature symbol enumeration may require language-specific query work; keep first languages narrow and explicit.
- **Risk:** terse aliases may reduce tokens but hurt model reliability. Benchmark JSON short-key vs tuple/freeform before defaulting.
- **Risk:** same-file batch rebase bugs can corrupt later edits; fail closed and test heavily.

## Recommended new-goal wording / criteria

Use this sharper goal center:

> Build Blitz into a Zig-native compact edit engine that removes old-code echo for supported symbol edits. The next slice implements a compact IR accepted by Blitz itself, deterministic AST target resolution, same-file batch rebasing, FastEdit-style snippet splice, guard/hash/parse validation, no partial writes, and tiny success output. Pi core `edit` remains the baseline/fallback. No token-saving or default-ready claim is valid until real Pi/tmux/Tokscale accepted rows with 100% correctness beat or honestly route to core.

Completion criteria for the new goal:

1. Save this competitor report and this Blitz/Zig report as required research artifacts.
2. Update the active Blitz 0.4 plan/spec to center Phase 2 on Zig-native compact IR before wrapper-only work.
3. Delegate implementation to `d5`, not main agent.
4. Implement compact IR v1 in `/home/kenzo/dev/blitz` only.
5. Add focused Zig tests for parsing, target ambiguity, splice, guards, parse validation, and same-file batch.
6. Run `zig build` and `zig build test`.
7. Benchmark against Pi core `edit` with real Pi/tmux/Tokscale before claiming savings.
8. If companion `/home/kenzo/dev/pi-blitz` work is needed, request/record authorization first.

## Confidence and gaps

- Confidence high: current repo has enough apply/target/splice infrastructure to implement compact IR v1 without new Zig/tree-sitter APIs.
- Confidence high: current benchmark data is negative for default readiness; new core protocol is necessary before more claims.
- Confidence medium: exact target enumeration complexity varies by language grammar; first slice should constrain language/target kinds.
- Gap: no second independent researcher report landed; this file is a main-agent replacement after subagent context failures.
- Gap: no fresh implementation branch or code changes yet; this is planning/research only.
