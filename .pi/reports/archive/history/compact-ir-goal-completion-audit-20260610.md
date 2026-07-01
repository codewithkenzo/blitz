# Blitz compact IR token-core completion audit

Date: 2026-06-10
Blitz branch: `feat/blitz-0.4-token-core-profile`
Blitz head: `dfeea52 docs: add compact IR completion audit`
pi-blitz branch: local `feat/blitz-0.4-token-core-profile-canonical`, pushed to `origin/feat/blitz-0.4-token-core-profile`
pi-blitz head: `f0d2c7a feat: send compact op IR directly`

## Objective restated

Build Blitz 0.4 into a real Pi core `edit` replacement candidate by implementing compact Zig-side edit IR in existing `blitz apply --edit - --json`, exposing it through pi-blitz, and gathering honest Pi/tmux/Tokscale evidence against Pi core `edit` without making unsupported default-ready/token-savings claims.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| Fresh goal file links archived/research artifacts | `.pi/goals/drafts/20260610-blitz-compact-ir-token-core.md` | Pass |
| Active Blitz 0.4 plan/spec prioritizes existing `blitz apply --edit - --json` compact IR over new command surface/wrapper-only work | `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md`, `.pi/docs/plans/archive/START-0.4-context-token-core.md`, commit `90949fd` | Pass |
| Implementation routed through `d5`; main agent acted as orchestrator/verifier | d5 implementation commits listed below; main-agent implementation code edits avoided | Pass |
| Compact object and tuple IR implemented in Blitz only | `9537273 Add compact apply IR parsing` | Pass |
| Compact success output implemented | `2bd363c feat(apply): emit compact IR success output` | Pass |
| Benchmark-only compact CLI payload evidence exists and is honestly labeled | `dc876a3 bench: add compact IR payload report`, `.pi/reports/archive/history/compact-ir-cli-payload-20260610.md` | Pass, benchmark-only |
| Guard/range validation before write | `344f0fe feat(apply): add compact guard validation`; `g:{"range":[start,end],"text":"expected"}` returns `HASH_MISMATCH` before mutation | Pass |
| Parent/ancestor target filter `p` | `411caca feat(apply): add compact parent target filter` | Pass |
| Same-file compact `ops` batch with sequential rebasing/no partial writes | `1fbfe31 feat(apply): batch compact same-file ops` | Pass |
| Zig build/test gates pass at final head | `zig fmt --check ... && zig build && zig build test` rerun after final report commit | Pass |
| pi-blitz exposes compact Zig IR directly | `f0d2c7a feat: send compact op IR directly`; `pi_blitz_op` sends `{v:1,f,ops}` to `blitz apply --edit - --json` | Pass |
| pi-blitz narrow profile exposes compact tool only | minimal profile visible tools: `pi_blitz_op`; report shows serialized tool spec tokens for minimal | Pass |
| pi-blitz checks pass | `bun run typecheck && bun test && bun run build` rerun after push | Pass |
| Product-real Pi/tmux/Tokscale benchmark attempted with saved artifacts | Initial harness reports under `.pi/reports/pi-compact-ir-2026-06-10*`; Anthropic blocked by OAuth policy | Pass as attempted; initial run blocked |
| Product-real compact route executed through Pi with valid compact Zig IR | Manual ZAI tmux run root `.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z`; exact tool call `pi_blitz_op` args `{"f":...,"ops":[["rb","function","smallTarget",snippet]]}` | Pass |
| Core comparison row executed through Pi core `edit` | Same manual run root, core lane exact tool call `{path,edits:[{oldText,newText}]}` | Pass |
| Tokscale accounting exists for successful rows | Tokscale required Pi-home layout; outputs saved at `core/tokscale-home.json` and `blitz/tokscale-home.json` under manual run root | Pass |
| Final report states honest verdict and no default-ready claim | `.pi/reports/archive/history/pi-compact-zig-ir-exposure-2026-06-10.md`, commit `6299d7b` | Pass |

## Final verification commands

From `/home/kenzo/dev/blitz`:

```bash
zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig
zig build
zig build test
```

From `/home/kenzo/dev/pi-blitz`:

```bash
bun run typecheck
bun test
bun run build
```

All passed in final rerun.

## Final benchmark evidence

Manual ZAI run root:

```text
/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z
```

| lane | provider/model | tool | exit | correct | wall ms | Pi input/output/cacheRead | Tokscale input/output/cacheRead | Tokscale messages | Tokscale cost |
|---|---|---|---:|---:|---:|---|---|---:|---:|
| core | `zai/glm-4.5-air` | `edit` | 0 | 100% | 43182 | 3686 / 243 / 43 | 3739 / 288 / 4014 | 2 | 0.00118502 |
| blitz | `zai/glm-4.5-air` | `pi_blitz_op` | 0 | 100% | 49669 | 3771 / 341 / 43 | 3833 / 454 / 4197 | 2 | 0.00139191 |

Exact compact Blitz tool call:

```json
{"name":"pi_blitz_op","arguments":{"f":"/home/kenzo/dev/blitz/.pi/reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z/blitz/work/sample.ts","ops":[["rb","function","smallTarget","\n  return \"hello \" + name.toUpperCase();\n"]]}}
```

Both lanes produced:

```ts
export function smallTarget(name: string): string {
  return "hello " + name.toUpperCase();
}
```

## Honest verdict

Goal implementation criteria are complete: compact Zig IR exists, pi-blitz exposes it as a real Pi tool path, checks pass, and real Pi/tmux/Tokscale evidence exists against core `edit`.

Blitz is **not default-ready** and no token-savings claim is made. The focused successful row proves the route is real and correct, but Blitz used more measured context/cost than core in this row. Next work should reduce schema/prompt/output overhead and rerun broader locked matrices before any core replacement/default claim.
