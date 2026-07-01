# Blitz compact IR progress audit

Date: 2026-06-10
Branch: `feat/blitz-0.4-token-core-profile`
Commits verified:
- `9537273 Add compact apply IR parsing`
- `90949fd docs: align compact IR plan`
- `2bd363c feat(apply): emit compact IR success output`

## Objective restated

Build Blitz 0.4 toward a token-saving Pi core `edit` replacement candidate by moving compact edit mechanics into the Zig binary first: compact apply IR, AST target resolution, deterministic snippet splice, validation/no partial writes, and honest benchmark evidence against Pi core `edit` before any default-ready claim.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| Fresh goal file exists and links archived/research artifacts | `.pi/goals/drafts/20260610-blitz-compact-ir-token-core.md` | Pass |
| Plan/spec updated to prioritize existing `blitz apply --edit - --json` compact IR over new command/wrapper work | `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md`, `.pi/docs/plans/archive/START-0.4-context-token-core.md`, commit `90949fd` | Pass |
| Builder handoff sent to `d5` with scope, files, verification, benchmark gates | subagent runs `34eb...` (failed stale Goal-x), `d0bd...` (implemented), `e45...` (format/check) | Pass, with subagent runtime caveats |
| Compact IR v1 implemented in `/home/kenzo/dev/blitz` only | commit `9537273`; dirty tree clean after `90949fd`; no `/home/kenzo/dev/pi-blitz` edits | Pass |
| Existing `blitz apply --edit - --json` accepts compact object and tuple forms | tests in `src/apply/mod.zig`: compact object rb, tuple ia; manual `/tmp` fixtures | Pass |
| Preserve verbose IR compatibility | existing test suite `zig build test` passes | Pass |
| `rb` / `replace_body` / `set_body` replaces resolved symbol body with snippet only | tests + manual `/tmp/blitz-compact-rb.json`; output file became `return 2;` | Pass |
| `ia` / `insert_after_symbol` inserts after symbol | tests + manual `/tmp/blitz-compact-ia.json`; inserted `second()` after `first()` | Pass |
| Unknown alias fails compactly | test `apply compact unknown alias rejects`; manual bad alias returned `UNSUPPORTED_OPERATION` exit 1 | Pass |
| Duplicate symbol without occurrence fails closed | test `apply compact duplicate ambiguity rejects unless occurrence selects`; manual duplicate returned `SYMBOL_AMBIGUOUS` and file unchanged | Pass |
| Occurrence disambiguates deterministically | test + manual object `occ:1` updated second duplicate | Pass |
| Parse-failing snippet causes no write | test `apply compact parse-after failure does not write` | Pass |
| `zig build` passes | `structured_return`: `zig build` completed | Pass |
| `zig build test` passes | `structured_return`: `zig build test` completed | Pass |
| Focused compact apply fixtures pass | manual rb/ia/ambig/occ/bad-alias fixtures under `/tmp` | Pass |
| Benchmark report exists with Pi core comparison, route labels, Tokscale accounting, 100% correctness accepted rows | `.pi/reports/archive/history/pi-tmux-true-streak-summary-20260610-d5.md/json` | Pass for current router/core evidence |
| Compact Zig op benchmark against Pi core exists | `.pi/reports/archive/history/compact-ir-cli-payload-20260610.md` compares compact CLI request/output payloads against verbose apply output and equivalent Pi core edit payloads for `rb` and `ia`. It is explicitly benchmark-only CLI payload/token evidence, not product-real Pi/Tokscale evidence. | Partial: payload-only benchmark exists; product-real Pi/Tokscale route benchmark still missing |
| Compact success output mode | Implemented for compact requests in `2bd363c`: compact stdout includes `ok`, status/op/file/symbol, changed/parse, ranges, and omits `routeDecision`, `metrics`, `diffSummary`. | Pass |
| Same-file batch rebasing | Not implemented; parser currently rejects `ops` length != 1. | Missing optional v1 / next work if required |
| Parent/ancestor target filter `p` | Not implemented; compact target with `p` fails closed as unsupported. | Missing optional v1 / next work |
| Guard/hash/range mismatch support | Commit `344f0fe` adds compact object `g` guard support with `{"range":[start,end],"text":"expected"}`. Guard mismatch returns `HASH_MISMATCH` before mutation and leaves file unchanged. | Pass for range+text guard; hash algorithm not implemented |

## Commands run

- `zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/target.zig src/ast.zig`
- `zig build`
- `zig build test`
- `git diff --check`
- `bun build .pi/bench/compact-ir-cli-payload.ts --target=bun --outfile=/tmp/compact-ir-cli-payload.js`
- `bun .pi/bench/compact-ir-cli-payload.ts` → `.pi/reports/archive/history/compact-ir-cli-payload-20260610.md`
- Focused CLI fixtures:
  - `zig-out/bin/blitz apply --edit - --json < /tmp/blitz-compact-rb.json`
  - `zig-out/bin/blitz apply --edit - --json < /tmp/blitz-compact-ia.json`
  - `zig-out/bin/blitz apply --edit - --json < /tmp/blitz-compact-ambig.json`
  - `zig-out/bin/blitz apply --edit - --json < /tmp/blitz-compact-occ.json`
  - `zig-out/bin/blitz apply --edit - --json < /tmp/blitz-compact-bad.json`

## Current verdict

Do **not** mark the goal complete yet.

Implementation, docs, build/test, and focused compact fixtures are landed and pushed, but the goal still has uncovered requirements if read strictly:

1. compact Zig op has not been benchmarked through real Pi/tmux/Tokscale against Pi core `edit`;
2. compact CLI payload/token benchmark exists only as benchmark-only local CLI evidence, not product-real Pi/Tokscale evidence;
3. guard/hash/range mismatch and parent target filtering are not implemented;
4. same-file batch rebasing remains unimplemented (optional in the smallest slice, but present in the broader objective).

## Recommended next slice

1. Decide whether compact CLI benchmark can be benchmark-only outside `/home/kenzo/dev/pi-blitz`, or authorize a pi-blitz route/tool exposure later.
2. Add compact output mode for compact requests (`ok`/ranges/parse status) while keeping verbose JSON available.
3. Add guard/hash/range support or explicitly defer it in the plan.
4. Add a benchmark report for compact CLI/tool exposure vs Pi core once the route is honest and product-real or clearly labeled benchmark-only.
