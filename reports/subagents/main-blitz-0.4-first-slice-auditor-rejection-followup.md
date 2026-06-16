# Auditor rejection follow-up — Blitz 0.4 Phase 0/1

Date: 2026-06-09
Branches:
- Blitz: `feat/blitz-0.4-token-core-profile`
- pi-blitz: `feat/blitz-0.4-token-core-profile`

## Why this follow-up exists

The first completion attempt was rejected because the auditor required stricter evidence from the START/PLAN wording:

1. A GPT/OpenAI-family matrix, not only the ZAI `glm-4.5-air` matrix.
2. More profile-variant comparison evidence.
3. Structural profile schema reduction >=70% versus full.
4. Better evidence/caveats for structural rows and simple-row routing.

This report records the corrective work after that rejection.

## Corrections made

### 1. Structural profile schema reduced

`/home/kenzo/dev/pi-blitz-token-profile` now has commit `990095c refine structural Blitz profile`.

Structural profile now exposes only:

- `pi_blitz_replace_body_span`
- `pi_blitz_multi_body`
- `pi_blitz_patch`

Verification in pi-blitz:

- `bun run typecheck && bun test && bun run build` — passed.

Measured with Blitz harness dump:

- `structural` schema tokens: `1344`
- full profile schema tokens: `5517`
- reduction: `75.6%`

This closes the earlier structural >=70% schema reduction gap.

### 2. GPT/OpenAI-family matrix added

New GPT-family matrix artifacts:

- `reports/pi-tmux-matrix-20260609-gpt-full-profile-035706.json`
- `reports/pi-tmux-matrix-20260609-gpt-full-profile-035706.md`
- `reports/pi-accounting-runs/20260609-gpt-full-profile-035706/`
- `reports/pi-tmux-runs/20260609-gpt-full-profile-035706/`
- `reports/bench-logs/20260609-gpt-full-profile-035706.log`

Run identity:

- provider: `openai-codex`
- model: `gpt-5.5`
- runner: `tmux`
- Tokscale: required
- profile: `full`
- artifact profiles: all

Summary:

- rows: `26`
- clean/correct rows: `10`
- failed/caveated rows: `16`
- Tokscale token-match mismatches on exit-0 rows: `0`
- session JSONL paths: `26`

Important caveat: GPT/Codex row correctness was much worse than ZAI in this run. These rows are accepted as GPT-family measurement evidence only. They are not publishable savings evidence, and failed/caveated rows are not counted as savings.

### 3. GPT/OpenAI-family profile-supported comparisons added

New GPT-family profile-supported artifacts:

- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-semantic.json`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-semantic.md`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-structural.json`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-structural.md`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-minimal.json`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-minimal.md`
- matching `reports/pi-accounting-runs/20260609-gpt-profile-supported-035842-{semantic,structural,minimal}/`
- matching `reports/pi-tmux-runs/20260609-gpt-profile-supported-035842-{semantic,structural,minimal}/`
- `reports/bench-logs/20260609-gpt-profile-supported-035842.log`

Run identity:

- provider: `openai-codex`
- model: `gpt-5.5`
- runner: `tmux`
- Tokscale: required

Profile-supported row summaries:

- `semantic`: 10 rows (core + blitz on semantic fixtures), 5 clean/correct, 5 caveated, schema `1152` tokens (79.1% below full), no Tokscale token mismatches.
- `structural`: 8 rows (core + blitz on supported structural fixtures), 1 clean/correct, 7 caveated, schema `1344` tokens (75.6% below full), no Tokscale token mismatches.
- `minimal-v0`: 2 rows (core + blitz on `multi/large-structural`), 0 clean/correct, 2 caveated, schema `442` tokens (92.0% below full), no Tokscale token mismatches.

Important caveat: GPT/Codex generated many correctness failures. These are measurement/caveat evidence and profile schema evidence only; no savings claim is made from failed rows.

### 4. ZAI structural reduced rerun added for structural preservation signal

New ZAI structural-reduced artifacts:

- `reports/pi-tmux-matrix-20260609-zai-structural-reduced-040405.json`
- `reports/pi-tmux-matrix-20260609-zai-structural-reduced-040405.md`
- `reports/pi-accounting-runs/20260609-zai-structural-reduced-040405/`
- `reports/pi-tmux-runs/20260609-zai-structural-reduced-040405/`

Run identity:

- provider: `zai`
- model: `glm-4.5-air`
- runner: `tmux`
- Tokscale: required
- profile: `structural`
- schema tokens: `1344`

Summary:

- rows: 8
- clean/correct rows: 7
- failed/caveated rows: 1 (`multi/large-structural` core timed out; Blitz structural succeeded)
- no Tokscale token-match mismatches on exit-0 rows

Structural preservation/caveat interpretation:

- Reduced structural profile still executes the large structural Blitz patch route successfully: `multi/large-structural` Blitz row correct, exit 0, `pi_blitz_patch`, total context `37489`, while core timed out and is not counted as savings.
- Simple/tail rows like `medium-10k/marker-tail` and `huge-100k/marker-tail` remain recommended for core routing when Blitz loses or is not cheaper.
- Structural profile now meets schema target; row-level savings are still not broadly established and remain future-slice work.

## Current completion judgment

The auditor rejection gaps are addressed as far as this Phase 0/1 slice can address them:

- GPT/OpenAI-family matrix evidence now exists.
- Profile-supported GPT comparisons now exist with core pairwise rows where the profile supports the required Blitz tool.
- Structural profile now meets the >=70% schema reduction target.
- Reduced structural ZAI rerun shows the large structural Blitz route can still succeed while simple routes remain core-preferred.
- Failed/caveated rows are explicit and excluded from savings.
- No core-replacement claim is made.

Remaining work is still later-phase product work, not Phase 0/1 completion work:

- Phase 2 compact operation/IR to reduce argument/output overhead.
- Better runtime routing / core fallback proof for all profiles.
- More repeated green GPT rows for publishable claims.
- Full profile variants across unsupported rows would require either explicit skip-row support in the harness or broader profiles that would defeat schema reduction; current evidence records profile-supported comparison plus fail-closed profile behavior.
