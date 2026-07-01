# PLAN-0.5I — Token moonshot / universal route strategy

Date: 2026-06-20
Parent epic: `bli-6uqs`

## Goal

Move from scoped minimal `blitz_edit` wins toward a practical provider-wide edit router that saves major context on real work.

Target is not "Blitz beats core on every row." Tiny exact edits have an irreducible token floor. Target is:

- choose the cheaper safe route per edit class;
- keep tiny exact at break-even or routed to core;
- push simple multi/config/doc rows to consistent token-positive;
- build an advanced explicit structural route that can save 50-80% on large/symbol edits;
- measure weighted real-edit savings, not cherry-picked rows.

## Hard truth

A literal 60-80% token saving on every provider/language/edit row is not credible for tiny edits. If the edit is one word and core already needs little context, schema/tool-call overhead dominates.

60-80% becomes plausible only when Blitz avoids large oldText/newText replay or unchanged-code replay:

- multi-file/multi-edit batches;
- symbol/body transforms;
- config/doc structured operations;
- AST-guided edits by reference;
- no resident skill/schema bloat;
- compact output and clear decline paths.

## Product direction

### Default/minimal profile

Scope:

- exact/simple replacements;
- same-file multi edits;
- config/doc edits;
- safety declines;
- structural aliases such as `rb` decline in minimal profile.

Policy:

- if deterministic route budget predicts core cheaper, choose/mark core;
- if Blitz wins or ties, use Blitz;
- never count decline/noop/fallback as Blitz success.

### Advanced/explicit structural profile

Future route. Not part of minimal claim until locked.

Scope:

- symbol body replace;
- insert-after symbol;
- import edit;
- local rename;
- wrap/delete/append blocks.

Requirements:

- explicit supported tuple/schema;
- deterministic formatting normalization;
- language capability matrix;
- provider-shape tests;
- no semantic-near-miss success;
- Tokscale-validated evidence before claim.

### Router/product claim

Future broad claim should be phrased as route-optimizer evidence, not forced-Blitz evidence:

> The edit router selected safe routes across provider/language rows, using Blitz where it beat/tied core and core where tiny floor made Blitz wasteful.

Forbidden until evidence:

- "Blitz saves 60-80% everywhere";
- "universal replacement";
- "all providers/languages";
- "structural default".

## Workstreams

1. Real-edit token anatomy
   - quantify where tokens go across successful/failed rows;
   - split resident schema, skill, prompt, args, output, cache, result payload;
   - identify rows where 60-80% is mathematically possible.

2. Route selector
   - deterministic cheaper-route guard;
   - row-class policy: core/tie/Blitz/advanced/decline;
   - budget tests prevent regressions.

3. Zero/min-resident mode
   - minimize resident schema/skill text;
   - avoid loading docs/skill text for simple exact rows;
   - compact tool descriptions and outputs;
   - consider profile with only the minimal edit surface exposed.

4. Compact IR v2
   - shrink args for common edits;
   - support aliases/dictionaries/top-level file defaults;
   - avoid unchanged-code replay;
   - keep safety exact and parseable.

5. Advanced structural route
   - reintroduce structural operations outside minimal profile;
   - strict provider-shape support;
   - formatting-preserving output;
   - explicit capability and decline taxonomy.

6. Weighted provider-language telemetry
   - after implementation fixes, run bounded matrix;
   - compute weighted savings by edit class;
   - report green-only, route-truth-only numbers.

## Suggested gates

### Gate A — deterministic guards only

No model runs.

Pass requires:

- route budget self-check passes;
- schema/skill/output tax guards pass;
- prompt shape guards pass;
- tiny exact not forced through Blitz when core cheaper.

### Gate B — focused telemetry

Bounded model runs.

Pass requires:

- Zai + OpenAI/Codex at minimum;
- tiny exact, same-file multi, config/doc, safety decline;
- Tokscale match;
- no hidden fallback;
- structural excluded unless testing advanced route separately.

### Gate C — advanced structural lock

Separate future gate.

Pass requires:

- explicit advanced structural route;
- provider-shape fixtures;
- strict formatting correctness;
- language matrix subset;
- token delta reported separately.

## Immediate next tickets

- architect route optimizer and target math;
- implement route selector policy as product behavior/harness guard;
- cut resident tax further only where measurable;
- design advanced structural profile instead of forcing it into minimal;
- run weighted telemetry only after code changes.
