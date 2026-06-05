# Blitz 0.4 — Context and Token Optimization Plan

Date: 2026-06-05
Status: planning record; implementation not started
Source baseline: `reports/pi-pair-full-gpt54mini-2026-05-25.json`, `reports/pi-lane-g-glm-arrow-20260525-123212.json`, `@codewithkenzo/pi-blitz` source at `/home/kenzo/dev/pi-blitz`

## Objective

Make Blitz save context-window and tokens as broadly as possible in real agent usage.

This is not a raw speed plan. Speed matters only when it helps agent throughput. Primary success metric is fewer model-visible tokens and less context pollution while preserving correctness.

## Baseline from 26-run GPT matrix

Report: `reports/pi-pair-full-gpt54mini-2026-05-25.json`

- Provider/model: `openai-codex/gpt-5.4-mini`
- Runner: tmux
- Tokscale required
- Runs: 26
- Token accounting matched parser: 26/26
- Core-vs-Blitz pairs: 12

### Current wins

Blitz works when core would rewrite or fail structural edits.

| Fixture | Core output | Blitz output | Output saved | Core args | Blitz args | Arg saved | Correctness |
|---|---:|---:|---:|---:|---:|---:|---|
| `medium-10k/wrap-body` | 9,672 | 117 | 9,555 | 9,656 | 97 | 9,559 | core failed, Blitz correct |
| `multi/large-structural` | 9,773 | 134 | 9,639 | 9,755 | 115 | 9,640 | core failed, Blitz correct |

### Current losses

Blitz does not yet save everywhere.

Across 8 both-correct pairs:

- Blitz saved output/args in only 3/8.
- Blitz lost output/args in 5/8.
- Total Tokscale tokens were worse for Blitz in 8/8 both-correct pairs because input/cache/tool overhead dominated.

Example:

| Fixture | Core output | Blitz output | Core args | Blitz args | Result |
|---|---:|---:|---:|---:|---|
| `medium-10k/marker-tail` | 92 | 112 | 76 | 91 | Blitz worse |
| `semantic/arrow-replace-return` | 92 | 101 | 76 | 81 | Blitz worse on output/args |

### Router-selected aggregate

Using current recommended lane per pair instead of the other lane saved across 12 pairs:

- Output tokens saved: 19,230
- Edit-arg tokens saved: 19,277
- Total Tokscale tokens saved: 31,878
- Cost saved: $0.07598

This proves routing avoids catastrophic losses, but it does not prove Blitz is optimized everywhere.

## Root-cause hypothesis

Blitz narrow op argument payloads are already small enough in many cases:

- `replace_return`: roughly 70-100 arg tokens
- `wrap_body`: roughly 90-120 arg tokens for known wrappers
- structural large-body savings: ~9.5k output/arg tokens per edit

The broad-loss problem is not primarily Zig execution. It is likely:

1. **Tool schema/context tax**: `pi-blitz` registers 14 tools, each with TypeBox schemas and descriptions. Even the benchmark's narrow Blitz lane exposes 8 `pi_blitz_*` structured tools.
2. **Skill/prompt tax**: `skills/pi-blitz/SKILL.md` is ~9,741 chars / ~2.4k rough tokens and tells the model many cases/routes.
3. **Input/cache overhead**: both-correct Blitz rows often have higher input/cache totals despite smaller edit args.
4. **Too many near-duplicate tools**: `pi_blitz_apply`, `pi_blitz_patch`, `pi_blitz_replace_body_span`, `pi_blitz_insert_body_span`, `pi_blitz_wrap_body`, `pi_blitz_compose_body`, `pi_blitz_multi_body`, `pi_blitz_try_catch`, `pi_blitz_replace_return`, etc. compete in context.
5. **No per-edit tool gating**: the model sees tools it cannot need for a given edit. External research agrees dynamic tool gating / lazy schema loading is the main fix for tool-schema context tax.

## External research notes

- OpenAI function-calling docs emphasize that function descriptions and schemas are part of request context and should be concise.
- OpenAI function calling docs mention tool search / deferred tool loading for many tools on newer models.
- Tool-gating research and OSS projects (`tool-attention`, ATR-style routers) target the same problem: avoid injecting every full schema every turn. Reported reductions are large in tool-heavy catalogs, but Blitz must measure on real Pi sessions before claiming numbers.

## Success criteria

Primary criteria:

1. On both-correct simple rows, Blitz must be no worse than core on model-visible context by threshold:
   - output tokens <= core + 5%
   - edit-arg tokens <= core + 5%
   - total Tokscale tokens <= core + 10% or router must choose core
2. On structural rows, preserve existing huge savings:
   - keep ~9k+ output/arg token savings on large body/wrap cases
   - preserve correctness when core fails
3. Reduce always-present `pi-blitz` tool/skill overhead:
   - measure current schema + skill token footprint
   - reduce resident tool schema/context by at least 70% in the common simple-edit lane
4. Real-world benchmark must use Pi/tmux/Tokscale, not synthetic-only numbers.

Secondary criteria:

- No loss of safety: deterministic preconditions, workspace checks, no mutation without exact target.
- No misleading report rows: correctness and route choice must remain explicit.

## Implementation plan

### Phase 0 — Measurement harness for actual context tax

Owner: `d5` for scripts, reviewer for report.

Deliverables:

- Add a benchmark mode that records:
  - tool schemas exposed per run
  - serialized tool schema token estimate
  - skill prompt token estimate
  - user prompt tokens
  - model input/output/cache tokens from Tokscale
  - edit-arg tokens
  - selected tool name
- Add a report section separating:
  - `tool_schema_tokens`
  - `skill_tokens`
  - `user_prompt_tokens`
  - `tool_arg_tokens`
  - `model_output_tokens`
  - `cache_read/write_tokens`

Why: current reports show input/cache overhead, but not which part is tool schema vs skill vs prompt.

Acceptance:

- Re-run the 12-pair GPT matrix with schema/skill breakdown.
- Produce a table showing exactly why Blitz loses simple both-correct rows.

### Phase 1 — Tool-surface minimization

Owner: `d5` in `/home/kenzo/dev/pi-blitz`.

Current problem:

`index.ts` registers all tools by default:

- read/edit/batch/apply
- replace body span
- insert body span
- wrap body
- compose body
- multi body
- patch
- try catch
- replace return
- rename
- undo
- doctor

Plan:

1. Add configurable tool profiles:
   - `minimal`: only one compact edit tool + doctor optional
   - `semantic`: `replace_return`, `try_catch`, `wrap_body`
   - `structural`: body span / compose / multi
   - `admin`: read/doctor/undo/rename
   - `full`: current behavior
2. Let benchmark and runtime select profile per task.
3. Default to `minimal` or `semantic`, not `full`.
4. Ensure unused tools are not registered, not merely ignored.

Expected win:

Cuts model-visible schema tax for simple edits by removing 8-13 unused tools.

Acceptance:

- Token report proves resident tool schema tokens fall by >=70% for simple edit lane.
- Simple `replace_return` benchmark improves total Tokscale tokens vs current Blitz.

### Phase 2 — One ultra-compact op tool

Owner: `d5` in `/home/kenzo/dev/pi-blitz`, maybe Blitz CLI if needed.

Current problem:

Even narrow tools still have verbose field names and multiple schemas. `pi_blitz_patch` is close but still exposed alongside many tools.

Plan:

1. Add `pi_blitz_op` or replace default with `pi_blitz_patch`-only profile.
2. Use compact tuple or short-key IR:

```json
{"f":"src/a.ts","op":[["rr","fn","expr","only"]]}
```

Candidate aliases:

- `rr` = replace return
- `rb` = replace body span
- `ib` = insert body span
- `wb` = wrap body
- `tc` = try/catch
- `mb` = multi body

3. Keep long-form API for human/manual use, but hide it from default model context.
4. Tool output should be compact by default:
   - success: `ok file changedBytes backupId?`
   - no large diff unless requested
   - no verbose diagnostics unless failure

Expected win:

- Lower arg tokens for simple semantic edits.
- Lower schema tokens by consolidating ops into one schema.

Acceptance:

- `replace_return` args fall below current 76-98 token range where possible.
- Both-correct simple Blitz rows become <= core output+arg tokens or route core.

### Phase 3 — Skill compression and lazy guidance

Owner: `d5`/docs in `/home/kenzo/dev/pi-blitz`.

Current problem:

`skills/pi-blitz/SKILL.md` is ~9,741 chars / ~2.4k rough tokens. It contains install docs, tool table, routing guidance, examples, undo discipline, etc. That is too much to keep resident for every simple edit.

Plan:

1. Split skill into:
   - short resident `SKILL.md` <= 500 tokens
   - `references/full-routing.md`
   - `references/examples.md`
   - `references/benchmarks.md`
2. Resident skill should say only:
   - use minimal profile
   - choose core for tiny/simple unless `pi_blitz_op` args are smaller
   - use compact op aliases
   - never repeat unchanged code
3. Benchmark both:
   - full current skill
   - compressed skill
   - no skill + tool descriptions only

Expected win:

Reduce static prompt/context tax by ~1.5k-2k tokens when skill is loaded.

Acceptance:

- Resident skill <= 500 tokens by tokenizer estimate.
- Matrix shows lower input/cache tokens without correctness regression.

### Phase 4 — Prompt rewrite for model behavior

Owner: benchmark skill + `d5`.

Current benchmark prompts sometimes still include lengthy exact JSON instruction strings for difficult tools. That may be necessary for correctness, but it pollutes measurement.

Plan:

1. Create concise prompts for compact op tool:

```text
Edit file X. Use pi_blitz_op once. Args: {"f":"X","op":[["rr","symbol","expr"]]}.
```

2. Keep a separate “human-natural” prompt set for real-world discoverability.
3. Benchmark both prompt modes:
   - copied args mode
   - natural instruction mode
4. Measure if compact tool descriptions are enough for natural usage without huge prompt hints.

Acceptance:

- Copied-args mode proves theoretical floor.
- Natural mode proves real-world usability.
- Reports separate those two claims.

### Phase 5 — Router becomes token-first, not speed-first

Owner: `d5` in Blitz + pi-blitz.

Plan:

1. Change route decision report fields and docs from “faster” to:
   - `contextTokensExpected`
   - `argTokensExpected`
   - `outputTokensExpected`
   - `schemaTokensExpected`
   - `contextSavingsPct`
2. Router should choose Blitz only when:
   - correctness risk acceptable
   - expected context+output+arg tokens beat fallback
3. Add simple-row guardrails:
   - core if file/edit tiny and compact Blitz not strictly cheaper
   - Blitz only if op alias avoids repeating code or core would likely emit large span

Acceptance:

- Re-run matrix; every selected Blitz row must be token/context justified.
- Reports label token wins/losses before wall time.

### Phase 6 — Real-world usage benchmark

Owner: benchmark skill + reviewer.

The 26-run matrix is useful but too fixture-shaped. Add a real-world benchmark set from actual agent edits:

- one-line return expression
- small config key
- insert logging line
- wrap function body
- replace long function body section
- multi-hunk body edit
- rename within file
- Markdown section append
- TSX component prop/body tweak

For each case:

- core edit
- current Blitz full tool surface
- optimized Blitz minimal/op profile
- router-selected path

Metrics:

- correctness
- output tokens
- tool arg tokens
- input/cache/tool schema tokens
- total Tokscale tokens
- context saved/lost

Acceptance:

- Optimized Blitz improves over current Blitz on simple both-correct rows.
- Router-selected path is best or within 5-10% of best for each case.
- No selected route exceeds core context tokens by >10% unless core fails correctness.

## Priority order

1. Measurement breakdown (must know schema/skill tax exactly).
2. Tool profile gating (largest likely win).
3. Single compact op tool / alias IR.
4. Skill compression.
5. Prompt rewrite.
6. Token-first router + real-world benchmark.

## Risks

| Risk | Mitigation |
|---|---|
| Compact aliases hurt model correctness | Keep copied-args benchmark and natural prompt benchmark separate; add examples only in lazy docs. |
| Hiding tools reduces discoverability | Use profile selection/router before model call; default minimal, expand only when needed. |
| Token wins come only from benchmark prompts | Add natural real-world benchmark suite. |
| Tool schema token counting inaccurate | Compare tokenizer estimates against Tokscale input/cache deltas and record both. |
| Over-optimizing names harms human API | Keep long-form API hidden from default model context; expose compact model-facing API separately. |

## Definition of done

This plan is done only when an optimized Blitz path proves one of these outcomes on real Pi/Tokscale runs:

1. For simple both-correct rows: optimized Blitz total context+output+arg tokens <= core within configured threshold; or router chooses core and reports why.
2. For structural rows: optimized Blitz preserves existing ~9k token savings and correctness wins.
3. Tool/skill resident context overhead is measured and reduced by >=70% in common lanes.
4. Reports present token/context savings first, wall time second.
