# Blitz v0.2 — Internal Hardening, Robustness, Feature Parity

Status: **DRAFT**
Scope: `codewithkenzo/blitz` (Zig CLI) + `codewithkenzo/pi-blitz` (TS extension)
Baseline: `0.1.0-alpha.9` at commit HEAD
Target: `0.2.0` release

## Context

Blitz is a 6,700 LOC Zig 0.16 AST-aware edit CLI with 5 tree-sitter grammars, marker-based splice merging, incremental re-parse validation, backup/undo, and 9 operation types. The pi-blitz extension wraps it as 12 Pi tools via a 1,587 LOC TypeScript layer using Effect v4.

Inspiration project (fastedit, Python) has 13k LOC source, 16 languages, cross-file rename/move, a 1.7B ML model for complex merges, MCP server, and pre-tool hooks. Blitz matches fastedit's deterministic path (74% of edits) at zero runtime cost. The gap is in language coverage, cross-file operations, and fallback resilience.

## Architecture audit findings (2026-05-11)

### Strengths
- Splice engine (`splice.zig`, 697 LOC) is a proper DP LCS implementation with marker-aware merge
- Tree-sitter FFI layer (`bindings.zig`, 383 LOC) is clean hand-written C interop, no `@cImport`
- Incremental re-parse (`incremental.zig`, 142 LOC) computes TSInputEdit deltas correctly
- Marker parser uses hand-rolled state machines (correct Zig approach)
- Allocator discipline is consistent throughout — proper `errdefer`, arena per tool call
- Error unions used correctly, no catch-unreachable slop
- pi-blitz validation layer is thorough — every operation type gets specific error messages
- TypeBox schemas properly constrained (maxLength, minItems, union types)
- Per-path mutex locking is correct for concurrent tool calls

### Weaknesses
- `cmd_apply.zig` is 1,900 LOC (28% of codebase) — monolith handling 9 operations, JSON IR parsing, target resolution, edit application, diff generation, validation all in one file
- `ast.zig` is a 12-line placeholder while tree-sitter is used directly everywhere
- `fallback.zig` (59 LOC) is fully written but not wired into the edit pipeline
- `symbols.zig` hardcodes 13 tree-sitter node kind strings — should come from grammar config
- `pi-blitz/tools.ts` (1,587 LOC) repeats identical tool-definition pattern 12 times
- LCS diff in splice is O(n*m) space — no optimization for large bodies
- Marker contract is too strict — mixed styles, multiple markers, ambiguous placements all hard-abort
- Only 5 languages (TypeScript, Rust, Go, Python, Zig) vs fastedit's 16
- No cross-file operations (rename-all, move-to-file)
- No MCP server (planned in roadmap but not started)
- No caller-safety check before delete operations

---

## Phase 1 — Internal Hardening

**Goal**: Clean codebase organization, eliminate dead code, wire existing unwired modules. Zero behavioral changes. Zero regression risk.

**Estimated effort**: 2-3 days

### 1.1 Split `cmd_apply.zig` into focused modules

Current: `src/cmd_apply.zig` (1,900 LOC) handles everything.

Target structure:
```
src/apply/
  mod.zig           — public entry point, command dispatch (~100 LOC)
  operations.zig    — per-operation execution logic (~600 LOC)
  target.zig        — symbol resolution, MatchKind, kind filtering (~300 LOC)
  diff.zig          — diff generation, compact summary output (~250 LOC)
  validate.zig      — parse validation, error classification (~200 LOC)
  ir.zig            — JSON IR request/response parsing (~400 LOC)
```

Rules:
- `mod.zig` imports and delegates to the others
- `main.zig` changes from `const cmd_apply = @import("cmd_apply.zig")` to `const cmd_apply = @import("apply/mod.zig")`
- All existing tests must pass without modification
- No new behavior — pure extraction

Acceptance:
- `zig build test` passes
- `zig build` produces same binary (verify with `sha256sum` on same commit)
- Each new file has clear single responsibility
- `cmd_apply.zig` is deleted, not left as a re-export wrapper

### 1.2 Wire `ast.zig` as shared symbol resolution layer

Current: `src/ast.zig` is a 12-line placeholder. Symbol walking logic is duplicated across `symbols.zig` (85 LOC), `edit_support.zig` (285 LOC), and inline in `cmd_apply.zig`.

Target:
- `ast.zig` becomes the canonical API for AST operations:
  - `resolveSymbol(tree, name, kind_hint, match_strategy)` — replaces `symbols.findEditableSymbolNode`
  - `bodyRange(node)` — replaces scattered `findBodyNode` calls
  - `walkDeclarations(tree, language)` — replaces hardcoded 13-kind lists
- `symbols.zig` becomes a thin re-export or is absorbed into `ast.zig`
- Declaration kinds move from hardcoded strings to per-grammar config arrays
- `edit_support.zig` calls `ast.*` instead of doing its own tree walks

Acceptance:
- No inline `switch` on node kind strings outside `ast.zig`
- `symbols.zig` either deleted or reduced to < 20 LOC re-export
- All existing symbol resolution behavior preserved
- `zig build test` passes

### 1.3 Wire `fallback.zig` into edit pipeline

Current: `src/fallback.zig` (59 LOC) implements `needs_host_merge` payload generation but is never called.

Target:
- When marker splice fails with `MarkerGrammarInvalid`, `AmbiguousAnchor`, or `AnchorNotFound`, instead of hard-aborting:
  1. Emit a structured `needs_host_merge` JSON payload to stdout
  2. Exit code 0 (not error — the agent can handle this)
  3. Payload includes: `{ status: "needs_host_merge", file, symbol, reason, original_body_bytes }`
- `cmd_edit.zig` calls `fallback.emitNeedsHostMerge` when splice returns error
- pi-blitz `classifySuccessStdout` already handles `needs_host_merge` — verify it still works

Acceptance:
- Marker failure no longer aborts edit — returns structured fallback signal
- pi-blitz receives `needs_host_merge` status and surfaces it to the agent
- `zig build test` passes
- New test: malformed marker → `needs_host_merge` JSON on stdout, exit 0

### 1.4 Extract grammar config from hardcoded values

Current: Language detection in `edit_support.zig`, symbol kinds in `symbols.zig`, comment styles in `edit_support.commentStylesFor` — all hardcoded switch/if chains.

Target:
```
src/grammar_config.zig — per-language config registry
  struct GrammarConfig {
    extension: []const u8,
    language_name: []const u8,
    grammar_fn: *const fn() *const TSLanguage,
    comment_styles: []const []const u8,
    declaration_kinds: []const []const u8,
    brace_language: bool,  // TS/Rust/Go vs Python
  }
  // Array of all supported configs, indexed/looked up by extension
```

- `edit_support.zig` calls `grammar_config.forExtension(ext)` instead of inline switches
- `symbols.zig` uses `config.declaration_kinds` instead of hardcoded list
- Adding a new grammar becomes: add config entry + vendor grammar dir + build.zig entry

Acceptance:
- Zero inline `if extension == ".ts"` or `switch kind` on language-specific strings outside `grammar_config.zig`
- `zig build test` passes
- `blitz doctor` still reports all grammars correctly

### 1.5 Refactor pi-blitz tool definitions with factory pattern

Current: `src/tools.ts` (1,587 LOC) repeats identical schema + execute + runWithProgress pattern 12 times.

Target:
- Extract `defineBlitzTool<TParams, TDetails>(opts)` factory:
  ```ts
  type BlitzToolDef<TParams, TDetails> = {
    name: string;
    label: string;
    description: string;
    parameters: TObject;
    buildArgs: (params: TParams) => { argv: string[]; stdin?: string };
    parseResult: (stdout: string, params: TParams) => BlitzToolResult;
    requiresLock?: boolean;
    timeoutMs?: number;
  };
  ```
- Each tool becomes a declarative config object instead of a full function
- Shared `runWithProgress` + `locks.withLock` + `runTool` wrapper lives in the factory
- Estimated reduction: ~400-500 LOC

Acceptance:
- `bun run typecheck` passes
- `bun test` passes
- All 12 tools produce identical results for identical inputs
- No behavioral change — pure structural refactor

### 1.6 Clean up dead/stale code

- Delete `tests/` directory if still empty (per gap report)
- Remove stale "scaffold" / "pre-alpha" strings from `cli.zig` and README
- Verify `compose_body` is either implemented or removed from the schema (roadmap says it was removed but verify)
- Consolidate version strings to one source of truth

---

## Phase 2 — Robustness and Hit Rate

**Goal**: Increase real-world edit success rate. Fewer aborted edits, more tolerant markers, better test coverage.

**Estimated effort**: 4-5 days

### 2.1 Loosen marker contract

Current: Marker parsing rejects:
- Mixed comment styles (e.g., `// ...` then `# ...`) → `MarkerGrammarInvalid`
- Multiple markers in one snippet → `MarkerGrammarInvalid`
- `@keep` with ambiguous placement → `AmbiguousAnchor`
- `@keep` when deletion window too small → `AnchorNotFound`

All of these hard-abort the edit.

Target tolerance levels:

**Level 1 (implement now)**:
- Multiple markers: use the first marker, ignore subsequent (warn in stderr)
- Mixed styles: if snippet language implies one comment style (from grammar config), normalize all markers to that style
- `@keep` anchor not found in current deletion window: expand window by ±3 lines and retry before failing
- After all tolerance attempts fail: emit `needs_host_merge` (wired in 1.3) instead of hard abort

**Level 2 (future)**:
- Fuzzy marker matching (allow `// ... existing ...` with extra words)
- Auto-detect marker intent from snippet structure

Acceptance:
- Snippet with `// ... existing code ...` followed by `// ... existing code ...` succeeds (uses first)
- `@keep lines=5` in a 3-line deletion window attempts window expansion before failing
- All tolerance paths tested
- `zig build test` passes
- No regression in existing marker test cases

### 2.2 Fixture expansion and test coverage

Current test gaps (per gap report):
- No tests for async/await patterns
- No tests for class method body wraps
- No tests for arrow function return replacement
- No tests for TSX function components
- No tests for nested returns with explicit occurrence
- No tests for multi-symbol return replacement
- No integration tests for pi_blitz_edit marker success/failure
- No coverage for `--json` marker-path correctness

Target:
- Add fixture files under `test/fixtures/` for each pattern above
- Each fixture gets a corresponding test in the relevant module
- Add `test/fixtures/README.md` documenting each fixture and what it tests
- Add integration test in pi-blitz: `test/smoke-apply.test.ts` that actually invokes blitz binary

Acceptance:
- `zig build test` includes new fixtures
- `bun test` in pi-blitz includes apply integration tests
- Coverage of all 9 operation types against each fixture pattern

### 2.3 LCS diff optimization for large bodies

Current: `buildDiffOps` in `splice.zig` allocates `(m+1) * (n+1) * sizeof(usize)` table — for a 500-line function body this is ~1MB. For a 2000-line body this is 16MB.

Target:
- Implement sliding-window LCS (2 rows instead of full table) for the forward pass
- Only build the full table when backtrace is needed (i.e., when markers are present)
- For marker-less direct replacement, skip diff entirely
- Add a body-size threshold (configurable, default 1000 lines) above which the operation rejects with a clear error suggesting `set_body` instead

Acceptance:
- Memory usage for splice on 500-line body drops to O(min(m,n)) for forward pass
- No behavioral change for bodies under 1000 lines
- `zig build test` passes
- Benchmark: splice on 2000-line body uses < 1MB heap

### 2.4 Structured error taxonomy

Current: Error classification is ad-hoc regex matching in pi-blitz (`classifySoft`) and string comparisons in zig.

Target:
- Define canonical error enum in zig:
  ```zig
  pub const EditError = error{
      SymbolNotFound,
      SymbolAmbiguous,
      BodyNotFound,
      MarkerGrammarInvalid,
      MarkerAmbiguous,
      MarkerAnchorNotFound,
      ParseFailedBefore,
      ParseFailedAfter,
      BackupFailed,
      FileNotFound,
      LanguageUnsupported,
      EditRangeInvalid,
  };
  ```
- Each error maps to a structured JSON output: `{ "status": "error", "code": "SYMBOL_NOT_FOUND", "message": "...", "suggest": "..." }`
- pi-blitz `classifySoft` switches from regex to JSON `code` field matching
- Remove fragile regex patterns like `/^No occurrences of /m.test(stderr)`

Acceptance:
- All CLI error outputs are valid JSON with `code` field
- pi-blitz classifies errors by `code` field, not stderr regex
- `zig build test` passes
- `bun test` passes

---

## Phase 3 — Feature Parity

**Goal**: Close the gap with fastedit on language coverage, cross-file operations, and integration surface.

**Estimated effort**: 10-14 days

### 3.1 Grammar expansion (priority order)

Add tree-sitter grammars for:

1. **Java** — enterprise codebase work, Spring/Android
2. **C++** — systems work, game dev
3. **C#** — Unity, .NET enterprise
4. **Ruby** — Rails, scripting
5. **Kotlin** — Android
6. **Swift** — iOS
7. **PHP** — web legacy

Per-grammar checklist:
- Vendor grammar under `grammars/tree-sitter-<lang>/src/parser.c` + `scanner.c`
- Add to `build.zig` compilation
- Add `GrammarConfig` entry in `grammar_config.zig` (from 1.4)
- Add comment styles
- Add declaration kinds
- Test: `blitz read <fixture>` produces correct structure
- Test: `blitz edit <fixture>` finds and replaces symbols
- Test: `blitz doctor` reports the grammar as linked

Acceptance per grammar:
- `zig build test` includes grammar-specific tests
- `blitz doctor` reports grammar as available
- `blitz read` on a real file in that language produces correct AST structure
- `blitz edit --replace <symbol>` on a real function in that language succeeds

### 3.2 Cross-file rename (`blitz rename-all`)

New command:
```bash
blitz rename-all <old_name> <new_name> [--root <dir>] [--dry-run] [--kind function|method|class|variable|type]
```

Implementation:
- Walk directory tree from `--root` (default: cwd)
- Skip vendor/dependency directories: `node_modules/`, `vendor/`, `.git/`, `target/`, `build/`, `dist/`
- For each source file matching a known extension:
  1. Parse with tree-sitter
  2. Find all identifier nodes matching `old_name`
  3. Filter by kind (if specified) using parent node type
  4. Skip identifiers inside strings, comments, docstrings
  5. Collect replacements
- Apply all replacements atomically (all or nothing)
- Report: files changed, identifiers renamed, skipped locations

Acceptance:
- Renames a function across 5 files correctly
- Skips string/comment occurrences
- `--dry-run` reports without writing
- `--kind function` only renames function declarations/calls, not variables
- pi-blitz tool `pi_blitz_rename_all` wraps this command
- `zig build test` passes

### 3.3 Cross-file symbol move (`blitz move-to-file`)

New command:
```bash
blitz move-to-file <symbol> <target_file> [--source <file>] [--dry-run]
```

Implementation:
- Parse source file, find symbol declaration node
- Extract the full declaration (signature + body)
- Remove from source file
- Insert at end of target file (or before first export/closing brace depending on language)
- Rewrite imports:
  - Remove unused import from source
  - Add necessary import to target
  - Update references in both files
- Per-language import syntax handling (this is the hard part):
  - TS/JS: `import { X } from "./source"`
  - Python: `from module import X`
  - Rust: `use crate::module::X`
  - Go: `"module/pkg"` with package-level rename
  - Java/C#/Kotlin: fully qualified class names

This is the largest single feature. fastedit's `move_to_file.py` is 2,076 LOC for a reason.

Phased approach:
1. v0.2.0: TS/JS only (highest ROI for agent workloads)
2. v0.2.1: Python, Rust
3. v0.2.2: Go, Java, C#

Acceptance for v0.2.0 (TS/JS only):
- Moves a function from `a.ts` to `b.ts`
- Adds import to `b.ts`
- Updates import in `a.ts` if other symbols reference the moved one
- Removes unused import from `a.ts`
- `--dry-run` reports changes without writing
- `blitz doctor` on both files shows valid AST after move
- pi-blitz tool `pi_blitz_move_to_file` wraps this command

### 3.4 MCP stdio server (`blitz-mcp`)

Already planned in roadmap. Spec from `release-roadmap-locked-2026-04-27.md`:

Transport: stdio (JSON-RPC over stdin/stdout)

Protocol:
- `initialize` — return capabilities
- `tools/list` — return tool definitions
- `tools/call` — dispatch to blitz command

Candidate MCP tools (from roadmap):
```
blitz_read, blitz_apply, blitz_wrap_body, blitz_try_catch,
blitz_replace_return, blitz_patch, blitz_undo, blitz_doctor
```

Diff handling:
- Do NOT return large diffs as default text
- Return compact structured content with metrics/ranges/diff summary
- For full diff, return resource link `blitz://diff/<id>` (deferred to post-v0.2)

Evaluate `mcp.zig` (v0.0.3) first:
- If stdio compiles on Zig 0.16 and obeys stdout/stderr rules → use it
- Otherwise implement minimal MCP stdio directly (initialize + tools/list + tools/call)

Acceptance:
- `blitz-mcp` starts, responds to `initialize`, lists tools, executes `tools/call`
- Works with Claude Desktop / Cursor / any MCP client
- Stderr is clean (no binary output pollution on stdout)
- `blitz doctor` reports MCP server status

### 3.5 Caller-safety check for delete operations

New command flag:
```bash
blitz apply --edit - --json  # with operation: "delete_symbol"
```

Or add to `blitz doctor` mode:
```bash
blitz references <symbol> --file <path>
```

Implementation:
- Parse all source files in project (or given root)
- Build identifier reference map
- For delete target: check if any other file references the symbol
- If references found: refuse delete, return structured list of callers
- `--force` override available

Acceptance:
- Attempting to delete a called function returns error with caller list
- `--force` proceeds anyway
- pi-blitz surfaces caller list to agent for informed decision

---

## Execution order

Within each phase, work in this order to minimize merge conflicts and maximize early value:

**Phase 1** (can be parallelized across agents with separate branches):
1. Split `cmd_apply.zig` → `apply/` (largest refactor, do first)
2. Wire `fallback.zig` (small, high-value, independent of 1.1)
3. Extract `grammar_config.zig` (enables 3.1, independent of 1.1)
4. Wire `ast.zig` (depends on 1.1 and 1.3 being done)
5. Refactor pi-blitz factory (independent of zig changes)
6. Clean up dead code (last, depends on 1.4 confirming what's dead)

**Phase 2** (sequential, each builds on phase 1):
1. Structured error taxonomy (enables everything else in phase 2)
2. Loosen marker contract (depends on fallback wiring from 1.3)
3. LCS optimization (independent, can parallel with 2.2)
4. Fixture expansion (independent, can parallel with 2.1)

**Phase 3** (mostly parallel tracks):
- Track A: Grammar expansion (3.1) — each grammar is independent
- Track B: Cross-file rename (3.2) + move-to-file (3.3) — sequential, 3.2 first
- Track C: MCP server (3.4) — independent of A and B
- Track D: Caller safety (3.5) — depends on 3.2 for reference scanning

## Concurrency safety

Per AGENTS.md rules:
- One branch per coding agent
- Never two agents on the same live branch
- Atomic commits per ticket slice
- Phase 1 work items are independent enough for parallel agent dispatch
- Phase 2 and 3 need more sequential coordination

## Branch naming

```
feat/v0.2/phase1-apply-split
feat/v0.2/phase1-fallback-wire
feat/v0.2/phase1-grammar-config
feat/v0.2/phase1-ast-wire
feat/v0.2/phase1-pi-factory
feat/v0.2/phase1-cleanup
feat/v0.2/phase2-error-taxonomy
feat/v0.2/phase2-marker-tolerance
feat/v0.2/phase2-lcs-optimize
feat/v0.2/phase2-fixtures
feat/v0.2/phase3-grammar-<lang>
feat/v0.2/phase3-rename-all
feat/v0.2/phase3-move-to-file
feat/v0.2/phase3-mcp-server
feat/v0.2/phase3-caller-safety
```

## Version milestones

- `0.2.0-alpha.1` — Phase 1 complete
- `0.2.0-alpha.2` — Phase 2 complete
- `0.2.0-beta.1` — Phase 3 partial (TS/JS move-to-file, MCP, 4+ new grammars)
- `0.2.0` — All phases complete, benchmarked, documented

## Benchmark gates

Before each milestone:
- `zig build test` passes
- `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast` succeeds
- Binary size ≤ 5 MB (current ~3-4 MB)
- `blitz doctor` reports all wired grammars
- pi-blitz: `bun run typecheck && bun test && bun run build` all pass
- Cold-call edit latency ≤ 20 ms on deterministic path (per §1 of spec)
- No regression in N=5 benchmark token savings numbers
