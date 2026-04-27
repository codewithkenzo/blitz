# Blitz release roadmap — locked 2026-04-27

## Current release branch

- Zig baseline: `0.16.0` stable.
- Tree-sitter: vendored C core + grammars, static link, tiny checked-in extern ABI, no `@cImport`.
- Pi extension: Effect v4 wrapper around the CLI.
- Benchmark evidence: see `reports/strong-classes-n5-summary-2026-04-27.md` and canonical N=5 raw reports.

## Completed after reviewer pass

Reviewer blockers addressed in `fix: harden blitz release blockers` and `feat(pi-blitz): add semantic patch tools`:

- Mutating CLI paths now acquire a per-realpath process lock before backup/write/undo.
- `set_body` is implemented in `blitz apply`.
- `multi_body` extension schema no longer advertises `compose_body`.
- `--diff` no longer serializes the whole edited file through JSON.
- Rename validates new identifiers and reparses before writing.
- Extension config docs/schema only expose the implemented `binary` option.
- Superseded patch benchmark reports moved under `reports/archive/superseded-2026-04-27/`.
- Added narrow semantic Pi tools:
  - `pi_blitz_try_catch`
  - `pi_blitz_replace_return`

Validation run:

```bash
~/.local/bin/zig-0.16 build test -Dtarget=x86_64-linux-musl
~/.local/bin/zig-0.16 build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
cd extensions/pi-blitz && bun run typecheck && bun test && bun run build
```

## Next high-ROI implementation

1. **Fresh Pi smoke for new narrow tools**
   - `pi_blitz_try_catch`
   - `pi_blitz_replace_return`
   - Verify one-call behavior and output tokens.

2. **Fixture expansion**
   - async function with `await`
   - class method body wrap
   - arrow function return replacement
   - TSX function component
   - nested returns with explicit occurrence
   - multi-symbol return replacement

3. **N=5 benchmark only for promising classes**
   - Start N=1 for new fixtures.
   - Promote to N=5 only when N=1 is correct and token-efficient.

4. **Packaging smoke**
   - `npm pack` for CLI package shape.
   - temp install.
   - `blitz doctor`.
   - `pi install` extension source/package.
   - live `pi_blitz_doctor` and one mutating tool smoke.

## MCP server lane

MCP is approved as a next surface, but should not block the Pi extension release.

### Transport decision

- Start with **stdio**.
- Reason: official MCP stdio is the right transport for local CLI/IDE integrations and requires no network/auth/origin surface.
- HTTP is deferred until after stdio because official Streamable HTTP requires Origin validation, localhost binding, auth/session handling, and protocol-version header behavior.

### Dependency decision

Evaluate `mcp.zig` in an isolated branch before adopting:

- It supports STDIO and HTTP transports.
- It is young (`v0.0.3`, small repo).
- Its HTTP docs appear simpler than the current official Streamable HTTP spec.
- If stdio compiles cleanly on Zig 0.16 and obeys stdout/stderr rules, use it.
- Otherwise implement minimal MCP stdio JSON-RPC directly for `initialize`, `tools/list`, and `tools/call`.

### Candidate MCP tools

- `blitz_read`
- `blitz_apply`
- `blitz_wrap_body`
- `blitz_try_catch`
- `blitz_replace_return`
- `blitz_patch`
- `blitz_undo`
- `blitz_doctor`

### Diff handling

- Do not return large diffs as default text.
- Return compact structured content with metrics/ranges/diff summary.
- For full diff, return a resource link such as `blitz://diff/<id>` once resource support exists.

## Zig 0.17 lane

Do not move the release branch to Zig 0.17 now.

Reasons:

- No tagged `0.17.0` release yet.
- 0.17 milestone remains open and moving.
- Current 0.16.0 musl build/test path is green.
- Tree-sitter C interop is stable on 0.16.

Run a separate evaluation branch only:

```bash
zig-0.17 build test -Dtarget=x86_64-linux-musl
zig-0.17 build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
./zig-out/bin/blitz doctor
```

Measure:

- build/test pass rate
- binary size
- build time
- ReleaseSafe tree-sitter doctor behavior
- host `.sframe` linker issue

## Deferred

- Router tool: rejected due overhead.
- HTTP MCP server: after stdio + security design.
- Broad Windows support: after Linux/macOS release path.
- Fuzzy recovery/semantic query rewrites: after structured ops are fully benchmarked.
