# Research: token-efficient code edit formats and repos

## Question
How should Blitz reduce tokens on every code edit by learning from Aider diff/udiff/CEDARScript, FastEdit/AFT/Morph Fast Apply/apply_patch/edit streaming, and tree-sitter AST edit APIs?

## Findings

### 1. Baseline edit-format lessons
- Full-file rewrites are simple but expensive: Aider says `whole` requires model to return entire updated file even for tiny edits. Use only for new files or unavoidable full rewrites. Source: https://aider.chat/docs/more/edit-formats.html
- Search/replace and unified-diff formats save output tokens by returning only changed hunks, but still spend tokens restating old code for location. Source: https://aider.chat/docs/more/edit-formats.html
- Aider `udiff` removes brittle line numbers (`@@ ... @@`) and treats hunks as search/replace instructions. Key principles: familiar, simple, high-level, flexible. Source: https://aider.chat/docs/unified-diffs.html
- High-level semantic hunks outperform surgical line edits: Aider reports removing high-level-diff prompting causes 30–50% more edit errors; disabling flexible patching causes 9x more hunk apply errors. Source: https://aider.chat/docs/unified-diffs.html
- Aider repo maps send compact symbol/signature context instead of whole files, with token budget (`--map-tokens`) and graph ranking. This supports AST target lookup before edit. Source: https://aider.chat/docs/repomap.html

### 2. CEDARScript: compact command IR
- CEDARScript is SQL-like DSL for code analysis + modification; it offloads line numbers, indentation, character ranges, and exact placement to runtime. Example: `UPDATE FILE "main.py" MOVE FUNCTION "execute" INSERT AFTER FUNCTION "plan"`. Source: https://github.com/CEDARScript/cedarscript-grammar
- Runtime editor exposes high-level targets: identifier names, line markers, relative positions (`AFTER`, `BEFORE`, `INSIDE`, `BODY`, `TOP`, `BOTTOM`) and can return XML for LLM parsing. Source: https://github.com/CEDARScript/cedarscript-editor-python
- Aider CEDARScript PR benchmark: Gemini 1.5 Flash refactoring vs `whole` showed pass-rate improvement, 93% duration reduction, sent tokens -37%, received tokens -96%, errors/malformed/syntax sharply reduced. Source: https://github.com/Aider-AI/aider/pull/1961
- Same PR also shows CEDARScript is model-sensitive: Gemini Pro vs diff-fenced had received tokens -68% but sent tokens +38%; editing benchmark variants sometimes increased tokens/errors. Treat CEDARScript-like IR as opt-in/benchmarked, not universal win. Source: https://github.com/Aider-AI/aider/pull/1961

### 3. FastEdit: AST target + chunk-local merge
- FastEdit thesis: diffs/search-replace/apply_patch force model to repeat old code; tree-sitter locates target by symbol name, agent emits only new snippet + tiny context. Source: https://github.com/parcadei/fastedit
- Reported output token savings: GPT-5.4 54.3%, Opus 4.6 46.5%, Opus 4.7 44.6%, Grok 4.20 43.6%. Source: https://github.com/parcadei/fastedit
- Modes: `--after symbol` instant insertion; `--replace symbol` deterministic context-anchor splice; fallback 1.7B SLM merges snippet into ~35-line chunk in <1s. Source: https://github.com/parcadei/fastedit
- Deterministic path: classify snippet lines as context vs new, splice new lines between matched anchors; FastEdit claims this handles 74% real edits with zero model calls. Source: https://github.com/parcadei/fastedit
- Useful implementation surface: read structure, edit function/class by name, batch-edit one file, delete/move/rename, cross-file rename, move-to-file, undo/diff; MCP tools cover read/search/edit/diff/delete/move/rename. Source: https://github.com/parcadei/fastedit

### 4. AFT: host-tool replacement + symbol-aware IDE/OS
- AFT replaces host `read/write/edit/apply_patch/grep` with tree-sitter/indexed/validated versions, while preserving agent tool slots. This matters: token savings become default, not optional. Source: https://github.com/cortexkit/aft
- Sensory model: `aft_outline` = symbols/ranges; `aft_zoom` = one symbol + optional callgraph; `aft_search` = hybrid semantic/lexical; `grep/glob` = trigram indexed. Source: https://github.com/cortexkit/aft
- Motor model: edit by fuzzy match or named symbol, batch/multi-file transactions, atomic rollback, formatting, diagnostics, AST structural transforms, ast-grep search/replace. Source: https://github.com/cortexkit/aft
- AFT strategy for Blitz: wrap existing edit pathways so agents keep using familiar tool names, but backend provides AST lookup, smaller reads, symbol-level writes, backup/undo, parse/format gates. Source: https://github.com/cortexkit/aft

### 5. Morph Fast Apply + apply models
- Morph Fast Apply merges `originalCode` + `codeEdit` snippet using `// ... existing code ...` markers; returns full merged code and optional udiff. Source: https://docs.morphllm.com/sdk/components/fast-apply
- Morph claims 10,500 tok/s, 98% accuracy, 40% token drop vs full-file rewrites; model table: `morph-v3-fast` 10,500+ tok/s 96%, `morph-v3-large` 2500+ tok/s 98%, `auto` ~98%. Sources: https://docs.morphllm.com/sdk/components/fast-apply and https://docs.morphllm.com/models/apply
- Morph says Fast Apply works best for existing-file edits, batching multiple edits to same file, CI/sandboxes; not needed for new files, rare full rewrites, binaries. Source: https://docs.morphllm.com/sdk/components/fast-apply
- Best-practice snippet uses clear `// ... existing code ...` markers plus first-person instruction to disambiguate. Source: https://docs.morphllm.com/models/apply
- Blitz takeaway: local deterministic merge should own easy cases; optional apply-model fallback can be modeled as chunk-local merge API, never whole-file model merge by default.

### 6. OpenAI apply_patch + streaming
- OpenAI `apply_patch` tool emits structured file operations: `create_file`, `update_file`, `delete_file`; harness applies V4A diff and reports `completed`/`failed` with output. Source: https://developers.openai.com/api/docs/guides/tools-apply-patch/
- Docs require harness-level path validation, backups/scratch copy, error handling, and chosen atomicity semantics. Source: https://developers.openai.com/api/docs/guides/tools-apply-patch/
- OpenAI recommends small focused diffs and sending failed patch outputs back so model can recover. Source: https://developers.openai.com/api/docs/guides/tools-apply-patch/
- Codex has `StreamingPatchParser` work for stateful streaming apply_patch parsing; streamable patch parsing can surface file changes while model still emits them. Source: https://github.com/openai/codex/commit/8426edf71e4a5b754467749ce16090515e2c13c9
- Blitz takeaway: compact IR should be stream-parseable and validated incrementally; show early syntax/schema failures before full model output completes.

### 7. tree-sitter edit API
- tree-sitter supports incremental parsing via `tree.edit({ startIndex, oldEndIndex, newEndIndex, startPosition, oldEndPosition, newEndPosition })` then `parser.parse(newSourceCode, tree)`. Source: https://github.com/tree-sitter/tree-sitter/blob/master/lib/binding_web/README.md
- Nodes expose byte/range positions; target lookup can map symbol/node -> byte range -> edit span. Source: https://github.com/tree-sitter/tree-sitter/blob/master/lib/binding_web/README.md
- Blitz should use incremental parse after edits for fast validation, range rebasing, stale-AST detection, and changed-node benchmarking.

## Recommendation

### Blitz edit IR: compact, AST-first, fallback-safe
1. Add `blitz edit-ir apply` command accepting JSON/JSONL or compact text:
   - `op`: `insert_after | insert_before | replace_body | replace_node | delete_node | move_node | rename_symbol | batch`
   - `file`, `lang`, `target`: `{kind,name,selector?,occurrence?,parent?}`
   - `snippet`: new code only; optional `anchors`: short before/after/context lines
   - `guards`: expected kind, old hash/range hash, parse language, max affected nodes, must-compile flag
2. Prefer AST targets over line numbers:
   - resolve symbol by tree-sitter queries;
   - disambiguate via parent chain/kind/signature/occurrence;
   - never require model to output old code for location.
3. Use chunk-local merge pipeline:
   - deterministic insert/replace/delete first;
   - anchor splice next (`#...` / `// ... existing code ...` style markers);
   - chunk-local apply-model fallback optional;
   - whole-file rewrite last resort only.
4. Schema gate before write:
   - parse IR;
   - validate path allowlist;
   - validate target existence/uniqueness;
   - validate snippet parses as body/node where possible;
   - dry-run diff;
   - require guard pass before write.
5. Parse/format/rollback gate after write:
   - atomic write + backup/undo id;
   - incremental tree-sitter parse;
   - optional formatter;
   - diagnostics/test hook pluggable;
   - rollback on parse failure unless `--force`.
6. Make token savings default:
   - expose `outline`, `zoom`, `symbols`, `edit-ir`, `batch-edit-ir`, `undo`, `diff`;
   - for Pi/plugin side, replace/augment existing read/edit tool semantics so agents naturally use symbol zoom + edit IR.

### Minimal IR examples
```json
{"op":"insert_after","file":"src/app.ts","target":{"kind":"function","name":"handleRequest"},"snippet":"function healthCheck() {\n  return { status: 'ok' }\n}\n"}
```

```json
{"op":"replace_body","file":"src/auth.ts","target":{"kind":"function","name":"login"},"snippet":"const user = await db.findUser(email)\nif (!user) throw new Error('Not found')\nreturn createSession(user)\n","guards":{"oldHash":"...","maxAffectedNodes":1}}
```

### Benchmark plan
- Metrics: output tokens/edit, input tokens/edit, apply success, parse success, test success, retries, wall time, bytes changed, old-code echo ratio.
- Compare formats on same tasks:
  1. full-file rewrite;
  2. search/replace;
  3. udiff/no-line-number;
  4. apply_patch;
  5. CEDARScript-like IR;
  6. Blitz compact IR.
- Task sets:
  - insert after symbol;
  - replace function body;
  - multi-hunk same function;
  - move function/method;
  - rename local/global symbol;
  - ambiguous duplicate names;
  - stale AST after chained edits;
  - whitespace/indent/style variants.
- Acceptance target for Blitz v1:
  - >=40% output-token reduction vs apply_patch on symbol edits;
  - >=95% deterministic apply success for single-symbol insert/replace/delete;
  - 0 writes without parse/schema gate;
  - undo works for every write.

## Sources
- Aider edit formats: https://aider.chat/docs/more/edit-formats.html
- Aider unified diff/laziness benchmark: https://aider.chat/docs/unified-diffs.html
- Aider repo map: https://aider.chat/docs/repomap.html
- CEDARScript grammar: https://github.com/CEDARScript/cedarscript-grammar
- CEDARScript editor runtime: https://github.com/CEDARScript/cedarscript-editor-python
- Aider CEDARScript PR/benchmarks: https://github.com/Aider-AI/aider/pull/1961
- FastEdit: https://github.com/parcadei/fastedit
- AFT: https://github.com/cortexkit/aft
- Morph Fast Apply SDK docs: https://docs.morphllm.com/sdk/components/fast-apply
- Morph Apply Model docs: https://docs.morphllm.com/models/apply
- OpenAI apply_patch docs: https://developers.openai.com/api/docs/guides/tools-apply-patch/
- Codex streaming patch parser commit: https://github.com/openai/codex/commit/8426edf71e4a5b754467749ce16090515e2c13c9
- tree-sitter web binding README/edit API: https://github.com/tree-sitter/tree-sitter/blob/master/lib/binding_web/README.md

## Version / Date Notes
- Researched 2026-06-05.
- Some docs reference future/current model names and product claims; benchmark claims from repo READMEs/PRs should be revalidated locally before product promises.
- CEDARScript benchmark data is from Aider PR #1961 in Nov 2024 and may not reflect current model behavior.
- Morph speed/accuracy/token claims are vendor claims; verify on Blitz workloads.
- AFT/FastEdit repos may move fast; pin commit before implementation work.

## Open Questions
- Which Blitz languages get first-class symbol queries first: Zig only, or Zig + TS/Python for benchmark breadth?
- Should Blitz IR be JSONL, fenced compact DSL, or both? JSON gates well; DSL may emit fewer tokens.
- Should apply-model fallback be local-only, vendor API optional, or omitted for v1?
- What exact Pi/plugin hook will make compact IR default without forcing agent retraining?
- How should Blitz disambiguate overloaded/duplicate symbols: parent chain, signature hash, occurrence index, or query selector?
