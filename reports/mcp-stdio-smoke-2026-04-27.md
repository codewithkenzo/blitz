# MCP stdio smoke — 2026-04-27

Implemented initial MCP stdio bridge:

```text
mcp/blitz-mcp.ts
```

Runtime:

```bash
BLITZ_BIN=/home/kenzo/dev/blitz/zig-out/bin/blitz \
BLITZ_WORKSPACE=/path/to/workspace \
bun /home/kenzo/dev/blitz/mcp/blitz-mcp.ts
```

## Protocol support

- JSON-RPC 2.0
- MCP stdio `Content-Length` framing
- newline-delimited JSON fallback for simple manual tests
- `initialize`
- `notifications/initialized`
- `tools/list`
- `tools/call`

Server logs nothing to stdout except JSON-RPC frames.

## Tools exposed

- `blitz_doctor`
- `blitz_read`
- `blitz_patch`
- `blitz_try_catch`
- `blitz_replace_return`
- `blitz_undo`

## Smoke

Manual client sent three framed messages:

1. `initialize`
2. `tools/list`
3. `tools/call` for `blitz_try_catch`

Result: all responses valid `Content-Length` JSON-RPC frames. File mutated correctly.

Input:

```ts
function handle(value: number): number {
  const doubled = value * 2;
  return doubled;
}
```

Output:

```ts
function handle(value: number): number {
  try {
    const doubled = value * 2;
    return doubled;
  } catch (error) {
    console.error(error);
    throw error;
  }
}
```

## Current status

This is a working spike, not release-final MCP packaging yet.

Before release:

- decide whether MCP bridge ships inside `@codewithkenzo/blitz` package or separate `@codewithkenzo/blitz-mcp`
- add a real MCP smoke script/test
- test with Pi MCP adapter / Claude Desktop style config
- document stdio config snippet
- consider native `blitz mcp` later, after protocol surface is stable
