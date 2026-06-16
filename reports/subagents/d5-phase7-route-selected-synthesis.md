# D5 Phase 7 route-selected synthesis

Date: 2026-06-09
Status: benchmark-only route-selected proof artifact created. Not Phase 7 completion. Not product-real core/apply_patch interception.

## Artifacts

- Script: `bench/phase7-route-selected-synthesis.ts`
- Markdown: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.md`
- JSON: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json`

## Selection rule

The script reads existing real tmux/Tokscale Phase 7 report JSON files only. It accepts rows only when `correctRate === 1`, Tokscale token match is `true`, no timeout, and exit codes are 0 when present. For each Phase 7 fixture it selects the accepted row with lowest `totalContextTokens`. Core baselines are lowest accepted `core` rows for the same fixture when present.

Core-selected rows are benchmark-level route choices from existing core evidence. They do not mean `pi_blitz_route_edit` invokes core/apply_patch.

## Selected-route summary

| Case | Fixture | Selected lane/tool | Selected total context | Core baseline total | Status |
|---|---|---|---:|---:|---|
| one-line return expression | `semantic/arrow-replace-return` | router/`pi_blitz_route_edit` | 10,821 | — | accepted; no core baseline |
| tiny exact text replace | `small/wrap-tail` | core/`edit` | 8,574 | 8,574 | accepted; core cheapest |
| small config key | `config/key-update` | core/`edit` | 8,263 | 8,263 | accepted; core cheapest |
| insert logging line | `logging/insert-timer` | core/`edit` | 8,785 | 8,785 | accepted; core cheapest |
| wrap function body | `medium-10k/wrap-body` | — | — | — | incomplete |
| replace long function body section | `long-section/replace-return` | — | — | — | incomplete |
| multi-hunk same-file edit | `multi/large-structural` | — | — | — | missing |
| rename within file | `rename/function-name` | core/`edit` | 8,598 | 8,598 | accepted; core cheapest |
| Markdown section append | `markdown/append-section` | router/`pi_blitz_route_edit` | 10,556 | — | accepted; no core baseline |
| TSX component prop/body tweak | `tsx/component-prop-body` | — | — | — | missing |
| JSON key update | `json/config-key` | core/`edit` | 8,484 | 8,484 | accepted; core cheapest |
| YAML key update | `yaml/config-key` | core/`edit` | 8,696 | 8,696 | accepted; core cheapest |
| TOML key update | `toml/config-key` | core/`edit` | 8,329 | 8,329 | accepted; core cheapest |
| HTML small edit | `html/small-edit` | core/`edit` | 8,336 | 8,336 | accepted; core cheapest |
| CSS small edit | `css/small-edit` | core/`edit` | 8,559 | 8,559 | accepted; core cheapest |

## START gate result

Evidence supports benchmark-level route selection for rows with accepted core/router candidates: the lower-token accepted row is selected, mostly core. This proves the gate only at benchmark-report level for those rows. It does not prove runtime core interception, apply_patch fallback, or Phase 7 completion.

Rows without paired accepted evidence remain unproven.

## Remaining gaps

- No direct apply_patch baseline exists in current harness evidence.
- No product-real `pi_blitz_route_edit` core/apply_patch invocation exists; core selections are report-level only.
- Current structural preservation missing: `multi/large-structural` absent, `medium-10k/wrap-body` no accepted current row in selected evidence.
- `tsx/component-prop-body` missing.
- `logging/insert-timer` lacks accepted router/Blitz evidence; selected proof uses core only.
- `long-section/replace-return` lacks accepted evidence; both router and core attempts failed in selected reports.
- `semantic/arrow-replace-return` lacks paired accepted current core baseline.
- `markdown/append-section` lacks accepted core baseline; core attempts failed.
- HTML router row remains accepted but extreme outlier; benchmark selection chooses core.

## Verification

Pending at time of write; final agent response records commands and commit.

## 2026-06-09 structural + semantic evidence update

Synthesis script now includes:
- `reports/pi-tmux-phase7-structural-core-20260609-d5.json`
- `reports/pi-tmux-phase7-structural-current-20260609-d5.json`
- `reports/pi-tmux-phase7-structural-router-20260609-d5.json`
- `reports/pi-tmux-phase7-semantic-core-20260609-d5.json`
- `reports/pi-tmux-phase7-semantic-router-20260609-d5.json`

Regenerated artifacts:
- `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.md`
- `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json`

Changed selected outcome:
- `semantic/arrow-replace-return`: selected router/`pi_blitz_route_edit`, total context 10,821, core baseline 18,845, accepted as benchmark row.
- `semantic/tsx-replace-return`: selected core/`edit`, total context 8,516, router accepted at 10,436 but loses to core.
- `multi/large-structural`: selected current Blitz/`pi_blitz_patch`, total context 30,913, accepted; no accepted core baseline.
- `medium-10k/wrap-body`: still incomplete; core timed out/Tokscale mismatch, current Blitz incorrect, router incorrect/timeout in selected evidence.

Status remains benchmark-only. Core-selected rows are evidence selection, not runtime core/apply_patch interception by `pi_blitz_route_edit`. Phase 7 remains **NO** because structural preservation is incomplete, direct apply_patch baseline is absent, and product-real routing fallback remains unproven.


## 2026-06-10 update

Synthesis regenerated with new evidence files:
- `reports/pi-tmux-phase7-wrapbody-rerun-20260610-d5.json` (stale/failed timeout, preserved)
- `reports/pi-tmux-phase7-wrapbody-rerun2-20260610-d5.json` (pre-fix rejected)
- `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json` (accepted)
- `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.json` (accepted core)
- `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.json` (accepted router)

Updated selections:
- `medium-10k/wrap-body`: accepted `blitz/pi_blitz_wrap_body`, total context 30,087, no accepted core/apply_patch baseline.
- `long-section/replace-return`: selected `core/edit`, total context 9,769; router accepted at 11,122 but loses.

Phase 7 remains NO. Synthesis remains benchmark-only; no product-real `pi_blitz_route_edit` core/apply_patch interception is proven.
