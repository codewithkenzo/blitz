# Research: Blitz tree-sitter edit architecture for Exodia

## Question
What are the deterministic safety rails and language/fallback behaviors for Blitz’s symbol/body editing stack when deciding between in-CLI AST edits, host-LLM fallback, and unsupported-path exits?

## Answer / Recommendation
Blitz’s current Exodia path is AST-first for a fixed extension set (`.rs`, `.ts`, `.tsx`, `.py`, `.go`, `.json`, `.jsonc`, `.yaml`, `.yml`, `.toml`, `.md`, `.markdown`, `.html`, `.htm`, `.css`) with a single shared declaration/body node policy. It is explicitly not a JS/JSX-native editor by extension mapping, and `needs_host_merge` is used as a **controlled fallback signal**, not a silent success path.

Recommendation: continue treating `needs_host_merge` as a hard protocol handoff (exit status 0 in CLI JSON mode) and preserve strict no-mutation on parse/rewrite failure. For coverage expansion, JS/JSX support requires grammar/router changes first (not just node-kind matching).

---

## Findings

### 1) Language support / routing surface
- Supported extensions and languages are centralized in the enum/dispatcher layer:
  - `bindings.Language` supports: `rust, typescript, tsx, python, go, json, jsonc, yaml, toml, markdown, html, css`.
  - `languageForExtension(...)` maps `.rs/.ts/.tsx/.py/.go/.json/.jsonc/.yaml/.yml/.toml/.md/.markdown/.html/.htm/.css` and returns `null` for others.
  - `cmd_edit`/`cmd_batch` print `unsupported language for <file>` when language is `null`.
  - `cmd_read` prints `<path> (unsupported language)` and exits `0` for unknown extension.
  - `docs/blitz.md` and `cmd_doctor` also expose the same extension/language surface.

Sources:
- `src/tree_sitter/bindings.zig` (enum + `Language.fromExtension`)
- `src/tree_sitter/bindings.zig` (`grammar list`)
- `src/cmd_edit.zig` (`runEdit` extension guard)
- `src/cmd_batch.zig` (`run` extension guard)
- `src/cmd_read.zig` (`run` extension guard)
- `src/cmd_doctor.zig` (`supported_grammars` + extension support summary)
- `docs/blitz.md` (README-style supported extension/route docs)

Key implication: there is no native `.js`/`.jsx` route today, so JS/JSX behavior is effectively “not supported” in CLI/AST edit routes.

---

### 2) Symbol/declaration/body-kind behavior (editor logic)
Blitz uses **shared** declaration/body lists for all supported languages:
- `declarationKinds = [function_declaration,function_definition,function_item,method_declaration,method_definition,class_declaration,class_definition,impl_item,struct_item,enum_item,interface_declaration,type_alias_declaration,variable_declarator]`
- `bodyKinds = [statement_block,block,class_body,declaration_list]`
- `name_fields = ["name"]`
- No per-language overrides for these lists.

Sources:
- `src/grammar_config.zig` (`declaration_kinds`, `body_kinds`, `name_fields`, per-language configs).

This means cross-language behavior is mostly gated by: extension support + whether the language’s AST contains expected declaration/body nodes + `replacementRangeFor` shape.

---

### 3) Language-specific node-kind coverage (for requested languages)
Using upstream `node-types.json` (where available) plus local vendored node-type files for fallback languages.

Observed relevant kinds from upstream files (shared coverage checks):

| Language | Supported by Blitz CLI extension | Shared decl kinds likely hit by parser | Notable missing from local editor config behavior | JSX nodes |
|---|---|---|---|---|
| TS (`.ts`) | ✅ | `function_declaration`, `method_definition`, `method_signature`, `arrow_function`, `class_declaration`, `interface_declaration`, `type_alias_declaration`, `variable_declarator`, `statement_block`, `class_body` | none additional from config | none |
| TSX (`.tsx`) | ✅ | same TS set + `jsx_element`, `jsx_self_closing_element`, `jsx_opening_element` | none additional | ✅ |
| JS (`.js`) | ❌ (extension unmapped) | upstream has `function_declaration`, `method_definition`, `arrow_function`, `class_declaration`, `variable_declarator`, `statement_block`, `class_body`, JSX nodes | blocked at extension layer | ✅ (as parser capability, not CLI route) |
| JSX (`.jsx`) | ❌ (extension unmapped) | upstream JS-like JSX sets | blocked at extension layer | ✅ |
| Python (`.py`) | ✅ | `function_definition`, `class_definition` | class/object/impl-specific kinds absent from shared policy | none |
| Go (`.go`) | ✅ | `function_declaration` | class/section/object kinds absent | none |
| Rust (`.rs`) | ✅ | `function_item`, `struct_item`, `impl_item`, `enum_item`, `declaration_list` | shared names like `function_declaration`/`variable_declarator` absent in Rust grammar | none |
| JSON (`.json`) | ✅ | no declaration/body candidates from config (`declaration_kinds` empty for json config)
| JSONC (`.jsonc`) | ✅ | same as JSON (none) | same as JSON | none |
| YAML/TOML (`.yaml/.yml/.toml`) | ✅ | no declaration/body candidates from config | same as JSON/TOML families | none |
| Markdown/HTML/CSS (`.md/.markdown/.html/.css`) | ✅ | no declaration/body candidates from config | same as JSON families | none |

Sources:
- `src/grammar_config.zig` (shared declaration/body policy)
- Upstream raw node-type files:
  - TypeScript: https://raw.githubusercontent.com/tree-sitter/tree-sitter-typescript/master/typescript/src/node-types.json
  - TSX: https://raw.githubusercontent.com/tree-sitter/tree-sitter-typescript/master/tsx/src/node-types.json
  - JavaScript: https://raw.githubusercontent.com/tree-sitter/tree-sitter-javascript/master/src/node-types.json
  - Python: https://raw.githubusercontent.com/tree-sitter/tree-sitter-python/master/src/node-types.json
  - Go: https://raw.githubusercontent.com/tree-sitter/tree-sitter-go/master/src/node-types.json
  - Rust: https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/master/src/node-types.json
- Local vendored config files for config-ish languages:
  - `grammars/tree-sitter-json/src/node-types.json`
  - `grammars/tree-sitter-jsonc/src/node-types.json`
  - `grammars/tree-sitter-yaml/src/node-types.json`
  - `grammars/tree-sitter-markdown/src/node-types.json`
  - `grammars/tree-sitter-html/src/node-types.json`
  - `grammars/tree-sitter-css/src/node-types.json`
  - `grammars/tree-sitter-toml/src/node-types.json`

Note: local script fetch in repo showed these fallback grammar files do not expose the shared declaration/body node names used by AST edit targeting.

---

### 4) Parse-validity postconditions
Postconditions after edit planning are enforced before write:
- `parseStrict` in `ast.zig` rejects null/error root after parse: source must parse clean before edit proceeds.
- `apply_support.parseEditedSourceIncremental` and `validateSingleRangeEditIncremental` apply `ts_tree_edit` + `ts_parser_parse` and enforce changed-range envelopes.
- `validate.parseAfterEdit`:
  - default path: incremental post-parse when possible, fallback to full reparse.
  - single-range path: if changed ranges are too broad (`ChangedRangesTooBroad`), parse validation fails closed.
- On parse validation failure, edit returns rejection (`PARSE_ERROR_AFTER`) and does **not** write.

Sources:
- `src/ast.zig` (`parseStrict`)
- `src/edit_support.zig` (`validateEditedSourceIncremental`, `validateSingleRangeEditIncremental`)
- `src/apply/validate.zig` (`parseAfterEdit`, `ChangedRangesTooBroad` handling)
- `src/apply/mod.zig` write gate (`if (changed and !dry_run) ... backup.store/atomicWrite` only after successful parse validation)
- Test: `src/apply/validate.zig` “single-range changed ranges too broad fails closed” and parse-after failure tests.

---

### 5) `insert_after` / safe replacement behavior matrix
- `cmd_edit`:
  - `--after` calls `edit_support.applyToSource(..., .after)` and inserts at `target_end`.
  - `--replace` does splice around normalized replacement range.
- `apply`:
  - top-level operation `.insert_after_symbol` is implemented and inserts at `target_end`.
  - In compact multi/multi-body routes, `insert_after_symbol` is unsupported:
    - `makeCompactPatchEdits` supports `replace/insert_after/wrap/replace_return/try_catch`; others fall through to `UnsupportedMultiEditOperation`.
    - `makeMultiBodyEdits` explicitly returns `UnsupportedMultiEditOperation` for `multi_body` and `insert_after_symbol`.

Sources:
- `src/edit_support.zig` (`EditMode.after`, insertion at `target_end`)
- `src/cmd_edit.zig` (`runAfter` path + `runEdit`)
- `src/apply/operations.zig` (`insert_after_symbol` in enum)
- `src/apply/mod.zig` (main switch includes `.insert_after_symbol` implementation)
- `src/apply/patch.zig` (unsupported op lists)
- Test references:
  - `src/cmd_edit.zig` tests: `runReplace marker ... fails falls back ...`
  - `src/apply/mod.zig` test: compact `ia` insert-after inserts successfully (`insert_after_symbol`)

---

### 6) Unsupported-language + fallback behavior by CLI path
#### `blitz edit <file> --after|--replace ...`
- Unsupported extension: immediate stderr message + exit code 1.
- Marker failures (`AnchorNotFound/MarkerGrammarInvalid/AmbiguousAnchor/MarkerSpliceTooLarge`) -> emit `needs_host_merge` JSON payload (Layer D style), no write.
- Syntax failure of edited result -> exit code 1.
- Symbol not found -> exit code 1.

#### `blitz batch-edit <file>`
- Unsupported extension: immediate exit 1 (no JSON payload fallback).
- Per-edit marker splice fail/parse fail/errors are returned as stderr and abort with exit 1.

#### `blitz apply`
- Default `auto` path:
  - parse operation and language; unsupported extension => failure `UNSUPPORTED_LANGUAGE`.
- `--route explain` or dry-run force-path:
  - route decision computed and for unsupported language can return status `needs_host_merge` (when `routeDecision` is `core_edit` path or `fallbackRoute == core_edit`) instead of immediate `UNSUPPORTED_LANGUAGE`.
- Normal success paths return status `applied/preview/no_changes`.
- `set_key` on unsupported ext also maps to `UNSUPPORTED_LANGUAGE`.

Sources:
- `src/grammar_config.zig` (supported extension map)
- `src/cmd_edit.zig` (edit path)
- `src/cmd_batch.zig` (batch path)
- `src/apply/mod.zig` (`run`, routeDecision, unsupported-language branches, explain branches, routeDecision for text/ast/format paths)
- Tests:
  - `src/cmd_edit.zig` marker fallback tests show `needs_host_merge` payload + unchanged file.
  - `src/apply/mod.zig` route explain and unsupported-language tests (`apply unsupported language returns stable code`, `unsupported language snapshot structured`).

---

## Source notes (kept vs dropped)
**Kept (high-confidence, explicit code paths):**
- Language map + extension guard behavior
- Shared kind-policy behavior
- parseStrict + parseAfter pipeline + changed-ranges fallback semantics
- exact routes for marker fallback vs hard failures
- explicit unsupported op handling in compact/multi-body patch resolvers

**Dropped/low-confidence:**
- Some external “v0.2 status” statements in planning docs are forward-looking, not current implementation behavior.
- Some language node-kind statements for `json/yaml/toml/markdown/html/css` rely on local vendored node-type files that may not be fully representative of intended parser versions for all build environments.

## Version / date notes
- Repo scope: `/home/kenzo/dev/blitz` currently v0.1.0-alpha.10 (`src/tree_sitter/bindings.zig`, `docs/blitz.md`).
- Tree-sitter C API references in `@0.26.9` (runtime) from `src/tree_sitter/bindings.zig`.

## Open Questions
1. JS/JSX support should be product-decided: add `.js/.jsx` extension mapping and grammar entries, or keep Exodia intentionally TSX-centric.
2. Should `apply` route `--route`/`route=core-edit` “needs_host_merge on unsupported language” be surfaced as host-visible behavior in all automation contexts? (Current behavior is conditional on route policy and request metadata.)
3. Should we add a hard integration test for `ChangedRangesTooBroad` inside full `apply` route (not only `validate.zig` unit coverage)?

## Builder-ready implications (implementation/test directions)
### Deterministic commands to run now
- `zig test src/apply/validate.zig`
- `zig test src/apply/mod.zig` (spot-check with test filters below)
- `zig test src/cmd_edit.zig`
- `zig test src/cmd_batch.zig`

Suggested focused checks to add/verify:
1. **insert_after denial in structured route:** verify compact multi-body payload with `insert_after_symbol` returns `UNSUPPORTED_OPERATION` in `makeMultiBodyOp` path.
2. **insert_after_symbol ambiguity/safety:** add/keep test where target ambiguous symbol insertion must return deterministic failure in structured route.
3. **ChangedRangesTooBroad in AST apply:** add integration test for single-range edit that makes `ChangedRangesTooBroad` surface as `PARSE_ERROR_AFTER`/`VALIDATION_FAILED` equivalent and no write.
4. **`needs_host_merge` vs hard fail matrix for apply route** for each language family (AST edit-supported, config-set-key, unsupported extension) in one table-driven test harness.
5. **Cross-route unsupported language matrix** for `blitz edit`, `batch-edit`, `apply --route explain`, `apply --route force-core`, and `read`.

---

## Top 3 findings
1. **Extension routing is the hard gate** for JS/JSX today (`.js/.jsx` unsupported), despite shared Tree-sitter-like kinds existing in JavaScript grammar.
2. **Parse safety is strict:** parse-before clean + parse-after clean are enforced; `ChangedRangesTooBroad` is a hard fail (no mutation).
3. **`needs_host_merge` is explicit protocol fallback, not success:** it is only returned for selected policy paths (edit marker failures, some apply route explain/fallback cases), not on all failures.

