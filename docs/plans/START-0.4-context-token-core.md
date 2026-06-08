# START — Blitz 0.4 Context/Token Core Replacement Goal

Use this as the next `/goal` or new-chat start prompt.

## Goal prompt

Make Blitz become a core-edit replacement by reducing context-window/token overhead and proving token savings with real Pi/Tokscale benchmarks. Start with Phase 0 measurement and Phase 1 minimal tool profile from `docs/plans/PLAN-0.4-context-token-optimization.md`.

## Required context before planning

Read in order:

1. `AGENTS.md`
2. `docs/blitz.md` §1 north star + §1.0.1 token-first doctrine
3. `docs/plans/PLAN-0.4-context-token-optimization.md`
4. `.pi/research/20260605-tool-schema-context-tax.md`
5. `.pi/research/20260605-token-efficient-edit-repos.md`
6. `.pi/skills/blitz-benchmarking/SKILL.md` and `references/tmux-tokscale-method.md`

If implementation touches `@codewithkenzo/pi-blitz`, also read its local `AGENTS.md`, tool registration code, skill text, and current benchmark integration before editing.

## Prime constraint

This project is nothing without token savings. Do not optimize for raw speed first. Speed is a guardrail; context/token savings are the product.

Blitz is **not core edit today**. This goal exists to make it core only if evidence proves it can be default-cheaper or can route cheaper alternatives correctly.

## Required first slice

Deliver **only Phase 0 + Phase 1** before broad implementation. Do not require `pi_blitz_op`, compact IR, or router-selected replacement results in this first slice; those belong to Phase 2 and Phase 6.

1. Measurement harness records exact token/context breakdown:
   - visible tools
   - Pi-serialized registered tool specs per profile
   - exact token count for serialized registered tool specs
   - exact resident skill text used by the run
   - exact token count for resident skill text
   - prompt/input/cache tokens
   - tool arg tokens
   - model output tokens
   - result payload tokens
   - total model-visible context
   - correctness status
   - route/tool profile
2. Raw accounting artifacts are preserved:
   - serialized tool-spec JSON per profile
   - resident skill text snapshot
   - tokenizer/model used for counts
   - Tokscale/session JSON used for reconciliation
   - residual analysis between local counts and provider/Tokscale input/cache totals
3. `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` exists in `@codewithkenzo/pi-blitz`.
4. Phase 1 `minimal` is a registration/profile slice only: it may expose the smallest existing useful Blitz edit/apply surface before `pi_blitz_op` exists. Phase 2 replaces or aliases it to `pi_blitz_op`.
5. Current full/narrow profile remains available for backcompat/debugging.
6. Same 12-pair GPT matrix can compare core, current Blitz full/narrow, and Phase 1 profile variants. Router-selected replacement claims wait until Phase 6.

## Implementation direction

After Phase 0/1 evidence, proceed only where data points:

- If simple rows lose from schema/skill overhead: compress skill, shrink schemas, lazy-load/discover tools.
- If simple rows lose from arg/output size: add compact op IR/freeform DSL.
- If semantic rows repeat too much code: add AST target + deterministic chunk-local merge.
- Runtime routing integration must be explicit before replacement claims: Pi extension facade/core-tool wrapper/skill-level route contract, not benchmark-only routing.
- If a Blitz route is not cheaper: route to core/apply_patch and record reason.

## Acceptance gates

Do not call goal done until all are true:

- `zig build` passes.
- `zig build test` passes.
- Benchmark harness reports token/context breakdown, not only wall time.
- Tokscale/token accounting matches for publishable rows.
- Correctness is 100% for accepted savings rows.
- Resident tool/skill overhead is measured; target reduction is >=70% for common lanes.
- Structural rows preserve current large token wins.
- Simple both-correct rows either beat/tie core after overhead or router chooses core/apply_patch with explicit token proof.
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

- updated `docs/plans/PLAN-0.4-context-token-optimization.md` if implementation findings alter plan
- benchmark JSON/MD under `reports/`
- raw tmux/Pi artifacts preserved for accepted token claims
- serialized tool-spec JSON/profile dumps and skill snapshots used for accounting
- companion `pi-blitz` branch/commit/test notes when touched
- concise final report with changed files, commands, pass/fail, token wins/losses, remaining risks
