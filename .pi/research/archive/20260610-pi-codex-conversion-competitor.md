# Research: pi-codex-conversion competitor report (lean)

## Executive summary: what competitor actually does
pi-codex-conversion implements a **Codex-shaped adapter layer** for Pi, not just UX wrappers. On session/model changes, it mutates active tools between Codex and Pi-native defaults (`src/adapter/activation/activation.ts`) and rewrites model context budget when target is `openai-codex` (`src/adapter/prompt/codex-context-budget.ts`).

Version 2.0.0 introduced a real **tool-bridge rewrite**: tool execution moved behind bundled Rust binaries for command-heavy PATH tools (`apply_patch`, `exec_bridge`, `view_image`, `web_run`, `imagegen`) and PATH mode was added with only `exec_command` + `write_stdin` exposed natively (`CHANGELOG.md` 2.0.0). Path tools are injected into tool call sessions via env PATH, not user shell PATH (`src/tools/path/binary.ts`).

## Evidence table: file path -> relevant fact

- `packages/pi-codex-conversion/README.md` — states active tool mode split (normal vs PATH), PATH tool coverage, claims of reduced token usage, and bundled Rust stability rationale.
- `CHANGELOG.md` — 2.0.0+ major rewrite: bundled binaries for exec/apply/web/image tools and PATH mode introduction; 2.0.1 context parsing hardening.
- `AGENTS.md` — PATH mode contract: native tools in PATH mode are only `exec_command` + `write_stdin`; PATH tools include `apply_patch`, `view_image`, `web_run`, `imagegen`.
- `PATH_TOOLS.md` — codex normal vs PATH tool availability table and env/path injection model.
- `package.json` — dependency/runtime surface: no `node-pty` currently, files include `src/tools/**/bin/**`, prepack verifies binaries; scripts `build:changed-path-tools`.
- `src/index.ts` — startup registers tools, sets PATH tool env, syncs adapter on `session_start/model_select`, injects Codex prompt.
- `src/prompt/build-system-prompt.ts` — PATH-mode guideline set: shell-centric instructions, heredoc/parallel guidance, tool command examples.
- `src/adapter/activation/activation.ts` — adapter/undo activation logic, PATH mode tool whitelist (`PATH_MODE_TOOL_NAMES`), apply-patch-only mode, status text handling.
- `src/adapter/activation/tool-set.ts` — canonical tool constants, normal vs PATH tool names.
- `src/tools/path/binary.ts` — PATH wrapper dir detection and env PATH prepending for bundled tools.
- `src/tools/path/runner.ts` — Rust process execution helper, 64MB output guard, parse last JSON line helper.
- `src/tools/apply-patch/tool.ts` — Pi tool registration for `apply_patch`, error handling, partial vs hard failure shaping.
- `src/tools/apply-patch/executor.ts` — calls Rust apply_patch binary with `PI_APPLY_PATCH_JSON`, maps Rust result to `ExecutePatchError` with mapped failed action.
- `src/tools/apply-patch/rust/Cargo.toml` — Rust crate stack for apply-patch.
- `src/tools/apply-patch/rust/lib.rs` — core patch parser+apply engine + summary output shape + failure result type.
- `src/tools/apply-patch/rust/parser.rs` — strict/lenient parser modes, hunk grammar, patch header/hunk validation.
- `src/tools/apply-patch/rust/invocation.rs` — command verification, heredoc extraction, shell parsing with tree-sitter, explicit `ImplicitInvocation` error when raw patch is passed as sole arg.
- `src/tools/apply-patch/rust/streaming_parser.rs` — incremental parser for streaming input and hunk emission during stream.
- `src/tools/apply-patch/rust/standalone_executable.rs` — CLI behavior, JSON success/failure payload, usage, and exact/move/create/delete summary.
- `src/tools/apply-patch/rust/seek_sequence.rs` — context-match with strictness tiers and safety for long patterns.
- `tests/codex-context-budget.test.ts` — verifies context-window adjustment for openai-codex only, and reserve token precedence of `.pi/settings.json` over agent-level.

## Rust rewrite + PATH mode architecture
- **TS/bridge boundary:** native Pi tools still orchestrate, but selected tool execution is handed to Rust binaries for isolation (`src/tools/apply-patch/executor.ts`, `src/tools/path/runner.ts`, `src/adapter/activation/activation.ts`).
- **Binary lookup:** platform-specific executables resolved under `src/tools/<tool>/bin/<platform>-<arch>/`; helpers fallback when absent (`getBundledApplyPatchBinaryPath`, `getBundledPathToolBinaryPath`).
- **PATH mode execution model:** native schema tools are reduced to `exec_command` and `write_stdin` (`PATH_MODE_TOOL_NAMES`), while `apply_patch/view_image/web_run/imagegen` are shell-available via injected PATH (`PATH_TOOLS.md`, `src/tools/path/binary.ts`, `src/adapter/activation/tool-set.ts`).
- **Session wiring:** `createBundledPathToolsEnv` is passed into session manager bootstrap and refreshed on session events (`src/index.ts`), so exec sessions inherit the injected bin directory.
- **Wrapper indirection:** repo includes Node wrapper scripts in `/bin` that execute the platform binary and inherit cwd/env; PATH mode does not touch user PATH.
- **Blow-up control:** PATH wrappers are only injected when files exist; missing wrappers disable PATH-mode tool augmentation.

## apply_patch parser/executor/failure semantics
- **TS call entry:** `registerApplyPatchTool` validates args, updates render state, and calls `executePatchWithRust` (`src/tools/apply-patch/tool.ts`).
- **Rust execution contract:** command returns JSON (when `PI_APPLY_PATCH_JSON` set) with `status`, optional `error`, `exact`, and `result.changedFiles/createdFiles/deletedFiles/movedFiles/fuzz` (`standalone_executable.rs`, `executor.ts`).
- **Failure mapping:** on non-success, tool treats this as `ExecutePatchError`; it re-parses patch to find likely failing action and returns partial-failure diagnostics if any actions already applied (`executor.ts`, `patch/types.ts`).
- **Patch parsing:** rust parser validates markers/hunks and can operate in lenient mode (e.g. heredoc wrappers) while checking context/start/end markers (`parser.rs`).
- **Invocation safety:** `invocation.rs` verifies shell forms (`bash -lc`, `powershell`, `cmd /c`) with tree-sitter AST for heredoc; explicit rejection for implicit single-arg patch invocation (`ImplicitInvocation`).
- **Execution semantics:** `lib.rs` applies hunks sequentially through filesystem abstraction and can leave partial delta when failure occurs; failures track `delta` (changed paths/content) so caller knows what stuck.
- **Streaming:** `streaming_parser.rs` allows incremental parsing and can return progressively discovered hunks.

## Token/context implications: proven vs claimed vs unknown
### Proven
- PATH mode truly narrows native tool surface: only `exec_command` + `write_stdin` in PATH_MODE_TOOL_NAMES.
- PATH tool availability and behavior is environment-injected, not user shell PATH.
- Prompt mode injection changes at runtime; PATH mode uses command-style guidelines and avoids mention of native `edit/write/read` semantics in that branch.
- Context budget adjustment for Codex path is implemented and tested (`tests/codex-context-budget.test.ts`): `getCodexContextBudgetAdjustedModel` changes openai-codex context window to Pi reserve-based value.

### Claimed (not formally measured)
- README says PATH mode “very likely” reduces tokens, not guaranteed.
- README says tool prompt/shape tweaks “tweak” to enable one-shot tool calls.
- Changelog states native helper migration improves stability and blast-radius; no explicit quantitative crash/recover metrics.

### Unknown/Not proven
- No benchmark artifacts in these files for token usage before/after tool/schema changes.
- No direct measurement of whether PATH mode reduces token footprint per message versus schema tools across models.
- No end-to-end user study of tool-call success rate in PATH mode vs normal mode.

## What Blitz should copy as principles
- Keep adapter behavior centralized and deterministic (single sync function keyed on session/model state).
- Move heavy/intrusive tools into separate executable boundaries for fault isolation.
- Use environment injection pattern rather than mutating user shell PATH.
- Enforce strict invocation verification and explicit failure taxonomy (`success`/`partial_failure`/`failed`) with actionable recovery hints.
- Parse patch input conservatively before disk writes; pre-verify operations before applying.
- Include fuzz/lenient parsing only with clear rationale and tests.
- Gate claims with tests and changelog notes; do not overclaim token/context improvements without instrumentation.

## What Blitz must avoid
- Avoid claiming “less tokens” as factual without collected benchmarks.
- Avoid implicit patch-call acceptance patterns that bypass explicit command semantics (they intentionally reject as unsafe/ambiguous).
- Avoid weakening parser validation (markers/hunk grammar) since that guardrails apply_patch correctness.
- Avoid unbounded stream output buffering; cap child output and fail fast on overflow (64MiB in runner).
- Avoid PATH-mode tool overexposure: keep native tool list intentionally narrow.

## Recommended new-goal criteria/wording
1. **Implement Rust-backed apply_patch tool path with explicit JSON result contract**: status, error message, exactness flag, and changed/created/deleted/moved counts + failure action.
2. **Implement PATH mode as a controlled two-tool native surface**: only `exec_command`/`write_stdin` are JSON tools; additional tools are shell-discoverable only through injected PATH.
3. **Add strict invocation verification**: reject implicit bare patch bodies; require explicit tool-call form, with clear partial-failure recovery metadata when partial writes occur.
4. **Codex prompt adaptation should be mode-aware**: inject PATH-specific, shell-centric instructions when PATH mode is active.
5. **Add benchmark/measurement gates** before claiming context-token savings in docs or goals.

## Confidence/gaps
- **Confidence:** High on implementation facts (direct file-level evidence) for adapter flow, PATH behavior, Rust rewrite path, and parser/failure semantics.
- **Confidence:** Medium on user-facing “token advantage” claims (self-reported, no benchmark source).
- **Gaps:** no quantified token benchmarks; no cross-language behavior matrix for all PATH-backed tools (image/web/run/exe bridge not deeply audited here).

## Version / Date Notes
- Repository snapshot path: `/tmp/pi-github-repos/IgorWarzocha/howaboua-pi-stuff/packages/pi-codex-conversion`
- Package version: `2.0.1` (`package.json`)
- Context-date for this note: `2026-06-10`
- Major architecture change reference: `2.0.0` rewrite + PATH mode (`CHANGELOG.md`)
