# Compact IR auditor remediation + breadth evidence

Date: 2026-06-11
Repo: `/home/kenzo/dev/blitz`
Branch: `feat/blitz-0.4-token-core-profile`
Implementation head: `a69d301 fix compact target kind and range resolution`

## Why this report exists

Independent goal audit rejected the earlier completion claim for two implementation gaps and one evidence gap:

1. Compact target kind `t.k` was parsed but not used to filter target resolver candidates.
2. Compact target range `t.range` was parsed but not enforced.
3. Product-real Pi/tmux/Tokscale evidence was too narrow: one focused `rb` row only.

This report records the remediation and the additional product-real breadth rows. It does **not** claim default-readiness or token savings.

## Implementation remediation

Builder: `d5` async run `b01a551e-a4cf-47eb-b907-0774e5b379eb`.

Committed and pushed:

```text
a69d301 fix compact target kind and range resolution
```

Changed files:

- `src/grammar_config.zig`
- `src/ast.zig`
- `src/apply/target.zig`
- `src/apply/mod.zig`

Behavior fixed:

- `t.k` now participates in resolver candidate filtering instead of acting as parsed-but-ignored metadata.
- Same-name cross-kind cases, e.g. `class Dup` + `function Dup`, can select `{"k":"function","n":"Dup"}` without false `SYMBOL_AMBIGUOUS`.
- Wrong kind fails closed without matching cross-kind candidates.
- `t.range:"body"` edits the body interior.
- `t.range:"node"` edits the full declaration node.
- Unsupported target ranges fail closed with `UNSUPPORTED_TARGET_RANGE` and no write.

Focused Zig tests added/updated by the builder cover:

- compact target kind disambiguates class/function same-name declarations;
- compact target wrong kind ignores cross-kind duplicate and leaves file unchanged;
- compact target `range:"node"` replaces declaration while `range:"body"` keeps wrapper;
- unsupported target range fails closed.

Final verification rerun by main agent:

```bash
zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig src/grammar_config.zig
zig build
zig build test
```

Result: passed.

## Product-real Pi/tmux/Tokscale breadth rows

Run root:

```text
/home/kenzo/dev/blitz/reports/pi-tmux-runs/compact-zig-ir-breadth-20260611T154326Z
```

Provider/model:

```text
zai / glm-4.5-air
```

Runner: tmux windows launched through `/tmp/run-compact-breadth-bench.sh`.

Each row used real Pi with either core `edit` or local pi-blitz `pi_blitz_op`:

- core lane: `--no-skills --no-extensions --tools edit`
- Blitz lane: `--no-extensions --extension /home/kenzo/dev/pi-blitz/dist/index.js --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz --tools pi_blitz_op`, with `PI_BLITZ_TOOL_PROFILE=minimal`

Tokscale was run against each lane after copying the session JSONL into a temporary Pi-home layout at `<run>/tokscale-home/.pi/agent/sessions/`.

### Accepted rows

All rows below exited 0, timed out false, invoked the intended tool, and produced the expected final TypeScript file for the fixture intent.

| fixture | lane | tool | exact compact/core shape | exit | wall ms | Pi input | Pi output | Pi cache read | Tokscale input | Tokscale output | Tokscale cache read | Tokscale messages | Tokscale cost |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `tiny-rb` | core | `edit` | `{path,edits:[{oldText,newText}]}` | 0 | 10537 | 3640 | 173 | 43 | 3658 | 231 | 3898 | 2 | 0.00110264 |
| `tiny-rb` | blitz | `pi_blitz_op` | `{f,ops:[["rb","function","smallTarget",snippet]]}` | 0 | 11525 | 743 | 221 | 2979 | 809 | 344 | 6921 | 2 | 0.00074783 |
| `symbol-ia` | core | `edit` | `{path,edits:[{oldText,newText}]}` | 0 | 10833 | 147 | 240 | 3566 | 165 | 291 | 7518 | 2 | 0.00057864 |
| `symbol-ia` | blitz | `pi_blitz_op` | `{f,ops:[["ia","function","alpha",snippet]]}` | 0 | 10330 | 3684 | 210 | 43 | 3751 | 244 | 3979 | 2 | 0.00113797 |
| `same-file-batch` | core | `edit` | `{path,edits:[{oldText,newText},...]}` | 0 | 11095 | 3710 | 271 | 43 | 3728 | 311 | 4066 | 2 | 0.00120968 |
| `same-file-batch` | blitz | `pi_blitz_op` | `{f,ops:[["rb",...],["rb",...],["ia",...]]}` | 0 | 11125 | 778 | 242 | 2979 | 846 | 316 | 6977 | 2 | 0.00072611 |

### Exact Blitz tool calls observed

`tiny-rb`:

```json
{"f":"work/sample.ts","ops":[["rb","function","smallTarget","\n  return \"hello \" + name.toUpperCase();\n"]]}
```

`symbol-ia`:

```json
{"f":"work/sample.ts","ops":[["ia","function","alpha","\nexport function beta(): number {\n  return 2;\n}\n"]]}
```

`same-file-batch`:

```json
{"f":"work/sample.ts","ops":[["rb","function","first","\n  return 10;\n"],["rb","function","second","\n  return 20;\n"],["ia","function","anchor","\nexport function afterAnchor(): boolean {\n  return true;\n}\n"]]}
```

## Honest accounting interpretation

These rows expand successful product-real evidence from one `rb` row to three compact-supported fixture types:

- tiny body replace (`rb`);
- symbol insert-after (`ia`);
- same-file compact multi-op batch (`ops`).

They prove the compact route is real, usable through Pi, and correct on these fixtures. They still do **not** prove Blitz should become the default core `edit` replacement:

- Tokscale total model-visible context (`input + output + cacheRead`) is not consistently lower for Blitz:
  - `tiny-rb`: core `7787`, Blitz `8074` — Blitz higher.
  - `symbol-ia`: core `7974`, Blitz `7974` — tie.
  - `same-file-batch`: core `8105`, Blitz `8139` — Blitz higher.
- Tokscale priced cost is lower for Blitz on `tiny-rb` and `same-file-batch`, higher on `symbol-ia`, but cost is not the sole acceptance metric for this goal.
- Cache behavior varied by lane and provider; report this as measurement behavior, not a savings claim.

## Status

Implementation gaps from the audit are fixed and verified. Product-real evidence is broader and successful for compact-supported rows, but the correct final product position remains:

- compact Pi route: **real and correct on accepted rows**;
- default-ready: **no**;
- token-savings claim: **no**, because total model-visible context did not beat core consistently.
