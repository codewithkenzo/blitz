# Research: Tree-sitter universal editing for Blitz

## Question
What current Tree-sitter C API / ecosystem practices matter for Blitz when editing Markdown, JSON, YAML, TOML, HTML, CSS, with fast incremental parsing, query perf, wasm/native loading, and non-AST fallback paths?

## Findings

1. **Latest upstream Tree-sitter = v0.26.9; repo pin = v0.26.8; ABI = 15.**
   - Upstream package page shows `tree-sitter` latest version `0.26.9` updated `2026-05-19` on crates.io. Tree-sitter docs still say ABI 15 is max supported for >=0.25. Sources: https://crates.io/crates/tree-sitter ; https://tree-sitter.github.io/tree-sitter/using-parsers/7-abi-versions.html
   - Blitz vendored copy is pinned to `upstream: tree-sitter/tree-sitter @ v0.26.8` in `third_party/tree-sitter/VERSION`. Source: `third_party/tree-sitter/VERSION`

2. **Incremental path = edit tree first, reparse with old tree, then diff changed ranges.**
   - `ts_tree_edit()` must get exact byte + point edit (`TSInputEdit`) before `ts_parser_parse*()` reuse works. `ts_tree_get_changed_ranges()` is only valid after old tree is edited to match new text. Sources: https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h ; https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html
   - `TSTree` copy is cheap (atomic refcount), but each tree instance not thread-safe; copy per thread. Source: https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html

3. **Perf knobs: narrow query range, contain matches, cap depth, cap match count, cache compiled query.**
   - Query cursor can use byte/point ranges + containing ranges to cut work on big files. Source: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html
   - `ts_query_cursor_set_max_start_depth()` and `ts_query_cursor_set_match_limit()` exist for pathological queries / wide trees. Source: https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h ; https://github.com/tree-sitter/tree-sitter/pull/2085 ; https://github.com/tree-sitter/tree-sitter/pull/3559
   - `TSQuery` immutable, share across threads; `TSQueryCursor` reusable, not share concurrently. Source: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html

4. **Input path: use `TSInput` callbacks for ropes/piece tables; `parse_string` only for plain contiguous text.**
   - `ts_parser_parse()` accepts `TSInput { read, payload, encoding, decode }`, so parser can read from custom storage and custom encodings. Source: https://tree-sitter.github.io/tree-sitter/using-parsers/2-basic-parsing.html
   - `read` must honor `byte_offset` / `position` contract; do not stream sequentially like `fread()` w/out seek. Source: https://github.com/tree-sitter/tree-sitter/issues/370 ; https://github.com/tree-sitter/tree-sitter/issues/2882

5. **Grammar loading: native shared libs on desktop, wasm for browser/edge/plugin.**
   - CLI `build` emits native `.so/.dylib/.dll` or `.wasm`; `parse` can use `--lib-path` or `--wasm`. Sources: https://tree-sitter.github.io/tree-sitter/cli/build.html ; https://tree-sitter.github.io/tree-sitter/cli/parse.html
   - `web-tree-sitter` loads each grammar from a `.wasm` file via `Language.load(...)`; docs say native bindings faster in Node. Source: https://tree-sitter-tree-sitter.mintlify.app/api/javascript/overview ; https://tree-sitter-tree-sitter.mintlify.app/api/javascript/parser
   - 0.26.9 fixes wasm supertype-table load for ABI 15 grammars. Source: https://github.com/tree-sitter/tree-sitter/releases/tag/v0.26.9

6. **Universal fallback stack: native parser first, then format-native parser, then text-level edit.**
   - Markdown: `remark` / `remark-parse` gives mdast; `markdown-it` uses token stream, not AST, and is built for fast transform/render. Sources: https://github.com/remarkjs/remark/blob/main/packages/remark-parse/readme.md ; https://github.com/markdown-it/markdown-it/blob/master/docs/architecture.md ; https://markdown-it.github.io/markdown-it/
   - JSON/JSONC: `jsonc-parser` is fault-tolerant and exposes scanner, parseTree, getLocation, modify, applyEdits. Sources: https://github.com/microsoft/node-jsonc-parser/blob/6de0c435/README.md ; https://code.visualstudio.com/docs/languages/json
   - YAML: `yaml` package has parse/stringify, Documents, and Lexer/Parser/Composer, with CST + AST and comment preservation. Sources: https://eemeli.org/yaml/ ; https://github.com/eemeli/yaml/
   - TOML: `toml` or `toml-eslint-parser` gives direct parse/AST. Sources: https://registry.npmjs.org/toml ; https://registry.npmjs.org/toml-eslint-parser
   - HTML: `parse5` is spec-compliant HTML parser/serializer. Source: https://parse5.js.org/
   - CSS: PostCSS parses into AST; tokenization separated for perf and complexity. Source: https://postcss.org/docs/postcss-architecture

## Sources
- `third_party/tree-sitter/VERSION`
- `third_party/tree-sitter/README.md`
- `build.zig`
- https://crates.io/crates/tree-sitter
- https://tree-sitter.github.io/tree-sitter/using-parsers/7-abi-versions.html
- https://github.com/tree-sitter/tree-sitter/blob/master/lib/include/tree_sitter/api.h
- https://tree-sitter.github.io/tree-sitter/using-parsers/3-advanced-parsing.html
- https://tree-sitter.github.io/tree-sitter/using-parsers/2-basic-parsing.html
- https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html
- https://tree-sitter.github.io/tree-sitter/cli/build.html
- https://tree-sitter.github.io/tree-sitter/cli/parse.html
- https://tree-sitter-tree-sitter.mintlify.app/api/javascript/overview
- https://tree-sitter-tree-sitter.mintlify.app/api/javascript/parser
- https://github.com/tree-sitter/tree-sitter/releases/tag/v0.26.9
- https://github.com/tree-sitter/tree-sitter/pull/2085
- https://github.com/tree-sitter/tree-sitter/pull/3559
- https://github.com/tree-sitter/tree-sitter/issues/370
- https://github.com/tree-sitter/tree-sitter/issues/2882
- https://github.com/remarkjs/remark/blob/main/packages/remark-parse/readme.md
- https://github.com/markdown-it/markdown-it/blob/master/docs/architecture.md
- https://markdown-it.github.io/markdown-it/
- https://github.com/microsoft/node-jsonc-parser/blob/6de0c435/README.md
- https://code.visualstudio.com/docs/languages/json
- https://eemeli.org/yaml/
- https://github.com/eemeli/yaml/
- https://registry.npmjs.org/toml
- https://registry.npmjs.org/toml-eslint-parser
- https://parse5.js.org/
- https://postcss.org/docs/postcss-architecture

## Version / Date Notes
- Tree-sitter docs say ABI 15 = current library ceiling for >=0.25. Source: https://tree-sitter.github.io/tree-sitter/using-parsers/7-abi-versions.html
- Upstream latest observed release: v0.26.9 on crates.io, updated 2026-05-19. Source: https://crates.io/crates/tree-sitter
- Blitz repo pin observed: v0.26.8 in `third_party/tree-sitter/VERSION`.
- Tree-sitter release stream is patch-only within release branches; patch bumps should stay drop-in. Source: https://tree-sitter.github.io/tree-sitter/6-contributing.html

## Open Questions
- Need Blitz move vendored Tree-sitter from v0.26.8 → v0.26.9 now, or wait for next grammar regen pass?
- Need browser/edge wasm path in Blitz, or native-only enough?
- For YAML/TOML/Markdown, do we need exact formatting preservation on every edit, or whole-doc reparse + rewrite acceptable?
- Which formats need only range lookup vs full transform/serialization?

## Recommendation
- Use Tree-sitter for span lookup / symbol targeting / incremental validation.
- Reuse parser + tree; always apply exact `TSInputEdit` before reparse.
- Cache `TSQuery`; set range + `set_max_start_depth` + `set_match_limit` for screen-sized or huge-file queries.
- For JSON/YAML/TOML/Markdown/HTML/CSS, keep format-native parser as fallback when AST edit cost > value.
- Prefer native parser on server/desktop; wasm only when deploy target needs it.
- Keep raw text canonical; serialize edits as byte-range patches, not AST round-trips.
