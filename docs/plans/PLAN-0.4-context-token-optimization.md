# Blitz 0.4 — Context/Token Optimization to Replace Core Edit

Date: 2026-06-05
Status: finalized research + implementation plan; implementation not started
Primary objective: make Blitz save context-window and tokens across realistic Pi edit streaks, enough to become the default-cheaper path only where real Pi/tmux/Tokscale evidence beats Pi core `edit`.

## Non-negotiable framing

Blitz is **not core edit today**. 0.4 exists because Blitz needs to become core edit: the default-cheaper edit path agents can trust for normal Pi code changes, not a niche fallback for structural failures.

This is **not** a raw speed plan. It is a context-window and token-savings plan.

A Blitz edit is successful only if it reduces model-visible context/output/tool-call tokens or correctly routes away from Blitz when Pi core `edit` is cheaper. Wall time stays a secondary guardrail: keep Blitz fast or make it faster, but do not call speed the main win.

## Baseline from existing real Pi/Tokscale bench

Report: `reports/pi-pair-full-gpt54mini-2026-05-25.json`

- Provider/model: `openai-codex/gpt-5.4-mini`
- Runner: tmux
- Tokscale required
- Runs: 26
- Token accounting matched parser: 26/26
- Core-vs-Blitz pairs: 12

### What works today

Blitz gives massive savings when core would rewrite/fail structural edits.

| Fixture | Core output | Blitz output | Output saved | Core args | Blitz args | Arg saved | Correctness |
|---|---:|---:|---:|---:|---:|---:|---|
| `medium-10k/wrap-body` | 9,672 | 117 | 9,555 | 9,656 | 97 | 9,559 | core failed, Blitz correct |
| `multi/large-structural` | 9,773 | 134 | 9,639 | 9,755 | 115 | 9,640 | core failed, Blitz correct |

Router-selected aggregate vs wrong lane across 12 pairs:

- output tokens saved: 19,230
- edit-arg tokens saved: 19,277
- total Tokscale tokens saved: 31,878
- cost saved: $0.07598

### What fails the user's actual goal today

Blitz does **not** yet save everywhere.

Across 8 both-correct pairs:

- Blitz saved output/args in only 3/8.
- Blitz lost output/args in 5/8.
- Total Tokscale tokens were worse for Blitz in 8/8 both-correct pairs because input/cache/tool/skill overhead dominated.

Examples:

| Fixture | Core output | Blitz output | Core args | Blitz args | Result |
|---|---:|---:|---:|---:|---|
| `medium-10k/marker-tail` | 92 | 112 | 76 | 91 | Blitz worse |
| `semantic/arrow-replace-return` | 92 | 101 | 76 | 81 | Blitz worse on output/args |

Conclusion: the previous 0.3 work proved routing and structural wins. It did **not** prove Blitz can replace core. 0.4 must attack overhead so Blitz becomes cheaper on simple edits too, or routes core with explicit token proof.

## Local codebase findings

### `@codewithkenzo/pi-blitz` overhead

Companion repo: `/home/kenzo/dev/pi-blitz`

Measured roughly from current source:

- resident skill: `skills/pi-blitz/SKILL.md`
  - 9,741 chars
  - ~2,435 rough tokens by chars/4
  - 265 lines
- registered tools in `index.ts`: 15 total
  - `pi_blitz_read`
  - `pi_blitz_edit`
  - `pi_blitz_batch`
  - `pi_blitz_apply`
  - `pi_blitz_replace_body_span`
  - `pi_blitz_insert_body_span`
  - `pi_blitz_wrap_body`
  - `pi_blitz_compose_body`
  - `pi_blitz_multi_body`
  - `pi_blitz_patch`
  - `pi_blitz_try_catch`
  - `pi_blitz_replace_return`
  - `pi_blitz_rename`
  - `pi_blitz_undo`
  - `pi_blitz_doctor`
- rough source-size estimates for model-facing tool definitions in `src/tools.ts`:
  - `pi_blitz_apply`: ~741 rough tokens
  - `pi_blitz_edit`: ~680
  - `pi_blitz_batch`: ~581
  - narrow/semantic tools: ~250-415 each
  - full registered surface is several thousand schema/description tokens before runtime serialization overhead.
- existing benchmark Blitz lane narrows to 8 `pi_blitz_*` tools, but that is still too many for simple edits.

Diagnosis: simple-edit losses are mainly **resident tool/skill/schema/prompt tax**, not Zig runtime or edit-arg size.

### Blitz CLI strengths already present

Repo: `/home/kenzo/dev/blitz`

Existing useful pieces:

- deterministic ops in `src/apply/operations.zig`
  - `replace_unique`
  - `insert_after_anchor`
  - `insert_before_anchor`
  - `replace_between`
  - `append_section`
  - `ensure_line`
  - `delete_range`
  - `replace_body_span`
  - `wrap_body`
  - `set_key`
  - `patch` / `compact_patch`
- parser/query primitives
  - tree-sitter 0.26.9 bindings
  - query cursor wrappers for byte/point range, match limit, max start depth
  - daemon parser/query cache for current TypeScript `read_summary`
- benchmark harness
  - `bench/pi-matrix.ts`
  - Tokscale validation
  - edit arg token estimates
  - route/cost reporting

Main missing pieces:

1. Exact schema/skill/token-tax accounting.
2. A default minimal tool profile.
3. A single ultra-compact model-facing op tool.
4. A token-first router and benchmark report.
5. Real-world benchmarks that prove simple edits improve, not only structural cases.

## External research findings

### OpenAI APIs

Sources:

- OpenAI function calling guide: https://developers.openai.com/api/docs/guides/function-calling
- OpenAI tools guide: https://developers.openai.com/api/docs/guides/tools
- OpenAI apply_patch guide: https://developers.openai.com/api/docs/guides/tools-apply-patch
- GPT-5 tools/cfg/freeform examples: https://developers.openai.com/cookbook/examples/gpt-5/gpt-5_new_params_and_tools

Findings:

- Function/tool names, descriptions, and schemas are part of the model context. Large tool sets consume context.
- `tool_search` exists for `gpt-5.4+`: defer rarely used tools and load them only when needed.
- Custom/freeform tools can accept raw text payloads instead of JSON object wrapping. This can be better for compact edit DSLs.
- Custom tools can be constrained by CFG grammar. That enables a compact Blitz edit language like `rr(path,symbol,expr)` or tuple text without verbose JSON keys. CFG can add generation latency, so benchmark required.
- `apply_patch` is an OpenAI-native code-edit comparator for future broader studies. Current 0.4 Pi-default evidence does not require it; Pi core `edit` is the baseline/fallback.

Action for Blitz:

- Implement `pi_blitz_op` as either:
  - one JSON-schema tool with compact short keys, or
  - one freeform custom tool with a compact grammar if Pi/OpenAI path supports it.
- Add a `tool_search`/lazy profile path for `gpt-5.4+` models where available.
- Benchmark current default-readiness against Pi core `edit`; keep apply_patch-style patches as optional future comparators.

### Anthropic MCP/code-execution strategy

Source: https://www.anthropic.com/engineering/code-execution-with-mcp

Findings:

- Direct tool calls consume context for each tool definition and each result.
- Large MCP tool sets slow agents and increase costs because definitions are loaded up front.
- Anthropic recommends presenting tools as code/filesystem APIs or adding `search_tools` so models load definitions on demand.
- Example claim: a workflow can drop from 150,000 tokens to 2,000 tokens when tools/data are loaded and processed in code instead of passed through model context.
- Progressive disclosure: models can navigate filesystems and read only needed tool definitions.

Action for Blitz:

- Treat `pi-blitz` tool definitions as a discoverable catalog, not always-on tools.
- Add one resident discovery/execution tool or use Pi tool profiles so only relevant Blitz schema is visible.
- Keep intermediate results in tool runtime. Return compact summaries; never return whole diffs unless requested.

### Aider edit formats

Sources:

- https://aider.chat/docs/more/edit-formats.html
- https://aider.chat/docs/unified-diffs.html

Findings:

- Whole-file edit format is simple but slow/costly because the model returns the entire file.
- Diff/udiff formats are efficient because the model returns only changed parts.
- Unified diffs reduced lazy coding for GPT-4 Turbo by making outputs look like strict patch data.
- Aider emphasizes formats that are familiar, simple, high-level, and flexible to apply.

Action for Blitz:

- Keep familiar patch/diff fallback for models that hate compact DSL.
- But for Blitz-native path, avoid requiring old code/location text. Use AST symbol name + compact op.
- Add forgiving parser for compact op text, like Aider's flexible patch application, but keep mutation preconditions strict.

### FastEdit / AST-aware edit strategies

Source: https://github.com/parcadei/fastedit

Findings:

- FastEdit explicitly frames the waste: diffs/search-replace/apply_patch force the model to repeat old code to locate edits.
- FastEdit eliminates location tokens with tree-sitter symbol lookup by name.
- It reports deterministic text-matching handles 74% of real edits with zero model calls; complex cases use a ~35-line local merge model.
- It claims deterministic path: 100% accuracy, 0 tokens, <1ms; model path: ~40 tokens, <1s; combined average ~10 tokens, ~130ms.

Action for Blitz:

- Copy the strategic pattern, not the local ML dependency at first:
  1. AST target by symbol/name.
  2. Model emits only changed snippet plus optional `#...`/keep markers.
  3. Deterministic anchor/splice first.
  4. If ambiguous, fail closed or use local chunk-level merge later.
- Add an optional chunk-local merge phase only after deterministic wins are measured.

### TanStack AI / tool lazy discovery

Sources:

- https://tanstack.com/ai/latest/docs/tools/lazy-tool-discovery
- https://tanstack.com/blog/tanstack-ai-lazy-tool-discovery

Findings:

- Sending every tool definition wastes tokens and degrades tool choice.
- Lazy tools are withheld; model sees one discovery tool listing names.
- Model calls discovery for needed tools; full schema is injected only after discovery.
- Example framing: 30 tools can burn 3k-5k tokens before conversation starts; lazy discovery keeps prompt lean.

Action for Blitz:

- Add Pi-level lazy discovery if Pi supports dynamic tool registration per turn; otherwise approximate with profiles:
  - `blitz-min`: only `pi_blitz_op`
  - `blitz-struct`: body/compose/multi
  - `blitz-admin`: read/doctor/undo
  - `blitz-full`: current behavior for debugging/manual use.

### Zig and tree-sitter APIs

Sources:

- Zig 0.16 release notes: https://ziglang.org/download/0.16.0/release-notes.html
- Tree-sitter query API: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/4-api.html

Findings:

- Zig 0.16 production path should remain stable. `std.Io.Threaded` is the stable I/O lane. `--watch`, `-fincremental`, `--time-report`, and `--webui` are useful dev-loop features but not release proof.
- Locally, current `--watch/-fincremental/--time-report` probes failed; keep as dev-loop backlog.
- Tree-sitter QueryCursor supports byte ranges, point ranges, match limits, and max start depth. Blitz already exposed wrappers; next work is using them in product query ops.

Action for Blitz:

- Use Tree-sitter query limits to make symbol lookup/query targeting cheaper and bounded.
- Keep Zig 0.16 stable for release. Optimize via less parsing, warm process, and cached parsers/queries before chasing compiler dev features.

## Product target: replace core edit

To replace core, Blitz must cover these real use cases:

1. **Tiny exact edit**: one-line return/config/string replacement.
2. **Small insert**: add logging/import/check line near anchor.
3. **Symbol semantic edit**: replace return expression, wrap body, try/catch.
4. **Large structural edit**: avoid repeated old code/location tokens.
5. **Multi-edit same file**: one tool call, one parse, one write.
6. **Text/Markdown/config edit**: deterministic anchors and section/key ops.
7. **Fallback edit**: if Blitz cannot be cheaper/correct under the current 0.4 gate, it must choose Pi core `edit` and report why. apply_patch-style fallbacks are future comparisons, not current acceptance gates.

For each use case, Blitz must prove:

- correctness
- smaller output tokens or selected fallback
- smaller tool arg tokens or selected fallback
- smaller resident schema/skill tax or selected fallback
- no huge intermediate output returned to model

## Architecture recommendation

### One resident model-facing edit tool

Default resident tool should be one compact tool, not 15 tools.

Candidate:

```json
{
  "name": "pi_blitz_op",
  "description": "Compact code/text edit. Use short op tuples. Does not require old code for location.",
  "parameters": {
    "type": "object",
    "properties": {
      "f": { "type": "string" },
      "ops": { "type": "array" },
      "p": { "type": "boolean" }
    },
    "required": ["f", "ops"],
    "additionalProperties": false
  }
}
```

Compact op examples:

```json
{"f":"src/a.ts","ops":[["rr","formatStatus","status.toUpperCase()"]]}
{"f":"src/a.ts","ops":[["ia","loadUser","const cached = cache.get(id);","after"]]}
{"f":"src/a.ts","ops":[["wb","mediumCompute","\n  try {","  } catch (e) {\n    throw e;\n  }\n",2]]}
{"f":"README.md","ops":[["as","## Usage","\nNew paragraph.\n"]]}
```

Alias map:

- `rr` = replace return expression
- `rb` = replace body span
- `ib` = insert body span
- `wb` = wrap body
- `tc` = try/catch
- `ru` = replace unique text
- `ia` = insert after/before anchor
- `bt` = replace between anchors
- `as` = append section
- `ek` = ensure line
- `dk` = delete range
- `sk` = set key

Long-form tools stay available only in non-default profiles.

### Tool profiles

Implement real registration profiles in `pi-blitz/index.ts`; unused schemas must not be registered. `allowed_tools` is not enough if the full schema remains resident in the model context.

Target profiles after Phase 2:

| Profile | Tools | Use |
|---|---|---|
| `minimal` | `pi_blitz_op` only | default for agent editing |
| `semantic` | `pi_blitz_op`, maybe `pi_blitz_read` | symbol edits needing structure summary |
| `structural` | `pi_blitz_op`, `pi_blitz_read`, `pi_blitz_patch` | complex structural edits |
| `admin` | read/doctor/undo/rename | diagnostics/manual |
| `full` | current 15 tools | debugging/backcompat |

Phase 1 profile registration may ship before `pi_blitz_op` exists. In that case `minimal` is a temporary smallest-existing-useful profile and must be labeled in reports as `minimal-v0`; Phase 2 replaces or aliases it to `pi_blitz_op` before any core-replacement claim.

Configuration:

- env: `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full`
- CLI/bench override: `--tools` already exists in `bench/pi-matrix.ts`; extend matrix profiles.
- Pi extension should default to `minimal`.

### Skill compression

Resident `SKILL.md` target: <= 500 tokens.

Move long content to references:

- `references/routing.md`
- `references/op-aliases.md`
- `references/examples.md`
- `references/benchmarks.md`
- `references/admin.md`

Resident skill should only say:

1. Use `pi_blitz_op` for edits that can be expressed compactly.
2. Do not repeat unchanged code.
3. Use Pi core `edit` when compact op is longer than direct edit or unsupported.
4. For uncertainty, call route/explain or read structure, then edit.
5. Always verify.

### Tool output compression

Default success output should be tiny:

```text
ok f=src/a.ts op=rr changed=14 backup=abc123
```

Only include diff/metrics when requested:

- `d:1` / `include_diff: true`
- `m:1` / `include_metrics: true`
- failure always includes enough structured error to recover.

### Token-first router

Route decision must measure or estimate and report:

- resident tool schema tokens from Pi-serialized registered specs
- skill tokens from the exact resident skill text used by the run
- user prompt tokens
- expected arg tokens
- expected output tokens
- cache read/write tokens
- total model-visible context tokens

Runtime integration point must be explicit before core-replacement claims. The router cannot exist only as a benchmark report selector. It must live in one of: Pi extension facade, core-tool wrapper/alias, skill-level route contract with enforced profile selection, or a documented temporary benchmark-only boundary until Phase 6.

Route selection order:

1. no-op if already applied
2. compact deterministic Blitz op if shorter than Pi core `edit` and safe
3. direct text/core for tiny exact edits where core is cheaper
4. structural Blitz for body/multi/symbol edits
5. future patch/diff fallback for multi-file patches, outside current Pi core-baseline gate
6. fail closed if target ambiguity or savings uncertain and no fallback chosen


## 2026-06-10 goal tweak: streak-first Pi core baseline

Active objective is narrowed from broad core-replacement parity to evidence for a default-cheaper Pi edit path over realistic edit streaks. Durable interpretation:

- Baseline/fallback is Pi core `edit` only. Codex/OpenAI `apply_patch` is not a required gate for this objective.
- Primary metric is cumulative model-visible context across edit streaks: schema/skill, prompt/input/cache, tool args, model output, result payload, residuals, and total context.
- Representative single rows remain useful diagnostics, but 10+ tiny and 20+ mixed streak totals decide whether Blitz can be default-cheaper.
- Huge structural rows remain capability evidence; they do not prove default readiness by themselves.
- Benchmark-only route-selected core choices must be labeled as synthesis, not product-real `pi_blitz_route_edit` fallback.
- If true sequential same-session Pi streak execution is not implemented, reports must say so and use accepted real Pi/tmux/Tokscale row aggregation only as an honest approximation.

## Implementation phases

### Phase 0 — Measurement harness for schema/skill/context tax

Deliverables:

- Extend `bench/pi-matrix.ts` to record:
  - visible tool names
  - Pi-serialized registered tool specs per profile
  - exact token count for serialized registered tool specs, using the same tokenizer/model family selected for the run when available
  - exact resident skill text snapshot used by the run
  - exact token count for resident skill text, using the same tokenizer/model family selected for the run when available
  - prompt tokens
  - tool arg tokens
  - model output tokens
  - input/cache tokens from Tokscale
  - residual analysis reconciling local schema/skill/prompt counts with provider/Tokscale input/cache totals
  - selected route/tool profile
- Preserve raw accounting artifacts under `reports/` or a linked run artifact directory:
  - `tool-specs.<profile>.json`
  - `skill.<profile>.md`
  - tokenizer/model metadata
  - Tokscale/session JSON
- Add profile variants to bench:
  - core
  - current Blitz full/narrow
  - Phase 1 minimal-v0/semantic/structural profiles
- Add report table: `schemaTokens`, `skillTokens`, `promptTokens`, `argTokens`, `outputTokens`, `cacheRead`, `cacheWrite`, `residualInputTokens`, `totalContextTokens`.

Do not use chars/4 or rough source-size estimates for acceptance. Rough estimates are allowed only in exploratory notes that are clearly excluded from savings claims.

Acceptance:

- Re-run existing 12 pairs.
- Report explains exactly why each current simple Blitz row loses.
- Raw serialized schema/skill artifacts exist for every profile claim.
- Token counts name tokenizer/model and reconcile with Tokscale/provider input/cache totals, including residuals.

### Phase 1 — Tool profile registration

Deliverables in `/home/kenzo/dev/pi-blitz`:

- Add `PI_BLITZ_TOOL_PROFILE`.
- Register only profile-selected tools.
- Add tests proving each profile registers expected tools.
- Keep `full` for backcompat.

Acceptance:

- `minimal-v0` or `minimal` exposes <= 2 tools.
- Unused profile tools are not registered and their schemas are absent from serialized tool-spec artifacts.
- Resident schema tokens, counted from serialized registered specs, are reduced >=70% vs current full registration.
- No claim is made that Phase 1 is an optimized replacement path until Phase 2/6 prove it.

### Phase 2 — Zig-native compact apply IR v1

Current 2026-06-10 direction: build the compact edit engine inside `/home/kenzo/dev/blitz` first by extending the existing `blitz apply --edit - --json` path. Do **not** start this phase in `/home/kenzo/dev/pi-blitz`, do not create a new CLI command surface like `blitz edit-ir apply`, and do not treat wrapper/profile trimming as the main implementation slice. Pi core `edit` remains the required baseline/fallback.

Deliverables in this repo:

- Extend existing apply IR parsing to accept compact JSON object form and tuple form while preserving verbose IR compatibility.
- Support initial compact op set:
  - `rb` / `replace_body` / `set_body`: replace resolved symbol body with new snippet only.
  - `ia` / `insert_after_symbol`: insert snippet after resolved symbol/node.
  - optional `mn` / `merge_body_chunk`: FastEdit-style keep-marker body merge using existing splice machinery.
  - optional same-file `ops` batch: one file, one parse/plan/write, deterministic rebasing after earlier edits.
- Implement minimum target object: `{"k":"function|method|class|object|section|any","n":"name","p":"optional parent","occ":0,"range":"body|node"}`.
- Resolve targets by clean parse, kind/name filter, optional parent/ancestor filter, deterministic occurrence, then body/node range. Zero matches and ambiguous matches without disambiguation must fail closed.
- Keep mutation safety: parse compact IR, validate path/guards, parse source cleanly unless explicitly opted out, compute all replacements in memory, parse-after validate merged file, and write only after all same-file ops plan successfully.
- Add compact success output mode after correctness: tiny `ok`/ranges/parse status by default for compact requests; verbose JSON remains available when requested.

Acceptance before benchmark claims:

- Compact object parses into canonical operation.
- Tuple aliases parse for `rb`, `ia`, and `mn` if implemented.
- Unknown aliases fail compactly.
- Duplicate symbol without occurrence/parent fails closed; occurrence and/or parent disambiguates deterministically.
- `rb` replaces body without old-code echo in the tool payload.
- `ia` inserts after symbol and preserves indentation/newline.
- Same-file batch rebases later operation ranges after earlier edit if batch is implemented.
- Parse-failing snippet/source and guard/hash/range mismatch cause no write.
- `zig build`, `zig build test`, and focused compact fixture CLI commands pass.

### Phase 3 — Skill compression and lazy docs

Deliverables:

- Resident `SKILL.md` <= 500 tokens.
- Move long docs/examples to references.
- Add benchmark mode with:
  - current full skill
  - compressed skill
  - no skill

Acceptance:

- Input/cache tokens drop without correctness regression.
- Skill no longer erases simple-edit savings.

### Phase 4 — Streaming/freeform/custom tool exploration

Deliverables:

- Prototype one of:
  - OpenAI custom/freeform Blitz DSL tool (if Pi/OpenAI path supports it), or
  - grammar-constrained compact op text, or
  - plain string `script` field inside `pi_blitz_op`.
- Compare to JSON schema tool.
- Study whether streaming parser can apply op as it arrives, like OpenAI apply_patch streaming.

Acceptance:

- Freeform/grammar path must reduce args/schema/output tokens or be rejected.
- No correctness regression.

### Phase 5 — Deterministic chunk-local merge

Goal: make Blitz useful when exact deterministic op is too limited but full core edit would repeat too much code.

Deliverables:

- AST-scope target to ~35-60 line chunk.
- Model emits changed snippet with keep markers, e.g. `#...` / `//...`.
- Blitz tries deterministic anchor classification/splice first.
- If ambiguous: fail closed initially; optional local merge model later.

Acceptance:

- Handles real small edits without repeating old code.
- Beats core on output+arg tokens for previously losing semantic/simple rows.

### Phase 6 — Token-first router and reports

Deliverables:

- Rename/report route contract away from speed-first:
  - `contextSavingsPct`
  - `schemaTokensExpected`
  - `argTokensExpected`
  - `outputTokensExpected`
  - `fallbackContextTokensExpected`
- Define and implement the runtime integration point, not just benchmark-side route selection. Acceptable locations:
  - Pi extension facade that picks profile/tool before model call,
  - core-tool wrapper/alias that makes Blitz the familiar default edit path,
  - skill-level route contract plus enforced profile selection,
  - or explicit documented boundary that routing is benchmark-only until a named follow-up phase.
- Router chooses Pi core `edit` if Blitz cannot beat token/context threshold.
- Reports put token/context first; wall time second.

Acceptance:

- Every selected Blitz row has token/context justification.
- Every non-selected Blitz row reports why Pi core `edit` was cheaper.

### Phase 7 — Real-world replacement benchmark

Benchmark set:

- one-line return expression
- tiny exact text replace
- small config key
- insert logging line
- wrap function body
- replace long function body section
- multi-hunk same-file edit
- rename within file
- Markdown section append
- TSX component prop/body tweak
- JSON/YAML/TOML top-level key update
- HTML/CSS small edit

For each case:

- core edit
- current Blitz full/narrow
- optimized Blitz minimal/op
- token-first router-selected path

Required metrics:

- correctness
- output tokens
- tool arg tokens
- schema tokens estimate
- skill tokens estimate
- prompt tokens
- input/cache Tokscale
- total context+output tokens
- wall time
- route/tool profile

Acceptance:

- Optimized Blitz improves over current Blitz on simple both-correct rows.
- Router-selected path is best or within 5-10% of best for every case.
- No selected route exceeds core context tokens by >10% unless core fails correctness.
- Structural rows preserve ~9k token savings.


## Research addendum from parallel researchers

Additional source-backed requirements from `.pi/research/20260605-tool-schema-context-tax.md` and `.pi/research/20260605-token-efficient-edit-repos.md`:

1. **Provider-native lazy loading where available.** OpenAI `tool_search` supports `defer_loading: true` for functions/MCP on `gpt-5.4+`; model sees namespace/server summary first, then loads needed schemas. OpenAI recommends fewer than 20 initial functions and fewer than 10 functions per namespace. Blitz should model edit capability as a deferred namespace/MCP server where possible.
2. **Use custom/freeform tools for edit DSL experiments.** OpenAI custom tools accept raw string inputs and optional grammar constraints. This is a strong candidate for `pi_blitz_op` because compact edit scripts avoid JSON-key overhead. Benchmark CFG/freeform latency before adoption.
3. **Cache-friendly stable prefix.** Prompt caching requires exact stable prefixes; changing tool lists can break locality. Prefer one stable resident discovery/execution facade plus on-demand schema loading, or stable small profiles, over ad-hoc large changing tool sets.
4. **Generic MCP clients still eagerly expose schemas.** MCP `tools/list` includes full `inputSchema`. Do not assume lazy schemas unless provider/client explicitly supports it. For generic Pi/MCP, use a compressor facade: `list_tools`, `get_tool_schema`, `invoke_tool`, or a single `pi_blitz_op`.
5. **Anthropic advanced tool-use validates same architecture.** Anthropic reports 58 tools ≈55K tokens and observed 134K tokens before optimization; Tool Search can load a ~500-token search tool plus 3-5 relevant tools (~3K tokens), and programmatic tool calling keeps intermediate results out of context. Blitz should expose code-callable APIs and keep edit/search intermediates in the runtime.
6. **CEDARScript proves compact command IR can beat diff/whole on refactors.** Reported Aider integration showed received-token reductions up to 96% and duration reductions up to 93% in some Gemini Flash refactor tests, but model sensitivity is real. Blitz should borrow high-level command IR, not claim universal CEDARScript wins without Pi/Tokscale proof.
7. **FastEdit proves target-name editing is the right north star.** FastEdit frames location tokens as waste, uses tree-sitter symbol lookup, reports 74% deterministic real edits with zero model calls, and uses chunk-local merge for hard cases. Blitz should implement deterministic chunk-local merge before any local model fallback.
8. **AFT-style host-tool replacement matters.** To truly replace core, Blitz should intercept/wrap existing edit pathways or expose a familiar minimal tool name, so agents do not need to choose an optional niche tool. Token savings must become default behavior.
9. **Morph/apply models are fallback baselines.** Morph Fast Apply and OpenAI `apply_patch` are the right competitors for non-deterministic edits. Blitz should benchmark against core edit **and** apply_patch/Morph-style chunk merge, not only against core.
10. **Streaming parser is a real optimization path.** Codex has a streaming apply_patch parser. Blitz compact IR should be stream-parseable so invalid ops fail early and UI can show progress while tool payload streams.

Plan impact: Phase 0 must measure schema/skill/prompt tax exactly; Phase 1 must implement profile registration without assuming `pi_blitz_op`; Phase 2 must evaluate both compact JSON and freeform DSL; Phase 5 must include deterministic chunk-local merge; Phase 6 must define runtime route integration; Phase 7 current gate must include Pi core `edit` baselines; apply_patch/Morph/CEDARScript-style baselines are future optional comparisons, not required for default-cheaper Pi evidence.

## Cross-repo execution contract

Blitz 0.4 spans two repositories:

- `/home/kenzo/dev/blitz`: CLI, Zig operations, bench harness, reports, durable specs.
- `/home/kenzo/dev/pi-blitz`: Pi tool registration, model-facing schemas, resident skill text, profile selection, runtime route/facade behavior.

For companion `pi-blitz` work:

- branch: `feat/blitz-0.4-token-core-profile`
- allowed scope: tool registration/profile code, schema serialization/debug dump utilities, resident skill text, package tests, benchmark integration needed to select installed/local profile
- forbidden scope: unrelated UI, unrelated MCP behavior, broad refactors, unmeasured skill rewrites
- required preflight: read local `AGENTS.md`, `package.json`, tool registration code, skill text, and current benchmark integration before edits
- required checks: run repo-owned typecheck/test/build commands discovered from `package.json`; if absent, record absence and run smallest meaningful Bun/TS syntax check
- package/install path: benchmark reports must state whether they used local source, linked package, `npm install -g .`, or published package
- handoff: final status must list both Blitz and pi-blitz branches/commits/checks when both repos are touched

## Definition of done

Blitz can be considered a candidate core replacement only when real Pi/tmux/Tokscale reports prove:

1. Current simple-edit losses are fixed by optimized Blitz or routed to Pi core `edit` with explicit token proof.
2. Tool/skill resident context overhead is reduced >=70% for common lanes.
3. Structural edits preserve large savings (~9k tokens per current representative case).
4. Reports prove token/context savings first and speed second.
5. No hidden failed rows, no correctness regressions, no unmeasured savings claims.

## Goal handoff

Use `docs/plans/START-0.4-context-token-core.md` as the next goal/new-chat start prompt. It is the operational contract for turning this plan into implementation: required readings, first slice, acceptance gates, builder routing, branch name, and output artifacts.

## Immediate next tasks

First slice only:

1. Implement Phase 0 measurement breakdown, including exact serialized schema/skill/prompt accounting, profile-visible tool list, raw artifact preservation, tokenizer metadata, and Tokscale residual reconciliation.
2. Implement `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` in `pi-blitz`; unused schemas must not register. If `pi_blitz_op` does not exist yet, label the smallest existing useful profile as `minimal-v0` in reports.
3. Re-run the existing 12-pair matrix against core, current Blitz full/narrow, and Phase 1 profile variants. Do not claim optimized replacement or router-selected savings yet.

After first-slice evidence:

4. Add `pi_blitz_op` compact alias tool; benchmark JSON short-key vs freeform DSL if runtime supports custom tools.
5. Compress resident skill to <=500 tokens and move examples to references.
6. Add deterministic chunk-local merge spike for symbol-scoped snippets with keep markers.
7. Define runtime router integration point, not benchmark-only routing.
8. Re-run 12-pair matrix plus realistic edit-streak set against Pi core `edit`, current Blitz, optimized Blitz, and route-selected evidence.
