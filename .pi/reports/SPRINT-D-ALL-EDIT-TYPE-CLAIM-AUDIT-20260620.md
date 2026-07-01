# Sprint D all edit-type claim audit

Date: 2026-06-20
Ticket: `bli-hndl`
Gate ticket: `bli-m3sj`
Status: scoped claim supported

## Exact scope audited

Only Sprint D all-edit-type gate evidence after `bli-z13z` fix:

- report: `.pi/reports/ALL-EDIT-TYPE-GATE-20260619-after-z13z.md`
- lock JSON: `.pi/reports/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-z13z.json`
- run root: `.pi/reports/pi-accounting-runs/20260619-after-z13z/`

No reruns. No implementation changes. No provider-wide claim.

## Provider / model

- provider: `zai`
- model: `glm-4.5-air`
- suffix: `20260619-after-z13z`
- gate status: `pass`

## Profiles / tools

- core lane: `core-optimized`
  - tool: `edit`
- Blitz lane: `blitz-edit`
  - tool/profile: minimal/default `blitz_edit`

Route truth: every accepted Blitz row reports only `blitz_edit`. No hidden `edit` / `apply_patch` fallback found in lock JSON.

## Row count / classes

Lock aggregate:

- row files: 14
- scenarios: `all-edit-types-gate`, `tiny-10`, `same-file-multi`, `mixed-20`, `class-d-config-docs-10`, `class-c-structural-10`, `structural-3`
- lanes: `core-optimized`, `blitz-edit`

Preflight registry self-check recorded by lock:

- `rows=18`
- `classes=18`
- `success=12`
- `safety=6`

Class coverage:

- E01 tiny exact single → `tiny-10`
- E02 exact same-file multi → `same-file-multi`
- E03 exact cross-file multi → `mixed-20`
- E04 config set/key edit → `class-d-config-docs-10`
- E05 doc/comment edit → `class-d-config-docs-10`
- E06 import edit → `all-edit-types-gate`
- E07 rename/local usage → `all-edit-types-gate`
- E08 structural function body replace → `class-c-structural-10`
- E09 structural insert-after function → `structural-3`
- E10 wrap body / try-catch → `all-edit-types-gate`
- E11 delete range → `all-edit-types-gate`
- E12 append section → `all-edit-types-gate`
- E13 noop/already-present → `all-edit-types-gate` safety
- E14 ambiguous match → `all-edit-types-gate` safety
- E15 no-match/stale context → `all-edit-types-gate` safety
- E16 unsupported structural → `all-edit-types-gate` safety
- E17 path escape/symlink/traversal → `all-edit-types-gate` safety
- E18 rollback failure case → `all-edit-types-gate` safety

## Correctness

Lock JSON row audit:

- bad rows: 0
- all 14 row files: `status=accepted`
- all 14 row files: `correct=true`
- scenario mismatch fixed: `true`
- reported `all-edit-types-gate` scenario stays `all-edit-types-gate`, not `tiny-10`

## Tokscale

- every row: `tokScaleMatched=true`
- token/session accounting match accepted for this lock
- Tokscale match means token/session-count agreement, not cost parity

## Schema / skill accounting

Blitz rows include resident schema + resident skill tokens:

- schema: 350 tokens per Blitz row
- skill: 268 tokens per Blitz row

Core rows show zero resident Blitz schema/skill tokens, as expected.

## Token delta

Lock aggregate totals:

- core total context: 34,923
- Blitz total context: 24,358
- delta: 10,565 fewer context tokens for Blitz
- savings: 30.25%

Claim allowed only for this provider/model/profile/lock aggregate.

## Excluded artifacts

Excluded from this claim:

- `20260619-after-bli-t3cl` run — invalid scenario emission (`all-edit-types-gate` reported as `tiny-10`)
- GPT-5.4-mini alternate gate — different provider/model, stopped on blocker
- older local/report-farm runs under `.pi/reports/natural-edit-runs/`
- dirty unrelated ticket/report artifacts not part of after-`z13z` lock

## Residual risks

- Single provider/model only: `zai/glm-4.5-air`.
- Single lock suffix only: `20260619-after-z13z`.
- Safety rows E13-E18 prove expected gate behavior here; they are not Blitz edit wins.
- Gate covers registered E01-E18 classes, not every possible edit shape.
- Provider-wide / GPT / historical scenario-mismatch residuals remain open for later sprint/epic work.
- Dirty `.tickets/bli-pg9j.md` and report farm were preserved, not normalized.

## Forbidden claims

Do not claim:

- Blitz is default/core replacement across providers.
- Blitz wins for all models.
- Blitz handles all possible edits.
- Safety declines/noops are edit successes.
- Structural support extends beyond rows proven by this gate.
- Old `20260619-after-bli-t3cl` evidence supports token claims.

## Audit conclusion

Supported scoped claim:

> On Zai `glm-4.5-air`, minimal/default `blitz_edit` passed Sprint D locked all-edit-type gate after `bli-z13z`, with route truth, correctness, Tokscale match, resident schema/skill accounting, no hidden fallback, and 10,565 fewer aggregate context tokens than Pi core across 14 locked row files.

Do not close parent epic from this audit. Provider-wide/universal replacement remains open.
