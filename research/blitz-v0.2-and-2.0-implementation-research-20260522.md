# Research: Blitz v0.2 implementation + 2.0 future/check lane

Date: 2026-05-22  
Status: implementation-oriented research report  
Active implementation scope: **Blitz v0.2**  
Complementary check lane: **Blitz 2.0 future/check docs only; non-authoritative for current release**

## Executive summary

Blitz v0.2 should continue as a hardening/reliability release for the existing Zig 0.16 CLI and Pi/MCP wrappers, not a scope rename to 2.0. The repo already contains the right building blocks: structured `blitz apply`, tree-sitter parsing, parse validation, backup/undo, per-file locks, MCP stdio bridge, and current Pi-facing narrow patch tools. The implementation risk is mostly architectural concentration and ambiguous contracts: `src/cmd_apply.zig` is too large, AST/symbol/body logic is spread across `src/symbols.zig`, `src/edit_support.zig`, and inline apply code, errors are not yet a stable machine contract everywhere, and future cross-file operations need LSP-style preconditions before writes.

Primary implementation recommendation:

1. Make v0.2 Phase 1 a **no-behavior-change extraction**: split `cmd_apply.zig`, add `grammar_config.zig`, centralize AST APIs in `ast.zig`, wire fallback payloads, and factor wrapper/MCP schema definitions.
2. Make v0.2 Phase 2 a **fail-closed robustness pass**: stable JSON error codes, marker tolerance that falls back to `needs_host_merge`, LCS memory guardrails, fixtures, and exact dry-run/apply parity.
3. Keep cross-file rename/move as **preview-first or gated** until file/target hash preconditions and all-range-before-write validation exist.
4. Use 2.0 docs only as a consistency checklist for schema/versioning, `WorkspaceEdit` semantics, result/error shapes, hash preconditions, operation coherence, and benchmark discipline.

## Local context inspected

Lifecycle/context:

- `tk` inspection was attempted; local shell reported `tk: command not found`. This is a tooling limitation for this run. No tk notes were written.
- `git status --short` showed markdown/research doc changes only at the time of research: `docs/blitz.md`, `specs/blitz-v0.2-hardening-and-parity.md`, new `docs/plans/`, new `docs/specs/`, and research markdown.
- Repo instructions read: `AGENTS.md`.
- Active and companion docs read: `README.md`, `docs/blitz.md`, `specs/blitz-v0.2-hardening-and-parity.md`, `reports/blitz-v02-ergonomics-plan.md`, `docs/specs/SPEC-2.0.md`, `docs/plans/PLAN-2.0.md`, `research/blitz-v0.2-external-best-practices.md`.
- Relevant source mapped: `src/cmd_apply.zig`, `src/ast.zig`, `src/fallback.zig`, `src/symbols.zig`, `src/edit_support.zig`, `src/splice.zig`, `src/incremental.zig`, `src/cli.zig`, `build.zig`, `mcp/blitz-mcp.ts`, and discovered companion wrapper locations `../pi-blitz/src/tools.ts` and `../pi-rig/extensions/pi-blitz`.

## External primary/source research

### Tree-sitter incremental parsing and AST range ownership

Sources:

- Tree-sitter advanced parsing: https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html
- Tree-sitter C API / parser docs: https://tree-sitter.github.io/tree-sitter/using-parsers/api.h
- Tree-sitter tree API: https://tree-sitter-tree-sitter.mintlify.app/api/c-api/tree

Implementation-relevant findings:

- Incremental parsing depends on accurate `TSInputEdit` byte offsets and point ranges. Blitz already has `src/incremental.zig` building byte/point edits and tests for UTF-8 byte columns, CRLF, and common prefix/suffix narrowing.
- `ts_tree_edit` updates an old tree before reparsing. Blitz should keep parse validation centralized so every operation follows the same path: parse before, resolve byte range, edit in memory, incremental reparse, full reparse fallback, reject on new parse errors.
- Tree-sitter queries and node kinds are useful, but byte ranges should remain the write source of truth. Operation modules should resolve AST nodes to explicit byte ranges before any string anchor matching.

Implications for v0.2:

- `src/ast.zig` should own `ResolvedSymbol`, `BodyRange`, declaration walking, match counts, and parse validation helpers.
- `src/grammar_config.zig` should own declaration kinds and body/comment behavior per language instead of scattering kind strings.
- Multi-edit operations must resolve all ranges before mutation and apply edits in descending byte order or through a single planned edit set to avoid offset drift.

### LSP WorkspaceEdit as future multi-file model

Sources:

- LSP 3.17 specification: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- WorkspaceEdit capability notes: https://lsp-devtools.readthedocs.io/en/latest/capabilities/workspace/workspace-edit.html

Implementation-relevant findings:

- `WorkspaceEdit` separates per-document text edits from document/resource operations and supports versioned document edits.
- Failure handling can be negotiated by clients (`abort`, transactional, undo-style variants). For Blitz, the safe local analogue is: dry-run first, validate all files, require hashes, write only after every edit plan validates.
- Ordered multi-resource edits can describe intermediate states; Blitz should not expose writable broad cross-file operations until it has explicit ordering, preconditions, and failure policy.

Implications for v0.2 and 2.0:

- v0.2 cross-file rename/move should be preview-first unless file hashes and all-or-nothing planning are implemented.
- 2.0 docs should keep `workspace_edit` as future/gated, not active v0.2 authority.
- Result schemas should include per-file ranges, old/new hashes, and failure codes before write paths expand.

### MCP tools, JSON Schema, and tool results

Sources:

- MCP tools spec 2025-06-18: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- MCP schema reference: https://modelcontextprotocol.io/specification/2025-06-18/schema
- JSON Schema 2020-12 core: https://json-schema.org/draft/2020-12/json-schema-core
- JSON Schema 2020-12 validation: https://json-schema.org/draft/2020-12/json-schema-validation

Implementation-relevant findings:

- MCP tools are described by names, descriptions, input schemas, and optional output schemas. Results can include text content and structured content when schemas exist.
- JSON Schema 2020-12 gives a stable vocabulary for enums, required fields, bounds, and shape validation. Blitz does not need to expose every schema feature; it should publish a provider-compatible subset with stable semantics.
- Tool wrappers should not encode hidden semantics only in prose. Invalid enum/field combinations should reject before invoking the binary where possible.

Implications for v0.2:

- Create a single operation/schema source for Pi and MCP wrappers where practical.
- Prefer narrow tools (`try_catch`, `replace_return`, `patch`) for common high-ROI operations, plus generic `apply` for expert use.
- Compact output remains default; full diff remains opt-in.
- Add stable error codes so wrappers classify by `code`, not stderr regex.

### Deterministic recipe/codemod practice

Sources:

- OpenRewrite recipes: https://docs.openrewrite.org/concepts-and-explanations/recipes
- OpenRewrite authoring practices: https://docs.openrewrite.org/authoring-recipes/recipe-conventions-and-best-practices
- jscodeshift repository: https://github.com/facebook/jscodeshift
- Semgrep rule overview: https://semgrep.dev/docs/writing-rules/overview
- ast-grep rule reference: https://ast-grep.github.io/reference/rule.html

Implementation-relevant findings:

- Mature codemod systems encode changes as repeatable, testable recipes/rules rather than freeform instructions.
- Good rules are constrained by syntax, kind, scope, and explicit match predicates.
- Fixture tests and no-op/idempotence tests are critical; repeat application should either produce the same result or report no changes.

Implications for v0.2:

- Each Blitz operation must specify exact payload fields, range ownership, ambiguity behavior, idempotence/no-op behavior, parse policy, no-mutation failure behavior, and fixtures.
- `patch` tuple ergonomics can remain, but canonical docs should map each tuple to the same typed operation semantics and error codes.

### Benchmark methodology

Sources:

- hyperfine: https://github.com/sharkdp/hyperfine
- Go performance benchmark guidance: https://go.dev/wiki/PerfBenchmarks
- Aider edit formats and benchmark framing: https://aider.chat/docs/more/edit-formats.html, https://aider.chat/docs/leaderboards/edit.html

Implementation-relevant findings:

- Benchmark claims need repeated runs, warmups, raw machine-readable output, and environmental metadata.
- Correctness must gate token/time claims. A fast or low-token failed edit is a failure, not a savings win.
- Provider output tokens and tool-call argument tokens are different metrics and must be reported separately.

Implications for v0.2:

- Keep current evidence-specific README/docs claims, but avoid generalizing from one operation class.
- Add regression gates per task class: correctness rate, malformed/retry rate, provider output tokens, tool-call arg tokens, wall time, cost, model/date/commit/N, binary size.

## v0.2 implementation recommendations

### 1. Split `src/cmd_apply.zig`

Current evidence: `src/cmd_apply.zig` contains request parsing, enum definitions, validation, operations, diffing, JSON output, target resolution, and tests in one large file.

Recommended target:

```txt
src/apply/
  mod.zig        command entry and high-level pipeline
  ir.zig         ApplyRequest/ApplyResult, operation payload parsing, schema constants
  errors.zig     stable codes and JSON error mapping
  target.zig     symbol/target resolution glue over ast.zig
  operations.zig typed operation execution
  patch.zig      compact tuple expansion into typed operations
  diff.zig       compact summaries and opt-in unified diff
  validate.zig   parse-before/after and dry-run/apply parity helpers
```

Acceptance:

- `src/cmd_apply.zig` is deleted or reduced only during a short-lived migration branch, not kept as a permanent second source of truth.
- `zig build test` passes after each extraction slice.
- Public `blitz apply` behavior and JSON fields are unchanged during the extraction phase.
- Operation-specific tests move next to modules without semantic changes.

Risk:

- Large extraction can break hidden behavior. Mitigate by first adding golden CLI snapshots for representative apply requests before moving code.

### 2. Add `src/grammar_config.zig`

Recommended fields:

```zig
pub const GrammarConfig = struct {
    language: bindings.Language,
    name: []const u8,
    extensions: []const []const u8,
    comment_styles: []const []const u8,
    declaration_kinds: []const []const u8,
    body_kinds: []const []const u8,
    name_fields: []const []const u8,
    brace_body: bool,
};
```

Acceptance:

- No language-specific declaration/comment/body lists remain in operation modules.
- `edit_support.commentStylesFor`, symbol declaration kinds, doctor grammar reporting, and future grammar additions read from config.
- Adding a grammar requires build entry + config entry + fixtures, not edits throughout apply logic.

Risk:

- Different languages share node kind strings with different semantics. Mitigate by fixture tests per language and by keeping body extraction language-aware.

### 3. Centralize AST APIs in `src/ast.zig`

Current evidence: `src/ast.zig` is a placeholder; `src/symbols.zig` owns a small recursive resolver; `src/edit_support.zig` owns body discovery; `src/cmd_apply.zig` has inline target handling.

Recommended APIs:

```zig
pub const ResolvedSymbol = struct {
    node: bindings.Node,
    name: []const u8,
    kind: []const u8,
    node_range: ByteRange,
    body_range: ?ByteRange,
    match_count: usize,
};

pub fn parseStrict(... ) !bindings.Tree;
pub fn resolveSymbol(source, root, config, target) !ResolvedSymbol;
pub fn bodyRange(source, config, node) ?ByteRange;
pub fn walkDeclarations(source, root, config, visitor) !void;
pub fn validateCandidate(...) !ValidationResult;
```

Acceptance:

- `symbols.zig` is deleted or a compatibility re-export under 20 LOC.
- `edit_support.zig` and apply operations call `ast.*` for symbol and body logic.
- Ambiguous duplicate symbols return candidates or count instead of first-match silently where structured ops require uniqueness.

### 4. Wire `src/fallback.zig`

Current evidence: `fallback.zig` defines `ScopePayload` and wire keys but no active edit pipeline integration was observed.

Recommended behavior:

- Marker failures (`MarkerGrammarInvalid`, `AmbiguousAnchor`, `AnchorNotFound`) should return structured `needs_host_merge` payload with exit 0 only for legacy `edit` marker path where host merge is expected.
- Structured `apply` operations should generally reject with stable `code` unless the operation explicitly supports fallback.
- Payload should include file, symbol, target range, reason code, and enough excerpt context for a host edit without dumping whole files.

Acceptance:

- Malformed marker fixture returns `status: "needs_host_merge"`, not a hard non-JSON abort.
- Pi/MCP wrappers recognize `needs_host_merge` by parsed JSON status.
- No fallback path mutates disk.

### 5. Structured error taxonomy

Recommended stable codes:

```txt
INVALID_JSON
UNSUPPORTED_SCHEMA_VERSION
UNSUPPORTED_OPERATION
INVALID_FIELD
MISSING_FIELD
FILE_NOT_FOUND
OUTSIDE_WORKSPACE
UNSUPPORTED_LANGUAGE
PARSE_ERROR_BEFORE
PARSE_ERROR_AFTER
SYMBOL_NOT_FOUND
SYMBOL_AMBIGUOUS
BODY_NOT_FOUND
NO_MATCH
AMBIGUOUS_MATCH
OVERLAPPING_EDITS
HASH_MISMATCH
VALIDATION_FAILED
BACKUP_FAILED
IO_ERROR
NEEDS_HOST_MERGE
```

Acceptance:

- New `apply --json` failures always emit parseable JSON with `status: "rejected" | "error"`, `code`, `message`, optional `suggest`.
- Pi/MCP wrappers branch on `code`/`status`, not stderr regex.
- Human stderr may exist but is not the integration contract.

### 6. Marker tolerance

Recommended v0.2 behavior:

- Legacy marker splice stays compatibility path, not primary agent API.
- Multiple markers: use first only if deterministic and warn in structured metadata; otherwise reject to fallback.
- Mixed comment styles: normalize only when grammar config provides a single obvious line-comment marker; otherwise reject to fallback.
- `@keep lines=N`: retry a bounded ±3-line expansion before fallback.
- Structured ops should not use fuzzy marker tolerance by default.

Acceptance:

- Tests cover multiple markers, mixed style, keep expansion, and fallback signal.
- Existing strict marker fixtures still pass.

### 7. LCS memory optimization

Current evidence: `src/splice.zig` has marker-aware diff machinery. The v0.2 spec notes O(n*m) table risk for large bodies.

Recommended approach:

- Skip LCS entirely when there is no marker.
- Add size guard for marker splice inputs before allocating an O(n*m) table.
- For marker path, add a two-row LCS length pass or Hirschberg-style split only if necessary; otherwise reject with a clear code such as `SPLICE_TOO_LARGE` and `needs_host_merge` for legacy edit.
- Track heap allocations in a fixture benchmark for 500/2000-line bodies.

Acceptance:

- Marker-less direct replacement has no diff-table allocation.
- Large marker splice either completes under memory threshold or returns deterministic non-mutating fallback.
- `zig build test` includes threshold behavior.

### 8. Pi-blitz and MCP tool factory/schema reuse

Current evidence: `mcp/blitz-mcp.ts` already exposes `blitz_doctor`, `blitz_read`, `blitz_patch`, `blitz_try_catch`, `blitz_replace_return`, and `blitz_undo` through schemas. Companion `../pi-blitz/src/tools.ts` exists for extension work.

Recommended approach:

- Define a shared tool descriptor shape in the Pi extension and use it to generate Pi tool registration and docs snippets.
- Keep MCP schemas close to the same descriptor or generated from the same JSON fragments where practical.
- Add output schema/result expectations once Blitz emits stable `code` and `structuredContent`-ready result fields.
- Maintain narrow tools for common operations, because models are more reliable with low-entropy schemas than with one broad union-shaped `edit` object.

Acceptance:

- Same operation names and option names across CLI, Pi, MCP, README, and skill docs.
- Wrapper tests verify invalid enum/field combos fail before spawning Blitz where possible.
- Compact responses remain under 1 KB without `include_diff` for common successes.

### 9. Cross-file rename/move safety

Recommendation:

- For v0.2, implement `rename-all` as dry-run/preview first, then write only after hash preconditions, all-file parse validation, overlap checks, and backup plan are present.
- Defer `move-to-file` writes unless scoped to TS/JS and protected by the same preconditions. Symbol moves require import rewriting and caller/reference checks; they should not be mixed with Phase 1 hardening.

Acceptance:

- `--dry-run` is default for cross-file operations.
- Real writes require explicit `--apply` and file hashes or a clean workspace policy.
- All target files parse before and after.
- Failures occur before any write.

### 10. Caller/reference safety checks

Recommendation:

- Before deletion or move operations, build a bounded reference scan over supported source files.
- Report callers/references in structured JSON and require `--force` to proceed with destructive delete semantics.
- Start with dry-run reference reporting; delay mutation until cross-file engine is mature.

Acceptance:

- Deleting a referenced symbol rejects with references.
- `--force` is explicit and auditable.
- Wrapper tools surface references rather than hiding them in text.

## Complementary 2.0 future/check recommendations

2.0 should remain a future consistency lens. It should not redefine v0.2 release work.

### Schema/versioning

- Add future `blitz schema --json` and `blitz --version --json` ideas to 2.0 docs only.
- Keep apply IR version independent enough to evolve without implying CLI major version changes.
- Publish JSON Schema-compatible docs for operation inputs and result outputs.

### Stable result/error schema

- Future result shape should include `status`, `code`, `message`, `operation`, `file`, `language`, `changed`, validation fields, ranges, metrics, hashes, compact diff summary, and optional full diff.
- Error codes should be stable and documented; wrappers should not parse prose.

### Hash preconditions

- Add `preconditions.fileHash`, `preconditions.targetHash`, and maybe `expectedSnippetHash` in future request shapes.
- Recheck hashes immediately before write, after acquiring locks.

### WorkspaceEdit ordering/atomicity

- Model multi-file operations after LSP `WorkspaceEdit.documentChanges` with ordered edits and failure policy.
- Keep writable workspace edit gated until all files can be validated first and recover cleanly on failure.

### Operation coherence

Every operation should have a row in a compatibility matrix:

- payload fields;
- target range ownership;
- occurrence and ambiguity behavior;
- idempotence/no-op semantics;
- parse policy;
- no-mutation failure behavior;
- fixture coverage;
- wrapper tool names.

### Benchmark methodology

2.0 docs should keep the benchmark checklist current but non-authoritative:

- correctness/golden first;
- provider output tokens separate from tool-call arg tokens;
- wall time/cost/model/date/commit/N;
- malformed/retry rate;
- cold/warm CLI timing;
- raw JSON artifacts plus markdown summaries.

## Implementation-ready acceptance checklist

### v0.2 Phase 1 gate

- `zig build test`
- `zig build`
- `blitz apply --json` fixtures produce byte-identical responses before/after extraction except allowed `wallMs` differences.
- No permanent duplicate implementations of apply, symbol resolution, grammar config, or error mapping.
- Pi/MCP wrapper command names and operation names match docs.

### v0.2 Phase 2 gate

- `zig build test`
- Legacy marker failure fixtures return `needs_host_merge` where specified.
- Structured apply failures emit JSON `code` fields.
- LCS large-body guard tested.
- Fixture expansion covers async function, class method, TSX component, arrow return, nested returns, duplicate symbols, parse-error baseline.
- Companion Pi extension: `bun run typecheck && bun test` if available.

### Cross-file gate

- Preview-only first.
- All files parse before/after in memory.
- File/target hash mismatch rejects before write.
- Overlaps rejected before write.
- Backup plan and failure behavior documented.

### Release claim gate

- Raw benchmark JSON and markdown summary exist.
- Public claims include N, model, date, commit, task class.
- Failed/malformed rows counted in correctness rate.
- Metrics separated: provider output tokens, tool-call arg tokens, wall time, cost, binary size.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Big `cmd_apply.zig` split changes behavior accidentally | Regression in shipped apply ops | Add snapshot fixtures before extraction; one module extraction per commit/branch |
| AST centralization overgeneralizes languages | Body ranges wrong for Python/TSX/Rust | Per-language config + fixtures before grammar expansion |
| Error schema churn breaks wrappers | Pi/MCP misclassify failures | Introduce `code` fields while keeping old text until wrappers migrate |
| Marker tolerance edits wrong span | Silent corruption | Tolerance only in legacy path; structured ops exact by default; fallback on ambiguity |
| Cross-file writes partially apply | Corrupted workspace | Preview-first; hash preconditions; all-range resolve; all-or-nothing write gate |
| Benchmark claims overfit one fixture | Misleading marketing | Report task class and correctness; keep raw artifacts |

## Open decisions

1. Should v0.2 include writable `rename-all`, or should it ship preview-only and defer writes until hash preconditions are implemented?
2. Should `move-to-file` remain deferred entirely, or ship TS/JS dry-run preview only?
3. Should `blitz schema --json` be pulled into v0.2 wrapper work, or kept in 2.0 future lane?
4. What exact maximum body/line threshold should guard marker splice LCS allocation?
5. Should stable error codes be introduced for all commands or only `apply --json` first?
6. What public live-model benchmark budget is acceptable for v0.2 release claims?

## Recommended builder tickets

Because `tk` was unavailable in this environment, these are ticket-ready slices rather than actual tk records:

1. `v0.2-phase1-apply-split`: Add apply golden snapshots, split `src/cmd_apply.zig` into `src/apply/*`, no behavior change.
2. `v0.2-phase1-grammar-config`: Add `src/grammar_config.zig`, migrate comments/declaration/body kinds.
3. `v0.2-phase1-ast-api`: Implement `src/ast.zig` as canonical parse/symbol/body API; reduce/delete `symbols.zig`.
4. `v0.2-phase1-fallback-wire`: Wire legacy marker failures to `needs_host_merge` JSON.
5. `v0.2-phase2-error-codes`: Add stable JSON error taxonomy for `apply --json`; migrate wrappers away from regex.
6. `v0.2-phase2-marker-lcs-fixtures`: Marker tolerance, LCS memory guard, and expanded fixtures.
7. `v0.2-wrapper-schema-factory`: Pi/MCP tool descriptor/schema reuse and output contract alignment.
8. `v0.2-cross-file-preview`: Preview-first `rename-all` with parse/hash/overlap plan; no writes until reviewed.

## Source links

- Tree-sitter advanced parsing: https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html
- Tree-sitter parser API: https://tree-sitter.github.io/tree-sitter/using-parsers/api.h
- Tree-sitter tree API: https://tree-sitter-tree-sitter.mintlify.app/api/c-api/tree
- LSP 3.17 specification: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- LSP workspace edit capability notes: https://lsp-devtools.readthedocs.io/en/latest/capabilities/workspace/workspace-edit.html
- MCP tools spec 2025-06-18: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- MCP schema reference: https://modelcontextprotocol.io/specification/2025-06-18/schema
- JSON Schema 2020-12 core: https://json-schema.org/draft/2020-12/json-schema-core
- JSON Schema 2020-12 validation: https://json-schema.org/draft/2020-12/json-schema-validation
- OpenRewrite recipes: https://docs.openrewrite.org/concepts-and-explanations/recipes
- OpenRewrite recipe practices: https://docs.openrewrite.org/authoring-recipes/recipe-conventions-and-best-practices
- jscodeshift: https://github.com/facebook/jscodeshift
- Semgrep rule overview: https://semgrep.dev/docs/writing-rules/overview
- ast-grep rule reference: https://ast-grep.github.io/reference/rule.html
- hyperfine: https://github.com/sharkdp/hyperfine
- Go performance benchmark guidance: https://go.dev/wiki/PerfBenchmarks
- Aider edit formats: https://aider.chat/docs/more/edit-formats.html
