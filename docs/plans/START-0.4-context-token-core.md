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

Deliver Phase 0 + Phase 1 before any broad implementation:

1. Measurement harness records exact token/context breakdown:
   - visible tools
   - serialized/resident schema tokens
   - resident skill tokens
   - prompt/input/cache tokens
   - tool arg tokens
   - model output tokens
   - result payload tokens
   - total model-visible context
   - correctness status
   - route/tool profile
2. `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` exists in `@codewithkenzo/pi-blitz`.
3. Minimal profile exposes at most `pi_blitz_op` plus one required discovery/read helper.
4. Current full/narrow profile remains available for backcompat/debugging.
5. Same 12-pair GPT matrix can compare core, current Blitz, optimized profile, and router-selected path.

## Implementation direction

After Phase 0/1 evidence, proceed only where data points:

- If simple rows lose from schema/skill overhead: compress skill, shrink schemas, lazy-load/discover tools.
- If simple rows lose from arg/output size: add compact op IR/freeform DSL.
- If semantic rows repeat too much code: add AST target + deterministic chunk-local merge.
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

## Branch

Suggested branch from updated `main`:

```bash
git switch -c feat/blitz-0.4-context-token-core
```

## Output artifacts

Expected durable artifacts:

- updated `docs/plans/PLAN-0.4-context-token-optimization.md` if implementation findings alter plan
- benchmark JSON/MD under `reports/`
- raw tmux/Pi artifacts preserved for accepted token claims
- concise final report with changed files, commands, pass/fail, token wins/losses, remaining risks
