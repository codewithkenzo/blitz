# AGENTS.md — third_party

Vendored dependency rules. Read `../AGENTS.md` first.

## Purpose

`third_party/` contains vendored upstream code used by Blitz, especially tree-sitter C sources.

## Skills to load

- `kenzo-zig-build` — when build integration or C source lists change.
- `kenzo-zig` — when Zig bindings depend on vendored ABI behavior.

## Rules

- Treat vendored code as upstream-owned.
- Avoid direct edits unless fixing integration-critical issues with clear source note.
- Preserve license headers and `NOTICE.md` obligations.
- Keep C ABI changes reflected in `src/tree_sitter/bindings.zig` and `build.zig`.
- Do not mix vendor updates with Blitz feature logic.

## Verification

```bash
zig build
zig build test
```

If vendored tree-sitter files change, document upstream source/version and update attribution if needed.
