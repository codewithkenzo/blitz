# NOTICE

`blitz` bundles the following third-party source code. All are MIT-compatible.

## tree-sitter
- Origin: https://github.com/tree-sitter/tree-sitter
- License: MIT (vendored at `third_party/tree-sitter/LICENSE`)
- Vendored into `third_party/tree-sitter/`
- Upstream release: **v0.26.8** (recorded in `third_party/tree-sitter/VERSION`)

## tree-sitter grammars (vendored into `grammars/`)

All grammars are MIT-licensed. Each vendored copy preserves the upstream
`LICENSE` file and records its source in `grammars/tree-sitter-<lang>/VERSION`.

| Language | Repo | Vendored path |
|---|---|---|
| Rust | https://github.com/tree-sitter/tree-sitter-rust | `grammars/tree-sitter-rust/` |
| TypeScript | https://github.com/tree-sitter/tree-sitter-typescript | `grammars/tree-sitter-typescript/` |
| TSX | https://github.com/tree-sitter/tree-sitter-typescript (tsx subdir) | `grammars/tree-sitter-tsx/` |
| Python | https://github.com/tree-sitter/tree-sitter-python | `grammars/tree-sitter-python/` |
| Go | https://github.com/tree-sitter/tree-sitter-go | `grammars/tree-sitter-go/` |

Each grammar directory contains `src/parser.c`, an optional `src/scanner.c`,
and `src/tree_sitter/*.h` (grammar-local parser header + allocator + array
helpers). `parser.c` tables are large (multi-MB) and not hand-edited.

## Algorithmic inspiration (not vendored)

- `fastedit` by parcadei (https://github.com/parcadei/fastedit, MIT) — deterministic splice algorithm ported, not copied.
- `Aider` by Paul Gauthier et al. (https://github.com/Aider-AI/aider, Apache-2.0) — relative-indent anchor recovery pattern.
