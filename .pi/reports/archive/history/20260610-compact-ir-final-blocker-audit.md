# Blitz compact IR final blocker audit

Date: 2026-06-10
Branch: `feat/blitz-0.4-token-core-profile`
Head verified: `1fbfe31 feat(apply): batch compact same-file ops`

## Objective restated

Build Blitz 0.4 into a token-saving Pi core `edit` replacement candidate by implementing Zig-native compact `blitz apply --edit - --json` mechanics first, then proving the route honestly against Pi core `edit` with real Pi/tmux/Tokscale evidence before any default-ready claim.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| Fresh goal file exists and links archived/research artifacts | `.pi/goals/drafts/20260610-blitz-compact-ir-token-core.md` | Pass |
| Active plan/spec prioritizes existing `blitz apply --edit - --json` compact IR over new command/wrapper work | `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md`, `.pi/docs/plans/archive/START-0.4-context-token-core.md`, commit `90949fd` | Pass |
| Implementation delegated to `d5`; main agent did not edit implementation code | d5 runs landed implementation commits `9537273`, `2bd363c`, `344f0fe`, `411caca`, `1fbfe31` | Pass |
| Compact IR v1 implemented in Blitz repo only | `src/apply/ir.zig`, `src/apply/mod.zig`; no `/home/kenzo/dev/pi-blitz` edits | Pass |
| Existing `blitz apply --edit - --json` accepts compact object and tuple forms | Commit `9537273`; tests + fixtures for object `rb` and tuple `ia` | Pass |
| Preserve verbose IR compatibility | Full `zig build test` passes after all compact changes | Pass |
| `rb` / `replace_body` / `set_body` replaces resolved symbol body with snippet only | Tests and fixtures; compact request stores snippet-only `edit` string | Pass |
| `ia` / `insert_after_symbol` inserts after symbol | Tests and fixtures | Pass |
| Unknown alias fails compactly | Test `apply compact unknown alias rejects` | Pass |
| Duplicate symbol without occurrence fails closed | Test `apply compact duplicate ambiguity rejects unless occurrence selects` | Pass |
| Occurrence disambiguates deterministically | Existing occurrence tests | Pass |
| Parse-failing snippet causes no write | Test `apply compact parse-after failure does not write` | Pass |
| Compact success output is tiny | Commit `2bd363c`; compact success emits `ok/status/op/file/symbol/changed/parse/ranges` and omits verbose metrics/route payload | Pass |
| Guard/range mismatch causes no write | Commit `344f0fe`; compact `g:{"range":[start,end],"text":"expected"}` returns `HASH_MISMATCH` before mutation | Pass for range+text; file hash algorithm deliberately not implemented |
| Parent/ancestor target filter `p` | Commit `411caca`; compact target supports `p`, e.g. `t:{"k":"method","n":"run","p":"Beta"}` | Pass |
| Same-file batch rebasing/no partial writes | Commit `1fbfe31`; compact `ops` length >1 routes to sequential in-memory planning, parse validation per step, one final write. d5 and main-agent CLI fixtures verify sequential apply and second-op failure leaves file unchanged. | Pass |
| Build passes | `zig build` rerun after `1fbfe31` | Pass |
| Tests pass | `zig build test` rerun after `1fbfe31` | Pass |
| Focused compact CLI fixtures pass | rb/ia/ambig/occ/bad-alias/guard/parent/batch fixtures passed during session | Pass |
| Benchmark-only compact payload evidence exists | `.pi/reports/archive/history/compact-ir-cli-payload-20260610.md`, commit `dc876a3` | Partial; CLI payload-only, no real Pi/Tokscale route |
| Product-real Pi/tmux/Tokscale compact route benchmark vs Pi core exists | Not possible in current authorized scope because compact Zig IR is not exposed through `/home/kenzo/dev/pi-blitz`, and editing that repo is explicitly unauthorized. Existing `.pi/reports/archive/history/pi-tmux-true-streak-summary-20260610-d5.md/json` covers current router/core evidence, not this compact Zig route. | Missing / blocker |
| No token-savings/default-ready claim without evidence | Reports and status label compact evidence as benchmark-only / not default-ready | Pass |

## Verification commands rerun at current head

- `git status --short --branch --untracked-files=normal` → clean branch at `origin/feat/blitz-0.4-token-core-profile`
- `zig fmt --check src/apply/ir.zig src/apply/mod.zig src/apply/errors.zig src/apply/target.zig src/ast.zig`
- `zig build`
- `zig build test`
- `bun build .pi/bench/compact-ir-cli-payload.ts --target=bun --outfile=/tmp/compact-ir-cli-payload.js`

All completed successfully.

## Current verdict

Do **not** call `update_goal` yet.

Zig-side compact IR implementation is complete for the requested v1 mechanics: compact aliases, snippet-only rb/ia, compact output, guard range text, parent filter, same-file batch/no partial write, and passing Zig gates.

The remaining objective requirement is evidence: a real Pi/tmux/Tokscale benchmark comparing the compact route against Pi core `edit` with correctness and token accounting. That requires exposing the compact Zig route to Pi (currently via `/home/kenzo/dev/pi-blitz` or an equivalent authorized tool lane). The standing constraint says not to edit `/home/kenzo/dev/pi-blitz` without explicit authorization.

## Blocker

Need explicit authorization for a narrow `/home/kenzo/dev/pi-blitz` benchmark/exposure slice, or an explicit scope change accepting benchmark-only CLI payload evidence as sufficient for this goal. Until then, completion would fail the independent audit.
