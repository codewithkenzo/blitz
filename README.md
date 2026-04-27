# blitz

Fast edits for coding agents. Less token waste, less waiting.

On a 10k-function try/catch wrap benchmark, Blitz used 85 provider output tokens instead of 9,640 and finished in 4.6s instead of 61s.

Blitz lets an agent change a large function without printing the large function back to you. Instead of sending thousands of tokens of replacement code, the model can send a tiny instruction like “wrap `handleRequest` in try/catch” or “replace the last return in `computeTotal`.” Blitz finds the code, applies the change, validates it, and keeps an undo snapshot.

## Why use it

Coding agents are slow and expensive when they rewrite code they mostly want to keep. Blitz is built for edits where most of the file should stay unchanged.

### Current benchmark snapshot

`gpt-5.4-mini`, live Pi tool calls, N=1 full matrix plus prior N=5 checks on strong classes:

| Edit class | Core edit | Blitz | Result |
|---|---:|---:|---|
| 10k function try/catch wrap | 9,640 output tokens / 61s | 85 output tokens / 4.6s | 99.1% fewer output tokens |
| Large structural patch, 3 edits | 9,708 output tokens / failed output | 107 output tokens / correct | 98.9% fewer output tokens vs failed core attempt |
| Async try/catch wrapper | 149 arg tokens | 42 arg tokens | 71.8% fewer tool-call arg tokens |
| Class method try/catch wrapper | 118 arg tokens | 40 arg tokens | 66.1% fewer tool-call arg tokens |
| TSX return replacement | 67 arg tokens | 48 arg tokens | 28.4% fewer tool-call arg tokens |

Full reports live under `reports/`. Public claims should keep correctness and token categories separate.

Good Blitz edits are usually:

- wrapping a large function body
- changing a return expression
- inserting a line after a known statement
- doing several small structural edits in one file
- renaming an identifier without touching comments or strings

On a larger three-edit structural patch, Blitz used 107 output tokens where a core edit attempt used 9,708 and failed the expected output. For smaller semantic edits, the savings are smaller but still useful: try/catch wrappers cut tool-call arguments by 66–72%, and return-expression rewrites cut them by 22–28% in the current Pi bench.

Small one-line edits still belong to normal text editing tools.

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

### npm

```bash
npm install -g @codewithkenzo/blitz
blitz doctor
```

The npm package installs a small wrapper plus the matching native platform package when available. `BLITZ_BIN` is still supported if you want to point at a custom local build:

```bash
BLITZ_BIN=/abs/path/to/blitz/zig-out/bin/blitz blitz doctor
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
