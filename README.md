# blitz

Fast edits for coding agents. Less token waste, less waiting.

Blitz lets an agent change a large function without printing the large function back to you. Instead of sending thousands of tokens of replacement code, the model can send a tiny instruction like “wrap `handleRequest` in try/catch” or “replace the last return in `computeTotal`.” Blitz finds the code, applies the change, validates it, and keeps an undo snapshot.

## Why use it

Coding agents are slow and expensive when they rewrite code they mostly want to keep. Blitz is built for edits where most of the file should stay unchanged.

Good Blitz edits are usually:

- wrapping a large function body
- changing a return expression
- inserting a line after a known statement
- doing several small structural edits in one file
- renaming an identifier without touching comments or strings

On a measured 10k-token function wrap, Blitz reduced model output from about 9,600 tokens to about 85 tokens and cut wall time from about 62s to about 4s. Small one-line edits still belong to normal text editing tools.

## How it works

Blitz uses tree-sitter to locate code by symbol and edit the relevant body/span directly. The model sends a compact operation; Blitz handles the file read, AST lookup, indentation, parse validation, backup, and write.

No Python. No local model. No model routing layer. Just a native Zig CLI.

## Install

### Build from source

```bash
git clone https://github.com/codewithkenzo/blitz
cd blitz
zig build -Doptimize=ReleaseFast
./zig-out/bin/blitz doctor
```

### npm wrapper

```bash
npm install -g @codewithkenzo/blitz
```

The npm package provides a wrapper. Until native platform packages are published, point it at your local build:

```bash
export BLITZ_BIN=/abs/path/to/blitz/zig-out/bin/blitz
blitz doctor
```

## Basic CLI usage

Read a file summary:

```bash
blitz read src/app.ts
```

Replace a symbol body:

```bash
cat new-body.ts | blitz edit src/app.ts --replace handleRequest --snippet -
```

Apply a compact structured edit:

```bash
cat <<'JSON' | blitz apply --edit - --json
{
  "version": 1,
  "file": "src/app.ts",
  "operation": "patch",
  "edit": {
    "ops": [
      ["try_catch", "handleRequest", "console.error(error);\nthrow error;"]
    ]
  }
}
JSON
```

Undo last Blitz edit for a file:

```bash
blitz undo src/app.ts
```

## Commands

| Command | Use for |
|---|---|
| `blitz read <file>` | File summary with declarations and line ranges. |
| `blitz edit` | Symbol-anchored body replacement or insertion. |
| `blitz batch-edit` | Multiple symbol edits in one file. |
| `blitz apply` | Compact JSON operations for low-token agent calls. |
| `blitz rename` | Rename code identifiers while skipping strings/comments. |
| `blitz undo` | Revert the last Blitz edit for a file. |
| `blitz doctor` | Check binary, grammars, and cache. |

## Agent integrations

### Pi extension

Use [`@codewithkenzo/pi-blitz`](https://github.com/codewithkenzo/pi-blitz) for Pi.

```bash
pi install npm:@codewithkenzo/pi-blitz
```

Configure the binary:

```json
// ~/.pi/pi-blitz.json
{ "binary": "/abs/path/to/blitz/zig-out/bin/blitz" }
```

### MCP server

Blitz also ships a stdio MCP server:

```bash
BLITZ_BIN=/abs/path/to/blitz/zig-out/bin/blitz \
BLITZ_WORKSPACE=/abs/path/to/project \
bun /abs/path/to/blitz/mcp/blitz-mcp.ts
```

Example `.mcp.json`:

```json
{
  "servers": {
    "blitz": {
      "command": "bun",
      "args": ["/abs/path/to/blitz/mcp/blitz-mcp.ts"],
      "env": {
        "BLITZ_BIN": "/abs/path/to/blitz/zig-out/bin/blitz",
        "BLITZ_WORKSPACE": "/abs/path/to/project"
      }
    }
  }
}
```

The MCP server rejects paths that escape `BLITZ_WORKSPACE`, including symlink escapes.

## When to use Blitz

Use Blitz when the model would otherwise need to repeat a lot of unchanged code.

| Use Blitz | Use normal edit/write |
|---|---|
| Large function body wraps | Tiny one-line changes |
| Return-expression rewrites | New files |
| Multi-step edits in one file | Whole-file rewrites |
| Identifier rename in code | Unsupported languages |
| Agent token savings matter | Human knows exact text replacement |

## Supported languages

- TypeScript
- TSX
- Python
- Rust
- Go

Unsupported files fall back to the host agent/editor.

## Development

```bash
zig build test -Dtarget=x86_64-linux-musl
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
bun scripts/mcp-smoke.ts
npm pack --dry-run --json
```

## License

MIT
