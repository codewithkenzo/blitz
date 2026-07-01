# Research: Blitz universal edit taxonomy addendum

## Question
Validate adversarial universal edit taxonomy in `PLAN-0.5` + current taxonomy and tighten missing failure classes, benchmark coverage, and pass/fail gates for universal default-route evaluation.

## Findings

### Missing/weak classes in current taxonomy

Current taxonomy (A–K) already covers core edit intent but misses adversarial filesystem/security + lifecycle stressors.

1. **L. File lifecycle edits**
   - create file, rename file, move file, delete file, duplicate file.
   - Route must refuse ambiguous path ops, preserve existing file checksums, and keep atomicity across multi-step lifecycle operations.

2. **M. Import/usage graph integrity**
   - multi-file dependency rewires (add/rename export + update all call sites + remove dead imports).
   - Current `Renames/refactors` mentions export updates but lacks full graph-closure and consistency checks.

3. **N. Path and environment boundary safety**
   - path traversal (`../`, symlink targets, case collisions), write outside repo root, read-only/locked files.
   - Should be explicit test classes; expected outcome is deterministic decline.

4. **O. Formatting/index drift safety**
   - route must detect if requested edit would force full-file reformat/noisy diff and still remain correct; no-op when unchanged after formatting normalization.
   - Current taxonomy mixes this into docs/config/structural risk but not explicit.

5. **P. Multi-turn stale-context/adversarial context switching**
   - same row edited after prior failed attempt or changed by concurrent process; model asks to continue with stale snippets.
   - Should fail closed on stale assumptions; no implicit re-run patch from old context.

6. **Q. Policy/tooling escape-row prompts**
   - user prompts that mention tool forcing, schema spoofing, or asks non-edit actions in edit lane.
   - Should be explicit decline/route-fallback class.

### Benchmark groups to add

Add a separate adversarial track, layered by risk, to supplement plan v0.5 required groups.

1. **File lifecycle track** (L-class)
   - create/rename/move/delete/restore patterns; workspace-bound checks.

2. **Cross-file graph track** (M-class)
   - exported symbol rename + import/index/barrel updates + test fixture sync; overlap + ordering edge cases.

3. **Boundary safety track** (N-class)
   - path traversal, symlink, glob-expanded path ambiguity, case-sensitive vs case-insensitive mismatch.

4. **Formatter/validator track** (O-class)
   - edits that would alter formatting significantly but preserve intent; semantic validator/no-op assertions.

5. **Stale-context track** (P-class)
   - two-turn edits, interrupted runs, and prompt conflicts where previous edit changed target text.

6. **Prompt-attack track** (Q-class)
   - route-control, policy-override, multi-call spamming attempts, incorrect tool invocation attempts.

7. **Provider-schema resilience track**
   - per-provider open/reject behavior for tuple-style and compact schemas (plan already mentions provider matrix smoke; expand to adversarial schema payloads).

### Revised pass/fail criteria (adversarial-aware)

- **Core rule**: still requires **100% correctness + tokscale match** on all accepted rows.
- **Row-level outcomes**:
  - `blitz_mutated` = mutation done via Blitz and correctness true.
  - `route_declined` = explicit decline/no-op/fallback **allowed only when declared decline class**.
  - Any mutation in decline class = hard fail.
  - Any hidden fallback on `blitz_mutated` expectation = fail.
- **Class policy**:
  - Deterministic/safe classes (A–J + O): prefer `blitz_mutated`; decline allowed only with explicit class exception.
  - Boundary/attack/safety classes (N, Q, P): decline/fallback-first acceptable; must be explicit and non-mutating.
- **Per-provider minimums**:
  - Universal matrix minimum remains **76 rows/provider** (60%? Actually from taxonomy: 50+20+6 scripted). Keep, but split at least 6 classes above.
  - Mandatory `system-pass` for every provider: **>= 95% route-level pass** (correctness + intended outcome + explicit accounting).
  - Mandatory `blitz-op success` for non-safety classes: **>= 85% on aggregate** with no incorrect/unsafe mutations.
- **Hard fail conditions**:
  - `fallback_hidden`, `unsafe_mutation`, `schema_reject` unhandled in compatibility profile, `tokscale_mismatch`, non-deterministic multi-match mutation.

## Sources
- `.pi/docs/plans/PLAN-0.5-universal-blitz-edit-exodia.md`
- `.pi/research/blitz-universal-edit-taxonomy-20260611.md`

## Version / Date Notes
- Sourced from repo-local docs dated 2026-06-11.
- Plan is pre-implementation (design/research stage), taxonomy is salvage/research draft.

## Open Questions
1. Should lifecycle ops (create/rename/delete/move) count as mandatory universal classes in v1 or remain v1.1 risk lane?
2. For O-class formatter-heavy edits, is route required to preserve style exactly or only semantic validator pass?
3. Should route be required to avoid any fallback on classes A–E in v1, or explicit per-class fallback policy is acceptable for all safe edits?

## Recommendation
Adopt addendum classes (L–Q), add dedicated tracks P/N/Q/O/M/L, and enforce explicit class-aware outcome contracts before locking universal gate. Keep universal claim on **default-route outcome**, with class-conditional success/decline rules.
