# D5 Blitz 0.4 auditor remediation

Date: 2026-06-09

## Scope

Closed feasible auditor blockers in clean worktrees only:

- Blitz repo: `/home/kenzo/dev/blitz`, branch `feat/blitz-0.4-token-core-profile`
- pi-blitz companion: `/home/kenzo/dev/pi-blitz-token-profile`, branch `feat/blitz-0.4-token-core-profile`
- Dirty canonical `/home/kenzo/dev/pi-blitz` was not mutated.

## Changed files

### Blitz

- `bench/pi-matrix.ts`
  - Adds `profileCoverage` artifacts with explicit supported/skipped fixture accounting per profile.
  - Adds `overheadComparisons` using combined resident schema+skill tokens, not schema-only.
  - Adds pairwise route decision fields: `acceptedRoute`, `routeDecisionReason`, `savingsCounted`, `totalContextSavingsPct`.
  - Pairwise markdown now states when simple both-correct rows route to core/apply_patch and excludes savings.
- `reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.{json,md}`
  - GPT/OpenAI-family smoke matrix proving changed harness fields.
- `reports/pi-accounting-runs/2026-06-09T02-25-21-688Z/`
  - Raw accounting artifacts for final v5 run.
- `reports/subagents/d5-blitz-0.4-auditor-remediation.md`
  - This report.

### pi-blitz companion

- `skills/pi-blitz/SKILL.md`
  - Compressed resident skill from 260 lines to compact routing guidance.
  - Final measured resident skill tokens: `444`.

## Benchmark artifact summary

Final GPT/OpenAI-family run:

- JSON: `reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.json`
- MD: `reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.md`
- Accounting root: `reports/pi-accounting-runs/2026-06-09T02-25-21-688Z/`
- Tmux run root: `reports/pi-tmux-runs/2026-06-09T02-25-21-688Z`
- Provider/model: `openai-codex` / `gpt-5.5`
- Runner: `tmux`
- Tokscale: required, token match `yes` for both rows
- Case: `semantic/arrow-replace-return`
- Rows: core + Blitz semantic, both correct

Pairwise decision:

- core total context: `8018`
- Blitz total context: `9905`
- output tokens: core `90`, Blitz `86`
- tool arg tokens: core `74`, Blitz `66`
- route decision: `core/apply_patch fallback: Blitz total context 9905 > core 8018`
- savings counted: `false`

Combined resident overhead evidence from v5:

| Profile | Schema tok | Skill tok | Combined tok | Reduction vs full | Target |
|---|---:|---:|---:|---:|---|
| minimal-v0 | 442 | 444 | 886 | 85.14% | meets |
| semantic | 1152 | 444 | 1596 | 73.23% | meets |
| structural | 1344 | 444 | 1788 | 70.01% | meets |
| admin | 622 | 444 | 1066 | 82.12% | meets |
| full | 5517 | 444 | 5961 | 0.00% | baseline/debug |

Profile skip accounting from v5 is present in JSON/MD:

- `minimal-v0`: skipped `semantic/arrow-replace-return` as unsupported.
- `semantic`: supported `semantic/arrow-replace-return`.
- `structural`: skipped `semantic/arrow-replace-return` as unsupported.
- `admin`: skipped `semantic/arrow-replace-return` as unsupported.
- `full`: supported `semantic/arrow-replace-return`.

Earlier rejection-followup artifacts remain relevant for broader 12-pair/full and structural evidence:

- `reports/subagents/main-blitz-0.4-first-slice-auditor-rejection-followup.md`
- `reports/pi-tmux-matrix-20260609-gpt-full-profile-035706.{json,md}`
- `reports/pi-tmux-matrix-20260609-gpt-profile-supported-035842-{semantic,structural,minimal}.{json,md}`
- `reports/pi-tmux-matrix-20260609-zai-structural-reduced-040405.{json,md}`

## Commands run

Blitz:

```bash
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-remediation-check.js
zig build && zig build test
bun bench/pi-matrix.ts --runner tmux --provider openai-codex --model gpt-5.5 --case semantic/arrow-replace-return --iters 1 --timeout-ms 120000 --tokscale --tool-profile semantic --artifact-profiles minimal,semantic,structural,admin,full --md-out reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.md --json-out reports/pi-tmux-matrix-20260609-remediation-gpt-semantic-smoke-v5.json
```

pi-blitz companion:

```bash
bun run typecheck && bun test && bun run build
```

All passed.

## Auditor blocker status

1. Same-matrix profile comparison with skipped/unsupported accounting: **partially closed in harness**. `profileCoverage` now records explicit skipped unsupported rows for each artifact profile. Existing broader GPT artifacts remain full/profile-supported evidence. Full 12-pair re-run with new field is still optional expensive evidence, not required to prove harness behavior.
2. Resident tool+skill overhead target >=70% for common lanes: **closed for minimal, semantic, structural, admin** in final v5 measurement. Full remains baseline/debug and does not meet target by definition.
3. Simple both-correct route fallback proof: **closed in harness and v5 artifact**. Both-correct semantic row loses total context after overhead, so route decision chooses `core` and `savingsCounted=false`.
4. Structural preservation: **not rerun in this D5 slice**. Existing reduced structural ZAI artifact from auditor follow-up remains stronger clean evidence: `reports/pi-tmux-matrix-20260609-zai-structural-reduced-040405.{json,md}`. Harness changes do not alter Blitz CLI behavior.
5. Caveats/no replacement claim: **closed in report wording**. No default core replacement claim; failed/caveated rows and unsupported profiles are explicit.

## Caveats / residual risks

- Final D5 GPT run is a targeted smoke, not a fresh 12-pair GPT matrix. It proves changed harness fields and overhead after skill compression; broader GPT evidence remains in earlier artifacts.
- `profileCoverage` is fixture/profile metadata accounting, not automatic execution of unsupported Blitz lanes. This is intentional: unsupported rows are explicitly skipped rather than hidden.
- Simple semantic row still loses total context because prompt/input/cache dominate; router fallback proof records core route and excludes Blitz savings.
- Structural preservation evidence relies on pre-existing reduced structural artifact, not a new post-harness rerun.

## Git notes

pi-blitz companion commits pushed:

- `docs(skill): compact resident Blitz guidance`
- `docs(skill): trim resident Blitz profile guidance`
- `docs(skill): minimize resident Blitz guidance`
- `docs(skill): shave Blitz resident tokens`
- `docs(skill): trim final Blitz resident token`

Blitz branch should include harness/report commit after final verification.
