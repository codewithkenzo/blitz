# Sprint F impact survey — 2026-06-20

Status: exploratory telemetry, not release/audit claim.

## Scope

- Providers: `zai/glm-4.5-air`, `openai-codex/gpt-5.4-mini`.
- Rows: `tiny-exact`, `same-file-multi`, `same-file-doc-comments`, `config-env-update`, `structural-body`.
- Lanes: core + Blitz.
- Raw model runs: 20 / 20 cap. No retries.
- Harness: `bench/natural-edit.ts --tokscale --keep-temp` spawn harness.
- Raw root: `reports/pi-accounting-runs/20260620-sprint-f-impact/`.

## Preflight

- `git status --short --branch --untracked-files=normal`: branch `feat/blitz-0.4-token-core-profile`; pre-existing `.tickets/bli-pg9j.md` dirty + report farm untracked preserved.
- `tk ready`: `bli-6uqs`, `bli-pg9j`, `bli-c9et`.
- `bun bench/natural-edit.ts --self-check-route-budget`: pass.
- `bun bench/natural-edit.ts --self-check-prompt-shapes`: pass.
- `zig build`: pass.

## Accounting

- Tokscale token match: 20/20.
- Timeouts: 0.
- Side-effect runs: 0.
- Auth/quota blocks: none observed.
- Hidden fallback: none observed in route outcomes; core rows reported `core_fallback`, Blitz rows reported `blitz_success` or `incorrect`.

## Current pair results

| Provider | Scenario | Core ok | Blitz ok | Core tokens | Blitz tokens | Δ tokens | Δ % | Status |
|---|---|:---:|:---:|---:|---:|---:|---:|---|
| openai-codex/gpt-5.4-mini | config-env-update | yes | yes | 1479 | 1526 | 47 | 3.2 | both_green |
| openai-codex/gpt-5.4-mini | same-file-doc-comments | yes | yes | 1572 | 1576 | 4 | 0.3 | both_green |
| openai-codex/gpt-5.4-mini | same-file-multi | yes | yes | 2162 | 2124 | -38 | -1.8 | both_green |
| openai-codex/gpt-5.4-mini | structural-body | yes | no | 6524 | 4868 | -1656 | -25.4 | blitz_red |
| openai-codex/gpt-5.4-mini | tiny-exact | yes | yes | 1558 | 1590 | 32 | 2.1 | both_green |
| zai/glm-4.5-air | config-env-update | yes | yes | 1993 | 1747 | -246 | -12.3 | both_green |
| zai/glm-4.5-air | same-file-doc-comments | yes | yes | 2074 | 1808 | -266 | -12.8 | both_green |
| zai/glm-4.5-air | same-file-multi | yes | yes | 2493 | 2321 | -172 | -6.9 | both_green |
| zai/glm-4.5-air | structural-body | no | yes | 3621 | 11166 | 7545 | 208.4 | core_red_blitz_green |
| zai/glm-4.5-air | tiny-exact | yes | no | 1977 | 1812 | -165 | -8.3 | blitz_red |

Δ% = `(Blitz tokens - core tokens) / core tokens`; only both-green rows can support token direction.

## Before vs after overlap

Previous source: `reports/PROVIDER-LANGUAGE-SURVEY-20260620.json`. Only overlapping scenarios shown; doc/comment + config rows had no previous provider-language row.

| Provider | Scenario | Prev status | Prev Δ% | Current status | Current Δ% | Δpp | Correctness shift |
|---|---|---:|---:|---|---:|---:|---|
| openai-codex/gpt-5.4-mini | same-file-multi | survey_green | 22.2 | both_green | -1.8 | -24 | core yes→yes, blitz yes→yes |
| openai-codex/gpt-5.4-mini | structural-body | survey_red_product | 5.3 | blitz_red | -25.4 | -30.7 | core yes→yes, blitz no→no |
| openai-codex/gpt-5.4-mini | tiny-exact | survey_green | 22 | both_green | 2.1 | -19.9 | core yes→yes, blitz yes→yes |
| zai/glm-4.5-air | same-file-multi | survey_green | 8.4 | both_green | -6.9 | -15.3 | core yes→yes, blitz yes→yes |
| zai/glm-4.5-air | structural-body | survey_red_product | -21.1 | core_red_blitz_green | 208.4 | 229.5 | core yes→no, blitz no→yes |
| zai/glm-4.5-air | tiny-exact | survey_green | 8.9 | blitz_red | -8.3 | -17.2 | core yes→yes, blitz yes→no |

## Findings

- Simple/token rows improved materially versus previous overlap: OpenAI tiny exact dropped from +22.0% to +2.1%; OpenAI same-file multi from +22.2% to -1.8%; Zai same-file multi from +8.4% to -6.9%.
- New doc/config telemetry: Zai Blitz saved tokens on green rows (`same-file-doc-comments` -12.8%, `config-env-update` -12.3%); OpenAI was near tie/slightly negative (`same-file-doc-comments` +0.3%, `config-env-update` +3.2%).
- Structural-body status mixed: Zai Blitz changed from previous red to green, but current Zai core row went red; OpenAI Blitz stayed red. No final structural claim.
- Sprint F prompt compaction appears to help simple rows, but correctness variance still blocks broad replacement/audit language.

## Provider-specific failures

- zai/glm-4.5-air tiny-exact blitz: route=incorrect, correct=false, exit=0, timeout=false, tokens=1812; small.ts: match=false, unchanged=true, matched=none; runDir=`reports/pi-accounting-runs/20260620-sprint-f-impact/natural-edit-runs/tiny-exact__blitz__0__2026-06-20T05-41-59-180Z`.
- zai/glm-4.5-air structural-body core: route=incorrect, correct=false, exit=0, timeout=false, tokens=3621; medium.ts: match=false, unchanged=false, matched=none; runDir=`reports/pi-accounting-runs/20260620-sprint-f-impact/natural-edit-runs/structural-body__core__0__2026-06-20T05-42-46-674Z`.
- openai-codex/gpt-5.4-mini structural-body blitz: route=incorrect, correct=false, exit=0, timeout=false, tokens=4868; medium.ts: match=false, unchanged=false, matched=none; runDir=`reports/pi-accounting-runs/20260620-sprint-f-impact/natural-edit-runs/structural-body__blitz__0__2026-06-20T05-44-59-418Z`.

## Caveats

- Spawn harness, not tmux pilot. Good telemetry, not publishable benchmark proof.
- One iteration per provider/scenario/lane. Model variance visible; no rerun fishing by design.
- Token deltas on red rows are diagnostic only.
- Cost remains unavailable in session totals; Tokscale token matching passed.
