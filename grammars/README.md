# Grammars

Vendored tree-sitter grammars. Populated by ticket **d1o-qphx**.

Each grammar lives in its own directory with:
- `parser.c` — generated parser from the grammar repo
- `scanner.c` or `scanner.cc` (if the grammar has external scanner)
- `LICENSE` — preserved from upstream (all MIT-compatible)
- a short `README.md` with the upstream commit / tag

## Target grammars for v0.1

| Language | Upstream | Vendored at |
|---|---|---|
| Rust | tree-sitter/tree-sitter-rust | tbd |
| TypeScript | tree-sitter/tree-sitter-typescript (typescript/) | tbd |
| TSX | tree-sitter/tree-sitter-typescript (tsx/) | tbd |
| Python | tree-sitter/tree-sitter-python | tbd |
| Go | tree-sitter/tree-sitter-go | tbd |

## Vendoring procedure (to be automated in ticket d1o-qphx)

```bash
# example for rust
mkdir -p grammars/tree-sitter-rust/src
curl -L https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/<TAG>/src/parser.c \
  -o grammars/tree-sitter-rust/src/parser.c
curl -L https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/<TAG>/src/scanner.c \
  -o grammars/tree-sitter-rust/src/scanner.c 2>/dev/null || true
curl -L https://raw.githubusercontent.com/tree-sitter/tree-sitter-rust/<TAG>/LICENSE \
  -o grammars/tree-sitter-rust/LICENSE
echo "upstream: tree-sitter/tree-sitter-rust@<TAG>" > grammars/tree-sitter-rust/README.md
```
