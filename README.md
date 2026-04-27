# blitz

AST-aware fast-edit CLI. Zig 0.16, tree-sitter, zero model, zero Python, single static binary.

> **Status: pre-alpha.** Scaffold only. See `docs/blitz.md` (mirror of the pi-rig spec) for the full design.

## What this is

A tool that lets a coding agent (or a human) edit source code by **symbol name** instead of by repeating old code. The agent writes the change it wants plus a symbol anchor (`--after handler` or `--replace handleRequest`); blitz uses tree-sitter to find the code and apply the edit deterministically.

## Why

- Cuts agent **output tokens by ~40-50%** on handled edits (hypothesis, gated on benchmark).
- No local ML model, no Python runtime, no `uv tool install` dance.
- ~3-5 MB static binary per platform.
- Ships as an npm package with prebuilt binaries (esbuild/biome pattern).

## Install (once published)

```bash
# via npm
npm install -g @codewithkenzo/blitz

# via cargo-style direct download (planned)
curl -sSL https://github.com/codewithkenzo/blitz/releases/latest/download/install.sh | sh

# from source
git clone https://github.com/codewithkenzo/blitz
cd blitz
zig build -Doptimize=ReleaseFast
./zig-out/bin/blitz --help
```

## Usage

```bash
# AST structure summary
blitz read src/app.ts

# Edit by symbol (deterministic splice or direct swap)
blitz edit src/app.ts --replace handleRequest --snippet -
< new-body.ts

# Insert after a symbol
blitz edit src/app.ts --after main --snippet '
fn helper() { }
'

# Rename across file (AST-verified)
blitz rename src/app.ts oldName newName

# Undo last edit (single-depth per file)
blitz undo src/app.ts

# Health check
blitz doctor
```

## Status

| Feature | State |
|---|---|
| Zig 0.16 project skeleton | ✅ scaffold (this commit) |
| tree-sitter static link + grammars | ⏳ ticket blitz-01 |
| `read` / `edit` direct-swap | ⏳ ticket blitz-02 |
| Layer A splice + markers + backup / undo / rename / doctor | ⏳ ticket blitz-03 |
| Layer B fuzzy recovery | ⏳ ticket blitz-07 (v0.2) |
| Layer C tree-sitter query rewrites | ⏳ ticket blitz-08 (v0.2) |

## Performance

Latest micro-benchmark covers both direct-swap and marker-splice lanes, with exact output assertions before perf gating. Run [`bench/run.ts`](./bench/run.ts) for current table.

## Pi integration

`@codewithkenzo/pi-blitz` — Effect v4 Pi extension that wraps this binary. Separate repo (tracked in `codewithkenzo/pi-rig`).

## Development

Requires Zig 0.16.0 stable (released 2026-04-13).

```bash
zig build              # native build
zig build run          # run the CLI
zig build test         # unit tests
zig build --watch -fincremental  # hot-rebuild dev loop
```

Cross-compile:

```bash
zig build -Dtarget=aarch64-macos
zig build -Dtarget=x86_64-linux-musl
zig build -Dtarget=x86_64-windows-gnu
```

## License

MIT. See `LICENSE`, `NOTICE.md`.
