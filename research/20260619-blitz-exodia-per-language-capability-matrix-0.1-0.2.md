# Research: Blitz Exodia 0.1/0.2 language capability matrix

## Question
Determine per-language edit capability for:
`typescript`, `tsx`, `javascript`, `jsx`, `python`, `go`, `rust`, `json`, `jsonc`, `yaml/yml`, `toml`, `markdown`, `html`, `css`
across:
- direct-text ops
- AST/grammar-structured ops
- set-key/format-text
- parse/validation behavior
- decline/fallback behavior and risks.

## Answer / Recommendation
Blitz currently recognizes **11 extensions** via `languageForExtension` (`.rs`, `.ts`, `.tsx`, `.py`, `.go`, `.json`, `.jsonc`, `.yaml/.yml`, `.toml`, `.md/.markdown`, `.html/.htm`, `.css`) and parses those grammars in doctor/binding initialization. `javascript` and `jsx` are not recognized extensions, so they are hard-unsupported today.

- **Direct text ops** (`replace_unique`, `insert_after_anchor`, `insert_before_anchor`, `replace_between`, `append_section`, `ensure_line`, `delete_range`) are available for all recognized extensions.
- **Structured AST body ops** are effectively supported where declaration+body node families are available in grammar + `bodyRangeFor` is non-null: **TS, TSX, Rust, Python, Go**.
- **`set_key` is supported only for**: `json`, `yaml/yml`, `toml`, `ts`, `tsx`.
- **`jsonc` and non-code formats** (`jsonc`, `yaml`, `toml`, `markdown`, `html`, `css`) do **not** get `set_key`.
- **`try_catch` compact patch op** is TS/TSX-only.
- **JavaScript/JSX** are unsupported via extension gate unless explicitly remapped.

## Findings (claim-backed)

| Language | Direct-text ops | Body AST ops (replace_body_span/compose/wrap/merge/set_body/insert_after_symbol) | `set_key` | Patch `replace_return` | Patch `try_catch` | Structural validation behavior | Primary decline modes | Test evidence completeness |
|---|---|---|---|---|---|---|---|---|
| **typescript** (`.ts`) | ✅ | ✅ | ✅ | ✅ | ✅ | parseBefore/parseAfter validated; direct ops `parseBefore/After=false` | Symbol not found/ambiguous, body not found, ambiguous patterns | Strong: TS structural/set_key tests exist |
| **tsx** (`.tsx`) | ✅ | ✅ | ✅ | ✅ | ✅ | Same as TS | Same as TS | Good: TSX parser presence + TSX config + TS-path structural tests |
| **python** (`.py`) | ✅ | ✅ | ❌ | ✅ (`return_statement`) | ❌ | parseBefore/parseAfter validated on body ops | Symbol not found/ambiguous, body not found | Weak: no python-specific apply tests in-repo |
| **go** (`.go`) | ✅ | ✅ | ❌ | ✅ (`return_statement`) | ❌ | parseBefore/parseAfter validated on body ops | Symbol not found/ambiguous, body not found | Weak: no go-specific apply tests |
| **rust** (`.rs`) | ✅ | ✅ | ❌ | ✅ (`return_expression`) | ❌ | parseBefore/parseAfter validated on body ops | Symbol not found/ambiguous, body not found | Weak: no rust-specific apply tests |
| **json** (`.json`) | ✅ | ❌ | ✅ | ❌ | ❌ | direct ops not AST-validated; set_key parses
| format-text route (`parseBefore/After=true`) | SYMBOL_NOT_FOUND/AMBIGUOUS_SYMBOL for body ops; set_key duplicate/parse checks | Moderate: JSON set_key tests exist |
| **jsonc** (`.jsonc`) | ✅ | ❌ | ❌ | ❌ | ❌ | direct ops no parse validation; no set_key parser path | SYMBOL_NOT_FOUND/AMBIGUOUS_SYMBOL for body; set_key => UNSUPPORTED_LANGUAGE | Weak: no apply tests |
| **yaml/yml** (`.yaml/.yml`) | ✅ | ❌ | ✅ | ❌ | ❌ | direct ops not AST-validated; set_key route parses yaml text heuristics with constraints | SYMBOL_NOT_FOUND/AMBIGUOUS_SYMBOL for body; format parse errors | Moderate: yaml set_key tests exist |
| **toml** (`.toml`) | ✅ | ❌ | ✅ | ❌ | ❌ | direct ops not AST-validated; set_key route parses toml text heuristics | SYMBOL_NOT_FOUND/AMBIGUOUS_SYMBOL for body; format parse errors | Moderate: toml set_key tests exist |
| **markdown** (`.md/.markdown`) | ✅ (incl. markdown-heading append/ensure behavior) | ❌ | ❌ | ❌ | ❌ | direct ops no AST validation | Body ops SYMBOL_NOT_FOUND/AMBIGUOUS for declaration search | Weak: no structured tests |
| **html** (`.html/.htm`) | ✅ | ❌ | ❌ | ❌ | ❌ | direct ops no AST validation | Body ops SYMBOL_NOT_FOUND/AMBIGUOUS | Weak: no structured tests |
| **css** (`.css`) | ✅ | ❌ | ❌ | ❌ | ❌ | direct ops no AST validation | Body ops SYMBOL_NOT_FOUND/AMBIGUOUS | Weak: no structured tests |
| **javascript** (`.js`) | ❌ (unsupported extension) | ❌ | ❌ | ❌ | ❌ | immediate `UNSUPPORTED_LANGUAGE` | UNSUPPORTED_LANGUAGE |
| **jsx** (`.jsx`) | ❌ (unsupported extension) | ❌ | ❌ | ❌ | ❌ | immediate `UNSUPPORTED_LANGUAGE` | UNSUPPORTED_LANGUAGE |

### Source anchors

- Grammar/config language registry and extension mapping are defined in `src/grammar_config.zig` and `src/tree_sitter/bindings.zig` (`Language.fromExtension`, parser list, declaration/body settings).
- Doctor/compatibility checks enumerate the supported grammars in `src/cmd_doctor.zig` (`supported_grammars`, `probeGrammar`, extensions line output).
- Apply routing + validation matrix comes from `src/apply/mod.zig` (`run` dispatcher, `isDirectTextOperation`, `parseBefore/parseAfter` usage, result metadata, `BodyNotFound`, `UnsupportedLanguage`, etc.).
- Parse-after logic and fallback semantics are implemented in `src/apply/validate.zig` (`ChangedRangesTooBroad => false`, else full-parse fallback).
- Body resolution and language-specific body extraction behavior is in `src/ast.zig` (`bodyRangeFor`, shared declaration kinds, grammar-specific body handling).
- `set_key` format-text branches and grammar-specific parsers in `src/apply/mod.zig` (`runSetKey`, `buildFormatSetKey`, `parseTreeClean`, `findTypeScriptTopLevelObjectKey`).
- Patch operator language gates in `src/apply/patch.zig` (`supportsTryCatch`, `collectReturnStatements`, replacement node collection).
- Current test evidence concentrated in `src/apply/mod.zig` tests (`set_key` + structural op behavior with `.ts` fixtures), and `src/tree_sitter/bindings.zig` parser smoke (`Parser parses each supported grammar`).
- `README.md` “Supported languages” list still says TS/TSX/Python/Rust only and is stale versus code.

## Version / date notes
- Runtime: tree-sitter runtime `v0.26.9`, ABI checks in `bindings.zig`.
- Doctor output claims “stage v0.1” and extension list matching current 11 mapped extensions (`cmd_doctor.zig`).
- No external web sources were used: web provider queries are unavailable in this session (API error 402).

## Source quality notes
- **Kept**: local code/tests/grammar artifacts as primary truth.
- **Dropped**: external language docs/blogs (unavailable in-session) and docs/README claim blocks not matching source truth for full language support.

## Open questions
1. Should `jsonc` intentionally remain without `set_key` support, or should `buildFormatSetKey` gain jsonc path parity with json semantics?
2. Is `javascript`/`jsx` extension support expected in Exodia scope via aliasing to TypeScript or distinct language handling?
3. Are parser-level confidence tests required for Python/Go/Rust structural edits before declaring those lanes production-ready?
4. Should direct-text ops on non-code formats be allowed by default if they bypass validation, or should they be explicitly constrained/fallback-only?

## Builder-ready implementation priorities
1. **High**: add/verify per-language structured tests for Rust/Go/Python + JSONC/markdown/html/css fail-path tests to close matrix confidence gaps.
2. **High**: decide and implement JavaScript/JSX extension support policy (alias mapping + TS/TSX behavior review).
3. **Medium**: normalize `README` and user-facing docs to 11-language support vs stale 4-language list.
4. **Medium**: harden non-code behavior by documenting expected direct-text-only fallback and whether it is acceptable for JSON/markup
5. **Low**: add dedicated tests for `set_key` on unsupported extensions (expect `UNSUPPORTED_LANGUAGE`) and for patch `try_catch` gate semantics in TS-only matrix coverage.

## Confidence
- **High**: extension gating and route-level op/validation behavior (direct vs AST ops, fail codes).
- **Medium-High**: per-language structural support inference for TSX/TS/Rust/Python/Go via shared declaration/body+parser checks.
- **Medium**: jsonc behavior on `set_key` (inferred from explicit branch fallthrough to UnsupportedLanguage) and absence of declaration nodes in configured grammars for non-code formats.
