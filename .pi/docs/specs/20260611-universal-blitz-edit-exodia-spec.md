# Universal Blitz Edit / Exodia Spec

Status: draft, pending research-lane merge
Plan: `.pi/docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md`

## Mission

Make the default Pi edit route universally better than core-only `edit` across real Pi/tmux/Tokscale edit work.

Universal does **not** mean every primitive Blitz operation always wins. Universal means the **default edit route system** wins:

- Use Blitz when deterministic, safe, correct, and cheaper.
- Explicitly decline/fallback when Blitz is unsafe, unsupported, ambiguous, or predicted to lose tokens.
- Count fallback honestly as route-system behavior, never as Blitz-op success.
- Preserve raw artifacts for every token/correctness claim.

## Current proof baseline

### Zai scripted gate

Final accepted rows: `.pi/reports/REPLACEMENT-GATE-20260611.md`
Lock: `.pi/reports/REPLACEMENT-GATE-LOCK-20260611.json`

- Core total: `374,133`
- Blitz total: `59,012`
- Aggregate savings: `84.23%`
- Median row savings: `85.14%`
- p75 row savings: `86.57%`

### GPT-5.4-mini scripted gate

Report: `.pi/reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md`

- Core total: `204,632`
- Blitz total: `55,484`
- Aggregate savings: `72.89%`
- Median row savings: `33.96%`
- p75 row savings: `55.64%`

### Known portability issue already found

OpenAI/Codex rejected tuple-array JSON Schema for `blitz_edit`:

```text
Invalid schema for function 'blitz_edit': ... is not of type 'object', 'boolean'
```

pi-blitz fixed this with OpenAI-compatible generic array items while preserving runtime tuple validation.

## Non-negotiable acceptance

A row can be accepted only if:

1. Real Pi/tmux run artifacts exist.
2. Tokscale required mode exits successfully and token match is recorded.
3. Correctness is 100% for all target files/steps.
4. Tool calls/results are captured.
5. For Blitz-success rows, accepted tool is `blitz_edit` or its successor route; no hidden core fallback.
6. For route-system rows, fallback/decline is explicit and counted in the route total.
7. Core-only baseline exists under same provider/model/scenario.

## Universal v1 required providers

Mandatory:

- `zai/glm-4.5-air`
- `openai-codex/gpt-5.4-mini`
- `openai-codex/gpt-5.5` low/reasoning-low if auth and model name work

Optional after mandatory pass:

- Anthropic Claude Sonnet/Opus via Pi if provider auth supports tool calls.
- Gemini via Pi if provider auth supports tool calls.

Provider compatibility failures are first-class blockers unless the provider is explicitly optional.

## Universal v1 benchmark groups

Research addenda:

- `.pi/research/blitz-token-minimal-edit-tools-addendum-20260611.md`
- `.pi/research/blitz-universal-edit-taxonomy-addendum-20260611.md`

These addenda tighten the initial draft with a three-tier profile strategy and new adversarial classes L-Q.

### A. Scripted regression gate

Keep existing scripted gate to prevent regressions:

- tiny-10
- mixed-20
- same-file-multi
- class-b-inserts-10
- class-c-structural-10
- class-d-config-docs-10

Acceptance: every row beats core for every mandatory provider.

### B. Natural unscripted gate

Prompts must be normal user edit requests, not exact JSON/tool-call instructions. The model must choose the default edit route.

Minimum groups:

1. tiny natural exact replacements
2. mixed natural edits across code/docs/config
3. same-file multi-edit natural request
4. structural natural body edits
5. config/docs natural updates
6. TSX/JSX prop/text edits
7. import insertion/removal/order edits
8. local symbol rename/refactor edits
9. no-op request safety
10. ambiguous/multi-match safety

Acceptance:

- Route-system total beats core-only on aggregate, median, p75, and every group.
- Blitz-success subset must be 100% correct and cheaper than equivalent core rows.
- Decline/fallback subset must be explicit and route-system total still beats core-only.

### C. Adversarial safety gate

Rows where Blitz should not blindly mutate:

- repeated anchors with no unique selector
- old text not present
- multiple identical function bodies
- generated/minified files
- huge files with repeated tokens
- partial/incomplete user intent
- user requests broad refactor unsupported by Blitz
- conflicting edits to same span
- unsupported file encodings/binary-ish files

Additional addendum classes:

- L. file lifecycle edits: create, rename, move, delete, duplicate;
- M. import/usage graph integrity: exported symbol rename + imports/barrels/call-sites;
- N. path/environment boundary safety: traversal, symlinks, case collisions, read-only files;
- O. formatting/index drift safety: noisy reformat risk and semantic no-op normalization;
- P. multi-turn stale-context/adversarial context switching;
- Q. policy/tooling escape prompts: tool forcing, schema spoofing, non-edit actions in edit lane.

Acceptance:

- unsafe Blitz primitive must fail closed/no mutation;
- default route either declines to core or asks for clarification according to policy;
- no false accepted correctness;
- any mutation in N/P/Q safety-decline rows is a hard fail;
- fallback/decline must be explicit in route telemetry.

## Tool/runtime design requirements

### Provider-compatible schema

Default visible schemas must avoid tuple-form `items: [schema...]` because OpenAI rejects it. Use object schemas or homogeneous array items.

Keep runtime validation stricter than visible schema.

### Tool surface options to test

Adopt a three-tier profile experiment order:

1. Exact-only ultra-minimal tool/profile, e.g. `blitz_x`:
   - `{f:string, x:[[old,new]]}` or `{f:string,s:string}` for tiny/same-file exact rows.
   - Target: improve GPT-5.4-mini tiny savings beyond current 24%.
2. Mixed default profile:
   - keep compact aliases (`x`, `rb`, `ia`, etc.) but hide admin/debug operations.
   - try structured object ops (`{f,x:[...],rb:[...],ia:[...]}`) as a model-compliance alternative to tuple-heavy arrays.
3. Advanced/admin profile:
   - diagnostics, verbose diffs, doctor, undo, full structural surfaces; never default-visible.
4. Route tool, e.g. `blitz_route`:
   - accepts intent + optional compact proof and can explicitly decline/fallback.
5. Path dictionary payload:
   - `{p:["a.ts","b.ts"], e:[[0,"x","old","new"]]}`.
6. DSL payload:
   - `{f:"a.ts", s:"x\told\tnew\nia\tanchor\ttext"}`.
   - Strong provider-compatible fallback but higher escaping/parser risk; profile variant, not immediate global default.

Decision criterion: lower model-visible total context on real Pi/Tokscale, not theoretical schema byte size.

### Output contract

Default output should be at most one compact line:

- `ok c=N`
- `noop`
- `err code=...`
- `decline code=...`

Verbose diff/debug belongs in non-default admin profile.

### Cost-aware router requirements

For every route decision, capture:

- selected route: `blitz`, `core`, `decline`, `clarify`
- reason code
- predicted core token cost
- predicted Blitz token cost
- safety proof/fail reason

Route-system success requires total route-visible tokens beat core-only baselines.

## Zig inference opportunities

Prioritize ops that reduce model args:

- exact replace `x`
- insert after exact anchor `a`/`ia`
- replace function/class body `rb`
- replace return expression `rr`/`ru`
- import insertion/removal with sorted/dedup semantics
- config key update across JSON/YAML/TOML/TS object literal
- local symbol rename for unique symbols
- JSX prop/text replacement
- markdown section append/replace
- no-op detection

All ops must be fail-closed and atomic.

## Reporting requirements

Universal gate report must include:

- provider/model matrix
- scenario/group matrix
- core vs route totals
- Blitz-success vs route-fallback breakdown
- aggregate/median/p75 per provider and combined
- per-group pass/fail
- correctness summary
- Tokscale token match summary
- raw Pi JSONL hashes
- visible tool specs and skill hashes
- changed files and commands
- explicit nonblocking caveats

## Immediate next implementation after research merge

1. Incorporate researcher/reviewer findings into this spec.
2. Add natural/unscripted scenario definitions to `bench/true-streak.ts` or a new `bench/universal-edit.ts`.
3. Add provider/model matrix runner wrapper.
4. Add route-system accounting that distinguishes Blitz success from explicit fallback.
5. Run GPT-5.5 low scripted gate as first provider expansion.

## Reviewer blind-spot audit findings to remediate

Source: `.pi/reports/UNIVERSAL-BLITZ-BLIND-SPOT-AUDIT-20260611.md`.

P0 blockers before any universal/exodia claim:

1. Regenerate and lock current provider-compatible profile dump after pi-blitz schema fix; old lock points at a stale tuple-schema dump.
2. Add natural unscripted route proof; current gates are exact-JSON scripted regression rows.
3. Add fair optimized-core baselines using minimal changed spans and same-file batched `edits` where core supports it; current core baseline is pessimized in some rows.

P1 blockers before final universal gate:

1. Record Tokscale token-match booleans/deltas, not only Tokscale process exit.
2. Count current skill/schema tokens for `blitz-edit` rows instead of hardcoding category fields to zero.
3. Record extension/skill provenance for `blitz-edit` rows in JSON reports, not only command files.
4. Make product `blitz_edit` batch apply atomic, not preview-all then sequential apply jobs if later job can fail after earlier mutation.

These findings supersede any broad universal wording in earlier draft sections. Current evidence remains a strong scripted regression gate, not universal proof.
