# Grammar/parser design quick validation

Date: 2026-05-25
Scope: quick validation for Blitz 0.3+ universal/format routes before committing the current branch.

## Current repo state

Blitz currently vendors and builds five code grammars in `build.zig`:

- Rust
- TypeScript
- TSX
- Python
- Go

`blitz doctor` reports Tree-sitter runtime `v0.26.9`, ABI 15, and those five grammars only. No JSON/YAML/TOML/Markdown/HTML/CSS grammars are vendored yet.

## External grammar availability

Quick web validation found maintained Tree-sitter grammar sources for the next format expansion targets:

- JSON: `tree-sitter/tree-sitter-json`
- YAML: `tree-sitter-grammars/tree-sitter-yaml`
- Markdown: `tree-sitter-grammars/tree-sitter-markdown`
- HTML: `tree-sitter/tree-sitter-html`
- CSS: `tree-sitter/tree-sitter-css`
- TOML: available in the Tree-sitter grammar ecosystem; should be pinned only after repo-level compatibility/ABI check.

## Design conclusion

Do not add all format grammars blindly in the same code slice. The safe next architecture is:

1. Keep current `set_key` JSON support as strict JSON-only, span-preserving, and local-splice based.
2. Add format grammars in pinned, audited slices: JSON/JSONC, YAML, TOML, Markdown, HTML, CSS.
3. For each grammar slice:
   - vendor exact grammar source and license/NOTICE entry;
   - update `build.zig` grammar table and scanner handling;
   - expose extension mapping and ABI in `doctor`;
   - add parse smoke tests and at least one fail-closed edit test;
   - avoid serializer round-trips for config/prose; use byte spans and preconditions.
4. Treat Markdown grammar as structural assistance, not a serializer or perfect CommonMark oracle.
5. Keep YAML/TOML comment/format preservation as a separate design: raw byte-range edits with parser-confirmed spans, never broad reserialization.

## Sources checked

- https://github.com/tree-sitter/tree-sitter-json
- https://github.com/tree-sitter-grammars/tree-sitter-yaml
- https://github.com/tree-sitter-grammars/tree-sitter-markdown
- https://github.com/tree-sitter/tree-sitter-html
- https://github.com/tree-sitter/tree-sitter-css
- Tree-sitter parser ecosystem / list-of-parsers references from search results.
