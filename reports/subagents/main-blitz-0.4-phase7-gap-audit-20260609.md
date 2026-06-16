# Main Phase 7 gap audit — Blitz 0.4 context/token core replacement

Date: 2026-06-09
Branch: `feat/blitz-0.4-token-core-profile`
Latest evidence commit before this audit: `26af905 docs(bench): record phase7 escape rerun evidence`

## Objective restated

Complete the context/token core-replacement work described by:

- `docs/plans/START-0.4-context-token-core.md`
- `docs/plans/PLAN-0.4-context-token-optimization.md`

Concrete completion means real Pi/tmux/Tokscale evidence proves the Phase 7 replacement benchmark and the START gates. Passing tests or having many reports is not enough.

## START acceptance gate checklist

| Gate | Current evidence | Status |
|---|---|---|
| `zig build` passes | D5 escape rerun reported `zig build && zig build test` passed. | Met for current branch |
| `zig build test` passes | Same D5 verification. | Met for current branch |
| Harness reports token/context breakdown, not only wall time | Phase 7 reports include schema, skill, prompt, arg, output, cache, result payload, residual input, total context, wall time. | Met |
| Tokscale/token accounting matches publishable rows | New rows record Tokscale match yes. | Met for accepted rows |
| Correctness 100% for accepted savings rows | No accepted savings rows yet. Correctness is enforced for accepted evidence rows. | Not applicable / no savings rows |
| Resident tool/skill overhead measured; >=70% reduction for common lanes | Router profile reports ~564 schema tokens + ~580 skill tokens and ~84% reduction vs full. | Met |
| Structural rows preserve current large token wins | Not re-proven in final/current Phase 7 matrix after latest changes. Earlier structural wins exist but are not yet rerun/audited against current router/core/full profiles. | Missing |
| Simple both-correct rows beat/tie core after overhead OR router chooses core/apply_patch with explicit token proof | Latest simple/text/config rows generally lose to core. `pi_blitz_route_edit` fallback is no-write decline, not product-real core/apply_patch. | Missing |
| Report lists failed/skipped rows and caveats; no hidden failures | Reports preserve failed terminal/quoted/escape rows and caveats. | Met |

## PLAN Phase 7 checklist

Benchmark set from PLAN Phase 7:

| Required case | Evidence today | Gap |
|---|---|---|
| one-line return expression | `semantic/arrow-replace-return` router parserfix accepted, Tokscale yes. | Needs paired core/current Blitz/optimized/router-selected comparison in final matrix. |
| tiny exact text replace | `small/wrap-tail` router accepted after escape rerun; core accepted; router loses by 1,980 tokens. | Needs router-selected core proof or overhead reduction. |
| small config key | `config/key-update` core accepted; router accepted unquoted `sk`; router loses by 2,172 tokens. | Needs router-selected core proof or overhead reduction. |
| insert logging line | `logging/insert-timer` router still correctness 0%; core accepted. | Needs correct optimized route or selected core/apply_patch proof. |
| wrap function body | Earlier structural artifacts exist, but current final matrix not rerun. | Missing structural preservation rerun. |
| replace long function body section | `long-section/replace-return` router correctness 0%; core also failed in escape core run. | Needs correct route/current Blitz/core/apply_patch evidence. |
| multi-hunk same-file edit | Earlier fixture coverage exists; current final matrix not rerun. | Missing structural preservation/current comparison. |
| rename within file | `rename/function-name` router/core accepted; router loses by 1,917 tokens. | Needs selected core proof or overhead reduction. |
| Markdown section append | Router accepted, but two core attempts failed; excluded from savings. | Needs accepted paired baseline or documented core failure handling. |
| TSX component prop/body tweak | Covered in fixture list but no accepted current final row in recent evidence. | Missing final paired matrix row. |
| JSON/YAML/TOML top-level key update | Router/core accepted for all three; router loses to core. | Needs selected core proof or overhead reduction. |
| HTML/CSS small edit | Router/core accepted; both lose to core, HTML badly. | Needs selected core proof or overhead reduction; investigate HTML outlier. |

Required Phase 7 metrics are present in generated JSON/MD rows when a row is run: correctness, output tokens, arg tokens, schema/skill tokens, prompt/input/cache Tokscale, total context, wall time, route/tool profile.

## Current conclusion

Goal is **not complete**.

Reasons:

1. Router-selected path is not best/within 5–10% for simple both-correct rows; it often exceeds core by ~1.9k tokens and once by 134k tokens.
2. `pi_blitz_route_edit` cannot invoke product-real core/apply_patch; unsupported fallback remains a no-write decline, so route-to-core proof is missing.
3. Structural rows have not been rerun in the current final Phase 7 matrix to prove preservation of the known ~9k token wins.
4. Several required cases are missing paired current-core/current-Blitz/optimized-router evidence.
5. No direct apply_patch/OpenAI-style baseline exists in the harness.
6. Latest pi-blitz extension path was used read-only from `/home/kenzo/dev/pi-blitz/dist/index.js`; companion repo state/reproducibility caveat must remain explicit in reports.

## Next concrete slice

Next builder should add/run a route-selected Phase 7 proof path without pretending `pi_blitz_route_edit` intercepts core:

- either a benchmark-level `selected` lane that chooses existing core rows when core is cheaper and Blitz/router rows only when accepted and cheaper;
- or a documented runtime-facing facade/wrapper plan if product-real routing requires pi-blitz changes.

The slice must produce real tmux/Tokscale artifacts and keep claims scoped. If it is benchmark-only, report it as benchmark-only and do not claim core replacement.
