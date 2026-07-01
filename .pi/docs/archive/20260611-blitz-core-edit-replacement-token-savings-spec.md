# Blitz Core Edit Replacement Token-Savings Spec

Date: 2026-06-11
Status: active spec
Plan: `.pi/docs/plans/archive/PLAN-0.4-core-edit-replacement-token-savings.md`
Owner intent: Blitz must replace Pi core `edit` everywhere by becoming lower-token at the user/model-visible loop level. Compact IR alone is not a completion goal.

## Thesis

This work is possible, but only if Blitz stops being an optional structural tool and becomes a smaller, stricter replacement for the exposed edit surface.

The completed compact IR slice proves Blitz can execute compact AST edits safely. It does **not** prove the user goal. Existing evidence shows Blitz/router currently loses total context on realistic streaks:

- 10 tiny edits: core 75,042 total context vs router/blitz 81,720 (`-8.9%` savings; core cheaper).
- 20 mixed edits: core 176,422 vs router/blitz 247,024 (`-40.0%`; core cheaper).
- same-file multi-edit: core 18,429 vs router/blitz 25,374 (`-37.7%`; core cheaper).
- focused compact `rb`: core total input+output+cacheRead 8,041 vs Blitz 8,484.

Therefore any next goal that completes without beating core on total model-visible tokens is invalid.

## Non-negotiable objective

Replace Pi core `edit` with a Blitz-owned edit surface that is lower-token than core `edit` across representative real Pi/tmux/Tokscale edit streaks.

Core `edit` may remain as an audit baseline in benchmarks, but it is not an acceptable product fallback/default. If Blitz needs exact text replacement, Blitz implements that exact replacement internally with equivalent safety and a smaller model-visible surface.

## Definition of complete

A completion claim is valid only when all gates pass:

1. **Default route**: the exposed/default edit tool available to the agent is Blitz-owned, not Pi core `edit`.
2. **Correctness parity**: every benchmark row reaches the same final file as core or a documented stricter no-write rejection.
3. **Token win**: Blitz total model-visible tokens are lower than core on:
   - aggregate total across the full matrix,
   - median row,
   - p75 row,
   - each mandatory class unless a pre-approved class exception exists.
4. **Tiny-edit win**: 10+ tiny exact edit streak beats core. This is the hardest gate and cannot be skipped.
5. **Mixed-streak win**: 20+ mixed code/config/docs streak beats core.
6. **No hidden fallback**: reports must not count benchmark-side synthetic fallback as Blitz replacement.
7. **No compact-IR-only completion**: compact `rb`/`ia`/`mn` existence is only a prerequisite.
8. **No token claims without Tokscale/session artifacts**: every savings number links to raw Pi JSONL + Tokscale output.

## Product architecture required to make this possible

### 1. One tiny resident Blitz edit tool

Current `pi_blitz_op` is too broad and still returns too much. Create a default replacement tool with minimal schema and no long prose.

Candidate name options:

- `edit` via wrapper/alias if Pi allows overriding/rebinding core tool.
- `blitz_edit` if core name cannot be overridden yet.

Model-facing schema target:

```json
{"f":"path","e":[["x","old","new"]]}
```

or equivalent with short keys. Required operations:

- `x`: exact replace old/new, Blitz-owned core-edit equivalent.
- `a`: append/insert by exact anchor.
- `u`: replace unique text.
- `rb`: symbol body replace.
- `ia`: insert after symbol/anchor.
- `mn`: marker merge.
- `sk`: set config key.

Default success output target: under 20 tokens, e.g.

```text
ok c=1
```

No file path, ranges, diff, metrics, or route details by default. Debug output is opt-in.

### 2. Blitz exact replace must be first-class

Tiny one-line edits dominate replacement viability. Blitz must provide exact `oldText/newText` semantics internally, with no AST overhead requirement and no model-visible old-code expansion beyond what core already needs.

Acceptance for exact replace:

- identical or stricter safety vs Pi core `edit`;
- no partial write;
- deterministic count/no-match/multi-match errors;
- smaller result payload than core;
- args equal or smaller than core for same old/new strings.

### 3. Remove resident skill tax

The default lane must run with either no skill or a sub-300-token resident skill. Current reports show 580 skill tokens in router rows; this alone kills tiny rows.

Default skill text target:

```text
Use Blitz edit for all edits. Prefer x exact replace for tiny changes; rb/ia/mn for symbol edits. Return no explanations after successful tools. Verify only when asked or required.
```

Long examples move to references and are not resident in replacement benchmarks.

### 4. Flatten pi-blitz output path

`applyResultToText` currently creates human text and details containing ranges/diffSummary/validation/metrics. Replacement mode needs a `quiet` output path that returns only:

- success: `ok c=N`
- no-op: `noop`
- rejection: `err code=...`

Detailed JSON stays behind debug flag.

### 5. Benchmark harness becomes acceptance harness

Existing `.pi/bench/true-streak.ts` and `.pi/bench/pi-matrix.ts` are useful but must be hardened into a replacement gate:

- real Pi session per row;
- raw session JSONL preserved;
- Tokscale run preserved;
- serialized visible tool specs captured;
- exact skill text captured;
- exact tool calls/results captured;
- report aggregates total model-visible tokens.

No chars/4 acceptance unless clearly marked exploratory.

## Mandatory benchmark matrix

### Class A — tiny core-equivalent edits

Must beat core. No exception.

- one-line return replacement;
- string literal replacement;
- config value replacement;
- markdown sentence replacement;
- JSON scalar replacement;
- import path replacement;
- rename one local identifier by exact text.

Run as 10+ true same-session edits and as isolated rows.

### Class B — small insert/anchor edits

Must beat or tie core by total tokens.

- insert logging line;
- insert guard after first line;
- add import;
- append markdown bullet;
- ensure line.

### Class C — symbol/structural edits

Must beat core strongly.

- function body replace;
- marker merge in body;
- insert after symbol;
- wrap body;
- same-file multi-edit.

### Class D — config/docs

Must beat core on aggregate.

- package/version/key edits;
- markdown section append;
- YAML/TOML/JSON key update.

## Acceptance thresholds

Initial hard thresholds:

- Aggregate total context: Blitz <= core * 0.90.
- Median row: Blitz <= core * 0.95.
- p75 row: Blitz <= core * 1.00.
- Tiny streak: Blitz <= core * 0.95.
- Mixed streak: Blitz <= core * 0.95.
- Structural rows: Blitz preserves >=50% of previously observed structural token savings where core repeats large code.
- Any row > core * 1.10 requires a tracked remediation ticket before completion.

Final replacement threshold after first pass should tighten to aggregate <= core * 0.80.

## Implementation plan

### Phase 1 — Measurement lock

- Convert current benchmark reports into one canonical replacement gate report.
- Ensure visible tool schema and skill text artifacts are captured for every row.
- Add a failing baseline report that names current losses as blockers.

Exit: report proves current Blitz is not replacement-ready and defines exact deltas to close.

### Phase 2 — Default Blitz exact-edit tool

In `/home/kenzo/dev/pi-blitz` and `/home/kenzo/dev/blitz`:

- add/route `x` exact replace to Blitz CLI;
- expose tiny default tool schema;
- return quiet result by default;
- add tests for no-match/multi-match/no partial write.

Exit: isolated exact replace rows beat core on args+output and pass correctness.

### Phase 3 — Resident tax elimination

- default profile registers only replacement tool;
- default skill <=300 tokens or no skill;
- remove verbose descriptions from default schema;
- debug/admin profiles keep docs.

Exit: serialized tool+skill context drops below core-equivalent overhead and below previous minimal profile.

### Phase 4 — Quiet output everywhere

- pi-blitz converts compact CLI success to `ok c=N`;
- CLI quiet mode returns smallest possible JSON/text;
- errors are compact but actionable.

Exit: tool result payload is lower than core in tiny rows.

### Phase 5 — Streak optimization

- batch same-file exact edits in one call;
- encourage model to call Blitz once for ordered same-file changes;
- support script/freeform DSL if Pi can route it cheaper than JSON.

Exit: 10 tiny and 20 mixed true-streak rows beat core.

### Phase 6 — Replacement integration

- make Blitz-owned edit the default editing instruction/tool profile;
- core edit removed from replacement benchmark tool list except baseline lane;
- no route decline to core.

Exit: real product lane uses Blitz by default.

## Open research tasks

Plan-mode note: this draft used existing repository research reports rather than spawning fresh researcher agents. Before implementation, run focused researchers on:

1. Pi extension/tool schema serialization and whether core tool can be overridden/aliased as `edit`.
2. Provider-specific tool schema tax for current default models.
3. Freeform/custom tool availability in Pi for raw compact edit DSL.
4. Exact core `edit` result payload shape and token cost across providers.
5. Prior art: FastEdit exact-edit path, Aider diff/search-replace failures, Anthropic Tool Search/lazy-loading constraints.

## Builder routing

- `d5`: Blitz CLI exact replace/quiet output/benchmark harness.
- `d5` in `/home/kenzo/dev/pi-blitz`: tool schema/profile/output path.
- `reviewer`: audit benchmark math and reject any completion without tiny-streak savings.
- `researcher`: external/provider/Pi tool-tax research before implementation.

## Non-completion examples

These are explicitly not complete:

- compact IR exists but total tokens lose;
- structural rows win but tiny rows lose;
- Blitz routes to core edit and calls that replacement;
- reports say candidate/fallback;
- savings are estimated from bytes without Tokscale;
- default profile still requires 500+ resident skill tokens;
- tool output includes metrics/ranges/diffs by default.

## Next action

Execute `.pi/docs/plans/archive/PLAN-0.4-core-edit-replacement-token-savings.md` using the stricter acceptance threshold: Blitz must win aggregate, median, p75, tiny streak, mixed streak, and every mandatory benchmark class unless a pre-approved evidence-backed class exception exists. First implementation slice is Blitz CLI exact replace (`x`) plus quiet output; dispatch to `d5` before pi-blitz profile work.
