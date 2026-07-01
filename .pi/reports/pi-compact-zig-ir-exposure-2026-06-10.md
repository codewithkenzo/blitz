# pi-blitz compact Zig IR exposure benchmark report

Date: 2026-06-10

## Runner / environment

- Provider/model: `anthropic` / `claude-haiku-4-5`
- Pi runner: `tmux`
- Pi binary: `/home/kenzo/.local/bin/pi`
- Blitz repo: `/home/kenzo/dev/blitz`
- pi-blitz source path: `/home/kenzo/dev/pi-blitz`
- pi-blitz build/install method: local source build via `bun run build`, benchmark extension path `/home/kenzo/dev/pi-blitz/dist/index.js`
- Blitz binary path prepend: `/home/kenzo/dev/blitz/zig-out/bin`
- Tool profile: `minimal`
- Visible compact tools: `pi_blitz_op`
- Tokscale mode: `--tokscale` required

## pi-blitz implementation evidence

`pi_blitz_op` now sends compact request JSON directly to `blitz apply --edit - --json`:

```json
{"v":1,"f":"/abs/file.ts","ops":[["rb","function","next","\n  return 2;\n"]]}
```

No expansion to `multi_body` or verbose apply wrapper occurs on this path. `pi_blitz_route_edit` also executes compact payloads through same direct compact path when route selects Blitz.

## Verification commands

From `/home/kenzo/dev/pi-blitz`:

```bash
bun run typecheck
bun test
bun run build
```

All passed.

## Benchmark commands

Combined run attempt:

```bash
bun bench/pi-matrix.ts --iters 1 --case medium-10k/marker-tail --tool-profile minimal --artifact-profiles minimal --runner tmux --tokscale --timeout-ms 180000 --json-out .pi/reports/pi-compact-ir-2026-06-10-r2.json --md-out .pi/reports/pi-compact-ir-2026-06-10-r2.md --extension /home/kenzo/dev/pi-blitz/dist/index.js --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz --pi-blitz-package /home/kenzo/dev/pi-blitz
```

Result: harness stopped before full compare because default lane set includes router, but `minimal` profile intentionally exposes only `pi_blitz_op`:

```text
error: tool profile minimal does not expose requested Blitz tools: pi_blitz_route_edit
```

Separate lane attempts:

```bash
bun bench/pi-matrix.ts --iters 1 --case medium-10k/marker-tail --lane core --tool-profile minimal --artifact-profiles minimal --runner tmux --tokscale --timeout-ms 180000 --json-out .pi/reports/pi-compact-ir-2026-06-10-core.json --md-out .pi/reports/pi-compact-ir-2026-06-10-core.md --extension /home/kenzo/dev/pi-blitz/dist/index.js --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz --pi-blitz-package /home/kenzo/dev/pi-blitz
```

```bash
bun bench/pi-matrix.ts --iters 1 --case medium-10k/marker-tail --lane blitz --tool-profile minimal --artifact-profiles minimal --runner tmux --tokscale --timeout-ms 180000 --json-out .pi/reports/pi-compact-ir-2026-06-10-blitz.json --md-out .pi/reports/pi-compact-ir-2026-06-10-blitz.md --extension /home/kenzo/dev/pi-blitz/dist/index.js --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz --pi-blitz-package /home/kenzo/dev/pi-blitz
```

## Artifacts

- Combined attempt report: `/home/kenzo/dev/blitz/.pi/reports/pi-compact-ir-2026-06-10-r2.md`
- Core lane report: `/home/kenzo/dev/blitz/.pi/reports/pi-compact-ir-2026-06-10-core.md`
- Blitz compact lane report: `/home/kenzo/dev/blitz/.pi/reports/pi-compact-ir-2026-06-10-blitz.md`
- Core run root: `/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-10T08-35-48-486Z`
- Blitz run root: `/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/2026-06-10T08-35-55-730Z`
- Core accounting root: `/home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-10T08-35-48-486Z`
- Blitz accounting root: `/home/kenzo/dev/blitz/.pi/reports/pi-accounting-runs/2026-06-10T08-35-55-730Z`

## Observed route/tool labels

| lane | route | profile | visible tools | tool observed | exit | correctness | Tokscale token match |
|---|---|---|---|---|---:|---:|---|
| core | `core_edit` | `core` | `edit` | none; provider auth failed before tool call | 1 | 0.0% | yes |
| blitz | `ast_narrow` | `minimal-v0` | `pi_blitz_op` | none; provider auth failed before tool call | 1 | 0.0% | yes |

## Token accounting from failed rows

| lane | schema tok | skill tok | prompt tok | arg tok | output tok | total context tok | input tok | Tokscale input | Tokscale output |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| core | 0 | 0 | 4631 | 0 | 0 | 4631 | 0 | 0 | 0 |
| blitz | 454 | 580 | 4745 | 0 | 0 | 5779 | 0 | 0 | 0 |

## Blocker

Both product-real Pi/tmux/Tokscale lane attempts failed before any edit tool call due Anthropic OAuth org policy:

```text
403 {"type":"error","error":{"type":"permission_error","message":"OAuth authentication is currently not allowed for this organization."}}
```

Tokscale artifacts exist, but no successful model/tool rows exist. Because no `pi_blitz_op` call occurred in benchmark, token-savings/default-ready claims remain blocked.

## Manual rerun with configured ZAI provider

Because the harness run used Anthropic OAuth and failed before tool execution, the main agent ran a focused tmux benchmark with the configured `zai/glm-4.5-air` provider.

Run root:

```text
/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z
```

Rows:

| lane | provider/model | tool | exact tool args shape | exit | correctness | wall ms | Pi usage input | Pi usage output | Pi cache read | Tokscale input | Tokscale output | Tokscale cache read | Tokscale messages | Tokscale cost |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| core | `zai/glm-4.5-air` | `edit` | `{path,edits:[{oldText,newText}]}` | 0 | 100% | 43182 | 3686 | 243 | 43 | 3739 | 288 | 4014 | 2 | 0.00118502 |
| blitz | `zai/glm-4.5-air` | `pi_blitz_op` | `{f,ops:[["rb","function","smallTarget",snippet]]}` | 0 | 100% | 49669 | 3771 | 341 | 43 | 3833 | 454 | 4197 | 2 | 0.00139191 |

Observed exact compact tool call in the Blitz lane:

```json
{"name":"pi_blitz_op","arguments":{"f":"/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z/blitz/work/sample.ts","ops":[["rb","function","smallTarget","\n  return \"hello \" + name.toUpperCase();\n"]]}}
```

Both output files matched the expected final file:

```ts
export function smallTarget(name: string): string {
  return "hello " + name.toUpperCase();
}
```

Tokscale note: the first direct `tokscale --home <run>/sessions` invocation returned zero rows because Tokscale expects a Pi home layout. The session JSONL was copied into `<run>/<lane>/tokscale-home/.pi/agent/sessions/` and Tokscale was rerun successfully. Saved outputs:

- `/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z/core/tokscale-home.json`
- `/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z/blitz/tokscale-home.json`

## Verdict

Compact route exposure in pi-blitz is implemented and locally verified. Product-real Pi/tmux rows now exist for a focused compact-supported `rb` fixture using `zai/glm-4.5-air`; both core and Blitz lanes exited 0 and produced correct files, and Tokscale parsed both session JSONLs after arranging them into a Pi-home layout.

This is sufficient to prove the compact pi-blitz route is real and executable through Pi, but it is **not** a default-ready/token-savings win: in this focused row, Blitz used more model-visible tokens and cost than core (`Tokscale total input+output+cacheRead`: core 8041 vs Blitz 8484). Next work should reduce prompt/schema/output overhead and run broader locked rows before any default replacement claim.
