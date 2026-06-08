# AGENTS.md — mcp

Standalone Blitz MCP server rules. Read `../AGENTS.md` first.

## Purpose

`mcp/` exposes Blitz as MCP tools for external agents. It is not the companion `@codewithkenzo/pi-blitz` repo, but schema/token-tax lessons apply.

## Skills to load

- `kenzo-bun` — Bun/TypeScript scripts.
- `kenzo-mcporter` — MCP access-layer patterns when comparing protocol behavior.
- `.pi/skills/blitz-benchmarking` — required before measuring schema/context tax or making token claims.

## Commands

```bash
bun mcp/blitz-mcp.ts
bun scripts/mcp-smoke.ts
bun run smoke:mcp
```

Package checks:

```bash
npm pack --dry-run --json
```

## Schema/token rules

- Keep model-visible tool schemas compact and stable.
- Document visible tool list/profile when benchmarked.
- Do not add examples, prose, or duplicate enums to resident schemas unless measured.
- Prefer tiny success output: changed file, op summary, byte/range info, validation status.
- Do not claim Pi core-edit replacement from MCP-only behavior.

## Boundaries

- MCP protocol/server behavior lives here.
- Pi extension registration, resident skill text, profile selection, and facade routing live in `/home/kenzo/dev/pi-blitz`.
- Avoid unrelated MCP refactors during Blitz 0.4 token work.

## Anti-patterns

- No broad tool-surface expansion without token accounting.
- No schema churn that breaks prompt-cache locality without report note.
- No hidden dependency on globally installed Blitz when local binary path matters; report install/source path.
