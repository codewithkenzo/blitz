# Sprint map — Blitz Exodia 0.5 implementation

Source anchor: `/home/kenzo/vaults/kenzo/04-systems/blitz-exodia-goal-copy-2026-06-16.md`
Parent epic: `bli-6uqs` — Blitz Exodia 0.5 implementation program

## Rule

Implementation first. Benchmarks are milestone gates, not the daily loop.

Do not run final matrices until Sprint A + Sprint B + token gate plan are green.

## Sprint A — product safety foundation

Goal: make the live minimal tool safe, package-clean, and testable before any broad proof.

Tickets:

- `bli-wwly` — 0.5A bench and package isolation guard
- `bli-97se` — 0.5A quarantine broken structural ops in minimal `blitz_edit`
- `bli-wcjq` — 0.5A exact edit safety suite
- `bli-42f3` — 0.5A route result taxonomy and output guard

Exit criteria:

- `.pi/bench/` cannot pollute package/install/runtime/language stats.
- Broken `rb`/`ia` cannot corrupt files and return `ok`.
- Exact `x` path has durable tests for filetypes, ambiguity, no-match, no-op, path escape, symlink escape, stale content, rollback.
- Tool/bench outcomes use canonical route truth.

## Sprint B — capability + provider reliability

Goal: define what Blitz can safely do by language/provider, without pretending unsupported paths are success.

Tickets:

- `bli-7x68` — 0.5B language capability matrix tests
- `bli-bbnw` — 0.5B provider preflight and smoke harness
- `bli-yzzg` — 0.5B pi-blitz Effect runtime testability slice

Exit criteria:

- Exact vs structural language capability is encoded in tests/docs.
- JS/JSX AST support decision is explicit.
- Provider rows record attempted/completed tool calls, profile/tool, route/fallback, malformed calls, retry/timeout, auth/rate-limit vs product failure, Tokscale/cache status.
- Effect work is limited to testability/reliability with no public schema/output expansion.

## Sprint C — token lock + claim gate

Goal: preserve 0.4 token win and produce bounded final evidence.

Tickets:

- `bli-09ru` — 0.5C token regression guards
- `bli-mj6a` — 0.5C token replacement gate plan
- `bli-o1pd` — 0.5C focused final lock run
- `bli-qgz1` — 0.5C final claim audit

Dependencies:

- `bli-o1pd` depends on Sprint A foundation, Sprint B provider/language gates, token regression guards, and token gate plan.
- `bli-qgz1` depends on `bli-o1pd`.

Exit criteria:

- Minimal schema/skill/output sizes have guards.
- Final benchmark plan has exact row counts, providers/models, retries/timeouts, token thresholds, artifact paths.
- Final run is one bounded proof session, not rerun fishing.
- Class C policy is strict for Exodia 0.5: structural decline is safety, not edit success; universal/default-replacement claim waits for supported Class C structural success in `blitz_edit`.
- Claim wording is scoped to evidence.

## Sprint D — all edit-type gate on one provider

Goal: widen from Sprint C A-D gate to all edit classes on one provider/model first, without exploding into provider × edit matrices.

Tickets:

- `bli-cca2` — 0.5D all edit-type gate plan
- `bli-91kk` — 0.5D all edit-type harness rows
- `bli-m3sj` — 0.5D focused all edit-type lock run
- `bli-hndl` — 0.5D all edit-type claim audit

Provider/model first target:

- `zai/glm-4.5-air` unless the plan ticket changes it with evidence.

Edit classes to cover:

- exact tiny single
- exact same-file multi
- exact cross-file multi
- config set/key edit
- doc/comment edit
- import edit
- rename/local usage
- structural function body replace
- structural insert-after function
- wrap body / try-catch if supported
- delete range
- append section
- noop/already-present
- ambiguous decline
- no-match decline
- unsupported structural decline
- path escape decline
- rollback failure

Rules:

- `bli-m3sj` depends on plan + harness rows.
- Stop on systemic failure and create blocker ticket; no rerun fishing.
- Provider-wide expansion is a later sprint, not Sprint D.

## Blocked lane — history remediation

Ticket:

- `bli-c9et` — 0.5X history remediation scope gate

Status:

- Not part of Exodia implementation unless exact target is supplied.
- Default action for bad code is revert.
- Purge/history rewrite requires explicit owner/security/legal approval, force-push/tag/release/npm plan, fresh clone, collaborator freeze, rollback plan.

## Current old context ticket

- `bli-pg9j` — old natural-harness/Zai evidence ticket. Keep as history/evidence context, not the active Exodia work loop.
