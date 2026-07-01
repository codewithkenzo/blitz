# Research: Provider-wide tool-call behavior and fallback policy for universal `pi-blitz` routing

## Question
Create a provider-wide behavior matrix for using `pi-blitz`/Blitz as default edit route across OpenAI, Anthropic, Gemini, Z.ai, and xAI, with focus on:
- tool schema shape + strictness
- tool-call/response shape and IDs
- retry/error semantics
- usage/cache accounting
- rate limits and practical compatibility traps
- fallback acceptance logic for universal route safety

## Answer / Recommendation
**Do not treat tool semantics as model-agnostic.** Universal routing should be provider-aware at both schema-build and runtime levels.

For current implementation evidence, OpenAI and Z.AI remain the highest-risk: **OpenAI tuple-array schema incompatibility** is a proven blocker for `tool_choice`/schema compatibility, while **Z.AI `tool_choice` is effectively `auto`-only** and limits strict forcing strategies. 

**Recommended rule-of-thumb for production universal routing (2026-06-19):**
1. Normalize tool schemas to provider-stable array-of-object function tools (no per-call tuple tricking).
2. Require provider-specific validation gates before route execution (schema, supported `tool_choice`, expected response IDs).
3. Route fallback must be explicit: `blitz_declined` on unsupported tool contract, `core_fallback` on ambiguity/no-op/safety, never silent mutation.
4. Record both provider-level tool-call intent and success metrics: attempted calls, completed calls, and token/cache deltas.

## Findings

### A. Tool schema and selection behavior

| Provider | Contract evidence | Risk | Operational impact |
|---|---|---|---|
| OpenAI / OpenAI-compatible (`pi-blitz` providers) | Function tools use `type: function` + JSON schema in `tools`; strict mode available and requires `additionalProperties: false` + required fields in strict mode. Tool search/defer loading exists (`tool_search`, namespaces, `defer_loading`). Tool choice supports `auto/required/none/function/...` and `allowed_tools` for subset dispatch. | **High** (known mismatch) | Use homogeneous array item schema (not tuple-item). Add schema canonicalization + strict-mode-safe payload. |
| xAI | Tool schema requires `name/description/parameters` and parameter root must be object; root not scalar/array or request 400. Supports `auto/required/none` and specific forced tool object, plus parallel tool calls via `parallel_tool_calls`/`parallel_tool_calls:false`. | Medium | Keep conservative schema validator; reject/normalize unsupported tool schema before call. |
| Anthropic | Supports client and server tools; tool use loop anchored to `tool_use` blocks + `tool_result` blocks; strict mode exists for structured tool handling. `tool_choice` controls whether tooling is forced/optional/required per API semantics. | Medium | Build explicit `tool_use`/`tool_result` formatting check and ordering guarantees. |
| Gemini | OpenAI-compatible mode + native function declaration mode; function calls represented as `functionCall` with stable IDs, and `toolResponse` must reference ID when returning execution result. Mixed `functionCall` + `toolCall` + `toolResponse` can happen in one turn. | Medium | Runtime parser must handle mixed parts and never assume function call last. |
| Z.AI | Tool-calling supports `tool_calls` with `function.name`, `function.arguments`, and `id`; `tool_choice` documented as default/only `auto` (i.e., no forced specific tool strategy). | **High** | Do not attempt strict/forced-tool routing; route must adapt to auto-only control plane. |

### B. Tool-call + output formatting + retry/error semantics

| Provider | Output shape | Retry/error signal | Route implications |
|---|---|---|---|
| OpenAI | `response.output` includes `function_call` items with `call_id`, `id`, `name`, `arguments`; streaming exposes per-call argument deltas; fine-grained retries can re-send `function_call_output` by `call_id`. | Schema/validation errors surface through response status; fine-grained status/error handling available through SDK-level call flow; fine-tuning can disable strict mode explicitly. | Track completed call outputs, not just attempt list; enforce `tool_calls`-to-`function_call_output` mapping integrity. |
| Anthropic | Model issues `tool_use` blocks (`id`, `name`, `input`) and loops until `stop_reason != tool_use`; tool results require adjacency constraints (`tool_result` first in same turn, must include `tool_use_id`, optional `is_error`). | Explicit `is_error` in tool results; malformed tool_result ordering can lead to loop termination/incorrect parse. | Fuzz ordering and run strict validation of tool-result placement before continue. |
| xAI | `tool_calls` list tracks requested tool usage; docs distinguish `server_side_tool_usage`/`server_side_tool_usage_details` in usage accounting (attempts vs server-side actuals). Streaming can be whole-call-at-once for function calls in SDK examples. | Tool-loop is still two-way when custom tools involved; server-side calls may succeed/fail independently and are billed/recorded separately. | Log both attempted and server-side completed counts; avoid counting raw `tool_calls` as guaranteed edit execution. |
| Z.AI | Tool handling is standard `tool_calls` + `tool_call.id`; examples return function args and then call back via `tool` role with `tool_call_id`. Streaming mode exists via `tool_stream=True`. | Standard tool-loop errors must be propagated as tool result content; no documented forced `tool_choice` reduces error containment options when precision needed. | For non-trivial constraints, require pre-validation in prompt not tool-force mode. |
| Gemini | Requires returning executed results via `functionResponse` with matching `id`; function calls may interleave with other tool parts in a turn (`toolCall/toolResponse/functionCall`). | Mixed-part turns can break simplistic parsers; unknown or malformed part order should fail closed into safe fallback. | Parser must handle heterogeneous part arrays and preserve IDs across both custom and built-in tool flows. |

### C. Context/cache and usage accounting

| Provider | Cache mechanics | Token accounting fields | Notable cautions |
|---|---|---|---|
| OpenAI | Prompt cache on exact prefix; first ~256-token routing hash + optional `prompt_cache_key`; 1024-token minimum for cache eligibility. In-memory/24h retention model options. Tools and structured output schema are cache-relevant prefixes. | `usage.prompt_tokens_details.cached_tokens` and prompt cache fields in response object. | Cache invalidation risks from tool surface/token churn; keep schema stable; maintain tool list/order stability across turns. |
| Anthropic | Explicit + automatic prompt caching; 20-block lookback and hierarchy (`tools` → `system` → `messages`); cache control points must be stable and not changing each turn for hitability. | `cache_creation_input_tokens`, `cache_read_input_tokens`, `input_tokens` in response. | Cache breakpoints consume only designated blocks; changing tool definitions invalidates all downstream cache. |
| Gemini | Implicit caching on 2.5+ (tool/model-specific min threshold) plus explicit caching API. Cached content is prefix-like; usage metadata returns cache hits. | Implicit path and explicit `usage_metadata` (cache hit indicators); cached tokens included in usage semantics. | Cache does not guarantee cost savings always; TTL and duration controls differ by model and cache type. |
| xAI | Usage includes `num_server_side_tools_used`, `server_side_tool_usage_details`; cached token behavior appears aligned with standard token usage fields. | `input_tokens`, `input_tokens_details.cached_tokens`, server-side tool counts in `usage` object sample fields. | Treat cached-token savings carefully: tool calls may be attempted without successful side effects. |
| Z.AI | Public caching guidance not found in current retrieved docs. | `usage` exists via OpenAI-compatible responses, but dedicated cache semantics not retrieved in gathered sources. | Treat as **undocumented** in current evidence; avoid assuming cache behavior without explicit source. |

### D. Rate limits / model constraints

| Provider | Rate/capacity evidence | Key constraints for universal testing |
|---|---|---|
| OpenAI | Prompt cache 1024+ tokens; no explicit hard provider limits in retrieved docs (model routing & quota outside these docs). Tool search from gpt-5.4+ only. | Use model-gated tool-search behavior and ensure no hardcoded universal assumptions for older models. |
| Anthropic | Caching model minimum token thresholds vary by model/version/platform; explicit 5m/1h TTL options and cache lookback rules. | Include model/version in route matrix and separate test baselines by model tier. |
| Gemini | RPM/TPM/RPD by model and tier; per-model free-tier caps and experimental behavior details. | Use tier-aware benchmark scheduling; avoid hardcoding single rate budget per project. |
| xAI | Tiered RPM/TPM with upgrade thresholds `$0/$50/$250/$1000/$5000` and per-model table per tier. | Keep per-model + tier aware retry budgets; enforce 429 backoff. |
| Z.AI | No reliable public rate-capability in retrieved snippets. | Use provider/client quotas and short timeouts as hard evidence is missing in current fetch set. |

### E. High-confidence repo evidence synthesis

- `NATURAL-ZAI-PROVIDER-MATRIX-RERUN-20260612.md`: Z.AI rerun completed natural route 25 scenarios, `35/50` correct/accepted, with failures across import/doc safety/no-op/ambiguity classes and missing tokscale matches in some structural rows. (Strong evidence that raw universal claim is not yet met.)
- `UNIVERSAL-BLITZ-BLIND-SPOT-AUDIT-20260611.md`: identifies route-system and fallback accounting gaps, atomicity issues, and lock/provenance inconsistencies that undermine universal assertions.
- Prior tracked issue evidence (cross-referenced as issue-level artifact): OpenAI-compatible payload drift when sending Anthropic-style tool choice objects to OpenAI-compatible endpoints caused 400/shape failures (`openai-completions` forced payload path), reinforcing strict tool schema normalization as mandatory before universal routing.

## Source Notes (keep/drop)

### Kept (high signal)
- Official provider docs for tool contracts and caching:
  - OpenAI function calling, tool search, prompt caching: `platform.openai.com/docs/guides/function-calling`, `/guides/tools-tool-search`, `/guides/prompt-caching`
  - Anthropic tool-use flow + prompt caching + caching structure: `docs.anthropic.com/.../tool-use/*`, `.../prompt-caching`
  - xAI function calling and REST inference/chat references: `docs.x.ai/developers/tools/function-calling`, `docs.x.ai/developers/rest-api-reference/inference/chat`
  - Z.AI function calling + streaming-tool pages: `docs.z.ai/guides/capabilities/function-calling`, `docs.z.ai/guides/capabilities/stream-tool`
  - Gemini function calling + caching/openai compatibility: `ai.google.dev/gemini-api/docs/function-calling`, `/docs/openai`, `/docs/caching`
- Repo-level benchmark artifacts: `.pi/reports/NATURAL-ZAI-PROVIDER-MATRIX-RERUN-20260612.md`, `.pi/reports/UNIVERSAL-BLITZ-BLIND-SPOT-AUDIT-20260611.md`.

### Dropped / low-confidence
- Publicly available Gemini pages with full tool-specific constraints were partly noisy/boilerplate; no strong full-text extraction for every section (some gaps in limits + edge-case matrix).
- Direct issue URL evidence was constrained by authentication blocks; therefore one key cross-repo bug claim remains as prior artifact evidence (not freshly retrieved) rather than first-party fetch.

## Version / Date Notes
- Docs fetched/verified: 2026-06-19 (timezone UTC where documented).
- Repo benchmark evidence up to 2026-06-12 rerun and 2026-06-11 audit/lock artifacts.

## Open Questions
1. Gemini official pages we captured include mixed function/tool-call behavior, but exact failure codes for malformed function-call JSON and full provider-specific tool restrictions remain partially underspecified in gathered text.
2. Z.AI official caching/rate-limit guarantees were not strongly retrievable in this pass; decide whether to treat as “explicitly unknown” or source from SDK/client docs/contract tests.
3. Which benchmark model set should be authoritative for universal claim once route behavior fixes land? Current evidence still mixes mandatory and optional provider scopes.

## Builder-Ready Implications

### Provider schema preflight (per-call)
- **OpenAI:** canonicalize tool list to array-of-object function tools with strict-safe schemas; avoid tuple-array constructs.
- **Anthropic:** validate request payload includes `tools + system/messages` cache strategy and that tool result ordering is guaranteed.
- **xAI:** enforce `parameters` root object; track `server_side_tool_usage_details` separately from model-visible attempt fields.
- **Gemini:** require return-path mapping for both `functionCall` and `toolResponse` ID; parser must tolerate mixed-part turn output.
- **Z.AI:** skip forced tool mode; use auto-driven tool routing and validate tool result echo fields.

### Runtime acceptance/fallback matrix (route decision)
1. **Pre-call gate**: build call only if provider/model supports requested tool semantics.
2. **Tool execution gate**: validate call-id presence and argument parse.
3. **Completion gate**:
   - If tool-call parse/exec succeeds and route-safe transformation accepted → `blitz_mutated`.
   - If safe no-op / already-correct state → `noop`.
   - If ambiguous, unsupported schema/forced-tool failure, ambiguous multi-match, or hard error → explicit fallback (`core_mutated` or `core_declined`) with reason code.
4. **Accounting gate**: persist (per row) provider, model, attempted tool calls, completed/actually executed calls, cache metrics (if available), tokscale match boolean, and `fallback_reason`.

### Immediate next steps
- **Research closure needed:** add Gemini capability gaps (exact unsupported function/tool combos, strict-mode/error behavior) into the matrix with at least one official page each.
- **Implementation prep:** align route controller with per-provider preflight gates above and wire `blitz_declined` telemetry.
- **Measurement hardening:** keep natural matrix expanded with explicit no-op/ambiguity and tokscale-match enforcement before claiming universal pass.

## Confidence
- **Overall confidence: 0.78**
- Strength: strong for OpenAI/xAI/Anthropic/Z.AI core schema+workflow claims.
- Weakness: medium on Gemini and Z.AI quota/caching nuance due partial extraction quality.

## Top 3 findings
1. **OpenAI shape drift is a real integration risk** (tuple-array/function-choice compatibility issues): must keep schema normalization as mandatory preflight.
2. **Z.AI’s `tool_choice` limitation (`auto`-only) is a structural constraint**: do not build universality on forced/required tool policies for Z.AI.
3. **Universal claim is not yet valid from evidence**: natural reruns show meaningful false positives/unsafe mutations and missing tokscale integrity; fallback accounting must be explicit and visible.
