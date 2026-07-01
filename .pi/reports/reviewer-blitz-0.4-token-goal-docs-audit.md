# Reviewer Audit — Blitz 0.4 token/core replacement docs

## Verdict

PASS WITH FIXES.

Docs are token-first and mostly goal-ready, but first slice has contradictions that can send long autonomous work into wrong repo, wrong measurement method, or benchmark-only routing.

## Spec Compliance

- Research incorporation: mostly compliant. Plan imports OpenAI/Anthropic/MCP lazy loading, freeform/custom tools, prompt caching, FastEdit/CEDARScript/AFT/Morph/apply_patch, and tree-sitter findings into architecture/phases.
- Token-first direction: compliant. `AGENTS.md:13-19`, `.pi/docs/blitz.md:32-45`, `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:7-13`, and `.pi/docs/plans/START-0.4-context-token-core.md:22-27` all make token/context savings product truth and speed secondary.
- Fake-savings guard: mostly compliant, but schema/skill accounting still says “estimate/rough” in key gates; needs exact artifact/tokenizer method before autonomous work.
- First slice concreteness: not yet compliant. START asks for Phase 0 + Phase 1 first, but also requires artifacts that belong to later phases.

## Findings

1. `.pi/docs/plans/START-0.4-context-token-core.md:30-46` + `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:339` + `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:452-455` — Required first slice is internally inconsistent: it says deliver only Phase 0 + Phase 1, but Phase 1 minimal profile depends on `pi_blitz_op`, which is not delivered until Phase 2, and START also asks for router-selected matrix before router Phase 6.

2. `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:412-427` + `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:443-446` + `.pi/docs/plans/START-0.4-context-token-core.md:32-40` — Acceptance alternates between “exact token/context breakdown” and schema/skill “estimate/rough tokens”; this leaves room for fake savings from chars/4 or non-serialized schema counts.

3. `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:436-441` + `.pi/docs/plans/START-0.4-context-token-core.md:20` + `.pi/docs/plans/START-0.4-context-token-core.md:80-95` — Phase 1 requires edits in `/home/kenzo/dev/pi-blitz`, but START only gives a Blitz branch/artifact plan; cross-repo branch ownership, file scope, package tests, install/build flow, and PR/push handoff are undefined.

4. `.pi/.pi/research/20260605-token-efficient-edit-repos.md:28-32` + `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:385-404` + `.pi/docs/plans/PLAN-0.4-context-token-optimization.md:511-527` — AFT host-tool replacement finding is only acknowledged in addendum; runtime router integration point is unspecified, so an agent can satisfy reports with benchmark-side route selection while Blitz still remains optional niche tool.

## Required Fixes

- Resolve first-slice contract. Either include `pi_blitz_op` + minimal router stub in Phase 0/1, or redefine first slice as measurement + profile registration only and move optimized/router matrix acceptance to Phase 2/6.
- Define exact schema/skill accounting method: dump Pi-serialized registered tool specs per profile, dump resident skill text used by run, count with same tokenizer/Tokscale-compatible model accounting where possible, preserve raw artifacts, and reconcile totals with input/cache/token residuals in report.
- Add cross-repo execution section for `@codewithkenzo/pi-blitz`: branch name, allowed files, build/test commands, package/install path used by Blitz harness, artifact paths, and push/PR policy.
- Specify where token-first router lives at runtime, not only in benchmark reports: Pi extension facade, core-tool wrapper/alias, skill-level routing, or explicit “benchmark only until Phase X” boundary.

## Verification Gaps

- `git status -sb` clean at review start; `git diff HEAD` empty.
- No code/tests run; scope was docs readiness audit.
- No JS/TS/Zig gates needed for docs-only review.
- No existing output report found before write; this file is generated review artifact.

## Spec/TK/Memory Notes

- No local `.tickets` found in repo.
- No memory updates needed; findings are task-local until docs are patched.
- `AGENTS.md` and START correctly require benchmarking skill + tmux/Tokscale method before token claims.

## Anything Missed / Review Next

- After docs are patched, review START/PLAN again before launching long autonomous goal.
- After implementation starts, review actual `pi-blitz` profile registration, benchmark schema dumps, raw tmux/Pi artifacts, and router runtime integration before accepting savings claims.
