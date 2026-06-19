# PLAN — Blitz 0.5C token replacement gate

Date: 2026-06-19
Ticket: `bli-mj6a`
Scope: exact final gate plan for `bli-o1pd`. This ticket does **not** run benchmarks.

## Purpose

Produce one bounded final lock proving whether the minimal `blitz_edit` route can be treated as a default core-edit replacement for the measured classes. The gate preserves the 0.4 token win while preventing rerun fishing, hidden fallback claims, or token accounting drift.

## Product route under test

- Blitz lane: `@codewithkenzo/pi-blitz` minimal profile, visible tool `blitz_edit` only.
- Blitz backend: bundled `@codewithkenzo/blitz` CLI through pi-blitz runtime.
- Core baseline: Pi native `edit` tool with optimized changed spans and same-file batched `edits` where supported.
- No accepted Blitz row may count core `edit` / `apply_patch` fallback as Blitz success.
- Structural rows may use compact tuple ops only where the current capability matrix says supported.

## Class C structural policy

Decision: **A — strict default replacement** for Exodia 0.5.

Class C structural decline is safety, not edit success. `unsupported_structural_op_minimal` with `noMutation=true`, route `blitz_edit`, and Tokscale match proves fail-closed route truth only. It does **not** satisfy the default-replacement gate and must not be counted as a replacement win.

For `bli-o1pd` to pass under the universal/exodia 0.5 goal, the default/minimal `blitz_edit` route must produce a successful Class C structural edit for the planned supported slice, with no hidden core/apply_patch fallback and no file corruption. Until that support lands, `bli-o1pd` remains blocked by implementation ticket `bli-sh7d`.

Initial required structural success slice:

- Languages: TypeScript and JavaScript only.
- Operations: unique function body replacement and insertion after a unique function declaration.
- Failure mode: unsupported language, parse error, ambiguous symbol, missing symbol, multi-match, or unsafe edit must decline with no mutation.
- Evidence: focused regression plus final lock row showing `class-c-structural-10` / `blitz-edit` accepted, correct, Tokscale matched, route `blitz_edit`, no fallback.

## Providers / models

Primary lock provider/model:

1. `zai` / `glm-4.5-air` — canonical final lock model because existing 0.4 lock evidence and runner defaults were built around it.

Portability smoke only if primary lock passes and time budget remains:

1. `openai` / `gpt-5.5-mini` — one Class A core+Blitz pair only, not part of the default-replacement pass/fail aggregate.

Do not add more providers in `bli-o1pd`. New provider failures become follow-up tickets, not rerun prompts.

## Row set and counts

Run exactly 12 primary comparison rows: 6 scenarios × 2 lanes.

| Scenario | Class | Core rows | Blitz rows | Operations | Purpose |
|---|---|---:|---:|---:|---|
| `tiny-10` | A tiny exact edits | 1 | 1 | 10 | hardest schema/output overhead check |
| `mixed-20` | A/B/D mixed edits | 1 | 1 | 20 | product-real mixed sequence |
| `same-file-multi` | A same-file batch | 1 | 1 | 3+ | optimized core batch vs compact Blitz batch |
| `class-b-inserts-10` | B anchor inserts | 1 | 1 | 10 | insert-after / local anchors |
| `class-c-structural-10` | C structural | 1 | 1 | 10 | `rb`/`ia` structural capability only |
| `class-d-config-docs-10` | D config/docs | 1 | 1 | 10 | non-code text/config edits |

Optional portability smoke: 2 additional rows max (`tiny-10` core+Blitz on `openai/gpt-5.5-mini`). Preserve separately and exclude from primary aggregate.

No broad matrix. No language matrix rerun. No exploratory natural-edit suite in this ticket.

## Retry and timeout policy

- Primary row timeout: 10 minutes per lane row.
- Harness/process setup failure before model call: one immediate retry allowed, recorded as infrastructure retry.
- Auth/rate-limit/provider outage: stop the lock and file/update a provider-blocker ticket.
- Model malformed tool call: no silent retry inside the accepted row. Preserve artifact, classify failure, and stop after one same-scenario replacement attempt only if the harness crashed before a usable model response.
- Correct-but-timeout after file mutation: classify as timeout failure; do not count.
- Incorrect edit: no rerun. Preserve artifact and file/update a product failure ticket.
- Maximum accepted primary attempts: 12. Maximum total primary attempts including infra retry: 18. Hitting the cap stops the gate.

## Pass / fail threshold

Primary gate passes only if all are true:

1. Correctness: 12/12 primary rows complete and the final file/content check passes.
2. Route integrity: every accepted Blitz row uses `blitz_edit`; none counts core/apply_patch fallback.
3. Accounting integrity: Tokscale token match is recorded for every accepted row, with pass/fail boolean and delta.
4. Token threshold: aggregate Blitz total model-visible context is at least 25% lower than optimized core across accepted primary rows.
5. Tiny-overhead guard: `tiny-10` Blitz is not worse than optimized core. It must either win or tie within 5% total model-visible context.
6. Schema/skill/output guard: current deterministic guards from `bli-09ru` pass before the lock.

If any required row fails correctness or route integrity, the default-replacement claim fails. Do not average it away.

## Required artifacts

Write new artifacts; do not overwrite 2026-06-11 baselines.

Required paths:

- Human report: `reports/REPLACEMENT-GATE-20260619.md`
- JSON lock: `reports/REPLACEMENT-GATE-LOCK-20260619.json`
- Tmux/Pi run root: `reports/pi-accounting-runs/20260619-replacement-gate/`
- Minimal profile dump: `reports/profile-dumps/minimal-blitz-edit-20260619.json`
- Optional portability smoke report: `reports/REPLACEMENT-GATE-PORTABILITY-SMOKE-20260619.md`

Each accepted row in the JSON lock must include:

- provider, model, runner, timestamp, scenario, class, lane (`core` or `blitz`)
- command line and timeout
- raw Pi session JSONL path, byte size, SHA-256
- tmux run dir path
- final correctness status and checker output
- tool calls: tool name, arguments summary/hash, result text/hash, result payload token count
- total model-visible context tokens: resident tool schema, resident skill text, prompt/input/cache, tool args, model output, result payload, total
- Tokscale command, exit code, token-match boolean, token deltas, stdout/stderr paths or hashes
- route/fallback classification
- retry/timeout classification

## Schema / skill token capture

Before running rows, capture and hash:

1. minimal tool schema dump from pi-blitz minimal profile;
2. resident skill file used by Pi for `pi-blitz`;
3. `bli-09ru` guard test output;
4. package commit SHAs for both repos:
   - `/home/kenzo/dev/blitz`
   - `/home/kenzo/dev/pi-blitz`

Schema and skill token counts must be recorded as separate fields, not buried in aggregate totals. If Pi exposes only byte counts for one component, record bytes and the tokenizer source used to derive tokens.

## Stop rules

Stop immediately and preserve artifacts when any of these occurs:

- any primary row has incorrect final content;
- any accepted Blitz row uses core/apply_patch fallback;
- Tokscale is missing, cannot parse the session, or token-match status cannot be recorded;
- `bli-09ru` deterministic guards fail;
- provider auth/rate-limit blocks more than one row;
- harness mutates fixtures without rollback;
- total primary attempts exceed 18;
- operator feels tempted to rerun for a prettier number. That is fishing; file a ticket instead.

## `bli-o1pd` execution order

1. Verify `bli-09ru` and this plan ticket are closed.
2. Run local guards/tests in pi-blitz.
3. Capture schema/skill/profile metadata and repo SHAs.
4. Run the 12 primary rows once with tmux runner and Tokscale enabled.
5. Build `REPLACEMENT-GATE-LOCK-20260619.json` from artifacts.
6. Write `REPLACEMENT-GATE-20260619.md` with pass/fail, not hype.
7. Classify any failures into tk tickets; do not rerun-fish.
8. Only if primary passes and budget remains, run the optional portability smoke.

## Claim boundary for `bli-qgz1`

Allowed wording if the gate passes:

> In the measured Sprint C gate on `zai/glm-4.5-air`, minimal `blitz_edit` beat optimized core edit by at least the configured aggregate token threshold across the locked A-D scenario set, with 12/12 correctness and Tokscale-recorded accounting.

Forbidden wording:

- “universal replacement” without class/provider caveat;
- “always cheaper”;
- “token savings” without Tokscale/session artifact links;
- claims based on wall time or byte counts alone.
