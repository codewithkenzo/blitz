# Replacement gate claim audit — final-after-sh7d

Date: 2026-06-19  
Ticket: `bli-qgz1`  
Source lock ticket: `bli-o1pd`  
Status: scoped claim approved; universal/default-provider claim forbidden

## Scope audited

This audit covers only final lock artifacts:

- `.pi/reports/archive/history/REPLACEMENT-GATE-LOCK-20260619-final-after-sh7d.json`
- `.pi/reports/archive/history/REPLACEMENT-GATE-20260619-final-after-sh7d.md`

Runtime and benchmark scope:

- Provider/model: `zai` / `glm-4.5-air`
- Runner: `tmux`
- Plan: `.pi/docs/plans/current/PLAN-0.5C-token-replacement-gate.md`
- Artifact suffix: `final-after-sh7d`
- Rows: 6 scenarios x 2 lanes = 12 rows
- Lanes: `core-optimized`, `blitz-edit`
- Blitz profile evidence: `minimal-blitz-edit` profile dump at `/home/kenzo/dev/pi-blitz/.pi/reports/profile-dumps/minimal-blitz-edit-20260611.json`
- Source commits recorded by lock:
  - blitz: `4ab8d5448b913f03051aa567f1da773eb2b7c97b`
  - pi-blitz: `c5d468895cc136fa61a4b98e215961b9cccf9dbe`

## Decision

Scoped claim is supported:

> In the `final-after-sh7d` tmux replacement gate on `zai/glm-4.5-air`, 12/12 total comparison rows and 6/6 `blitz-edit` rows were accepted and correct, with Tokscale token matches on every row, all Blitz rows routed through `blitz_edit`, no core/apply_patch fallback, and 33.12% lower aggregate model-visible context than the core-optimized `edit` lane.

Not supported:

> Blitz is a universal/default replacement for Pi core edit across providers, natural prompts, all edit classes, or CI/release policy.

## Row evidence

| Scenario | Class | Core status | Core correct | Core tool | Core tokens | Blitz status | Blitz correct | Blitz tool | Blitz tokens | Tokscale |
| --- | --- | --- | --- | --- | ---: | --- | --- | --- | ---: | --- |
| `tiny-10` | A | accepted | yes | `edit` | 5950 | accepted | yes | `blitz_edit` | 3890 | matched |
| `mixed-20` | A/B/D | accepted | yes | `edit` | 10133 | accepted | yes | `blitz_edit` | 5911 | matched |
| `same-file-multi` | A | accepted | yes | `edit` | 1982 | accepted | yes | `blitz_edit` | 2249 | matched |
| `class-b-inserts-10` | B | accepted | yes | `edit` | 6623 | accepted | yes | `blitz_edit` | 4127 | matched |
| `class-c-structural-10` | C | accepted | yes | `edit` | 5415 | accepted | yes | `blitz_edit` | 4238 | matched |
| `class-d-config-docs-10` | D | accepted | yes | `edit` | 5991 | accepted | yes | `blitz_edit` | 3726 | matched |

Notes:

- 12/12 rows accepted and correct.
- `class-c-structural-10` Blitz row is accepted via `blitz_edit`; not declined.
- No accepted Blitz row used `edit`, core fallback, or `apply_patch`.
- `same-file-multi` is a row-level token loss for Blitz (2249 vs 1982); aggregate still passes. Do not claim Blitz wins every simple row.

## Token accounting

Lock aggregate:

- Core total context tokens: `36094`
- Blitz total context tokens: `24141`
- Delta: `33.12%` lower for Blitz
- Tiny guard: core `5950`, Blitz `3890` → pass
- Lock booleans: `correctness=true`, `routeOk=true`, `tokScaleOk=true`, `tokenThresholdOk=true`, `tinyOverheadOk=true`

Token claim allowed only for total model-visible context in this lock, not wall time, cost parity, or generic tokenizer estimates.

## Route truth

Core lane:

- Route tool: `edit`
- No Blitz credit assigned to core lane.

Blitz lane:

- Route tool: `blitz_edit`
- Declined: false for all Blitz rows
- No core/apply_patch fallback counted
- No noop/decline counted as success

## Correctness and Tokscale

Evidence from lock JSON and final MD:

- `status`: `passed`
- row count: `12`
- every row status: `accepted`
- every row correct: `true`
- every row `tokScaleMatched`: `true`
- every Tokscale delta: zero for input/output/cache/messages

## Residual risks

- Single provider/model lock only: `zai/glm-4.5-air`.
- Scripted replacement-gate scenarios only; not universal natural/adversarial coverage.
- Not provider-wide; no OpenAI/Anthropic/Gemini lock proven by this artifact.
- Not all edit shapes/languages/filesizes covered.
- CI/release enforcement of this exact lock is not asserted here.
- `same-file-multi` shows Blitz can lose tokens on a valid row; claims must stay aggregate/scoped.
- Prior failed/caveated/declined runs remain historical evidence; this audit supersedes them only for `final-after-sh7d` scope.

## Forbidden broader claims

Do not claim:

- `blitz_edit` is default-safe for all Pi edits.
- Blitz always beats core edit on tokens.
- Blitz is provider-wide validated.
- Blitz is natural-prompt/adversarial validated.
- Blitz can replace core edit without profile/scope caveats.
- Token savings imply latency savings or cost savings.
- Declines/noops/fallbacks count as Blitz wins.

## Release-note wording allowed

Use this wording or narrower:

> `blitz_edit` passed the 2026-06-19 `final-after-sh7d` scoped replacement gate on `zai/glm-4.5-air`: 12/12 total comparison rows and 6/6 `blitz-edit` rows accepted and correct, Tokscale matched all rows, all Blitz rows used `blitz_edit` with no core/apply_patch fallback, and aggregate model-visible context was 33.12% lower than core-optimized `edit` (24141 vs 36094 tokens). Scope: tmux runner, minimal blitz-edit profile, replacement-gate scenario set only.

## Audit result

`bli-qgz1` acceptance satisfied for scoped claim language. Epic should remain open unless renamed/scoped to this Sprint C gate, because current `bli-6uqs` title and linked/open work imply broader Exodia 0.5/provider-wide follow-up remains.
