# Research: Tool/schema/context token tax reduction for coding agents

## Question
How can LLM coding-agent runtimes reduce tool/schema/context token overhead enough that a code-edit tool can replace core edit? Focus: OpenAI tool search/deferred loading/custom/freeform tools/prompt caching, MCP tool tax/lazy schemas, Anthropic code execution with MCP.

## Findings

### 1) OpenAI now has native tool-search + deferred loading for large tool surfaces
- OpenAI `tool_search` lets model search/load tools dynamically instead of loading all definitions up front; docs say this may reduce token use/cost and is designed to preserve model cache by injecting loaded tools at end of context. Only `gpt-5.4`+ supports `tool_search`. Source: https://developers.openai.com/api/docs/guides/tools-tool-search
- To enable: add `{ "type": "tool_search" }`; mark functions with `defer_loading: true`, or mark MCP server tool definition with `defer_loading: true`. Source: https://developers.openai.com/api/docs/guides/tools-tool-search
- OpenAI recommends namespaces or MCP servers over many individual deferred functions because start-of-request model sees only namespace/server name+description, not each function schema. Best-practice target: fewer than 10 functions per namespace. Source: https://developers.openai.com/api/docs/guides/tools-tool-search
- OpenAI supports hosted tool search and client-executed tool search. Client mode can search project/tenant/runtime state and return trusted tool schemas later via `tool_search_output`. Source: https://developers.openai.com/api/docs/guides/tools-tool-search
- `additional_tools` input item can add tools at a specific point in conversation; loaded tool ordering matters for cache. Source: https://developers.openai.com/api/docs/guides/tools-tool-search

Action for Blitz/pi-blitz:
- Model edit capability as deferred namespace/MCP server: e.g. initial always-loaded tiny tools: `search_tools`, `read_minimal`, `apply_edit`; defer rare AST transforms.
- If using OpenAI: build client-executed tool-search index over edit operations and language grammars. Load only matching schema after model asks.
- Keep namespace descriptions short, stable, capability-focused; put detail in deferred tool desc/schema.

### 2) OpenAI confirms function/tool schemas are input tokens; custom freeform tools can avoid JSON-wrapper bloat
- OpenAI function definitions are injected into system message, count against context, and are billed as input tokens. For token limits, docs suggest fewer up-front functions, shorter descriptions, or `tool_search`. Source: https://developers.openai.com/api/docs/guides/function-calling
- OpenAI best practice: fewer than 20 functions initially available; combine functions always called in sequence; do not ask model for arguments code already knows. Source: https://developers.openai.com/api/docs/guides/function-calling
- `tool_choice.allowed_tools` can restrict callable subset without changing full tool list, preserving prompt-cache savings when stable tool list is sent. Source: https://developers.openai.com/api/docs/guides/function-calling
- OpenAI custom tools accept arbitrary string input/output instead of JSON schema arguments; useful for code/edit payloads that should not be wrapped in large JSON. Source: https://developers.openai.com/api/docs/guides/function-calling
- Custom tools support grammar-constrained freeform input via `format: { type: "grammar", syntax: "lark"|"regex" }`. Source: https://developers.openai.com/api/docs/guides/function-calling

Action for Blitz/pi-blitz:
- Core edit replacement should prefer freeform/custom tool shape for patch/code-edit DSL, not deep JSON schemas.
- Add small grammar for Blitz edit language if OpenAI path used; keep grammar bounded/simple.
- Collapse multi-step primitives into higher-level edit ops where always paired: e.g. parse+find+replace as one operation.

### 3) OpenAI prompt caching makes stable tool prefix valuable, but changing tools breaks cache locality
- Prompt caching is automatic on recent models; prompts >=1024 tokens eligible; can reduce latency up to 80% and input token costs up to 90%. Source: https://developers.openai.com/api/docs/guides/prompt-caching
- Cache hits require exact prefix matches; static instructions/tools should be at beginning, variable content at end. Tools must be identical between requests. Source: https://developers.openai.com/api/docs/guides/prompt-caching
- `prompt_cache_key` can improve routing for shared prefixes; usage exposes `cached_tokens`. Source: https://developers.openai.com/api/docs/guides/prompt-caching
- Extended cache retention exists up to 24h for newer models; OpenAI docs list `gpt-5.5`, `gpt-5.4`, `gpt-5.2`, `gpt-5.1-codex*`, `gpt-5`, `gpt-5-codex`, `gpt-4.1`. Source: https://developers.openai.com/api/docs/guides/prompt-caching

Action for Blitz/pi-blitz:
- Keep always-loaded tool surface tiny and byte-stable across turns/releases.
- Put repo-specific file paths, task text, diffs, tool outputs after stable prefix.
- Track `cached_tokens` during benchmarks; report cache hit rate separately from raw token savings.

### 4) OpenAI MCP connector supports `allowed_tools` and `defer_loading`; MCP list item can be kept to avoid repeated list latency
- OpenAI remote MCP uses `tools: [{ type: "mcp", server_label, server_url, ... }]`; first use lists tools and creates `mcp_list_tools`. Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- OpenAI says you pay for tokens used when importing MCP tool definitions or making tool calls; no extra per-tool-call fee. Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- `allowed_tools` imports only named tools from a large MCP server, reducing cost/latency. Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- As long as `mcp_list_tools` remains in request context, API will not re-fetch tool list each turn; docs recommend keeping it for latency. Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- With tool search, OpenAI can defer MCP server loading via `defer_loading: true`; model sees server label+description and loads individual definitions only when needed. Source: https://developers.openai.com/api/docs/guides/tools-connectors-mcp

Action for Blitz/pi-blitz:
- If exposing Blitz as MCP, use `allowed_tools` for phase-specific runs: read/map vs edit/apply vs benchmark.
- Add high-quality `server_description`; it becomes routing metadata when schemas deferred.

### 5) MCP protocol still exposes full schemas through `tools/list`; lazy schema hydration remains pattern/proposal, not baseline protocol guarantee
- MCP `tools/list` response includes each tool with `name`, `description`, and `inputSchema`; `inputSchema` must be valid JSON Schema object. Source: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- MCP servers with tools declare `capabilities.tools`; `listChanged` only signals clients to re-fetch changed tool list. Source: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- Protocol supports pagination for `tools/list`, but pagination alone does not mean model context is smaller if client imports all pages/schemas. Source: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- Community issues/proposals discuss lazy hydration/progressive discovery, but current durable spec still centers `tools/list` full tool objects. Sources: https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1978, https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/1923

Action for Blitz/pi-blitz:
- Do not assume generic MCP clients lazy-load schemas. Design Blitz MCP server with few exposed tools by default.
- Use separate MCP servers or modes for domains if client lacks provider-native `defer_loading`.
- Consider explicit meta-tools: `list_edit_ops`, `get_edit_op_schema`, `invoke_edit_op`.

### 6) Anthropic advanced tool-use directly targets tool tax: Tool Search, Programmatic Tool Calling, examples
- Anthropic states tool definitions can consume huge context: sample 5-server setup 58 tools ≈55K tokens; observed 134K tokens before optimization. Source: https://www.anthropic.com/engineering/advanced-tool-use
- Anthropic Tool Search Tool loads only a small search tool up front (~500 tokens), then 3-5 relevant tools (~3K tokens), claiming 85% token reduction and 95% context preservation in example. Source: https://www.anthropic.com/engineering/advanced-tool-use
- Anthropic says deferred tools are excluded from initial prompt and do not break prompt caching; full definitions added only after search. Source: https://www.anthropic.com/engineering/advanced-tool-use
- MCP `mcp_toolset` can set `default_config: { defer_loading: true }` and override high-use tools with `defer_loading: false`. Source: https://www.anthropic.com/engineering/advanced-tool-use
- Anthropic Programmatic Tool Calling lets Claude call tools from code execution; intermediate results stay in code env, only final output enters context. Claimed average complex research usage dropped from 43,588 to 27,297 tokens (37%). Source: https://www.anthropic.com/engineering/advanced-tool-use
- Advanced features require beta header `advanced-tool-use-2025-11-20` in examples; feature naming/version may drift. Source: https://www.anthropic.com/engineering/advanced-tool-use

Action for Blitz/pi-blitz:
- For Claude path, design Blitz tool as code-callable API plus `allowed_callers: ["code_execution_20250825"]` for operations safe from code.
- Keep 3-5 common tools loaded; defer full transform library.
- Add 1-3 `input_examples` only for ambiguous edit ops; examples cost tokens, use where accuracy improves.

### 7) Anthropic code execution with MCP gives strongest architecture pattern for replacing core edit
- Anthropic argues most MCP clients load all tool definitions upfront and pass every intermediate result through context, causing cost/latency. Source: https://www.anthropic.com/engineering/code-execution-with-mcp
- Recommended pattern: present MCP servers as code APIs/files. Agent lists server dirs, reads only specific tool files/interfaces needed, writes code to call MCP tools. Source: https://www.anthropic.com/engineering/code-execution-with-mcp
- Example claim: Google Drive/Salesforce workflow reduces token usage from 150,000 to 2,000 tokens (98.7%) by loading only needed definitions and moving transcript directly between tools in execution env. Source: https://www.anthropic.com/engineering/code-execution-with-mcp
- Benefits: progressive disclosure, filter/aggregate large results before model sees them, loops/conditionals in code, privacy-preserving intermediate data, persisted workspace/skills. Source: https://www.anthropic.com/engineering/code-execution-with-mcp
- Caveat: code execution requires sandboxing, resource limits, monitoring; direct tool calls avoid this infra. Source: https://www.anthropic.com/engineering/code-execution-with-mcp

Action for Blitz/pi-blitz:
- Best core-edit replacement shape: one stable code/execution tool + tiny Blitz SDK exposed in sandbox (`read`, `parse`, `query`, `replace`, `apply`, `preview`). Model writes code/DSL; Blitz performs exact edits.
- Keep raw AST/query matches in sandbox; return compact summaries/diffs only.
- Persist reusable edit scripts as skills/snippets after successful runs.

### 8) MCP compression/proxy pattern is practical fallback when provider-native lazy loading unavailable
- Atlassian reports a large MCP server can consume 10K-17K+ tokens just for tool descriptions; GitHub MCP-style 94-tool scenario ≈17,600 tokens. Source: https://www.atlassian.com/blog/development/mcp-compression-preventing-tool-bloat-in-ai-agents
- `mcp-compressor` wraps an MCP server and exposes tiny wrapper interface: `get_tool_schema(tool_name)`, `invoke_tool(tool_name, tool_input)`, optionally `list_tools()`. Source: https://www.atlassian.com/blog/development/mcp-compression-preventing-tool-bloat-in-ai-agents
- Atlassian claims 70-97% reduction; example GitHub-like 17,600 tokens → 3,900/3,300/2,200/500 depending compression level. Source: https://www.atlassian.com/blog/development/mcp-compression-preventing-tool-bloat-in-ai-agents
- Key principles: preserve exact schema on demand, namespace tools, keep wrapper stable/cache-friendly, provide explicit discovery path. Source: https://www.atlassian.com/blog/development/mcp-compression-preventing-tool-bloat-in-ai-agents

Action for Blitz/pi-blitz:
- If Pi/runtime cannot use OpenAI/Anthropic native tool search, implement compressor-like facade around Blitz tools.
- Default loaded API should be at most: `search_ops`, `get_op_schema`, `invoke_op` + maybe `apply_patch`.
- Benchmark raw vs compressed vs code-mode separately; quality may depend on model/tool-call training.

## Sources
- OpenAI, Using tools: https://developers.openai.com/api/docs/guides/tools
- OpenAI, Tool search: https://developers.openai.com/api/docs/guides/tools-tool-search
- OpenAI, MCP and connectors: https://developers.openai.com/api/docs/guides/tools-connectors-mcp
- OpenAI, Function calling/custom tools/grammars: https://developers.openai.com/api/docs/guides/function-calling
- OpenAI, Prompt caching: https://developers.openai.com/api/docs/guides/prompt-caching
- Anthropic, Advanced tool use: https://www.anthropic.com/engineering/advanced-tool-use
- Anthropic, Code execution with MCP: https://www.anthropic.com/engineering/code-execution-with-mcp
- MCP spec, Tools 2025-11-25: https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- MCP lazy hydration proposal: https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1978
- MCP progressive discovery discussion: https://github.com/modelcontextprotocol/modelcontextprotocol/discussions/1923
- Atlassian, MCP compression: https://www.atlassian.com/blog/development/mcp-compression-preventing-tool-bloat-in-ai-agents

## Version / Date Notes
- Researched 2026-06-05.
- OpenAI docs fetched 2026-06-05 mention future/current model names (`gpt-5.4`, `gpt-5.5`, `gpt-5.1-codex*`). Verify model availability and API field names before implementation.
- Anthropic advanced tool-use article uses beta header `advanced-tool-use-2025-11-20`, tool type names like `tool_search_tool_regex_20251119`, and `code_execution_20250825`. Treat names as beta/versioned.
- MCP spec cited is 2025-11-25. If runtime targets older clients/specs, `title`, `icons`, `execution`, and task support may differ; core `tools/list` + `inputSchema` behavior remains relevant.
- Atlassian compression claims are vendor/blog claims; useful as pattern + benchmark target, not independent proof.

## Open Questions
- Which target provider/runtime must Blitz optimize first: OpenAI Responses, Anthropic Messages/Claude Code, Pi local tools, or generic MCP clients?
- Can Pi expose provider-native `defer_loading`/tool search through current agent tool plumbing, or must Blitz implement MCP-compressor/code-mode fallback?
- What minimum edit DSL/schema gives high edit accuracy without core edit: unified diff, Blitz AST query+replace DSL, freeform code tool, or JSON op list?
- Benchmark gap: need measure prompt tokens, cached tokens, wall time, success rate for core edit vs Blitz tool raw schema vs compressed schema vs code-mode.

## Recommendation
1. Build Blitz replacement around progressive disclosure, not many flat tools.
2. Stable always-loaded surface: `search_ops`, `get_op_schema`, `invoke_op`/`apply_edit`, plus tiny docs.
3. Provider paths:
   - OpenAI: `tool_search` + `defer_loading` namespaces/MCP; use custom/freeform grammar for edit DSL.
   - Anthropic: Tool Search + Programmatic Tool Calling/code execution; expose Blitz as code-callable API.
   - Generic MCP/Pi: compressor-style facade; no assumption of native lazy schemas.
4. Keep intermediate AST/search data out of model context. Return compact summaries, exact diffs, and diagnostics only.
5. Make benchmark acceptance include `input_tokens`, `cached_tokens`, schema-token overhead, wall time, edit correctness, and retry count.
