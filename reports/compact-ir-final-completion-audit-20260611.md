# Blitz compact IR token-core final completion audit

Date: 2026-06-11
Blitz branch/head: `feat/blitz-0.4-token-core-profile` / `31453da docs: record compact IR audit remediation`
pi-blitz branch/head: `origin/feat/blitz-0.4-token-core-profile` / `f0d2c7a feat: send compact op IR directly`

## Objective restated as concrete deliverables

Build Blitz 0.4 into a real Pi core `edit` replacement candidate by:

1. moving supported edit mechanics into Zig through compact `blitz apply --edit - --json` IR;
2. preserving safety: AST target resolution, deterministic snippet splice, guard/parse validation, same-file batch no partial writes, and compact success payload;
3. exposing the compact Zig IR through pi-blitz so Pi can call it as a real tool route;
4. proving the route honestly against Pi core `edit` with real Pi/tmux/Tokscale artifacts;
5. avoiding unsupported default-ready/token-savings claims when rows lose or tie core.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| Fresh goal file links prior research/artifacts | `.pi/goals/drafts/20260610-blitz-compact-ir-token-core.md` | Pass |
| Active plan/spec prioritizes existing `blitz apply --edit - --json` compact IR over new command surface | `docs/plans/PLAN-0.4-context-token-optimization.md`, `docs/plans/START-0.4-context-token-core.md`, commit `90949fd` | Pass |
| Implementation through builder, not main-agent implementation edits | d5 implementation commits; main agent limited to docs/reports/verification/orchestration | Pass |
| Compact object/tuple IR implemented | `9537273 Add compact apply IR parsing`; supports compact `rb`/`ia` object+tuple normalization | Pass |
| Compact success output implemented | `2bd363c feat(apply): emit compact IR success output` | Pass |
| Guard/range validation before write | `344f0fe feat(apply): add compact guard validation`; mismatch returns `HASH_MISMATCH` and leaves file unchanged | Pass |
| Parent/ancestor target filter `p` | `411caca feat(apply): add compact parent target filter` | Pass |
| Same-file compact `ops` batch with sequential rebasing and no partial writes | `1fbfe31 feat(apply): batch compact same-file ops` | Pass |
| `t.k` kind filtering actually affects resolver | `a69d301 fix compact target kind and range resolution`; tests for class/function same-name disambiguation and wrong-kind no-write | Pass |
| `t.range` enforced | `a69d301`; tests for `body` vs `node`; unsupported range fails closed | Pass |
| Zig verification at final state | `zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig src/grammar_config.zig && zig build && zig build test` rerun after final report commit prep | Pass |
| pi-blitz compact route exposed | pi-blitz `f0d2c7a feat: send compact op IR directly`; `pi_blitz_op` sends compact `{v:1,f,ops}` to `blitz apply --edit - --json`; minimal profile exposes only `pi_blitz_op` | Pass |
| pi-blitz verification | `bun run typecheck && bun test && bun run build` rerun at final state | Pass |
| Product-real Pi/tmux/Tokscale row proves compact route invocation | Manual ZAI row root `reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z`; exact `pi_blitz_op` args used `[["rb","function","smallTarget",snippet]]` | Pass |
| Broader successful product-real rows | Breadth root `reports/pi-tmux-runs/compact-zig-ir-breadth-20260611T154326Z`; accepted `tiny-rb`, `symbol-ia`, `same-file-batch` core+Blitz rows | Pass |
| Benchmark/token report includes route labels, tool args, Tokscale accounting, correctness, caveats | `reports/pi-compact-zig-ir-exposure-2026-06-10.md`, `reports/compact-ir-auditor-remediation-20260611.md` | Pass |
| No false token-savings/default-ready claim | Reports state compact route is real/correct but not default-ready; total model-visible context does not consistently beat core | Pass |

## Final verification commands

From `/home/kenzo/dev/blitz`:

```bash
zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig src/grammar_config.zig
zig build
zig build test
```

Result: passed.

From `/home/kenzo/dev/pi-blitz`:

```bash
bun run typecheck
bun test
bun run build
```

Result: passed.

## Product-real benchmark evidence

### Initial harness blocker

The original `bench/pi-matrix.ts --runner tmux --tokscale` attempt with Anthropic failed before tool calls due provider policy:

```text
OAuth authentication is currently not allowed for this organization.
```

That blocker is preserved in:

- `reports/pi-compact-ir-2026-06-10.md`
- `reports/pi-compact-zig-ir-exposure-2026-06-10.md`

### Successful focused proof row

Run root:

```text
reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z
```

Result: core `edit` and Blitz `pi_blitz_op` both exited 0 and produced correct files. Blitz tool args used valid compact Zig IR:

```json
{"f":".../work/sample.ts","ops":[["rb","function","smallTarget","\n  return \"hello \" + name.toUpperCase();\n"]]}
```

### Successful breadth rows

Run root:

```text
reports/pi-tmux-runs/compact-zig-ir-breadth-20260611T154326Z
```

Accepted rows:

| fixture | core tool | Blitz tool | compact operation coverage | result |
|---|---|---|---|---|
| `tiny-rb` | `edit` | `pi_blitz_op` | `rb` body replace | both exit 0/correct |
| `symbol-ia` | `edit` | `pi_blitz_op` | `ia` insert after symbol | both exit 0/correct |
| `same-file-batch` | `edit` | `pi_blitz_op` | same-file `ops` batch with `rb`, `rb`, `ia` | both exit 0/correct |

Tokscale totals are saved in each row’s `tokscale-home.json`; exact tool calls and Pi usage are in the session JSONLs under each row’s `sessions/` directory.

## Honest final verdict

The goal is complete as a candidate/proof slice: compact Zig IR exists, target semantics and safety gaps are fixed, pi-blitz exposes the route, and product-real Pi/tmux/Tokscale evidence covers body replace, insert-after, and same-file batch rows against core `edit`.

Blitz remains **fallback/candidate-only**, not default-ready. No token-savings claim is made: the accepted breadth rows did not consistently beat core on total model-visible context. The correct next phase is overhead reduction and larger locked matrices, not default enablement.
