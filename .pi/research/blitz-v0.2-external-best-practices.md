# Research: blitz v0.2 external best practices

## Question
What external best practices and proven patterns should inform the blitz v0.2 hardening/parity spec for standalone Zig 0.16 CLI, tree-sitter AST-aware edits, deterministic code modification, patch validation, JSON tool API for LLM agents, token-saving edit ops, and benchmark methodology?

## Findings

### 1. Core architecture: deterministic, local, typed edit engine
- blitz already points at right product shape: standalone Zig 0.16 CLI, vendored tree-sitter runtime/grammars, structured apply IR, parse validation, backup/undo, and token-saving narrow ops. Repo source: `README.md`, `.pi/docs/blitz.md`, `build.zig`, `build.zig.zon`.
- OpenRewrite pattern supports this direction: encode changes as repeatable recipes over lossless syntax trees, not ad-hoc text rewrite. OpenRewrite emphasizes automated refactoring, recipes, multiple cycles until stable, tests, and Lossless Semantic Trees preserving formatting/source info. Sources: https://docs.openrewrite.org/, https://docs.openrewrite.org/concepts-and-explanations/recipes, https://docs.openrewrite.org/concepts-and-explanations/lossless-semantic-trees, https://docs.openrewrite.org/authoring-recipes/recipe-conventions-and-best-practices
- LSP `WorkspaceEdit` is strong model for multi-file future: versioned document edits, resource operations, change annotations, ordered application, and client capability negotiation. Source: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/

Spec clauses:
- `blitz apply` MUST accept typed operations, not freeform prose.
- Every operation MUST be deterministic from `{file snapshot, op JSON, CLI version, grammar version}`.
- Every write path MUST support `--dry-run` and `--diff` using same engine as apply.
- Multi-file v0.2 work SHOULD model ordered edits after LSP `WorkspaceEdit.documentChanges`, with file version/hash preconditions.

Acceptance criteria:
- Same request over same input bytes produces byte-identical output and JSON response.
- Operation schema includes `version`, `operation`, `target`, `edit`, `preconditions`, `validation`, `responseFormat`.
- Dry-run output equals later apply diff for same file hash.

Anti-patterns:
- Freeform `snippet` semantics where model must guess body-vs-node-vs-span.
- Hidden model routing or hosted fast-apply dependency in core path.
- Text-only global replace for code semantics.

### 2. Tree-sitter: use parse tree boundaries, queries, incremental validation, but keep byte-ranges source of truth
- Tree-sitter C API supports parser/tree lifecycle, incremental edits via `TSInputEdit` and `ts_tree_edit`, reparse using old tree, changed-range detection, included ranges, and query APIs. Sources: https://tree-sitter.github.io/tree-sitter/using-parsers/, https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html, https://tree-sitter-tree-sitter.mintlify.app/api/c-api/tree, https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h
- ast-grep and Semgrep prove value of AST pattern matching with constrained rule objects: positive pattern, inside/has/follows/precedes constraints, kind filters, regex/metavariable constraints. Sources: https://ast-grep.github.io/guide/introduction.html, https://ast-grep.github.io/reference/rule.html, https://semgrep.dev/docs/writing-rules/overview
- comby proves syntax-aware structural matching can be simpler than full AST for some transformations, but it is still template/rule based, not opaque prose. Source: https://github.com/comby-tools/comby

Spec clauses:
- Target resolution MUST return explicit byte range, point range, node kind, symbol name, and match count.
- Default safety MUST require single match unless caller opts into indexed/all matches.
- Parse validation MUST run after edit. `requireParseClean` defaults true for supported languages.
- Grammar support MUST be data-driven: node kinds, named declarations, body extraction, comment/string exclusion rules live in per-language grammar config.
- Query layer SHOULD expose `find`, `replace`, `insert`, `wrap`, and `rename` only through constrained schemas, not raw arbitrary query strings by default.

Acceptance criteria:
- Ambiguous symbols fail with actionable candidates.
- Edits never touch comments/strings during rename unless `includeComments`/`includeStrings` explicitly true.
- Incremental validation test verifies TSInputEdit byte/point delta correctness against full reparse.
- Each language fixture includes: function, method, class/type, nested symbol, duplicate symbol, comments, strings, syntax-error baseline.

Anti-patterns:
- Using AST only to locate approximate line, then regexing unconstrained spans.
- Hardcoding all language node names inside operation logic.
- Accepting parse errors as warning for deterministic edits by default.

### 3. Patch validation: preconditions, conflict detection, atomic writes, and idempotence
- LSP edits are version-aware and can include annotations/resource ops, proving clients need conflict detection before applying workspace changes. Source: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- OpenRewrite recipe practice stresses tests, recipe conventions, repeatable transformations, and avoiding unnecessary changes. Sources: https://docs.openrewrite.org/authoring-recipes/recipe-conventions-and-best-practices, https://docs.openrewrite.org/concepts-and-explanations/recipes
- jscodeshift codemods combine parser selection, transform functions, dry-run style workflows, and testable fixtures. Source: https://github.com/facebook/jscodeshift

Spec clauses:
- Request MUST support `preconditions.fileHash` and optional `preconditions.expectedSnippetHash` for target span.
- Response MUST include `changed`, `idempotent`, `oldHash`, `newHash`, `ranges`, `validation.parseClean`, and compact diff summary.
- Apply MUST use atomic write/replace and backup/undo snapshot.
- Validation pipeline: load -> hash check -> parse baseline -> resolve target -> compute edit -> overlap/conflict check -> apply to memory -> parse final -> optional formatter/lint command -> atomic write.

Acceptance criteria:
- Stale file hash fails without write.
- Re-running idempotent op reports `changed=false` or `idempotent=true`, no duplicate wrapper/import.
- Multi-edit op rejects overlapping ranges unless operation defines deterministic merge order.
- Crash/interruption test leaves either old file or new file, never truncated file.

Anti-patterns:
- Best-effort writes after partial validation.
- Applying multiple edits in ascending byte order without adjusting offsets or sorting descending.
- Returning only human text; agents need machine-readable failure codes.

### 4. JSON tool API for LLM agents: constrained schemas, low-entropy enums, compact responses
- Anthropic tool use and OpenAI function calling both rely on named tools with JSON schemas/parameters, letting models select tools and provide structured args. Sources: https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview, https://platform.openai.com/docs/guides/function-calling
- MCP tool spec defines tools as model-controlled functions with names, descriptions, input schemas, optional output schemas, and structured content. Source: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- JSON Schema 2020-12 provides portable validation vocabulary for object shapes, enums, required properties, bounds, and annotations. Sources: https://json-schema.org/draft/2020-12/json-schema-core, https://json-schema.org/draft/2020-12/json-schema-validation

Spec clauses:
- Tool schemas MUST be valid JSON Schema 2020-12 subset and published with CLI version.
- Use narrow operation tools for high-value patterns: `wrap_body`, `replace_return`, `insert_after_symbol`, `rename_identifier`, `multi_edit`, plus generic `apply` escape hatch.
- Inputs MUST prefer enums and small strings over natural-language instructions.
- Output MUST default compact: status, code, message, changed ranges, token-saving metrics, validation. Full diff opt-in.
- Error codes MUST be stable: `FILE_NOT_FOUND`, `HASH_MISMATCH`, `PARSE_ERROR`, `NO_MATCH`, `AMBIGUOUS_MATCH`, `CONFLICT`, `UNSUPPORTED_LANGUAGE`, `VALIDATION_FAILED`.

Acceptance criteria:
- Schemas reject unknown operation names and invalid option combos.
- Max string lengths and array lengths enforced before file access.
- Same schema usable by Pi/MCP/OpenAI/Anthropic wrappers with no semantic drift.
- Compact success response under 1 KB for common edits unless diff requested.

Anti-patterns:
- One mega-tool with broad `instruction: string`.
- Tool descriptions that encode hidden semantics not present in schema.
- Verbose diffs in default response causing token regression.

### 5. Token-saving edit ops: design around semantic anchors and minimal changed text
- Aider documents multiple edit formats; whole-file formats are simple but costly, while diff/search-replace formats reduce output but require precise matching. Source: https://aider.chat/docs/more/edit-formats.html
- Repo benchmark evidence already shows blitz narrow structured ops can save huge output/tool tokens for large body wrapping, while small one-line edits may not justify special ops. Sources: `README.md`, `.pi/research/compact-edit-ops.md`, `.pi/docs/blitz.md`.
- ast-grep/Semgrep/OpenRewrite/jscodeshift all point toward reusable codemod/recipe operations with explicit targets and constraints rather than one-off generated whole files. Sources above.

Recommended v0.2 op set:
- `wrap_body`: add prefix/suffix around body with indentation handling and idempotence marker/pattern.
- `replace_body_span`: replace matched subspan inside symbol body by anchor text, statement index, or AST predicate.
- `replace_return`: replace nth/last return expression in function/method.
- `insert_after_symbol` / `insert_before_symbol`: declaration-level insert.
- `insert_body_span`: insert before/after first/last matched statement.
- `rename_identifier`: scope-aware, excludes comments/strings by default.
- `ensure_import` / `remove_import`: idempotent import management.
- `multi_edit`: ordered list of typed ops with conflict detection.
- `workspace_edit`: post-v0.2 or preview-only multi-file, LSP-inspired, versioned.

Spec clauses:
- Operation payload MUST contain only changed text plus anchors/selectors.
- Each op MUST define idempotence behavior.
- Each op MUST define whitespace/indent ownership.
- Each op MUST define exact match semantics and ambiguity failure.

Acceptance criteria:
- Large wrapper benchmark: model/tool args remain O(wrapper text), not O(body size).
- No op requires model to echo unchanged function body.
- All ops have golden fixture tests with unchanged surrounding bytes except intended formatting.

Anti-patterns:
- Asking model for full replacement when only wrapper/import/return changed.
- Marker protocols requiring model to preserve large unchanged islands.
- Diff format as only API; useful fallback, weak semantic contract.

### 6. Benchmark methodology: separate correctness, provider output tokens, tool arg tokens, wall time, cold start
- hyperfine supports warmups, minimum/exact runs, parameter scans/lists, setup/preparation, and JSON/CSV export. Source: https://github.com/sharkdp/hyperfine
- Go benchmark guidance highlights repeated runs, noise awareness, and statistical comparison tooling. Source: https://go.dev/wiki/PerfBenchmarks
- Aider public leaderboards separate edit/refactor benchmarks and compare model/edit-format performance, useful precedent for reporting task class and correctness separately. Sources: https://aider.chat/docs/leaderboards/edit.html, https://aider.chat/docs/leaderboards/refactor.html

Spec clauses:
- Benchmark suite MUST report correctness first; token/time numbers invalid for failed output.
- Separate metrics: provider output tokens, tool-call arg tokens, total tokens, wall time, CLI CPU time, peak RSS, binary size, cold vs warm latency.
- Use fixture classes: one-line edit, large body wrap, return replacement, import ensure, multi-symbol edit, duplicate ambiguity, parse-error baseline, multi-file rename.
- Use N>=10 local CLI timing with warmup; use N>=5 live model/tool tests where cost allows.
- Export raw JSON plus markdown summary; include model name/version/date, CLI commit, grammar versions, OS/CPU.

Acceptance criteria:
- `bench` command produces machine-readable JSON with environment metadata and per-run samples.
- Regression gate thresholds exist for latency, token count, correctness, binary size.
- Public claims say `N`, model, date, task class, and whether failed baselines are excluded/included.

Anti-patterns:
- Reporting token savings for incorrect edits as win.
- Mixing provider output tokens with tool arg tokens without labels.
- Single-run public claims without date/model drift warning.

### 7. Zig 0.16 implementation constraints
- Repo pins `.minimum_zig_version = "0.16.0"` in `build.zig.zon` and comments build as Zig 0.16 stable in `build.zig`.
- Zig 0.16 release notes are official source for stdlib/build API drift. Source: https://ziglang.org/download/0.16.0/release-notes.html
- Zig download index is source for current release metadata. Source: https://ziglang.org/download/index.json

Spec clauses:
- v0.2 MUST pin Zig minor in `.zig-version`/`build.zig.zon` and CI.
- C interop MUST avoid runtime dynamic dependencies; tree-sitter runtime and grammars vendored or pinned by hash.
- Memory ownership MUST be explicit per command: arena for request lifetime, long-lived allocator only for caches.
- CLI MUST expose `blitz doctor` reporting Zig/runtime/grammar/tool schema versions.

Acceptance criteria:
- Clean `zig build test` on Linux/macOS targets in CI.
- Release artifact includes SBOM/license notice for vendored grammars/tree-sitter.
- `blitz --version --json` includes `zigVersion`, `treeSitterVersion`, `schemaVersion`, `gitCommit`.

Anti-patterns:
- Tracking Zig master APIs in released spec.
- Unpinned grammar submodules/tarballs.
- Depending on system tree-sitter shared library for distributed binary.

## Sources
- Repo: `README.md`
- Repo: `.pi/docs/blitz.md`
- Repo: `build.zig`
- Repo: `build.zig.zon`
- Repo: `.pi/research/compact-edit-ops.md`
- Tree-sitter using parsers: https://tree-sitter.github.io/tree-sitter/using-parsers/
- Tree-sitter advanced parsing: https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html
- Tree-sitter C API tree docs: https://tree-sitter-tree-sitter.mintlify.app/api/c-api/tree
- Tree-sitter C API header: https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h
- ast-grep intro: https://ast-grep.github.io/guide/introduction.html
- ast-grep rule reference: https://ast-grep.github.io/reference/rule.html
- Semgrep rule overview: https://semgrep.dev/docs/writing-rules/overview
- comby repo/docs: https://github.com/comby-tools/comby
- LSP 3.17 specification: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
- OpenRewrite docs: https://docs.openrewrite.org/
- OpenRewrite recipes: https://docs.openrewrite.org/concepts-and-explanations/recipes
- OpenRewrite LST: https://docs.openrewrite.org/concepts-and-explanations/lossless-semantic-trees
- OpenRewrite recipe best practices: https://docs.openrewrite.org/authoring-recipes/recipe-conventions-and-best-practices
- jscodeshift: https://github.com/facebook/jscodeshift
- Aider edit formats: https://aider.chat/docs/more/edit-formats.html
- Aider edit leaderboard: https://aider.chat/docs/leaderboards/edit.html
- Aider refactor leaderboard: https://aider.chat/docs/leaderboards/refactor.html
- Anthropic tool use: https://docs.anthropic.com/en/docs/agents-and-tools/tool-use/overview
- OpenAI function calling: https://platform.openai.com/docs/guides/function-calling
- MCP tools spec: https://modelcontextprotocol.io/specification/2025-06-18/server/tools
- JSON Schema core 2020-12: https://json-schema.org/draft/2020-12/json-schema-core
- JSON Schema validation 2020-12: https://json-schema.org/draft/2020-12/json-schema-validation
- hyperfine: https://github.com/sharkdp/hyperfine
- Go perf benchmarks: https://go.dev/wiki/PerfBenchmarks
- Zig 0.16 release notes: https://ziglang.org/download/0.16.0/release-notes.html
- Zig download index: https://ziglang.org/download/index.json

## Version / Date Notes
- Research date: 2026-05-22.
- Zig 0.16 and tree-sitter API details can drift; pin exact Zig patch, tree-sitter commit/tag, and grammar commits in the v0.2 spec.
- LSP cited version is 3.17; future LSP versions may refine workspace edit semantics.
- Anthropic/OpenAI/MCP tool specs evolve quickly; freeze blitz schemas independent of provider-specific wrappers.
- Aider leaderboard/model results are date/model dependent; use as methodology precedent, not stable performance claim.
- Repo claims cited from current working tree on branch `main`; not independently verified against published npm artifacts.

## Open Questions
- Which languages are mandatory for v0.2: current five plus TSX, or broader fastedit parity?
- Should `workspace_edit` ship preview-only in v0.2 or remain deferred until after single-file ops harden?
- Should blitz expose raw tree-sitter query tools to agents, or keep queries behind curated operation schemas only?
- What exact formatter/linter hooks are safe for deterministic validation without adding language toolchain dependencies?
- What public benchmark budget is acceptable for live model N>=5 tests per release?
- Should schema version follow CLI semver or independent `applyIRVersion`?

## Recommendation
Make blitz v0.2 spec a deterministic codemod hardening/parity lane, not smarter diff apply. Keep standalone Zig 0.16 binary and vendored tree-sitter. Define JSON Schema-backed narrow ops, AST target resolution, hash preconditions, parse-clean validation, atomic writes, compact machine-readable responses, and hyperfine/live-model benchmark gates. Use LSP `WorkspaceEdit` as model for future multi-file/versioned changes, OpenRewrite/jscodeshift as safety/test pattern, ast-grep/Semgrep/comby as constrained structural matching precedent, and Aider as evidence that edit format materially affects token/correctness tradeoffs.
