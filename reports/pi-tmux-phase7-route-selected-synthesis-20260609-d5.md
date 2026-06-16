# Phase 7 route-selected synthesis — benchmark-only proof

Date: 2026-06-09
Status: benchmark-only route-selected synthesis; not Phase 7 completion; not product-real core/apply_patch interception.

## Method

- Source rows: `reports/pi-tmux-phase7-text-alias-router-escapes-20260609-d5.json`, `reports/pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json`, `reports/pi-tmux-phase7-markdown-core-escapes-20260609-d5.json`, `reports/pi-tmux-phase7-format-config-router-sk-20260609-d5.json`, `reports/pi-tmux-phase7-format-config-core-20260609-d5.json`, `reports/pi-tmux-phase7-config-router-sk2-20260609-d5.json`, `reports/pi-tmux-phase7-config-core-20260609-d5.json`, `reports/pi-tmux-phase7-router-semantic-parserfix-20260609.json`, `reports/pi-tmux-phase7-router-semantic-rerun-20260609.json`, `reports/pi-tmux-phase7-router-pilot-20260609-d5.json`, `reports/pi-tmux-phase7-structural-core-20260609-d5.json`, `reports/pi-tmux-phase7-structural-current-20260609-d5.json`, `reports/pi-tmux-phase7-structural-router-20260609-d5.json`, `reports/pi-tmux-phase7-semantic-core-20260609-d5.json`, `reports/pi-tmux-phase7-semantic-router-20260609-d5.json`, `reports/pi-tmux-phase7-wrapbody-rerun-20260610-d5.json`, `reports/pi-tmux-phase7-wrapbody-rerun2-20260610-d5.json`, `reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json`, `reports/pi-tmux-phase7-longsection-rerun-20260610-d5.json`, `reports/pi-tmux-phase7-longsection-router-rerun-20260610-d5.json`.
- Accepted row: correctness 100%, Tokscale token match yes, no timeout, exit code 0 when present.
- Selected route: lowest `totalContextTokens` among accepted real rows per fixture.
- Core baseline: lowest accepted `core` row for same fixture where present.
- Core selections below are benchmark-level choices from existing core rows. They do not mean `pi_blitz_route_edit` invokes core/apply_patch at runtime.

## Selected-route table

| Phase 7 case | Fixture | Status | Selected lane/tool | Selected total context | Core baseline total | Gate result | Evidence |
|---|---|---:|---|---:|---:|---|---|
| one-line return expression | semantic/arrow-replace-return | accepted | router/pi_blitz_route_edit | 10821 | 18845 | blitz-router-beats-or-ties-core | pi-tmux-phase7-router-semantic-parserfix-20260609.json |
| tiny exact text replace | small/wrap-tail | accepted | core/edit | 8574 | 8574 | route-selected-core-cheapest | pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json |
| small config key | config/key-update | accepted | core/edit | 8263 | 8263 | route-selected-core-cheapest | pi-tmux-phase7-config-core-20260609-d5.json |
| insert logging line | logging/insert-timer | accepted | core/edit | 8785 | 8785 | route-selected-core-cheapest | pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json |
| wrap function body | medium-10k/wrap-body | accepted | blitz/pi_blitz_wrap_body | 30087 | — | accepted-router-no-core-baseline | pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json |
| replace long function body section | long-section/replace-return | accepted | core/edit | 9769 | 9769 | route-selected-core-cheapest | pi-tmux-phase7-longsection-rerun-20260610-d5.json |
| multi-hunk same-file edit | multi/large-structural | accepted | blitz/pi_blitz_patch | 30913 | — | accepted-router-no-core-baseline | pi-tmux-phase7-structural-current-20260609-d5.json |
| rename within file | rename/function-name | accepted | core/edit | 8598 | 8598 | route-selected-core-cheapest | pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json |
| Markdown section append | markdown/append-section | accepted | router/pi_blitz_route_edit | 10556 | — | accepted-router-no-core-baseline | pi-tmux-phase7-text-alias-router-escapes-20260609-d5.json |
| TSX component prop/body tweak | semantic/tsx-replace-return | accepted | core/edit | 8516 | 8516 | route-selected-core-cheapest | pi-tmux-phase7-semantic-core-20260609-d5.json |
| JSON/YAML/TOML top-level key update | json/config-key | accepted | core/edit | 8484 | 8484 | route-selected-core-cheapest | pi-tmux-phase7-format-config-core-20260609-d5.json |
| JSON/YAML/TOML top-level key update | yaml/config-key | accepted | core/edit | 8696 | 8696 | route-selected-core-cheapest | pi-tmux-phase7-format-config-core-20260609-d5.json |
| JSON/YAML/TOML top-level key update | toml/config-key | accepted | core/edit | 8329 | 8329 | route-selected-core-cheapest | pi-tmux-phase7-format-config-core-20260609-d5.json |
| HTML/CSS small edit | html/small-edit | accepted | core/edit | 8336 | 8336 | route-selected-core-cheapest | pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json |
| HTML/CSS small edit | css/small-edit | accepted | core/edit | 8559 | 8559 | route-selected-core-cheapest | pi-tmux-phase7-text-alias-core-escapes-20260609-d5.json |

## START gate proof/disproof

For rows with accepted core and router/core candidates, selected benchmark route chooses the lower-token accepted row. Current evidence supports benchmark-level route-to-core proof for tiny text, config, rename, JSON/YAML/TOML, CSS, HTML. It does not prove product runtime core interception.
Rows without accepted paired core/router evidence remain unproven. Rows where router is accepted but core absent cannot prove beat/tie against core.

## Remaining gaps

- Benchmark-level route selection only: selected core rows are proof choices from existing evidence, not product-real pi_blitz_route_edit core/apply_patch interception.
- No direct apply_patch baseline exists in current harness evidence; current harness lanes are core/edit, blitz, and router facade only.
- Structural preservation improved: medium-10k/wrap-body and multi/large-structural now have accepted current Blitz evidence, but neither has an accepted core/apply_patch baseline for beat/tie proof.
- TSX semantic row has accepted core and router rows, but selected benchmark route chooses core; this does not prove product-real core fallback.
- Semantic arrow row has accepted router and core rows and router is cheaper in selected evidence; current proof is still benchmark evidence, not product runtime replacement.
- Long-section now has accepted core and router rows after fixture escaping fix; selected benchmark route chooses core.
- Markdown append has accepted router evidence but accepted core baseline is absent; core attempts failed.
- HTML router row is accepted but extreme 142,615-token outlier; selected path chooses accepted core row for benchmark proof only.

## Candidate row caveats

Failed/incomplete rows remain preserved in source reports and raw tmux run roots. This synthesis does not fabricate, delete, or overwrite raw evidence.
