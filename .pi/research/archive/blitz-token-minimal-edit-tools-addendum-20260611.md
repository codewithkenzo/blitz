# Research: Blitz token-minimal edit tool addendum (2026-06-11)

## Question
Can token-minimal edit tool design in `blitz_edit` be improved to keep gains across unscripted Universal-Route benchmarks while avoiding hidden fallback inflation?

## Findings
- `PLAN-0.5` already frames universal success as **route-level**, not tool-level (Blitz-only wins + explicit fallback accounting) and requires 100% correctness + Tokscale match. This should be enforced in all future tool-profile changes to avoid false wins. (Source: `.pi/docs/plans/archive/PLAN-0.5-universal-blitz-edit-exodia.md`)
- The existing recommendation file is directionally correct: split cheap exact flow from richer structural flow, shrink visible schema, minimize args, and avoid always-visible verbose tools. Evidence indicates biggest token wins are in schema/toolset surface + arg repetition, not in function output payload shape. (Source: `.pi/research/archive/blitz-token-minimal-edit-tools-20260611.md`)
- New validated pattern for next slice: **three-tier tool profile** (exact-only -> default mixed -> advanced/admin), with same-file shorthand as first-class in exact profile.
  - Exact-only: `f + x` only, optional script `s` for bulk exact.
  - Mixed default: keep alias op names (`x`, `rb`, `ia`, etc.) but hide advanced operations.
  - Advanced/admin: explicit opt-in profile for tests/diagnostics.
- Two concrete arg-compression wins are high-confidence and low-risk:
  - **Path dictionary or same-file default** to avoid repeating long paths.
  - **Structured object ops** (`{f,x:[...]}` / `{f,rb:[...]}`) for natural prompts and easier model compliance than tuple-heavy nested forms.
- DSL string strategy remains a strong fallback if tuple compatibility issues persist, but should stay behind strict parser+error telemetry; use it as profile variant, not global default, since escape/validation risk increases with model variability.
- Operational risk ranking:
  1. Path-dictionary ambiguity (path index mismatch, cwd traversal).
  2. Parser drift for DSL/object normalization.
  3. Profile explosion causing schema/tool tax backslide.
  4. Decline behavior becoming silent fallback if route telemetry not logged.

## Sources
- `.pi/docs/plans/archive/PLAN-0.5-universal-blitz-edit-exodia.md`
- `.pi/research/archive/blitz-token-minimal-edit-tools-20260611.md`

## Version / Date Notes
- Reviewed 2026-06-11 against current plan + existing recap.
- No external API/library claim changes requested in this pass.
- Open-loop items in plan still include provider matrix expansion (Zai/OpenAI + possibly others) and adversarial/natural benchmark evidence before locking universal profile.

## Open Questions
1. Should exact-only profile become default first-pass before natural-routing heuristics in all models, or only for short prompts/low-risk classes?
2. Is path compression safest as same-file default, explicit file dictionary, or a two-key scheme (`f` + relative path index)?
3. Should `decline` output be canonical in default profile (`decline CODE`) to keep universal telemetry clean and avoid false positives?

## Recommendation
Lock next experiment order to minimize risk:
1) same-file exact schema
2) minimal path-compression variant
3) object-op JSON variant
4) optional DSL fallback profile
Then measure on natural/adversarial matrix with explicit route outcome labels (`blitz`, `decline`, `fallback`) before profile promotion.

## Next experiments
- Run matrix rows: tiny + mixed + structural natural prompts with same `blitz_x` vs `blitz_edit` split.
- Compare token delta from path compression and object-op schema separately to avoid confounded gains.
- Add regression test proving path/route telemetry distinguishes fallback from true success.
