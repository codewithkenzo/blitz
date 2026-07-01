# Research: Final default-replacement claim readiness for `blitz` + `pi-blitz`

## Question
What evidence is required to support a final claim that `@codewithzenko/pi-blitz` can replace Pi core `edit` by default, and what is currently verified?

## Answer / recommendation
Current evidence is **insufficient for a universal final claim**. We have strong proof for a **scoped, benchmark-anchored replacement posture** (profile-aware tool surface, explicit no-fallback route semantics, and required gate rows under at least one benchmark variant), but we do not yet have a clean, cross-provider, cross-scenario universal acceptance artifact.

**Recommended decision now:** keep final claim blocked until:
1. a new lock run includes required realistic streak/row coverage with fully preserved artifacts and zero ambiguous or partial status, and
2. CI/release enforces the same lock file as a pre-merge guard.

---

## Findings (claim-audit)

### Claim 1 — `PI_BLITZ_TOOL_PROFILE` is real, enforced routing control for tool visibility.
**Status: Verified.**
- `index.ts` reads `process.env.PI_BLITZ_TOOL_PROFILE`, resolves via `resolvePiBlitzToolProfile`, and registers only that profile’s tools.
- `tool-profiles.ts` defines `minimal|router|semantic|structural|admin|full` and errors on invalid values (`invalid PI_BLITZ_TOOL_PROFILE=...; expected ...`).
- `resolvePiBlitzToolProfile` defaults to `minimal` when env is missing.
- `PI_BLITZ_TOOL_PROFILE` is passed through in both `piArgs` (matrix runner) and benchmark artifact capture.

**Evidence:** `/home/kenzo/dev/pi-blitz/index.ts`, `/home/kenzo/dev/pi-blitz/src/tool-profiles.ts`, `/home/kenzo/dev/blitz/bench/pi-matrix.ts`.

### Claim 2 — Route semantics enforce explicit no-write/decline behavior (no hidden internal fallback).
**Status: Verified.**
- `pi_blitz_route_edit` computes route decisions and returns `routeDeclineResult` with `status:"declined"`, `terminal:true`, `noWrite:true`, `actionRequired:"use_external_core_or_apply_patch"`, and includes reason text.
- Route result text is parseable as declined (`"route declined"`) and parsed by natural harness as an explicit `decline`/`fallback` outcome rather than being inferred as success.

**Evidence:** `/home/kenzo/dev/pi-blitz/src/tools.ts` (`routeDeclineResult`, `routeEditToolDef`), `/home/kenzo/dev/blitz/bench/natural-edit.ts` (`RouteOutcome`, route probe/parser, acceptance rule).

### Claim 3 — The benchmark harness captures the required context/token accounting needed for truthful route claims.
**Status: Partially verified (sufficient for scoped claims).**
- `bench/pi-matrix.ts` captures per-run: schema/tool spec tokens, resident skill tokens, prompt tokens, tool-call arg tokens, output tokens, cache read/write, residual input tokens, total context, and row-level command/session provenance.
- `captureAccountingArtifacts()` writes serialized tool-spec snapshots + skill/token metadata for each profile and run.
- `parseSession` and `compareSessionWithTokScale()` reconcile local tokenization with Tokscale and include match/fail states.
- Pairwise savings are only counted when both rows are correct and total context does not increase.
- natural harness similarly preserves run dirs, session JSONL, side-effects, and route outcomes (`blitz_mutated`, `core_mutated`, `decline`, `noop`, etc.) with accepted criteria requiring correctness + Tokscale match.

**Evidence:** `/home/kenzo/dev/blitz/bench/pi-matrix.ts`, `/home/kenzo/dev/blitz/bench/natural-edit.ts`.

### Claim 4 — A scoped replacement lock has been produced, but it is not the final universal baseline.
**Status: Verified for scoped scope; not universal.**
- `reports/REPLACEMENT-GATE-LOCK-20260611.json` records required class rows, tool/skill hash provenance, run roots, and aggregate savings (84.23% aggregate context savings over 6 scenario rows).
- D5 review report marks gate pass for that specific lock and states row-level criteria were met with no accepted rows relying on internal fallback.
- However, these rows do not replace the need for broader natural/adversarial/provider-complete lock coverage; several remediation and partial-failure reports remain open.

**Evidence:** `/home/kenzo/dev/blitz/reports/REPLACEMENT-GATE-LOCK-20260611.json`, `/home/kenzo/dev/blitz/reports/D5-REVIEWER-AUDIT-20260611.md`.

### Claim 5 — Provider/schema portability and universal route stability are not yet fully proven.
**Status: Not yet sufficient.**
- OpenAI/Codex initially rejected tuple-array tool schema; corrected in `blitz_edit` schema and rerun succeeded (documented in GPT-5.4 rerun report).
- Natural matrix attempts on ZAI are marked partial/failing with repeated Blitz lane failures, empty error text retry loops, and grouped-payload edge cases.
- No official lock artifact demonstrates universal pass across all required providers + full scenario set with stable outcomes.

**Evidence:** `/home/kenzo/dev/blitz/reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md`, `/home/kenzo/dev/blitz/reports/NATURAL-ZAI-PROVIDER-MATRIX-PARTIAL-FAILURE-20260612.md`, `/home/kenzo/dev/blitz/reports/NATURAL-ZAI-FAILED-ROWS-REMEDIATION-20260612.md`.

### Claim 6 — CI/release is not yet enforcing replacement lock.
**Status: Verified negative.**
- `bench/run.ts` smoke gate runs only on Linux-musl during CI; it is not tied to replacement lock JSON/audit artifacts.
- `.github/workflows/ci.yml` has no lock file assertion, route-fallback policy check, or CI fail-stop on lock failure.

**Evidence:** `/home/kenzo/dev/.github/workflows/ci.yml`, `/home/kenzo/dev/blitz/bench/run.ts`.

---

## Source notes

### Kept (used for final recommendation)
- `docs/plans/PLAN-0.4-context-token-optimization.md` + `docs/plans/START-0.4-context-token-core.md`
- `pi-blitz/index.ts`, `pi-blitz/src/tool-profiles.ts`, `pi-blitz/src/tools.ts`, `pi-blitz/scripts/dump-tool-specs.ts`
- `blitz/bench/pi-matrix.ts`, `blitz/bench/natural-edit.ts`
- `reports/REPLACEMENT-GATE-LOCK-20260611.json`, `reports/D5-REVIEWER-AUDIT-20260611.md`
- `reports/NATURAL-*` remediation and coverage reports
- `.github/workflows/ci.yml`, `bench/run.ts`

### Dropped/low-confidence for final universal claim
- First-pass natural smokes (`NATURAL-EDIT-HARNESS-20260611.md`) due timeout/timing artifacts and partial parsing issues.
- Any report marked “partial/failed” or with caveat-only scope.

## Version / date notes
- Evidence is current as of repo timestamped `2026-06-19` and reflects post-`0.4` plan updates.
- Last known accepted lock object is `REPLACEMENT-GATE-LOCK-20260611.json` (and D5 audit).

---

## Open questions (must be answered before final default claim)

1. Do we require universal-pass across at least one additional provider baseline (currently lock evidence is strongest for specific ZAI + GPT-5.4 scenarios)?
2. Should `pi_blitz_route_edit` become the actual product default in runtime path, or remain synthesis-only until explicit core-tool facade integration is shipped?
3. What route outcome threshold is required for lock closure (e.g., no `decline_or_no_mutation` in required rows, no schema/token-mismatch rows)?
4. Should single-row + streak lock require Tokscale parser match for every pair at hard-stop level?

---

## Builder-ready implications

### Required evidence artifacts before final claim
- New replacement lock JSON/MD produced after remediation, including:
  - accepted rows for required classes/streaks,
  - explicit failed/skipped rows preserved,
  - raw run roots + session JSONLs + Tokscale outputs,
  - profile/tool-spec/skill snapshot hashes in same lock artifact,
  - route outcomes (`blitz/core/decline/fallback`) per row.
- Same lock format used for both benchmark matrix and natural matrix or explicit reason for omission.
- CI gate update to enforce lock pass before merge.

### Recommended hard blockers (fail gate)
- Any required row in lock is in `blitz_failed` / `incorrect` / `decline` / Tokscale mismatch state.
- Any claim row lacks residual reconciliation with local + Tokscale accounting.
- Any required provider/provider-model lacks a clean full run.
- Any unresolved benchmark row where route result text suggests fallback/decline but is treated as success.

### Practical next steps (in order)
1. Rerun and finalize a **provider-complete natural/adversarial matrix** after remediation.
2. Regenerate lock artifact tying in all required rows + exact artifacts and hash manifests.
3. Add CI policy/command requiring lock file generation + pass status + row integrity checks.
4. Keep route/no-fallback invariants explicit in both runtime and harness output.

---

## Short answer for decision makers
- **Current top 3 findings:**
  1) profile + no-hidden-fallback control is implemented and measurable;
  2) accounting stack is mature enough for scoped claims;
  3) universal/default claim is blocked by incomplete natural/provider evidence and missing CI lock enforcement.
- **Confidence:** `~0.26` for universal claim (`No`); `~0.84` for scoped scripted-gate claim under current documented conditions.
- **Next action:** do not ship final default-replacement claim until one non-caveated lock run closes OpenAI/ZAI full row + natural coverage and CI enforces it.
