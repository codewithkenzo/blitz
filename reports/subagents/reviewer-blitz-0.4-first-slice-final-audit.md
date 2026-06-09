# Independent final audit — Blitz 0.4 Phase 0/1 first slice

Date: 2026-06-09
Reviewer lane: external model audit via `xai_generate_text` after pi-subagents reviewer retry failed from provider billing/usage limits.

## Verdict

APPROVE — complete as a Phase 0/1 measurement/profile-registration evidence slice, with caveats. Do not claim Blitz is a core-edit replacement yet.

## Spec Compliance

- PASS: Phase 0 harness captures required accounting fields: visible tools, serialized tool specs/tokens, resident skill snapshot/tokens, prompt tokens, tool arg tokens, output/result tokens, cache/input/Tokscale fields, residual input, route/profile, correctness, and total model-visible context.
- PASS: Raw artifacts are durable under `reports/`: matrix JSON/MD, accounting roots, tokenizer metadata, per-profile tool spec JSON, skill snapshots, and tmux/session JSONL run roots.
- PASS: Phase 1 profiles exist in `pi-blitz`: `minimal`, `semantic`, `structural`, `admin`, `full`; missing/empty default resolves to `minimal-v0`; `full` remains backcompat/debug.
- PASS: Profile schema reductions are measured. `minimal-v0` is 442 schema tokens (92.0% below full); `semantic` is 1152 (79.1% below full); `structural` is 2551 (53.8% below full, correctly flagged as future work).
- PASS: Full and profile-variant Pi/Tokscale matrix artifacts exist and list failed/caveated rows explicitly. Failed rows are not counted as savings.
- PASS: No unsupported replacement/savings claim is made. The reports treat full Blitz losses as baseline evidence and route/replacement decisions as later Phase 2/6 work.

## Evidence Checked

- `reports/subagents/main-blitz-0.4-first-slice-completion-audit.md`
- `reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.json`
- `reports/pi-tmux-matrix-20260608-first-slice-full-profile-retry-071648.md`
- `reports/pi-accounting-runs/20260608-first-slice-full-profile-retry-071648/`
- `reports/pi-tmux-runs/20260608-first-slice-full-profile-retry-071648/`
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-semantic.json`
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-structural.json`
- `reports/pi-tmux-matrix-20260608-profile-variants-073417-minimal.json`
- `reports/pi-accounting-runs/20260608-profile-variants-073417-{semantic,structural,minimal}/`
- `reports/bench-logs/20260608-profile-variants-073417.log`

## Matrix Findings

- Full profile matrix: 26 rows; 20 clean/correct; 6 failed/caveated; no Tokscale token-match mismatches on exit-0 rows; 24 session JSONL paths preserved.
- Full profile schema: 5517 serialized tool-spec tokens; resident skill: 2358 tokens.
- Full Blitz loses total model-visible context on every both-correct pair, so it remains baseline/backcompat evidence only.
- Semantic profile: 5/5 clean/correct, Tokscale matches, 1152 schema tokens, 79.1% less than full.
- Structural profile: 5/7 clean rows, 2 timeout/caveats, 2551 schema tokens, 53.8% less than full. This does not meet the 70% schema-reduction target and is correctly documented as future splitting/Phase 2 work.
- Minimal-v0 profile: 1/1 clean/correct patch row, 442 schema tokens, 92.0% less than full.

## Verification Evidence

Passed after artifact generation:

- `/home/kenzo/dev/blitz`: `zig build && zig build test`
- `/home/kenzo/dev/blitz`: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-final-check.js`
- `/home/kenzo/dev/pi-blitz-token-profile`: `bun run typecheck && bun test && bun run build`

## Caveats / Required Follow-up

Not blockers for this first slice:

- Some full/structural rows failed or timed out. They are reported and excluded from savings.
- Structural profile does not hit >=70% schema reduction; next slice should split structural further or move to compact Phase 2 IR.
- Core-replacement readiness is not proven and must wait for Phase 2 compact op/IR plus Phase 6 runtime routing.
- Publishable savings claims require repeated green rows and no failed-row inclusion.

## Auditor Rejection Follow-up

After the first goal audit was rejected, additional evidence and one profile fix were added:

- `pi-blitz` commit `990095c refine structural Blitz profile` reduces `structural` to `pi_blitz_replace_body_span`, `pi_blitz_multi_body`, and `pi_blitz_patch`.
- Reduced structural schema is now `1344` tokens versus full `5517`, a `75.6%` reduction.
- GPT/OpenAI-family full matrix was added: `reports/pi-tmux-matrix-20260609-gpt-full-profile-035706.{json,md}` using `openai-codex` / `gpt-5.5`, 26 rows, 10 clean/correct, 16 caveated, 0 Tokscale token-match mismatches, 26 session JSONL paths.
- GPT profile-supported comparison artifacts were added: `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-{semantic,structural,minimal}.{json,md}`.
- ZAI reduced-structural rerun was added: `reports/pi-tmux-matrix-20260609-zai-structural-reduced-040405.{json,md}`, 8 rows, 7 clean/correct, structural schema `1344`, and the large structural Blitz patch row succeeded while core timed out.
- Follow-up report: `reports/subagents/main-blitz-0.4-first-slice-auditor-rejection-followup.md`.

Caveat: GPT/Codex row correctness was poor. These GPT rows are measurement/Tokscale/profile evidence only; no savings are claimed from failed/caveated rows.

## Final Decision

APPROVE for marking the active goal complete as Phase 0/1 evidence only. Remaining core-replacement readiness belongs to later phases.
