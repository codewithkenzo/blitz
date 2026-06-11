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
| Required v1 target kinds implemented | `3942de4 Support compact object and section targets`; `targetKindMatches` supports `function`, `method`, `class`, `object`, `section`, `any`; `object` requires object-valued declarations, `section` is narrow named containers/object-valued vars | Pass |
| Non-v1 target kinds fail closed | `ede0d5c Reject unsupported compact target kinds`; compact parser rejects object and tuple forms for `variable`/`type` with `INVALID_FIELD` before target resolution/write; CLI smoke confirmed no-write for both | Pass |
| `t.range` enforced | `a69d301`; tests for `body` vs `node`; unsupported range fails closed | Pass |
| Zig verification at final state | `zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig src/grammar_config.zig && zig build && zig build test` rerun after final report commit prep | Pass |
| pi-blitz compact route exposed | pi-blitz `f0d2c7a feat: send compact op IR directly`; `pi_blitz_op` sends compact `{v:1,f,ops}` to `blitz apply --edit - --json`; minimal profile exposes only `pi_blitz_op` | Pass |
| pi-blitz verification | `bun run typecheck && bun test && bun run build` rerun at final state | Pass |
| Product-real Pi/tmux/Tokscale row proves compact route invocation | Manual ZAI row root `reports/pi-tmux-runs/compact-zig-ir-manual-20260610T083926Z`; exact `pi_blitz_op` args used `[["rb","function","smallTarget",snippet]]` | Pass |
| Broader successful product-real rows | Breadth root `reports/pi-tmux-runs/compact-zig-ir-breadth-20260611T154326Z`; accepted `tiny-rb`, `symbol-ia`, `same-file-batch` core+Blitz rows | Pass |
| Tiny edit streak | `reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z`; `tiny-streak-1/2/3__blitz` each exit 0 with one `pi_blitz_op` and expected final file | Pass |
| Mixed edit streak | `reports/pi-tmux-runs/compact-zig-ir-mixed-seq-20260611T155319Z`; sequential `mixed-seq-rb`, `mixed-seq-ia`, `mixed-seq-mn` product-real Blitz rows all exit 0 and save Tokscale | Pass |
| Marker-merge compact row | `reports/pi-tmux-runs/compact-zig-ir-mn-fix-20260611T155221Z`; `marker-merge-valid__blitz` uses compact `mn` and exits 0 with expected merge | Pass |
| Explicit fallback row | `reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z/fallback-decline__router`; `pi_blitz_route_edit` declines no-payload route to apply_patch/core without mutating file | Pass |
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

### Successful streak / marker / fallback addendum

Detailed addendum:

```text
reports/compact-ir-streak-benchmark-20260611.md
```

Run roots:

```text
reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z
reports/pi-tmux-runs/compact-zig-ir-mn-fix-20260611T155221Z
reports/pi-tmux-runs/compact-zig-ir-mixed-seq-20260611T155319Z
```

Accepted rows:

| requirement | rows | result |
|---|---|---|
| tiny edit streak | `tiny-streak-1/2/3__blitz` | each exit 0, one `pi_blitz_op`, expected final file, Tokscale saved |
| mixed edit streak | `mixed-seq-rb__blitz`, `mixed-seq-ia__blitz`, `mixed-seq-mn__blitz` | each exit 0, one `pi_blitz_op`, expected final file, Tokscale saved |
| marker merge | `marker-merge-valid__blitz` | compact `mn` row exits 0 and preserves/merges expected body lines |
| fallback | `fallback-decline__router` | `pi_blitz_route_edit` declines no-payload request to apply_patch/core path without mutating file |

### Object/section resolver remediation

Final blocker remediation report:

```text
reports/compact-ir-object-section-remediation-20260611.md
```

Implementation commit:

```text
3942de4 Support compact object and section targets
```

Evidence:

- `object` kind resolves only object-valued declarations; scalar variables reject.
- `section` kind resolves named containers and object-valued variables; functions reject.
- bogus/unsupported kinds still fail closed.
- focused unit tests and CLI smokes passed.

### Non-v1 target kind fail-closed remediation

Final blocker remediation commit:

```text
ede0d5c Reject unsupported compact target kinds
```

Evidence:

- compact parser now allowlists only `function`, `method`, `class`, `object`, `section`, `any`.
- object-form compact targets with `k:"variable"` and `k:"type"` reject with `INVALID_FIELD` / `unsupported target kind`.
- tuple-form compact targets with `k:"variable"` and `k:"type"` reject with the same error.
- `targetKindMatches("variable", "variable_declarator")` and `targetKindMatches("type", "type_alias_declaration")` return false.
- main-agent CLI smoke confirmed both `k:"variable"` and `k:"type"` exited 1, returned `changed:false`, and left the file unchanged.

## Honest final verdict

The goal is complete as a candidate/proof slice: compact Zig IR exists, required target semantics and safety gaps are fixed, pi-blitz exposes the route, and product-real Pi/tmux/Tokscale evidence covers body replace, insert-after, same-file batch, tiny streak, mixed streak, marker merge, and explicit fallback rows.

Blitz remains **fallback/candidate-only**, not default-ready. No token-savings claim is made: accepted rows did not consistently beat core on total model-visible context. The correct next phase is overhead reduction and larger locked matrices, not default enablement.
