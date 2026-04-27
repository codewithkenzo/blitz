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

Optional env:

```text
BLITZ_MCP_TIMEOUT_MS=30000
BLITZ_MCP_MAX_FRAME_BYTES=1048576
```

## Protocol support

- JSON-RPC 2.0
- MCP stdio `Content-Length` framing only
- `initialize`
- `notifications/initialized`
- `tools/list`
- `tools/call`

Server logs nothing to stdout except JSON-RPC frames.

## Safety behavior

- Tool file paths are resolved under `BLITZ_WORKSPACE` / process cwd.
- Absolute paths outside workspace are rejected.
- Frames above `BLITZ_MCP_MAX_FRAME_BYTES` are rejected.
- Blitz subprocess calls use `BLITZ_MCP_TIMEOUT_MS`.
- HTTP transport is not implemented.

## Tools exposed

- `blitz_doctor`
- `blitz_read`
- `blitz_patch`
- `blitz_try_catch`
- `blitz_replace_return`
- `blitz_undo`

## Smoke

Manual client sent framed messages:

1. `initialize`
2. `tools/call` for `blitz_try_catch`
3. `tools/call` for `blitz_read` on `/etc/passwd`

Result: valid `Content-Length` JSON-RPC frames. Mutation succeeded. Escape read rejected.

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

Escape check:

```json
{"code":-32000,"message":"path escapes workspace: /etc/passwd"}
```

## Current status

This is a working alpha MCP bridge.

Done:

- stdio config snippet documented in README
- automated smoke exists at `scripts/mcp-smoke.ts` / `npm run smoke:mcp`
- smoke covers mutation, absolute escape rejection, and symlink escape rejection

Still later:

- test with Pi MCP adapter / Claude Desktop style config
- consider native `blitz mcp` later, after protocol surface is stable
