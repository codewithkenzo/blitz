# AGENTS.md — grammars

Vendored grammar rules. Read `../AGENTS.md` first.

## Purpose

`grammars/` contains vendored tree-sitter grammars and shared scanner code used by Blitz language support.

## Skills to load

- `kenzo-zig-build` — grammar C source/build integration.
- `kenzo-zig` — parser integration and ABI-facing changes.

## Rules

- Treat grammar dirs as vendored upstream code.
- Do not hand-edit generated parser/scanner files unless explicitly doing a documented vendor patch.
- Preserve grammar licenses and update `NOTICE.md` when source/vendor set changes.
- Add/remove grammar support through `build.zig`, `src/grammar_config.zig`, and tests together.
- Avoid broad grammar refresh during unrelated edit-engine work.

## Verification

```bash
zig build
zig build test
```

For language support changes, add focused CLI smoke using representative fixture before claiming parser coverage.
