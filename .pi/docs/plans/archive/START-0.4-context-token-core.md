# START — Blitz 0.4 Context/Token Core Replacement Goal

Use this as the next `/goal` or new-chat start prompt.

## Goal prompt

Make Blitz become a default-cheaper Pi edit path by reducing context-window/token overhead and proving cumulative savings over realistic edit streaks with real Pi/Tokscale benchmarks. Start with Phase 0 measurement and Phase 1 minimal tool profile from `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md`.

## Required context before planning

Read in order:

1. `AGENTS.md`
2. `.pi/docs/product/blitz.md` §1 north star + §1.0.1 token-first doctrine
3. `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md`
4. `.pi/research/archive/20260605-tool-schema-context-tax.md`
5. `.pi/research/archive/20260605-token-efficient-edit-repos.md`
6. `.pi/skills/blitz-benchmarking/SKILL.md` and `references/tmux-tokscale-method.md`

If implementation touches `@codewithkenzo/pi-blitz`, also read its local `AGENTS.md`, tool registration code, skill text, and current benchmark integration before editing.

## Prime constraint

This project is nothing without token savings. Do not optimize for raw speed first. Speed is a guardrail; context/token savings are the product.

Blitz is **not core edit today**. This goal exists to make it default-cheaper only if evidence over realistic edit streaks proves it beats Pi core `edit` or routes to Pi core when core is cheaper.


## 2026-06-10 goal tweak

Interpret this start prompt under current narrowed objective:

- Pi core `edit` is the only required baseline/fallback. Do not add or require Codex/OpenAI `apply_patch` parity for this slice.
- Primary evidence is cumulative model-visible context across realistic edit streaks, not isolated structural wins.
- Required streak reports should include 10+ tiny edits, 20+ mixed language/config/markdown/code edits, one same-file multi-edit scenario, and representative single rows.
- Huge structural rows are secondary capability evidence.
- Benchmark-only route-selected core choices must be labeled as synthesis, not product-real `pi_blitz_route_edit` fallback.

## Current next slice — 2026-06-10 compact apply IR

Phase 0/1/profile evidence exists and shows the current router/Blitz route still loses to Pi core `edit` on realistic streaks. The next slice is now the Zig-side compact engine, not more wrapper-only trimming.

Deliver the compact IR v1 inside `/home/kenzo/dev/blitz` by extending existing `blitz apply --edit - --json`:

1. Preserve verbose apply IR compatibility.
2. Add compact JSON object and tuple forms.
3. Support at minimum `rb`/`replace_body`/`set_body` and `ia`/`insert_after_symbol`; add `mn`/`merge_body_chunk` and same-file `ops` batch only if they fit the safe slice.
4. Target shape: `{"k":"function|method|class|object|section|any","n":"name","p":"optional parent","occ":0,"range":"body|node"}`.
5. Fail closed for zero matches, ambiguous matches without occurrence/parent, unknown aliases, parse failure, and guard/hash/range mismatch.
6. Plan all same-file ops in memory, parse-after validate before atomic write, and avoid partial writes.
7. Add compact output mode for compact requests after correctness: tiny `ok`/ranges/parse status, with verbose JSON still available.
8. Required checks before benchmark claims: `zig build`, `zig build test`, and focused CLI compact fixtures.

Do **not** start with `pi_blitz_op`, new `blitz edit-ir apply` command, daemon/warm state, `/home/kenzo/dev/pi-blitz` edits, Codex/apply_patch parity, or product-real default replacement claims. Pi core `edit` remains baseline/fallback.

## Implementation direction

After Phase 0/1 evidence, proceed only where data points:

- If simple rows lose from schema/skill overhead: compress skill, shrink schemas, lazy-load/discover tools.
- If simple rows lose from arg/output size: add compact op IR/freeform DSL.
- If semantic rows repeat too much code: add AST target + deterministic chunk-local merge.
- Runtime routing integration must be explicit before replacement claims: Pi extension facade/core-tool wrapper/skill-level route contract, not benchmark-only routing.
- If a Blitz route is not cheaper: route to Pi core `edit` and record reason.

## Acceptance gates

Do not call goal done until all are true:

- `zig build` passes.
- `zig build test` passes.
- Benchmark harness reports token/context breakdown, not only wall time.
- Tokscale/token accounting matches for publishable rows.
- Correctness is 100% for accepted savings rows.
- Resident tool/skill overhead is measured; target reduction is >=70% for common lanes.
- Structural rows preserve current large token wins.
- Simple both-correct rows either beat/tie Pi core `edit` after overhead or route-selected evidence chooses core with explicit token proof.
- Report lists failed/skipped rows and caveats; no hidden failures.

## Builder routing

Main agent should map/review/verify. Implementation code goes to builders:

- `d5`: Blitz CLI, Zig, benchmark harness, daemon/MCP/backend plumbing.
- `t4`: Pi extension UI/docs only if frontend surface appears.
- `researcher`: provider/runtime docs, OpenAI/Anthropic/MCP changes, external repo comparisons.
- `reviewer`: required after material implementation before commit/push.

## Cross-repo execution

This repo (`/home/kenzo/dev/blitz`) owns the CLI, bench harness, reports, and durable specs. The companion repo (`/home/kenzo/dev/pi-blitz`) owns Pi tool registration, resident skill text, schemas, and runtime route/facade behavior.

When Phase 1 touches `@codewithkenzo/pi-blitz`:

- create a companion branch: `feat/blitz-0.4-token-core-profile`
- allowed scope: tool registration/profile code, schema serialization/debug dump utilities, resident skill text, package tests, benchmark integration needed to select installed/local profile
- forbidden scope: unrelated UI, unrelated MCP behavior, broad refactors, unmeasured skill rewrites
- expected checks: inspect `package.json` and local AGENTS first, then run the repo-owned typecheck/test/build commands; if absent, record the absence and run the smallest meaningful Bun/TS syntax check
- package/install path: document whether Blitz harness uses local source, `npm install -g .`, linked package, or published package; benchmark reports must state this
- push/PR policy: push verified companion branch at safe boundaries; final handoff must list both Blitz and pi-blitz commits/branches

## Branch

Suggested branch from updated `main` for this repo:

```bash
git switch -c feat/blitz-0.4-context-token-core
```

Suggested companion branch in `/home/kenzo/dev/pi-blitz` when needed:

```bash
git switch -c feat/blitz-0.4-token-core-profile
```

## Output artifacts

Expected durable artifacts:

- updated `.pi/docs/plans/archive/PLAN-0.4-context-token-optimization.md` if implementation findings alter plan
- benchmark JSON/MD under `.pi/reports/`
- raw tmux/Pi artifacts preserved for accepted token claims
- serialized tool-spec JSON/profile dumps and skill snapshots used for accounting
- companion `pi-blitz` branch/commit/test notes when touched
- concise final report with changed files, commands, pass/fail, token wins/losses, remaining risks
