# blitz

AST-aware symbol-scoped edit CLI. Zig 0.16, tree-sitter, no Python, no local model, single static binary.

## What it does

Blitz lets a coding agent or a human edit source code by **symbol name** rather than by repeating unchanged code. Provide a symbol anchor (`--after handler` or `--replace handleRequest`); blitz uses tree-sitter to locate the declaration and applies the edit deterministically. Structured apply operations (`replace_body_span`, `wrap_body`, etc.) let the caller describe only the changed portion — blitz owns body extraction, indentation, validation, backup, and write.

## Status

Private release candidate. Standalone CLI passed local `gpt-5.5` xhigh review. Benchmarks against the Pi model runtime show meaningful reductions in provider output tokens, tool-call argument tokens, wall time, and cost on handled symbol edits (see [docs/blitz.md §10](docs/blitz.md) for exact numbers and caveats). Not a universal replacement for core text edits; tiny or one-line edits often favor the core `edit` tool.

## Install

```bash
# from source (Zig 0.16 required)
git clone https://github.com/codewithkenzo/blitz
cd blitz
zig build -Doptimize=ReleaseFast
./zig-out/bin/blitz --help

# npm prebuilts (once published)
npm install -g @codewithkenzo/blitz
```

## Commands

| Command | Description |
|---|---|
| `blitz read <file>` | AST structure summary. Files ≤100 lines get full content. |
| `blitz edit <file> --replace\|--after <symbol> --snippet -` | Single symbol-anchored edit via stdin snippet. |
| `blitz batch-edit <file> --edits -` | Multiple symbol edits in one file from a JSON array via stdin. |
| `blitz apply --edit - [--dry-run] [--diff]` | Structured edit via JSON IR (`replace_body_span`, `insert_body_span`, `wrap_body`, `compose_body`, `insert_after_symbol`, `set_body`, `multi_body`, `patch`). |
| `blitz rename <file> <old> <new> [--dry-run]` | AST-verified rename; skips strings/comments/docstrings. |
| `blitz undo <file>` | Revert last backup. Single-depth per file. |
| `blitz doctor` | Version, supported grammars, tree-sitter lib version, cache health. |

### Structured apply operations

`blitz apply` accepts a JSON IR on stdin:

```json
{
  "version": 1,
  "file": "src/app.ts",
  "operation": "replace_body_span",
  "target": { "symbol": "computeTotal" },
  "edit": { "find": "return total;", "replace": "return total + 1;", "occurrence": "last" }
}
```

Operations: `replace_body_span`, `insert_body_span`, `wrap_body`, `compose_body`, `insert_after_symbol`, `set_body`, `multi_body`, `patch`.

## Snippet markers

When using `blitz edit`, pass a full replacement body (no markers) or use a preservation marker to keep unchanged sections:

- `// ... existing code ...` / `# ... existing code ...` — fastedit-compatible auto-detected
- `// @keep` / `# @keep` — strict recommended form
- `// @keep lines=N` / `# @keep lines=N` — numeric anchor, unambiguous

## Language support

Five vendored grammars (all MIT-compatible): TypeScript, TSX, Python, Rust, Go.

Unsupported language → blitz emits a compact scope-payload JSON and exits 0 so the host agent can perform the edit directly.

## Development

Requires Zig 0.16.0 (released 2026-04-13).

```bash
zig build                          # native build
zig build run                      # run CLI
zig build test                     # unit tests
zig build --watch -fincremental    # incremental hot-rebuild
```

Cross-compile:

```bash
zig build -Dtarget=aarch64-macos
zig build -Dtarget=x86_64-macos
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=aarch64-linux-musl
zig build -Dtarget=x86_64-windows-gnu
```

## Pi integration

`@codewithkenzo/pi-blitz` — Effect v4 Pi extension that wraps this binary. Exposes typed tools for AST reads, structured apply operations, semantic patch helpers, rename, undo, and doctor. See the extension README for install and configuration.

## Design reference

`docs/blitz.md` — full spec covering CLI surface, edit algorithm, layer pipeline, Zig 0.16 alignment, benchmark data, and risk register.

## License

MIT. See `LICENSE`, `NOTICE.md`.
