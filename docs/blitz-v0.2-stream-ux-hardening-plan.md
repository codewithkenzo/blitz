# Blitz v0.2 Stream UX + Hardening Plan

Status: active draft  
Owner: Kenzo / Pi main agent  
Repos: `codewithkenzo/blitz`, `codewithkenzo/pi-blitz`, Pi Rig mirror  
Last updated: 2026-04-28

## Purpose

Make Blitz feel obvious and trustworthy in AI coding sessions without adding setup friction or token noise.

This plan focuses on the next post-alpha.10 slice:

1. Stream-readable Pi tool results.
2. Minimal progress updates where they add trust.
3. MCP/install docs that start from copy/paste usage, not env/config theory.
4. Security/reliability hardening backlog captured clearly.
5. Release/CI and code-shape debt sequenced behind UX-safe work.

No full TUI overlay for this slice. The stream is the product surface.

## Current state

- `@codewithkenzo/blitz@0.1.0-alpha.10` published.
- `@codewithkenzo/pi-blitz@0.1.0-alpha.10` published.
- Platform packages published for Linux x64/arm64 musl, macOS arm64/x64, Windows x64.
- MCP server supports `blitz-mcp --workspace <path>`.
- MCP falls back to current working directory only when it looks like a project root.
- Zig CLI enforces workspace boundaries via `--workspace-root`.
- Pi extension calls Blitz as subprocess and returns text + structured `details`.
- Tool results are functional but too mechanical for human skimming.
- `multi/three-body-ops` benchmark expectation fixed.
- Vendored grammars and benchmark fixtures are hidden from GitHub Linguist stats.

## Decision principles

1. Install friction wins. Default path must remain `npm install` / `pi install` / copy-paste MCP.
2. Stream output must be compact. Every result line enters model context.
3. Safety is implicit, not marketing copy. Keep workspace guards and clear errors.
4. Token-savings proof belongs in docs/results when useful, not every tool call.
5. No router. Keep narrow tools and compact payloads.
6. No full TUI overlay in this phase. Add stream renderers first.
7. Effect v4 is the target. Do not introduce v3-only APIs or heavy DI.
8. Zig performance claims must be measured.

## UX target: Pi stream result

Normal applied result should fit in 5-6 short lines:

```text
blitz patch applied: src/app.ts
op: try_catch(handleRequest)
parse: clean
changed: +6/-1
wall: 42ms
undo: pi_blitz_undo file=src/app.ts
```

Preview result:

```text
blitz patch preview: src/app.ts
op: replace_return(computeTotal)
parse: clean
changed: +1/-1
no files written
```

Soft miss:

```text
blitz miss: symbol not found
file: src/app.ts
next: run pi_blitz_read or use core edit
```

Optional savings line only when all are true:

- status is `applied` or `preview`
- parse is clean
- metric is present
- estimated savings is greater than 20%

Example:

```text
saved: ~72% payload vs anchor edit
```

Do not include source snippets, ranges, raw metrics JSON, or long diffs by default.

## TUI/renderer target: stream-only

Do not build a `/blitz` overlay yet.

Add Pi tool renderers if supported by current ExtensionAPI and package types:

- `renderCall` for concise call display.
- `renderResult` for one-line collapsed stream display.
- fallback remains plain `content[0].text`.

Collapsed result shape:

```text
✓ blitz patch · src/app.ts · try_catch(handleRequest) · clean · +6/-1 · 42ms
```

Partial/running shape:

```text
◌ blitz patch · running · src/app.ts
```

Failure shape:

```text
✗ blitz miss · src/app.ts · symbol not found
```

Implementation should model `flow-system/src/renderers.ts`, not copy its deck overlay.

## Workstream A — Pi stream readability

Target repo: `/home/kenzo/dev/pi-blitz`

Primary files:

- `src/tools.ts`
- `src/tool-runtime.ts`
- `test/*.test.ts`

Implementation details:

- Refactor `applyResultToText` into small pure helpers:
  - `formatBlitzStatusLine`
  - `formatOpLabel`
  - `formatParseLine`
  - `formatDiffLine`
  - `formatSavingsLine`
  - `formatUndoLine`
- Preserve existing `details` payload.
- Add `details.summary` for renderer use.
- Add `details.status`, `details.operation`, `details.file`, `details.diffSummary`, `details.metrics` as today.
- Add small derived details if useful:
  - `opLabel`
  - `pathLabel`
  - `durationMs`
  - `added`
  - `removed`
  - `savingsPct`
- Improve `renderSoftText` so soft errors are short and actionable.
- Keep hard errors thrown.

Acceptance criteria:

- Normal success text <= 6 lines.
- Normal success text <= 450 chars.
- Soft error text <= 350 chars.
- No raw JSON in content text.
- No source snippets unless `include_diff` explicitly requests CLI diff output.
- Existing tests pass.
- Add/update tests for applied, preview, dirty parse, soft miss.

Validation:

```bash
bun run typecheck
bun test
bun run build
npm pack --dry-run --json
```

## Workstream B — Pi renderers and minimal progress updates

Target repo: `/home/kenzo/dev/pi-blitz`

Primary files:

- `src/renderers.ts` (new if needed)
- `src/tools.ts`
- `test/*.test.ts`

Implementation details:

- Verify current `ToolDefinition` supports `renderCall` / `renderResult` in installed `@mariozechner/pi-coding-agent` types.
- Add renderers only if type-safe without `as any`.
- Use `Text` from `@mariozechner/pi-tui` if available, following flow-system.
- Use `details.summary` first, then fallback to first text result.
- Add optional `emitBlitzUpdate` helper using the existing execute signature:

```ts
execute(toolCallId, params, signal, onUpdate, ctx)
```

- Emit at most two default updates:
  - `blitz: running <operation>`
  - `blitz: done`
- For very fast operations, it is acceptable to emit no updates beyond Pi's own running indicator.
- Never include code, diff, or large details in `onUpdate`.

Acceptance criteria:

- Rendered result is one line in normal collapsed stream.
- Plain result remains readable if renderer unavailable.
- Update events do not exceed two for normal single-file operations.
- No extra source/code tokens enter update text.

Validation:

```bash
bun run typecheck
bun test
```

## Workstream C — MCP/install docs UX

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `README.md`
- `docs/blitz.md`

External references verified:

- Claude Code MCP docs use `mcpServers`, `command`, `args`, `env`, and CLI `claude mcp add ... -- <command> [args...]`.
- VS Code MCP docs use top-level `servers`, `type: "stdio"`, `command`, `args`, and `${workspaceFolder}`.
- Codex MCP docs use `[mcp_servers.<name>]`, `command`, `args`, optional `env`, `env_vars`, `cwd`.

Implementation details:

- Keep README first-screen focused on value + install.
- MCP section should start with copy/paste commands/snippets.
- Add Claude CLI helper example:

```bash
claude mcp add --transport stdio blitz -- npx --yes --package=@codewithkenzo/blitz -- blitz-mcp --workspace "$PWD"
```

- Keep `BLITZ_BIN` only under custom/source builds.
- Explain `command`/`args` briefly:
  - MCP clients launch Blitz as a local subprocess and speak JSON-RPC over stdin/stdout.
- Do not lead with env vars.

Acceptance criteria:

- A user can install Pi extension without reading source-build instructions.
- A user can copy one MCP snippet without understanding `BLITZ_WORKSPACE`.
- Source build is clearly optional.
- macOS/Windows are described as published but not fully runtime-verified until tested.

## Workstream D — Zig safety tests and hardening backlog

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `src/workspace.zig`
- `src/lock.zig`
- `src/cmd_read.zig`
- `src/cmd_apply_tests.zig`
- `src/test_all.zig`

Scope for next implementation batch:

- Add tests before refactoring hot code.
- Cover:
  - `--workspace-root` realpath enforcement
  - absolute path escape rejection
  - symlink escape rejection
  - huge source cap
  - huge stdin cap
  - stale lock cleanup behavior

Defer until tests exist:

- PID/owner lock records.
- clearer lock contention messages.
- deeper `cmd_apply.zig` split.

Acceptance criteria:

- Existing stress scripts become optional confidence checks, not only coverage.
- Linux musl validation remains green.

Validation:

```bash
~/.local/bin/zig-0.16 build test -Dtarget=x86_64-linux-musl
~/.local/bin/zig-0.16 build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
bun scripts/mcp-smoke.ts
```

## Workstream E — Code-shape cleanup

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `src/cmd_apply.zig`
- `src/ast.zig`
- `src/fallback.zig`

Plan:

1. Read-only scout maps current seams.
2. Delete unused placeholder files only if build references prove safe.
3. Split `cmd_apply.zig` only after safety/golden tests exist.

Potential split:

- `apply_payload.zig`
- `apply_ops.zig`
- `apply_response.zig`
- `apply_metrics.zig`

Acceptance criteria:

- No behavior drift in semantic fixtures.
- No public command/schema changes.
- Wall time unchanged within noise on key rows.

## Workstream F — Release and provenance

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `.github/workflows/ci.yml`
- `.github/workflows/release.yml` (future)
- `scripts/check-release.mjs` (future)

Plan:

- Keep manual publish fallback until CI release passes twice.
- Add checks for:
  - main wrapper version matches platform package versions
  - optional dependency versions match
  - `blitz --version` matches package version
  - `mcp/blitz-mcp.js` generated from `mcp/blitz-mcp.ts`
  - `npm pack --dry-run --json` passes
- Later: publish with provenance from CI.

Acceptance criteria:

- No accidental alpha publish with mismatched platform package versions.
- Release steps are documented and reproducible.

## Subagent execution plan

Use isolated worktrees for any coding agents.

1. Pi UX worker
   - Repo: `/home/kenzo/dev/pi-blitz`
   - Skills: `kenzo-pi-extensions`, `kenzo-bun`, `kenzo-effect-ts`
   - Scope: Workstream A, maybe B after A passes.
   - Verify: typecheck, tests, build, pack dry-run.

2. Zig scout
   - Repo: `/home/kenzo/dev/blitz`
   - Skills: `kenzo-zig`, `kenzo-zig-build`
   - Scope: Workstream D/E read-only first.
   - Output: seam map and test-first patch recommendation.

3. Docs/MCP reviewer
   - Repo: `/home/kenzo/dev/blitz`
   - Skills: `kenzo-research-tools`, `kenzo-pi-web-search`
   - Scope: Workstream C.
   - Output: stale/confusing docs findings and exact snippets.

4. Final reviewer
   - Review final spec + first implementation diff.
   - Focus: token bloat, UX regression, safety, over-scoping.

## External trend check

`gx` result on 2026-04-28 ranked priorities:

1. Install friction.
2. MCP setup.
3. Readable tool results in agent stream.
4. Progress UI.
5. Safety.
6. Token savings proof.
7. Advanced config.

Interpretation for Blitz:

- Keep install/MCP easy above all.
- Make stream results skimmable next.
- Progress should build trust but stay sparse.
- Keep safety enforced but not noisy.
- Token savings proof should be visible in docs/benchmarks and only selectively in stream.
- Advanced config stays at bottom of README.

## Release sequencing

### v0.1.x patch

- Pi stream readability.
- Soft error text cleanup.
- README/MCP copy-paste polish.
- Optional renderers if type-safe and low risk.

### v0.2

- Minimal progress updates.
- Zig safety tests.
- Placeholder cleanup.
- Initial release/version consistency checks.

### v1 readiness

- CI platform build/publish with provenance.
- Runtime verification on macOS and Windows.
- Stronger lock owner/PID behavior.
- `cmd_apply.zig` refactor complete.
- Stable docs without stale alpha/source-build framing.

## Final verification matrix

Blitz CLI:

```bash
~/.local/bin/zig-0.16 build test -Dtarget=x86_64-linux-musl
~/.local/bin/zig-0.16 build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
bun scripts/mcp-smoke.ts
npm pack --dry-run --json
```

Pi Blitz:

```bash
bun run typecheck
bun test
bun run build
npm pack --dry-run --json
```

Install smoke after publish, if publishing:

```bash
npm install @codewithkenzo/pi-blitz@latest --prefer-online
./node_modules/.bin/blitz --version
npx --yes --package=@codewithkenzo/blitz -- blitz-mcp --workspace "$PWD"
pi install npm:@codewithkenzo/pi-blitz@<version>
```

## Rollback plan

- Result text formatting can revert independently of Blitz CLI.
- Renderers can be removed while keeping plain text output.
- `onUpdate` helper can become a no-op.
- Docs changes can be patched without package release.
- Zig refactors should not start until test coverage exists.
