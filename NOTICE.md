# NOTICE

`blitz` bundles the following third-party source code. All are MIT-compatible.

## tree-sitter
- Origin: https://github.com/tree-sitter/tree-sitter
- License: MIT
- Vendored into `third_party/tree-sitter/`
- Upstream commit: _pinned on integration (ticket d1o-qphx)_

## tree-sitter grammars (vendored into `grammars/`)

| Language | Repo | License |
|---|---|---|
| Rust | https://github.com/tree-sitter/tree-sitter-rust | MIT |
| TypeScript + TSX | https://github.com/tree-sitter/tree-sitter-typescript | MIT |
| Python | https://github.com/tree-sitter/tree-sitter-python | MIT |
| Go | https://github.com/tree-sitter/tree-sitter-go | MIT |

Each grammar's `LICENSE` file is preserved in its vendored copy.

## Algorithmic inspiration (not vendored)

- `fastedit` by parcadei (https://github.com/parcadei/fastedit, MIT) — deterministic splice algorithm ported, not copied.
- `Aider` by Paul Gauthier et al. (https://github.com/Aider-AI/aider, Apache-2.0) — relative-indent anchor recovery pattern.
