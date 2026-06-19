# PLAN-0.5D — All edit-type gate

Date: 2026-06-19
Parent epic: `bli-6uqs`
Sprint ticket: `bli-cca2`

## Purpose

Widen the proven Sprint C replacement gate from the A-D scenario slice to a one-provider all edit-type gate.

This is still not provider-wide Exodia. It is the next scoped proof layer.

## Non-goals

- Do not run provider × edit-type matrix in this sprint.
- Do not claim universal/default across providers.
- Do not rerun until green. Failures create blocker tickets.
- Do not count fallback, decline, or noop as Blitz success.
- Do not broaden structural support beyond implemented safe routes during the gate.

## Provider/model

Initial target:

- provider: `zai`
- model: `glm-4.5-air`
- runner: tmux/Pi where required by benchmark harness
- token accounting: Tokscale required

Provider-wide follow-up is a later sprint after this gate passes.

## Tool/profile lanes

Core baseline:

- lane: `core-optimized` or repo-equivalent core lane from existing replacement gate harness
- route: Pi core `edit`

Blitz lane:

- lane/tool: minimal/default `blitz_edit`
- route truth: every accepted Blitz row must show `blitz_edit`
- hidden fallback: forbidden

## Outcome vocabulary

Use exactly these outcome buckets:

- `blitz_success` — Blitz tool mutated or no-op-handled exactly as requested, correctness passed, no hidden fallback.
- `core_success` — core baseline correctness passed.
- `decline` — explicit no-write decline; safe, but not edit success.
- `noop` — old state already satisfies request; safe, but not edit success unless row intent is explicitly no-op.
- `core_fallback` — host/core fallback; never Blitz success.
- `needs_host_merge` — explicit handoff; never Blitz success.
- `incorrect` — mutation/result mismatch.
- `error` — tool/provider/harness/system failure.

## Edit classes

The gate must cover these classes before `bli-m3sj` can run.

| ID | Class | Expected Blitz behavior | Notes |
|---|---|---|---|
| E01 | tiny exact single | success | Minimal old/new replacement. Tiny guard row. |
| E02 | exact same-file multi | success | Multiple exact replacements in one file. |
| E03 | exact cross-file multi | success | Multi-file exact replacements with rollback protection. |
| E04 | config set/key edit | success | JSON/YAML/TOML/TS config where supported; explicit behavior for JSONC gap. |
| E05 | doc/comment edit | success | Markdown/comment text; no formatting drift. |
| E06 | import edit | success | Insert/remove/reorder import with exact expected output. |
| E07 | rename/local usage | success or explicit scoped limitation | If not fully supported by minimal `blitz_edit`, classify as required implementation blocker before final all-type claim. |
| E08 | structural function body replace | success | TS/JS unique function target from `bli-sh7d`. |
| E09 | structural insert-after function | success | TS/JS unique function target from `bli-sh7d`. |
| E10 | wrap body / try-catch | success if supported, otherwise explicit implementation blocker | Cannot be counted as success if declined. |
| E11 | delete range | success if represented in minimal route, otherwise blocker/scope decision | Must not use hidden fallback. |
| E12 | append section | success if represented in minimal route, otherwise blocker/scope decision | Markdown/config/doc common case. |
| E13 | noop/already-present | noop | Must classify as `noop`, not edit success except no-op-intent row. |
| E14 | ambiguous match | decline | No mutation. |
| E15 | no-match/stale context | decline | No mutation. |
| E16 | unsupported structural | decline | No mutation. Safety only. |
| E17 | path escape/symlink/traversal | decline/error safety | No mutation outside workspace. |
| E18 | rollback failure case | decline/error with rollback truth | No partial mutation; incomplete rollback must report truthfully. |

## Row policy

Each success-intended class needs a paired row:

- one core baseline row;
- one Blitz row.

Safety/decline classes can have Blitz-only rows if core baseline is irrelevant, but the report must not count them as Blitz edit wins.

Required per row:

- scenario ID and class ID;
- provider/model;
- lane/tool/profile;
- route outcome;
- expected vs actual file hash or file contents check;
- correctness boolean;
- mutation/no-mutation classification;
- Tokscale match;
- input/output/cache/schema/skill/tool-args/result-payload token fields;
- artifact path.

## Pass criteria for `bli-m3sj`

The all edit-type lock passes only if:

- all success-intended core rows are correct;
- all success-intended Blitz rows are correct;
- every Blitz success row uses `blitz_edit` with no hidden `edit`/`apply_patch` fallback;
- all safety rows decline/noop/error exactly as expected and do not mutate files;
- Tokscale matches every counted row;
- resident schema and resident skill tokens are present from Pi artifacts or validated first-class harness data;
- total Blitz tokens are lower than core over the success-intended paired set;
- tiny exact guard remains lower than core;
- failures are preserved and classified, not rerun away.

## Stop rules

Stop immediately and create a blocker ticket if:

- any success-intended Blitz row is incorrect;
- any core baseline row is incorrect and the row cannot be classified as invalid scenario/harness bug;
- any Blitz row mutates on expected decline;
- any hidden fallback is detected;
- Tokscale mismatch appears on a counted row;
- schema/skill token accounting is missing;
- provider/auth/rate-limit failure prevents trustworthy classification.

No rerun is allowed until the blocker is closed with a fix or explicit policy change.

## Artifact names

Suggested outputs:

- `reports/ALL-EDIT-TYPE-GATE-LOCK-20260619.json`
- `reports/ALL-EDIT-TYPE-GATE-20260619.md`

If rerun after a blocker fix:

- append reason suffix, e.g. `-after-<ticket>`.

## Implementation order

1. `bli-91kk`: add/verify harness rows and self-checks for E01-E18.
2. Close any scope blockers discovered by row definition before running model rows.
3. `bli-m3sj`: run one focused all edit-type lock.
4. `bli-hndl`: audit scoped claim from artifacts.

## Row registry status

`bench/true-streak.ts --self-check-all-edit-types` is the deterministic pre-run guard for this sprint. It verifies that all E01-E18 classes exist and that success rows are paired while decline/noop/error rows cannot be counted as paired Blitz wins.

Rows currently mapped to existing scenarios:

- E01: `tiny-10`
- E02: `same-file-multi`
- E03: `mixed-20`
- E04/E05: `class-d-config-docs-10`
- E08: `class-c-structural-10`
- E09: `structural-3`

Rows materialized by Sprint D row-fixture tickets before `bli-m3sj`:

- E06 import edit: runnable paired `all-edit-types-gate` fixture with exact expected output.
- E07 rename/local usage: runnable paired `all-edit-types-gate` fixture scoped to same-file local usage.
- E10 wrap body / try-catch: runnable paired `all-edit-types-gate` exact replacement fixture.
- E11 delete range: runnable paired `all-edit-types-gate` exact deletion fixture.
- E12 append section: runnable paired `all-edit-types-gate` Markdown append fixture.
- E13 noop/already-present: runnable safety fixture classified `noop`, no mutation, not Blitz success.
- E14 ambiguous match: runnable safety fixture classified `decline`, no mutation, not Blitz success.
- E15 no-match/stale context: runnable safety fixture classified `decline`, no mutation, not Blitz success.
- E16 unsupported structural decline: runnable safety fixture classified `decline`, no mutation, not Blitz success.
- E17 path escape/symlink/traversal: runnable safety fixture classified `decline`, no mutation outside workspace, not Blitz success.
- E18 rollback failure case: runnable safety fixture classified `decline`, no partial mutation or truthful rollback failure, not Blitz success.

`bli-m3sj` can be checked for readiness only after these rows remain materialized and the deterministic self-check stays green.

## Claim language if this passes

Allowed:
> On Zai `glm-4.5-air`, minimal/default `blitz_edit` passed the locked all edit-type gate with route truth, Tokscale match, no hidden fallback, and lower total tokens than Pi core for success-intended paired rows.

Forbidden:

- universal provider-wide replacement;
- all models;
- all possible edits;
- structural support beyond the rows proven in this gate.
