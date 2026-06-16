# Pi/tmux/Tokscale cumulative edit-streak synthesis

Date: 2026-06-10
Status: exploratory; not default-ready proof
Baseline/fallback: Pi core `edit` only. Codex/OpenAI `apply_patch` is out of scope.

## Method

- Source synthesis: `reports/pi-tmux-phase7-route-selected-synthesis-20260609-d5.json`.
- Rows are accepted only when correctness is 100%, Tokscale token match is yes, no timeout, and exit codes are 0.
- This is cumulative synthesis from independent real Pi/tmux/Tokscale rows, not true same-session sequential execution.
- Raw artifacts remain in source report run roots under `reports/pi-tmux-runs/`.

## Cumulative scenarios

| Scenario | Edits | Rows with core baseline | Selected total context | Core total context | Delta vs core | Savings vs core | Correct | Verdict |
|---|---:|---:|---:|---:|---:|---:|---|---|
| 10 tiny/core-likely edits | 10 | 10 | 85140 | 85140 | 0 | 0.0% | yes | selected <= core |
| 20 mixed language/config/markdown/code edits | 20 | 17 | 221987 | 166479 | -55508 | -33.3% | yes | not proven |
| same-file multi-edit scenario | 1 | 0 | 30913 | — | — | — | yes | not proven |

### Token breakdown by scenario

| Scenario | schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 tiny/core-likely edits | 0 | 0 | 1552 | 767 | 3579 | 65695 | 0 | 244 | 12536 | 85140 |
| 20 mixed language/config/markdown/code edits | 14882 | 2866 | 13289 | 1611 | 8409 | 136099 | 0 | 558 | 24914 | 221987 |
| same-file multi-edit scenario | 6595 | 580 | 4891 | 115 | 754 | 9170 | 0 | 59 | 1459 | 30913 |

## Representative single edits

| Fixture | Selected lane/tool | Selected context | Core context | Delta vs core | Correct | Source |
|---|---|---:|---:|---:|---|---|
| semantic/arrow-replace-return | router/pi_blitz_route_edit | 10821 | 18845 | 8024 | yes | reports/pi-tmux-phase7-router-semantic-parserfix-20260609.json |
| config/key-update | core/edit | 8263 | 8263 | 0 | yes | reports/pi-tmux-phase7-config-core-20260609-d5.json |
| long-section/replace-return | core/edit | 9769 | 9769 | 0 | yes | reports/pi-tmux-phase7-longsection-rerun-20260610-d5.json |
| medium-10k/wrap-body | blitz/pi_blitz_wrap_body | 30087 | — | — | yes | reports/pi-tmux-phase7-wrapbody-zigfix-20260610-d5.json |
| multi/large-structural | blitz/pi_blitz_patch | 30913 | — | — | yes | reports/pi-tmux-phase7-structural-current-20260609-d5.json |

## Verdict

Not default-ready. Tiny/config/text cumulative route mostly proves Pi core remains default-cheaper. Blitz/router has targeted wins, especially semantic arrow replace, and structural capability remains useful, but default-cheaper streak proof needs true sequential same-session harness plus more accepted paired baselines.
