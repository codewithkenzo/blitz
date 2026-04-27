# blitz

AST-aware symbol-scoped edit CLI. Zig 0.16, tree-sitter, no Python, no local model, single static binary.

## What it does

Blitz lets a coding agent or a human edit source code by **symbol name** rather than by repeating unchanged code. Provide a symbol anchor (`--after handler` or `--replace handleRequest`); blitz uses tree-sitter to locate the declaration and applies the edit deterministically. Structured apply operations (`replace_body_span`, `wrap_body`, etc.) let the caller describe only the changed portion — blitz owns body extraction, indentation, validation, backup, and write.

## Status

`0.1.0-alpha.0`. Standalone CLI passed local `gpt-5.5` xhigh review. 54/54 unit tests pass (x86_64-linux-musl). Authenticated Pi/model benchmarks show meaningful reductions in provider output tokens, tool-call argument tokens, wall time, and cost on handled symbol edits (see [docs/blitz.md §10](docs/blitz.md) for exact numbers and caveats). Not a universal replacement for core text edits; tiny or one-line edits often favor the core `edit` tool. npm prebuilt binaries are not yet published; install from source.

## Install

### From source (Zig 0.16 required)

```bash
git clone https://github.com/codewithkenzo/blitz
cd blitz
zig build -Doptimize=ReleaseFast
./zig-out/bin/blitz --help
```

### npm wrapper

```bash
npm install -g @codewithkenzo/blitz
```

The npm package ships `bin/blitz.js`, a Node wrapper. Alpha packages do not include native prebuilts. The wrapper resolves the binary in order:

1. `BLITZ_BIN` env var
2. `zig-out/bin/blitz` (local source build)
3. `bin/blitz` (future platform package location)

Until prebuilts ship, build from source and set `BLITZ_BIN=/abs/path/to/zig-out/bin/blitz`.

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

## MCP stdio server

`mcp/blitz-mcp.ts` is a standalone MCP server (JSON-RPC over stdio, protocol `2025-06-18`). Run it with Bun; no separate install required beyond Bun and the blitz binary.

**Tools exposed:**

| MCP tool | Description |
|---|---|
| `blitz_doctor` | Binary version, grammar list, cache status. |
| `blitz_read` | AST/source summary for a file. |
| `blitz_patch` | Apply compact patch tuples (`replace`, `insert_after`, `wrap`, `replace_return`, `try_catch`). |
| `blitz_try_catch` | Wrap a symbol body in try/catch without repeating the body. |
| `blitz_replace_return` | Replace a return expression inside a symbol body. |
| `blitz_undo` | Revert last blitz mutation for a file. |

**Wire in `.mcp.json` (Claude / Pi):**

```json
{
  "servers": {
    "blitz": {
      "command": "bun",
      "args": ["/abs/path/to/blitz/mcp/blitz-mcp.ts"],
      "env": {
        "BLITZ_BIN": "/abs/path/to/blitz/zig-out/bin/blitz",
        "BLITZ_WORKSPACE": "/abs/path/to/your/project"
      }
    }
  }
}
```

**Workspace safety:** all file paths are resolved relative to `BLITZ_WORKSPACE` and rejected if they escape it. No reads or writes outside the workspace root.

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `BLITZ_BIN` | `blitz` (PATH) | Path to the blitz binary used by the MCP server and `bin/blitz.js` wrapper. |
| `BLITZ_WORKSPACE` | `process.cwd()` | Root directory for MCP path resolution and escape guard. |
| `BLITZ_MCP_TIMEOUT_MS` | `30000` | Per-call timeout in ms for MCP tool invocations. |
| `BLITZ_MCP_MAX_FRAME_BYTES` | `1048576` | Maximum JSON-RPC frame size in bytes. |

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

## Pi extension

`@codewithkenzo/pi-blitz` — Effect v4 Pi extension that wraps this binary. Exposes typed tools for AST reads, structured apply operations, semantic patch helpers, rename, undo, and doctor. See the extension README for install and configuration.

For local use before the extension is published, the MCP server (`mcp/blitz-mcp.ts`) covers the same tool surface and works with any MCP-capable host.

## Design reference

`docs/blitz.md` — full spec covering CLI surface, edit algorithm, layer pipeline, Zig 0.16 alignment, benchmark data, and risk register.

## License

MIT. See `LICENSE`, `NOTICE.md`.
