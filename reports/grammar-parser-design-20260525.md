# Grammar/parser design quick validation

Date: 2026-05-25
Scope: quick validation for Blitz 0.3+ universal/format routes before committing the current branch.

## Current repo state

Blitz vendors and builds code grammars plus first format grammar slice in `build.zig`.

Code grammars:

- Rust
- TypeScript
- TSX
- Python
- Go

Format grammars added in this slice:

| Format | Repo | Commit | Path | Scanner | ABI |
|---|---|---:|---|---|---:|
| JSON | https://github.com/tree-sitter/tree-sitter-json | `001c28d7a29832b06b0e831ec77845553c89b56d` | `grammars/tree-sitter-json/` | none | 14 |
| YAML | https://github.com/tree-sitter-grammars/tree-sitter-yaml | `a1c4812a73ec5e089de8e441fdea3a921e8d5079` | `grammars/tree-sitter-yaml/` | `scanner.c` | 15 |
| TOML | https://github.com/tree-sitter/tree-sitter-toml | `342d9be207c2dba869b9967124c679b5e6fd0ebe` | `grammars/tree-sitter-toml/` | `scanner.c` | 13 |
| Markdown | https://github.com/tree-sitter-grammars/tree-sitter-markdown | `c3570720f7f7bbad22fe96603f106276618e0cf5` | `grammars/tree-sitter-markdown/` | `scanner.c` | 15 |
| HTML | https://github.com/tree-sitter/tree-sitter-html | `73a3947324f6efddf9e17c0ea58d454843590cc0` | `grammars/tree-sitter-html/` | `scanner.c` | 14 |
| CSS | https://github.com/tree-sitter/tree-sitter-css | `dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f` | `grammars/tree-sitter-css/` | `scanner.c` | 15 |

`blitz doctor` reports Tree-sitter runtime `v0.26.9`, ABI 15, min-compatible ABI 13, and all vendored grammars as ABI-compatible.

## External grammar availability

Validated maintained Tree-sitter grammar sources:

- JSON: `tree-sitter/tree-sitter-json`
- YAML: `tree-sitter-grammars/tree-sitter-yaml` (`tree-sitter/tree-sitter-yaml` unavailable)
- TOML: `tree-sitter/tree-sitter-toml`
- Markdown: `tree-sitter-grammars/tree-sitter-markdown` (`tree-sitter/tree-sitter-markdown` unavailable)
- HTML: `tree-sitter/tree-sitter-html`
- CSS: `tree-sitter/tree-sitter-css`

## Slice boundaries

Implemented only parser/doctor support. No YAML/TOML/Markdown edit semantics added. Current `set_key` remains strict JSON-only local scanner.

JSONC extension is not mapped because vendored JSON grammar has no JSONC support in this slice.

Markdown upstream repo contains separate block and inline grammars. Blitz vendors/builds block grammar source from `tree-sitter-markdown/tree-sitter-markdown/src` only. Inline Markdown grammar remains skipped until a combined parse strategy is designed.

No `scanner.cc` grammars were wired. All added scanners are C (`scanner.c`) or absent.

## Design conclusion

Keep adding format capability in pinned, audited slices:

1. Keep current `set_key` JSON support strict JSON-only, span-preserving, local-splice based.
2. Use the vendored format parsers for detection/validation/routing, not lossy serialization.
3. For future edit slices, use raw byte-range edits with parser-confirmed spans and fail-closed preconditions.
4. Treat Markdown grammar as structural assistance, not a serializer or perfect CommonMark oracle.
5. Keep YAML/TOML comment/format preservation separate from parser vendoring.
