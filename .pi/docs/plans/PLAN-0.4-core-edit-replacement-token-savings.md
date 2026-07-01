# PLAN — Blitz 0.4 Core Edit Replacement Token Savings

Date: 2026-06-11
Status: active execution plan
Spec: `.pi/docs/20260611-blitz-core-edit-replacement-token-savings-spec.md`
Related plan: `.pi/docs/plans/PLAN-0.4-context-token-optimization.md`
Owner intent: Blitz must become the default lower-token Pi edit surface, not merely a structural helper.

## Decision: acceptance threshold

Use the stricter interpretation from the spec:

- Blitz must win aggregate total model-visible tokens, median row, p75 row, tiny streak, mixed streak, and each mandatory benchmark class.
- A class exception is allowed only if it is documented before completion with evidence that core is intrinsically cheaper for that class and Blitz/product routing has a non-benchmark fallback story. No current exception is approved.
- Any row worse than core by more than 10% requires a remediation ticket/report item before completion.
- Completion is impossible if tiny exact-edit streaks still lose.

Rationale: the product goal says “replace Pi core edit everywhere.” Aggregate-only wins can hide tiny-edit regressions and would repeat the current failure mode.

## Current state

Known evidence from existing .pi/reports/spec:

- Compact IR exists for structural edits, but compact IR alone is not product completion.
- Current Blitz/router loses to Pi core `edit` on realistic streaks:
  - 10 tiny edits: core `75,042` total context vs router/blitz `81,720`.
  - 20 mixed edits: core `176,422` vs router/blitz `247,024`.
  - same-file multi-edit: core `18,429` vs router/blitz `25,374`.
  - focused compact `rb`: core total input+output+cacheRead `8,041` vs Blitz `8,484`.
- Root causes are resident schema/tool/skill tax, verbose output, and no first-class tiny exact-edit Blitz surface.
- Local repo has no `.tickets` directory; lifecycle tracking for this slice is this plan plus the active Goal-x checkpoint until/if a `tk` store is initialized or companion pi-rig tickets are linked.

## Deliverables

### D0 — Source-of-truth docs

- Spec marked active and linked to this plan.
- This plan remains the execution source of truth.
- Existing `PLAN-0.4-context-token-optimization.md` stays as broader .pi/research/architecture context.

### D1 — Measurement lock / failing baseline gate

Produce a canonical replacement-gate report that proves the current lane is not ready and freezes the acceptance math.

Required artifacts:

- `.pi/reports/` MD + JSON replacement-gate baseline.
- Raw Pi session JSONL paths preserved.
- Tokscale output preserved.
- Serialized visible tool specs captured.
- Resident skill text captured.
- Exact tool calls/results captured.
- Aggregate, median, p75, mandatory class, tiny streak, mixed streak, and row > +10% remediation table.

Checks:

- Tokscale token match for accepted accounting rows.
- Correctness separated from token accounting.
- Report status labeled `baseline` or `piloted`, not publishable replacement.

### D2 — Blitz CLI first-class exact replace + quiet output

Builder: `d5` in `/home/kenzo/dev/blitz`.

Scope:

- Extend `blitz apply --edit - --json` or the existing compact apply path with compact exact replacement op `x`.
- Semantics: exact `old -> new`, deterministic count, no partial write, zero-match/multi-match fail closed, atomic write, parse validation when language is known.
- Add compact/quiet output mode:
  - success: `ok c=N`
  - no-op: `noop`
  - error: `err code=...`
- Preserve verbose apply IR compatibility.

Required checks:

- `zig build`
- `zig build test`
- focused CLI fixtures for no-match, multi-match, exact one-match, no partial write, compact success output.

Exit evidence:

- Isolated exact replace rows can be benchmarked with args+output lower than core for the same old/new strings.

### D3 — pi-blitz tiny default replacement tool/profile

Builder: `d5` in `/home/kenzo/dev/pi-blitz`.

Scope:

- Add a tiny Blitz-owned default edit tool/profile, preferably `blitz_edit` unless Pi can safely alias/override `edit`.
- Minimal schema target equivalent to:

```json
{"f":"path","e":[["x","old","new"]]}
```

- Required op aliases: `x`, `a`, `u`, `rb`, `ia`, `mn`, `sk` as available; unavailable aliases must fail closed or be omitted from the exposed minimal schema.
- Default success output must be under 20 tokens.
- Debug/admin profile keeps verbose output; replacement profile does not.
- Default resident skill is removed or <=300 tokens.
- No benchmark-side synthetic fallback may be counted as product replacement.

Required checks:

- Inspect pi-blitz `AGENTS.md` and package commands first.
- Run repo-owned typecheck/test/build if present; otherwise run smallest meaningful Bun/TS syntax/package check and document command absence.
- Capture serialized tool schema/profile dump.

Exit evidence:

- Serialized tool+skill context drops at least 70% from current common Blitz lane and below previous minimal profile.

### D4 — Acceptance harness / streak matrix

Builder: `d5` in `/home/kenzo/dev/blitz` with pi-blitz integration when needed.

Scope:

- Harden `bench/pi-matrix.ts` / related harness as a replacement gate, not a rough benchmark.
- Capture and report model-visible totals:
  - resident tool schema
  - resident skill text
  - prompt/input
  - cache read/write
  - tool args
  - model output
  - result payload
  - total model-visible context
- Add/verify mandatory matrix classes:
  - A: 10+ tiny core-equivalent same-session edits plus isolated tiny rows.
  - B: small insert/anchor edits.
  - C: symbol/structural edits.
  - D: config/docs edits.
  - 20+ mixed code/config/docs streak.
  - same-file multi-edit scenario.

Required checks:

- Harness smoke build, e.g. `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js`.
- Tmux runner with `--tokscale` for locked rows.
- Correctness 100% for accepted savings rows.

Exit evidence:

- Replacement gate report includes pass/fail against every threshold and raw artifact links.

### D5 — Review / remediation loop

Builders/reviewers:

- `reviewer`: audit benchmark math, raw artifact links, and correctness gates.
- `researcher`: only if Pi alias/freeform/deferred-tool behavior is unclear after repo inspection.
- `d5`: implement remediation for any row/class regression.

Required outcome:

- If thresholds fail: leave plan open with row-specific remediation items and do not claim replacement.
- If thresholds pass: update spec/report with completion evidence and exact default product route.

## Mandatory benchmark matrix

### Class A — tiny exact edits, must win

- one-line return replacement
- string literal replacement
- config value replacement
- markdown sentence replacement
- JSON scalar replacement
- import path replacement
- rename one local identifier by exact text
- 10+ true same-session tiny edit streak

### Class B — small insert/anchor edits, must beat or tie

- insert logging line
- insert guard after first line
- add import
- append markdown bullet
- ensure line

### Class C — symbol/structural edits, must win strongly

- function body replace
- marker merge in body
- insert after symbol
- wrap body
- same-file multi-edit

### Class D — config/docs, aggregate must win

- package/version/key edits
- markdown section append
- YAML/TOML/JSON key update

### Mixed streak, must win

- 20+ mixed language/config/markdown/code edits in one realistic session.

## Completion gates

A completion claim is valid only when evidence proves all gates:

1. Default exposed edit tool is Blitz-owned, not Pi core `edit`.
2. Every accepted benchmark row reaches the same final file as core or a documented stricter no-write rejection.
3. Blitz total model-visible tokens are lower than core on aggregate, median, p75, every mandatory class, tiny streak, and mixed streak.
4. 10+ tiny exact edit streak beats core.
5. 20+ mixed streak beats core.
6. Reports do not count synthetic benchmark fallback as product replacement.
7. Compact IR existence is treated only as prerequisite evidence.
8. Every savings number links to raw Pi JSONL and Tokscale output.
9. `zig build` and `zig build test` pass for Blitz CLI changes.
10. pi-blitz package checks pass or are explicitly absent with a smaller meaningful check run.
11. Reviewer audit accepts benchmark math and semantic coverage.

## Delegation prompts

### d5 — Blitz CLI exact replace + quiet output

Task:

> In `/home/kenzo/dev/blitz`, implement the D2 slice from `.pi/docs/plans/PLAN-0.4-core-edit-replacement-token-savings.md`. Read `AGENTS.md`, `src/AGENTS.md`, `src/apply/AGENTS.md`, `.pi/docs/20260611-blitz-core-edit-replacement-token-savings-spec.md`, `.pi/docs/plans/PLAN-0.4-context-token-optimization.md`, and `.pi/skills/blitz-benchmarking/SKILL.md` first. Add compact exact replace op `x` to the existing apply/compact path, with deterministic count, fail-closed no-match/multi-match/no partial write, atomic writes, and quiet output `ok c=N`/`noop`/`err code=...`. Preserve verbose IR compatibility. Run `zig build`, `zig build test`, and focused CLI fixtures. Do not touch pi-blitz.

Acceptance:

- Changed files limited to CLI/apply/tests/fixtures/docs needed for D2.
- `zig build` and `zig build test` pass.
- Exact replace fixtures cover success, no-match, multi-match, and no partial write.
- No token-savings claim beyond “ready to benchmark”.

### d5 — pi-blitz tiny tool/profile

Task:

> In `/home/kenzo/dev/pi-blitz`, implement D3 from `/home/kenzo/dev/blitz/.pi/docs/plans/PLAN-0.4-core-edit-replacement-token-savings.md`. Read pi-blitz `AGENTS.md`, package commands, tool registration/profile code, current skill text, and Blitz spec/plan files first. Add a tiny default Blitz-owned edit tool/profile with compact schema, quiet success output, <=300-token resident skill or no resident skill, and debug/admin verbose path separated. Capture serialized tool schema/profile dump. Do not count core edit fallback as product replacement.

Acceptance:

- Default replacement profile exposes only tiny Blitz edit surface.
- Serialized schema/skill overhead is measured and reported.
- Package checks pass or absence is documented with a smaller meaningful check.

### d5 — replacement benchmark gate

Task:

> In `/home/kenzo/dev/blitz`, implement D4 acceptance harness from `.pi/docs/plans/PLAN-0.4-core-edit-replacement-token-savings.md`. Use `.pi/skills/blitz-benchmarking` and `references/tmux-tokscale-method.md`. Add matrix/report coverage for tiny streak, mixed streak, same-file multi-edit, and mandatory classes A-D. Capture visible tool specs, skill text, raw Pi JSONL, Tokscale output, tool calls/results, correctness, and aggregate/median/p75/class thresholds. Preserve failed attempts as artifacts.

Acceptance:

- Harness smoke build passes.
- Tmux/Tokscale rows produce token-match accounting.
- Report labels status correctly and rejects replacement if any gate fails.

### reviewer — benchmark acceptance audit

Task:

> Audit the replacement-gate report against `.pi/docs/20260611-blitz-core-edit-replacement-token-savings-spec.md` and `.pi/docs/plans/PLAN-0.4-core-edit-replacement-token-savings.md`. Verify raw artifacts exist, Tokscale token-match claims are real, correctness rows are 100%, class thresholds are calculated correctly, tiny/mixed streaks are included, and no benchmark-side synthetic fallback is counted as product replacement. Return approve/reject with file:line findings.

## Prompt-to-artifact audit checklist

| Requirement | Evidence artifact |
|---|---|
| Default route Blitz-owned | pi-blitz profile/tool registration diff + serialized schema dump |
| Exact replace internal to Blitz | Blitz CLI tests/fixtures + implementation diff |
| Quiet output under 20 tokens | CLI/pi-blitz fixture output + benchmark result payload tokens |
| Resident skill tax removed/reduced | captured skill snapshot + token count in report |
| Tool/schema tax measured | serialized visible tool specs + token accounting report |
| Tiny streak beats core | tmux/Tokscale report row/group for 10+ edits |
| Mixed streak beats core | tmux/Tokscale report row/group for 20+ edits |
| Class A-D thresholds | replacement gate aggregate/class table |
| Correctness parity | golden final-file comparison per row |
| No hidden fallback | report lane metadata + tool-call name audit |
| Raw artifacts preserved | run root paths in report |
| Tokscale validation | Tokscale JSON output + token-match column |
| Blitz build/tests | command output for `zig build` and `zig build test` |
| pi-blitz checks | package command output or documented absence + fallback check |
| Reviewer audit | reviewer report approve/reject |

## Current next action

Dispatch D2 to `d5` first. D2 is the smallest buildable unit and unblocks meaningful tiny exact-edit benchmarking. Do not start D3 before D2 has a passing CLI surface, unless a separate explorer/researcher only inspects pi-blitz schema override feasibility without writing code.
