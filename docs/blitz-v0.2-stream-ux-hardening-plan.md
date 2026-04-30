# Blitz Stream UX + v0.2 Hardening Plan

Status: active draft
Owner: Kenzo / Pi main agent
Repos: `codewithkenzo/blitz`, `codewithkenzo/pi-blitz`, Pi Rig mirror
Branch: `spec/blitz-v02-stream-ux-plan`
Last updated: 2026-04-28

## Purpose

Make Blitz feel obvious and trustworthy in AI coding sessions without adding setup friction or token noise.

This plan separates the immediate patch slice from deeper v0.2/v1 hardening:

1. **v0.1.x patch:** stream-readable Pi tool results and MCP/install docs polish.
2. **v0.2:** safety tests, optional Pi renderers/progress, code-shape cleanup prep.
3. **v1 readiness:** CI provenance, platform runtime verification, stronger locking, deeper refactors.

No full TUI overlay for this plan. The stream is the product surface.

## Current state

- `@codewithkenzo/blitz@0.1.0-alpha.10` published.
- `@codewithkenzo/pi-blitz@0.1.0-alpha.10` published.
- Platform packages published for Linux x64/arm64 musl, macOS arm64/x64, Windows x64.
- Linux x64 npm/Pi/MCP path has been smoke-tested locally.
- macOS/Windows packages are published but not runtime-verified yet.
- MCP server supports `blitz-mcp --workspace <path>`.
- MCP falls back to current working directory only when it looks like a project root.
- Zig CLI enforces workspace boundaries via `--workspace-root`.
- Pi extension calls Blitz as subprocess and returns text + structured `details`.
- Tool results are functional but too mechanical for human skimming.
- No `renderCall`/`renderResult` is wired in `pi-blitz` today.
- Current pi-blitz `execute` functions use narrower 2-arg signatures even though Pi supports 5 args.
- `multi/three-body-ops` benchmark expectation fixed.
- Vendored grammars and benchmark fixtures are hidden from GitHub Linguist stats.

## Decision principles

1. Install friction wins. Default path must remain `npm install` / `pi install` / copy-paste MCP.
2. Stream output must be compact. `content[0].text` enters model context across Pi and MCP-like clients.
3. Pi renderers are TUI cosmetics only. They reduce **zero** MCP/provider tokens.
4. Safety is enforced quietly through workspace guards, path checks, and clear errors.
5. Token-savings proof belongs in docs/benchmarks and only selectively in stream.
6. No router. Keep narrow tools and compact payloads.
7. No full TUI overlay in this phase.
8. Effect v4 is the target. Pin v4 beta exactly until stable.
9. Zig performance claims must be measured.

## UX target: stream result text

Default result text should be readable without custom renderer support.

Normal applied result, maximum 5 lines:

```text
blitz patch applied: src/app.ts
op: try_catch(handleRequest)
parse: clean
changed: +6/-1 · wall: 42ms
```

Applied result may include savings only when all are true:

- status is `applied`
- parse is clean
- metric is present
- estimated savings is at least 30%

Example optional fifth line:

```text
saved: ~72% payload vs anchor edit
```

Preview result:

```text
blitz patch preview: src/app.ts
op: replace_return(computeTotal)
parse: clean
changed: +1/-1 · no files written
```

Soft miss:

```text
blitz miss: symbol not found
file: src/app.ts
next: run pi_blitz_read or use core edit
```

Do not include by default:

- source snippets
- raw ranges
- raw metrics JSON
- long diffs
- undo instructions in model-visible text

Undo hints belong in `details.summary` / Pi renderer if renderer lands, not default stream content.

## UX target: Pi renderer, optional and zero-token-impact for MCP

Renderer work is **not** stream-token optimization. It only improves Pi's interactive collapsed display.

If current Pi package types allow it without `as any`, add:

- `renderCall` for concise call display.
- `renderResult` for one-line collapsed Pi stream display.
- plain `content[0].text` remains canonical fallback.

Collapsed result shape:

```text
✓ blitz patch · src/app.ts · try_catch(handleRequest) · clean · +6/-1 · 42ms
```

Partial/running shape from call args or update details:

```text
◌ blitz patch · running · src/app.ts
```

Failure shape:

```text
✗ blitz miss · src/app.ts · symbol not found
```

Implementation should model `flow-system/src/renderers.ts` conceptually. Because `pi-blitz` is a separate repo, vendor tiny helpers like `ellipsize` locally rather than importing Pi Rig shared internals.

## Workstream D — Zig safety tests and hardening backlog

Run this early as backfill, before any major Zig refactor. It does not need to block the v0.1.x stream-UX patch.

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `src/workspace.zig`
- `src/lock.zig`
- `src/cmd_read.zig`
- `src/test_all.zig`
- new dedicated test files only if added to `build.zig`

Scope for next implementation batch:

- Add named Zig tests for:
  - `workspace realpath allows in-root file`
  - `workspace rejects absolute path outside root`
  - `workspace rejects symlink escape`
  - `read rejects huge source over cap`
  - `apply rejects huge stdin over cap`
  - `lock stale cleanup removes old lock dir`
- Verify `BLITZ_WORKSPACE` passed by Pi extension stays aligned with CLI `--workspace-root` safety model.

Defer until tests exist:

- PID/owner lock records.
- clearer lock contention messages.
- deeper `cmd_apply.zig` split.

Acceptance criteria:

- Each listed scenario has a named test or a tracked follow-up ticket with reason.
- Existing stress scripts become optional confidence checks, not sole coverage.
- Linux musl validation remains green.

Validation:

```bash
~/.local/bin/zig-0.16 build test -Dtarget=x86_64-linux-musl
~/.local/bin/zig-0.16 build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
bun scripts/mcp-smoke.ts
npm pack --dry-run --json
```

## Workstream A — Pi stream readability

This is the highest-value v0.1.x patch.

Target repo: `/home/kenzo/dev/pi-blitz`

Primary files:

- `src/tools.ts`
- `src/tool-runtime.ts`
- `test/apply-runtime.test.ts`
- `test/smoke.test.ts`
- optional new `test/format.test.ts`

Current gaps:

- `applyResultToText` emits one mechanical dotted sentence.
- `editMetricsResult` emits a long payload-estimate sentence.
- `renderSoftText` includes raw `stderr`, which can be multi-line/noisy.
- Tests do not assert line/char budgets.

Implementation details:

- Refactor formatting into small pure helpers:
  - `formatBlitzStatusLine`
  - `formatOpLabel`
  - `formatParseLine`
  - `formatDiffWallLine`
  - `formatSavingsLine`
- Keep canonical structured data in `details`, but avoid duplicate large fields.
- Add `details.summary` as compact renderer/update source.
- If adding derived fields, keep them small and non-duplicative:
  - `opLabel`
  - `pathLabel`
  - `durationMs`
  - `changeLabel`
  - `savingsPct`
- Preserve existing detailed `metrics`, `diffSummary`, and `validation` only if already present and useful.
- Restrict savings line to `applied` + parse clean + savings >= 30%.
- No savings line for preview.
- Remove default undo line from stream text.
- Tighten soft errors:
  - first stderr line only
  - max 200 stderr chars before ellipsis
  - total soft error text max 350 chars

Acceptance criteria:

- Normal success text <= 5 lines.
- Normal success text <= 450 chars.
- Soft error text <= 350 chars.
- No raw JSON in content text.
- No source snippets unless `include_diff` explicitly requests CLI diff output.
- No savings claim on preview or parse-dirty result.
- `details.summary` present for normal success and soft miss.
- Existing tests pass.
- Add tests for applied, preview, dirty parse, soft miss, and multi-operation patch summary.

Validation:

```bash
bun run typecheck
bun test
bun run build
npm pack --dry-run --json
```

If repo adds lint/format tooling later, include it here. Do not invent `oxlint`/`oxfmt` unless package config owns those commands.

## Workstream C — MCP/install docs UX

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `README.md`
- `docs/blitz.md`

External references verified:

- Claude Code MCP docs use `mcpServers`, `command`, `args`, `env`, and CLI `claude mcp add ... -- <command> [args...]`.
- Claude Desktop currently prefers Desktop Extensions / `.mcpb`; direct JSON remains possible but should not be over-emphasized.
- VS Code MCP docs use top-level `servers`, `type: "stdio"`, `command`, `args`, and `${workspaceFolder}`.
- Codex MCP docs use `[mcp_servers.<name>]`, `command`, `args`, optional `env`, `env_vars`, `cwd`.
- Cursor docs expose MCP but exact current snippet shape is less stable/public; keep wording conservative.

Implementation details:

- Keep README first-screen focused on value + install.
- MCP section should start with copy/paste commands/snippets.
- Add Claude CLI helper example:

```bash
claude mcp add --transport stdio blitz -- npx --yes --package=@codewithkenzo/blitz -- blitz-mcp --workspace "$PWD"
```

- Keep JSON snippets secondary.
- VS Code snippet can use `${workspaceFolder}`.
- Codex snippet can keep `--workspace`; optionally add `cwd = "/absolute/path/to/project"` note.
- Keep `BLITZ_BIN` only under custom/source builds.
- Explain `command`/`args` in one sentence:
  - MCP clients launch Blitz as a local subprocess and speak JSON-RPC over stdin/stdout.
- Do not lead with env vars.

Acceptance criteria:

- First 60 README lines contain no `BLITZ_*` env variable mention.
- README has one primary copy/paste block per MCP client.
- Source build is clearly optional.
- macOS/Windows are described as published but not fully runtime-verified until tested.
- Snippets only use CLI flags that exist in `blitz-mcp` / Blitz wrapper.

## Workstream B1 — Minimal progress updates

Optional v0.2 item after Workstream A succeeds.

Target repo: `/home/kenzo/dev/pi-blitz`

Primary files:

- `src/tools.ts`
- `test/*.test.ts`

Implementation details:

- Update all 14 tool defs if adopting `onUpdate`:
  - `read`
  - `edit`
  - `batch`
  - `apply`
  - `replace_body_span`
  - `insert_body_span`
  - `wrap_body`
  - `compose_body`
  - `multi_body`
  - `patch`
  - `try_catch`
  - `replace_return`
  - `rename`
  - `undo`
  - `doctor`
- Note: this list has 15 registered tools including `doctor`; keep implementation exhaustive.
- Use the full Pi execute signature:

```ts
execute(toolCallId, params, signal, onUpdate, ctx)
```

- Add `emitBlitzUpdate(onUpdate, summary, details)` helper.
- Emit at most two default updates for normal single-file mutation:
  - `blitz: running <operation>`
  - `blitz: done`
- Consider no updates for very fast read/doctor calls.
- Never include code, diff, or large details in update text.

Acceptance criteria:

- Single-file mutation emits <= 2 updates.
- Read/doctor emit 0 or 1 updates.
- Updates are <= 120 chars each.
- Tests mock `onUpdate` and assert call count.

## Workstream B2 — Pi renderers

Optional v0.2 item after Workstream A succeeds. Zero token impact for MCP consumers.

Target repo: `/home/kenzo/dev/pi-blitz`

Primary files:

- `src/renderers.ts` (new if needed)
- `src/tools.ts`
- `test/*.test.ts`

Implementation details:

- Verify current `ToolDefinition` supports `renderCall` / `renderResult` in installed package types.
- Add renderers only if type-safe without `as any`.
- Define typed details before renderer work:

```ts
type BlitzDetails = PiBlitzDetails & {
  summary: string;
  opLabel?: string;
  pathLabel?: string;
  durationMs?: number;
  changeLabel?: string;
  savingsPct?: number;
};
```

- Prefer a single `BlitzDetails` type unless per-tool details truly diverge.
- Ensure `details` is always present once renderers depend on it; avoid `details: undefined` for success paths.
- Use local `ellipsize` helper, not Pi Rig shared import.

Acceptance criteria:

- Rendered result is one line in normal collapsed Pi stream.
- Plain result remains readable if renderer unavailable.
- No `as any` in renderer path.
- Generic `ToolDefinition` typing keeps result/details type-safe.

Validation:

```bash
bun run typecheck
bun test
```

## Workstream E — Code-shape cleanup

Target repo: `/home/kenzo/dev/blitz`

Primary files:

- `src/cmd_apply.zig`
- `src/ast.zig`
- `src/fallback.zig`
- `build.zig`

Plan:

1. Read-only scout maps current seams.
2. Confirm whether `src/ast.zig` and `src/fallback.zig` are imported or build-referenced.
3. Delete or clearly document unused placeholder/planned files only if build references prove safe.
4. Split `cmd_apply.zig` only after safety/golden tests exist.

Potential split:

- `apply_payload.zig` — slice E1 done; owns apply JSON payload/result types, error set, shared source cap.
- `apply_response.zig` — slice E2/E3 done; owns apply success/failure output emission and error reason mapping.
- `apply_ops.zig` — slice E4 done; owns operation/range parsing, JSON field helpers, and match selector/span selection.
- `apply_metrics.zig` — slice E5 done; owns status labels, language labels, diff summary construction, and success result metrics assembly.
- `cmd_apply_response_tests.zig` — slice E6 done; owns apply command semantic/golden tests moved out of production module.

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
- Current local check: `npm run release:check` (`scripts/check-release.mjs`). It verifies wrapper/platform package versions, local binary `--version` when present, generated MCP JS freshness, and pack contents.
- Later: publish with provenance from CI.

Acceptance criteria:

- No accidental alpha publish with mismatched platform package versions.
- Release steps are documented and reproducible.
- README explicitly states Linux verified / macOS+Windows published-only until runtime smoke runs.

## Effect v4 policy

Target package: `/home/kenzo/dev/pi-blitz/package.json`

- Pin Effect exactly to `=4.0.0-beta.48` until v4 stable or an intentional upgrade ticket.
- Use `Effect.runPromiseExit` at Pi boundaries.
- Use `Cause.findErrorOption` as current implementation does.
- Avoid v3-only helpers.
- Avoid new heavy Effect DI layers in pi-blitz.
- Keep TypeBox for schemas; do not migrate tool schemas to Effect Schema.
- Add typecheck/test coverage so beta API drift fails loudly.
- Watch `Effect.catch` alias; if beta removes it, switch to `Effect.catchAll` or current v4 equivalent in one dedicated change.

## Token-efficiency policy

- `content[0].text` is canonical and model-visible.
- Renderer output is Pi-only cosmetic.
- `details` may be visible to some clients; keep it useful but not bloated.
- Default mutation result <= 450 chars.
- Default soft error <= 350 chars.
- `onUpdate` events <= 120 chars each.
- No raw JSON or source snippets in default text.
- Savings line only on applied + parse-clean + >= 30% estimated savings.
- No savings line on preview.
- Benchmark claims continue to separate:
  - provider output tokens
  - tool-call arg tokens
  - input/cache tokens
  - correctness
  - wall time
  - cost

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

## Subagent execution plan

Use isolated worktrees for coding agents.

1. Pi UX worker
   - Repo: `/home/kenzo/dev/pi-blitz`
   - Skills: `kenzo-pi-extensions`, `kenzo-bun`, `kenzo-effect-ts`
   - Scope: Workstream A only first. B1/B2 only after A passes.
   - Verify: typecheck, tests, build, pack dry-run.

2. Zig scout
   - Repo: `/home/kenzo/dev/blitz`
   - Skills: `kenzo-zig`, `kenzo-zig-build`
   - Scope: Workstream D/E read-only first.
   - Output: seam map and test-first patch recommendation.

Main agent handles docs/MCP edits inline after researcher/reviewer notes. Final reviewer runs after first implementation diff.

## Release sequencing

### v0.1.x patch

- Pi stream readability.
- Soft error text cleanup.
- README/MCP copy-paste polish.
- Optional Effect exact pin if current range is loose.

### v0.2

- Minimal progress updates.
- Pi renderers if type-safe and low risk.
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

## Open questions

- Cursor exact current MCP snippet: keep conservative until verified in Cursor docs/app.
- Claude Desktop: decide whether to document `.mcpb`/Desktop Extension later or keep Blitz docs focused on Claude Code.
- Pi renderer generics: verify package types before implementation.
- Whether `details` is serialized into LLM context in every client; keep it compact regardless.
