# AGENTS.md — src/apply

Structured edit engine rules. Read `../AGENTS.md` and `../../AGENTS.md` first.

## Purpose

`src/apply/` owns Blitz structured edit IR, target selection, operation execution, patch handling, validation, and apply-layer tests.

## Skills to load

- `kenzo-zig` — Zig 0.16 implementation patterns.
- `.pi/skills/blitz-benchmarking` — required for compact IR/token-impact work.

## Files

- `ir.zig` — operation/input representation.
- `target.zig` — target resolution.
- `operations.zig` — concrete edit operations.
- `validate.zig` — preflight and safety validation.
- `patch.zig`, `diff.zig` — patch/diff handling.
- `errors.zig` — apply-layer errors.
- `test_support.zig` — focused test helpers.
- `mod.zig` — module surface.

## 0.4 constraints

- Compact IR must reduce model-visible tokens, not just bytes.
- Prefer short aliases only when reports include exact token accounting.
- Structural ops must avoid replaying unchanged surrounding code.
- Target resolution must be deterministic; ambiguity should fail with actionable candidates.
- Tiny success output is product behavior: op, target, changed range, validation status.
- Keep core/apply_patch fallback honest when Blitz route loses tokens.

## Safety rules

- Validate before mutation.
- Keep operations local to requested file/range/symbol.
- Do not hide failed preconditions behind fuzzy fallback.
- Preserve newline/format behavior intentionally; benchmark newline drift as failure unless accepted by fixture.

## Verification

```bash
zig build test
```

Add or update focused tests with operation changes. If token-facing op syntax changes, update benchmark fixtures/reports in same work loop.
