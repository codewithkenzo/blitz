# PLAN 0.5 — Universal Blitz Edit / “Exodia” Route

## Context

Blitz now has a default Pi edit route (`blitz_edit`) that beats core `edit` on the locked required gate matrix for Zai and GPT-5.4-mini. The latest GPT-5.4-mini rerun exposed an important portability blind spot: OpenAI rejected tuple-array function schemas until pi-blitz changed the visible schema while preserving the runtime tuple contract.

Current proof is strong for scripted default edit gates, but not universal. “Universal” must mean the **system route** is better than core-only across broad real edit work: Blitz first when safe/cheaper, deterministic decline/fallback when not, and no hidden fallback counted as Blitz success.

## Approach

Build a new universal edit program with four tracks:

1. **Research / design lanes** — use researcher/reviewer agents after plan approval to gather provider schema constraints, token-minimal tool patterns, adversarial edit taxonomies, and Zig/AST inference opportunities.
2. **Benchmark expansion** — add unscripted and adversarial Pi/tmux/Tokscale suites beyond the current scripted gate.
3. **Runtime/router evolution** — make the default route a cost-aware Blitz-first router, not “always force Blitz.”
4. **Token-shrink iterations** — reduce schema, args, prompt, output, and model-loop overhead until every accepted route beats core or cleanly declines to core.

## Files to modify

Blitz repo:

- `bench/true-streak.ts` — add provider/model matrix mode and unscripted/adversarial scenario groups.
- `bench/pi-matrix.ts` — align isolated and natural prompt rows with `blitz_edit` / future router surfaces.
- `bench/regression-thresholds.json` — add universal-gate thresholds after evidence is locked.
- `reports/` — add universal-gate reports and raw lock JSON.
- `docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md` — this plan/spec.
- Potentially `src/apply/*` — add compact ops/inference support if research/benchmarks show gaps.

pi-blitz repo:

- `src/tools.ts` — refine schema/args/output and maybe split visible tools.
- `src/tool-profiles.ts` — profiles for exact-only, router, admin/debug, provider-specific compatibility.
- `skills/pi-blitz/SKILL.md` — keep resident instruction minimal but enough for unscripted tool choice.
- `test/tool-profiles.test.ts` — lock provider-compatible schemas and visible tools.
- `reports/profile-dumps/` — profile dumps per provider-compatible route.

## Reuse

Existing assets to reuse:

- `bench/true-streak.ts` — real Pi/tmux/Tokscale same-session runner.
- `bench/pi-matrix.ts` — larger fixture matrix/accounting harness.
- `reports/REPLACEMENT-GATE-LOCK-20260611.json` — lock-file shape for raw artifacts/hashes/tool calls.
- `reports/REPLACEMENT-GATE-20260611.md` — D1-D5 reporting structure.
- `reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md` — provider portability template.
- `src/apply/mod.zig` / `src/apply/ir.zig` / `src/apply/operations.zig` — compact op execution and safety checks.
- `/home/kenzo/dev/pi-blitz/src/tools.ts` — `blitz_edit` runtime and schema bridge.
- `/home/kenzo/dev/pi-blitz/test/tool-profiles.test.ts` — profile/schema regression location.

## Research lanes to run after approval

- **researcher: provider schema compatibility**
  - OpenAI/Codex, Zai, Anthropic/Gemini if available: supported JSON Schema subsets, array tuple limitations, strict tools behavior, schema-size/token effects.
  - Output: `research/blitz-provider-tool-schema-compat-20260611.md`.

- **researcher: token-minimal editing tool patterns**
  - Survey OSS agent tools / patch formats / function-calling payload strategies.
  - Focus: path dictionaries, op dictionaries, single-file defaulting, DSL strings vs JSON arrays, output minimization.
  - Output: `research/blitz-token-minimal-edit-tools-20260611.md`.

- **researcher: adversarial edit taxonomy**
  - Build a taxonomy of edit classes that could break “universal”: ambiguous anchors, repeated matches, generated/minified files, JSX, imports/renames, config formats, multi-file refactors, comment/doc edits, huge files, no-op requests.
  - Output: `research/blitz-universal-edit-taxonomy-20260611.md`.

- **reviewer: blind-spot audit**
  - Review current D1-D5 reports and GPT-5.4-mini rerun for hidden benchmark bias, scripted-prompt dependence, untested providers, fallback accounting, and correctness gaps.
  - Output: `reports/UNIVERSAL-BLITZ-BLIND-SPOT-AUDIT-20260611.md`.

## Implementation steps

- [ ] Step 1 — Research and blind-spot audit
  - Run the researcher/reviewer lanes above.
  - Summarize concrete design changes into this plan or a linked spec.

- [ ] Step 2 — Define “universal better” acceptance precisely
  - Universal is not “Blitz op always wins.” It is “default edit route beats core-only everywhere in accepted matrix by using Blitz when safe/cheaper and deterministic decline/fallback when not.”
  - Accepted Blitz-success rows must use Blitz only; fallback rows must be counted as route-system success, not Blitz-op success.
  - No row may be accepted without 100% correctness and Tokscale token match.

- [ ] Step 3 — Add natural/unscripted benchmark suite
  - Add prompts where the model receives normal edit requests, not exact JSON.
  - Required groups: tiny natural, mixed natural, same-file natural, structural natural, config/docs natural, JSX/imports, rename/refactor, ambiguous/no-op/multi-match safety.
  - Each group must run core-only vs default-route on at least Zai and GPT-5.4-mini; add GPT-5.5 low if provider auth supports it.

- [ ] Step 4 — Add provider matrix mode
  - Support provider/model lists in the runner or wrapper script.
  - Preserve separate raw run roots and reports per provider.
  - Fail closed on provider schema rejection; provider compatibility is part of the gate.

- [ ] Step 5 — Shrink the tool surface further
  - Measure current minimal schema/skill after OpenAI schema fix.
  - Evaluate an exact-only `blitz_x` or provider-specific minimal schema if it lowers tiny rows.
  - Evaluate path dictionary / current-file default / op alias compression.
  - Keep verbose/admin/debug surfaces out of default profile.

- [ ] Step 6 — Add cost-aware router
  - Route to Blitz when deterministic uniqueness/cost estimate says win.
  - Decline to core/apply_patch for ambiguity, multi-match, unsupported semantic edits, or predicted token loss.
  - Report route decisions explicitly so fallback is not hidden.

- [ ] Step 7 — Expand Zig inference ops
  - Add or improve compact ops where they reduce args: return replacement, import insertion, config-key update, symbol rename, JSX prop/text edit, append section, no-op detection.
  - Preserve fail-closed semantics and atomic writes.

- [ ] Step 8 — Lock universal gate
  - Produce `reports/UNIVERSAL-BLITZ-EDIT-GATE-YYYYMMDD.md` and `.json` lock.
  - Include raw Pi JSONL hashes, Tokscale output, tool specs, skill text hash, tool calls/results, correctness, aggregate/median/p75/per-class/per-provider math.

- [ ] Step 9 — Final reviewer audit
  - Independent reviewer verifies no hidden fallback, all fallback accounting is explicit, all accepted rows correct, and default route beats core-only across the matrix.

## Verification

Minimum verification commands per implementation slice:

Blitz:

```bash
zig build
zig build test
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
bun build bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js
```

pi-blitz:

```bash
bun run typecheck
bun test
bun run build
```

Benchmark gates:

```bash
# Existing scripted gate, Zai + GPT-5.4-mini
bun bench/true-streak.ts --provider zai --model glm-4.5-air --lane core --scenario tiny-10 --tokscale
bun bench/true-streak.ts --provider zai --model glm-4.5-air --lane blitz-edit --scenario tiny-10 --tokscale
bun bench/true-streak.ts --provider openai-codex --model gpt-5.4-mini --lane core --scenario tiny-10 --tokscale
bun bench/true-streak.ts --provider openai-codex --model gpt-5.4-mini --lane blitz-edit --scenario tiny-10 --tokscale
```

New universal gate must run all configured scenarios/providers and produce one lock file with pass/fail summary.

## Open questions

1. Should “universal” allow a visible route tool that sometimes explicitly declines to core, as long as the **default route system** beats core-only? I recommend yes.
2. Which providers/models are mandatory for universal v1: Zai + GPT-5.4-mini + GPT-5.5 low, or also Anthropic/Gemini?
3. How large should unscripted/adversarial v1 be: 50, 100, or 200 rows per provider?
4. Is any per-row exception allowed if aggregate/default-route wins, or must every accepted class/provider row beat core?

## Execution log — 2026-06-11 checkpoint 1

Started implementation slice 1 via D5 subagent (`fa7e3f09-d8ed-40c2-96b6-b38676af9a67`) to address reviewer P0/P1 accounting blockers before any natural/adversarial matrix work:

- regenerate current OpenAI-compatible pi-blitz minimal profile dump;
- record `extension`/`skill` provenance for `blitz-edit` rows;
- count current schema/skill tokens for `blitz-edit` rows;
- record Tokscale token-match booleans/deltas and fail/caveat mismatches;
- add a concise report note and run verification gates.

Next after slice 1 lands: fair optimized-core baseline, atomic `blitz_edit` batch semantics, then natural/adversarial route matrix.

## Execution log — 2026-06-11 checkpoint 2

Accounting/provenance remediation landed:

- Blitz `89d0b42` records `extension`, `skill`, `profileDump`, schema tokens, skill tokens, and Tokscale token-match deltas in `bench/true-streak.ts`.
- pi-blitz `95b4914` refreshes the minimal profile dump to the OpenAI-compatible schema.
- Smoke proof: `reports/pi-tmux-true-streak-accounting-fix-tiny-10-blitz-edit-20260611-rerun.md` accepted with Tokscale match yes and all deltas 0.

Started implementation slice 2 via D5 subagent (`e8ad1dbf-b086-4ced-b2be-f35fd9406c18`) in `/home/kenzo/dev/pi-blitz` to fix product `blitz_edit` same-file batch atomicity. Target: group same-file ops into one compact preview/apply request; document remaining cross-file transaction limitation if Blitz CLI cannot provide multi-file atomicity yet.

Next after slice 2: implement fair optimized-core baseline in `bench/true-streak.ts`, then natural/unscripted route harness.

## Execution log — 2026-06-11 checkpoint 3

Started implementation slice 3 via D5 subagent (`da63631a-7728-4cf8-9521-767f5a89141d`) in `/home/kenzo/dev/blitz` for fair optimized-core baseline support:

- add a new core `edit`-only lane such as `core-optimized`;
- use minimal changed spans instead of full-file old/new where safe;
- use same-file batched `edits` when core supports it, or document limitation;
- preserve existing `core` and `blitz-edit` lanes;
- add a report note and smoke row.

This directly addresses the blind-spot audit P0 finding that current scripted core baselines are pessimized for same-file and structural rows.

## Execution log — 2026-06-11 checkpoint 4

Atomicity slice landed in pi-blitz:

- pi-blitz `a1f81e0` groups `blitz_edit` operations by file.
- Same-file multi-op now uses one compact preview request and one compact apply request.
- Cross-file calls preview all file groups before any apply, then apply per file; cross-file transaction remains explicitly non-atomic.
- pi-blitz verification passed: `bun run typecheck`, `bun test`, `bun run build`, `git diff --check`.

Fair optimized-core slice is still pending. D5/d5-fast hit the subagent queue bug, and cmd needed `--yolo` for file writes.

## Execution log — 2026-06-11 checkpoint 5

Fair optimized-core baseline expanded:

- Blitz `3944591` added `core-optimized` lane and fair-core report.
- Accepted Zai fair-core rows now exist for tiny-10, mixed-20, Class B inserts, Class C structural, and Class D config/docs.
- Same-file fair-core row remains caveated: final file correct and Tokscale matched, but timeout/exit -1 after repeated core `edit` calls; not counted.

Started implementation slice 4 via D5 subagent (`418aa278-5600-4c37-92b9-e63005393faf`) to add the first natural/unscripted benchmark harness slice with explicit route/outcome labels. Scope is Blitz only; no universal claim yet.

## Execution log — 2026-06-12 checkpoint 6

Natural/unscripted harness hardening landed:

- Blitz `907b630` added audit identity, route-outcome accounting, session JSONL hash/provenance, Tokscale audit fields, `--tokscale` alias, fail-closed acceptance, and preserved natural run artifacts.
- Blitz `6535fbf` added independent Pi session JSONL usage parsing for natural rows and compares parser totals to Tokscale totals with exact match/deltas before accepting validated rows.
- Verification passed: `bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js`, `git diff --check`, and parser self-check on committed natural JSONL.

Started implementation slice 5 via D5 subagent (`ba306c6e-6f8c-45c6-9aad-90dc3bab5e75`) to add the first adversarial/safety matrix slice to `bench/natural-edit.ts`: selectable adversarial scenarios, >=20 rows/provider when run, required safety categories, and a cheap non-provider coverage check. No long provider matrix yet.

## Execution log — 2026-06-12 checkpoint 7

Natural coverage expansion slice prepared:

- `bench/natural-edit.ts` natural group expanded from 6 to 25 natural/user-like scenarios.
- Documented row semantics: at `--iters 1`, both default lanes (`core` + `blitz`) produce 50 natural rows/provider.
- Required natural categories are covered: tiny, mixed code/docs/config, same-file multi, structural body, config/docs, TSX/JSX prop/text, import insertion/removal/order, local symbol rename/refactor, no-op/idempotence, and ambiguous/multi-match safety.
- Added `reports/NATURAL-EDIT-COVERAGE-EXPANSION-20260612.md` with mandatory-provider full-matrix commands and cheap non-provider assertion.
- No provider matrix run; this slice only proves harness coverage capacity.
