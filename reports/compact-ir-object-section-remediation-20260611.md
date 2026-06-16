# Compact IR object/section target remediation

Date: 2026-06-11
Branch: `feat/blitz-0.4-token-core-profile`
Implementation commit: `3942de4 Support compact object and section targets`

## Auditor blocker addressed

Previous audit found that the minimum v1 resolver contract required `t.k` support for:

```text
function | method | class | object | section | any
```

but `targetKindMatches` did not support `object` or `section`.

## Implemented semantics

Changed files:

- `src/grammar_config.zig`
- `src/ast.zig`

Semantics:

- `object`: matches only object-valued `variable_declarator` nodes. Scalar variables do not match.
- `section`: intentionally narrow named container semantics: class/type-ish declarations plus object-valued variables. Functions do not match.
- unsupported kind strings still fail closed by matching nothing.
- object-valued variable body replacement uses the object literal brace interior, so compact `rb` can update object contents safely.

## Evidence

Tests added in `src/ast.zig`:

- `ast kind filter object matches only object-valued declarations`
- `ast kind filter section matches named containers but not functions`

Builder CLI smokes passed:

- object success: `Config` object body replaced with compact `k:"object"`.
- object rejection: scalar `Count` rejected with `SYMBOL_NOT_FOUND`.
- section success: `Panel` class body replaced with compact `k:"section"`.
- section rejection: `helper` function rejected with `SYMBOL_NOT_FOUND`.
- bogus kind rejected with `SYMBOL_NOT_FOUND`.

Main-agent final verification after the commit:

```bash
zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig src/grammar_config.zig
zig build
zig build test
```

Result: passed.

pi-blitz verification rerun:

```bash
bun run typecheck
bun test
bun run build
```

Result: passed.

## Status

The explicit minimum resolver set now has implemented support for all required kinds:

```text
function, method, class, object, section, any
```

This closes the final independent-auditor implementation blocker. Overall product posture remains unchanged: compact route is a verified candidate/fallback, not default-ready, and no token-savings claim is made.
