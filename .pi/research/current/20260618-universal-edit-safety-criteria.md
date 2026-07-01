# Research: Universal Blitz edit-route safety semantics (v1)

## Question
What exact behavior rules should `blitz_edit` enforce for replacement semantics, safety, rollback safety, route outcomes, and adversarial handling so that universal routing remains unambiguous and auditable?

## Answer / recommendation
Use **route-level acceptance** as the gate: a row is a Blitz win only when tool output shows `route: "ast_narrow"` (or equivalent non-core route) with mutation and correctness. Any `core_edit` fallback or hidden mutation path counts as `fallback`/`decline` only, not Blitz success. For unknown/noise/ambiguous/security-boundary inputs, explicitly return no-mutation decline with declared reason.

### Core policy (must be enforced)
- Default output-lean route should be: **Blitz when deterministic + safe + token-efficient**, otherwise **explicit decline/fallback**.
- Never infer `blitz` from rows that fell back to core.
- For boundary or adversarial inputs, prefer deterministic non-mutation outcomes.

## Findings (claim-by-claim)

1. **OpenAI-style strict tool schemas must be object-based and fully specified.**
   OpenAI function schemas require `additionalProperties: false` and all fields required for strict mode; best practices require required fields and clear field definitions.
   - Source: `https://platform.openai.com/docs/guides/function-calling`
   - Source: `.pi/docs/plans/archive/PLAN-0.5-universal-blitz-edit-exodia.md`

2. **MCP distinguishes protocol-level errors from tool-execution errors, and route clients should not treat protocol errors as retryable success signals.**
   Tool calls with execution problems should be delivered as `isError: true` in tool results; protocol errors are for transport/request issues.
   - Source: `https://modelcontextprotocol.io/specification/draft/server/tools`

3. **Ambiguous or missing exact-text anchors must fail closed (no mutation).**
   Local apply logic rejects ambiguous matches (`AmbiguousMatches`) and no-match states; tests assert file content is unchanged in ambiguous rejection cases.
   - Source: `src/apply/operations.zig`
   - Source: `src/apply/mod.zig` (tests: "apply replace_body_span ambiguous rejects without mutation")

4. **Route telemetry already has explicit semantics for no-mutation, needs-host-merge, and core fallback; use it, don’t collapse it.**
   Route decision logic can mark `core_edit` and emit `needs_host_merge` in explain mode; fallback routes are explicit, so benchmark accounting can’t mistake explain/fallback as Blitz success.
   - Source: `src/apply/mod.zig`
   - Source: `.pi/bench/natural-edit.ts`
   - Source: `.pi/docs/product/blitzd-protocol.md`

5. **Path-boundary safety must be realpath-based + inside-check, not string-prefix-only.**
   Blitz/pi path canonicalization already resolves cwd+input then realpath and rejects when resolved path is outside workspace root unless trusted.
   - Source: `/home/kenzo/dev/pi-blitz/src/paths.ts`
   - Source: `https://github.com/OWASP/ASVS/blob/v4.0.3/4.0/en/0x20-V12-Files-Resources.md`
   - Source: `https://cwe.mitre.org/data/definitions/23`

6. **Atomic write + lock discipline exists but must be preserved to prevent partial writes/concurrency corruption.**
   Writes use `createFileAtomic(...).replace()` plus per-realpath lock directories before mutation; this prevents interleaving edits and preserves all-or-nothing replacement.
   - Source: `src/backup.zig`
   - Source: `src/lock.zig`
   - Source: `https://man7.org/linux/man-pages/man2/rename.2.html`

7. **Filetype matrix and unsupported formats should be explicit, not implicit.**
   Language support is extension-driven (`grammar_config` table); unsupported/structurally-unsafe targets should route to host/merge/decline path instead of pretending success.
   - Source: `src/grammar_config.zig`
   - Source: `src/apply/mod.zig`

## Source Notes (kept vs dropped)
- Kept: repo-local protocol and harness sources (they encode product rules directly).
- Kept: OpenAI + MCP + OWASP/CWE/manpage references (high-signal, stable external contracts).
- Dropped: anecdotal social/forum claims about tuple compatibility unless validated in local provider test matrix; keep as internal compatibility watch list only.

## Version / Date Notes
- Repo-local findings reflect Blitz v0.5 universal planning + current Exodia harness state under `/home/kenzo/dev/blitz`.
- External references current as of 2026-06-18.

## Open Questions
1. For boundary classes (path traversal/symlink/case-collision), should route outcome be `decline` only, or can class-specific fallback to core be allowed with explicit evidence?
2. Should unchanged-but-intentful requests (semantic no-op) return `noop` or `decline`? Current harness has both pathways; choose one canonical output.
3. How aggressively should the router pre-classify unsupported filetypes before parse to reduce false starts while preserving correctness telemetry?

## Builder-Ready implications
### Concrete acceptance criteria (must be in next lock)
- **No hidden fallback:** accepted Blitz rows must include route marker showing true Blitz route and a successful mutation.
- **No-mutation classes:** ambiguous/stale/attack/path-boundary classes must be deterministic no-op/decline outcomes.
- **No ambiguity guess:** if match count != 1 and explicit selector absent, reject with `AMBIGUOUS_MATCH` (or equivalent) and unchanged file.
- **Security hardening:** all path checks use realpath + inside-check; no string-only checks.
- **Write safety:** atomic write/backup and lock remain enabled; verify interrupted-run behavior does not create partial mutations.
- **Reporting:** keep route-level telemetry (`blitz|core|fallback|decline|clarify|noop|incorrect`) and classify each row there.
- **Evidence:** keep real tmux/Pi artifacts, tokscale, and correctness traces for route claims.
