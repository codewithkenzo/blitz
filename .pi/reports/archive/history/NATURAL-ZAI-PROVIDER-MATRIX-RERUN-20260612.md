# Natural Zai provider matrix rerun — 2026-06-12

Status: failed/caveated real provider matrix. Preserved as remediation evidence. This is **not** a universal-pass report.

## Preconditions

- Blitz branch: `feat/blitz-0.4-token-core-profile`
- pi-blitz remediation pushed: `4fcb25e fix(edit): apply blitz exact ops sequentially`
- Focused smoke after remediation passed:
  - `tiny-exact / blitz`: `blitz_mutated (1/1 correct)`
  - `same-file-multi / blitz`: `blitz_mutated (1/1 correct)`

Focused smoke log:

- `.pi/reports/provider-matrix-logs/natural-zai-focused-smoke-after-sequential-20260612T055156Z.log`

## Full matrix command

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group natural \
  --provider zai \
  --model glm-4.5-air \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000
```

Artifacts:

- log: `.pi/reports/provider-matrix-logs/natural-zai-glm-4.5-air-rerun-20260612T055247Z.log`
- JSON: `.pi/reports/natural-edit-harness/natural-edit-2026-06-12T05-52-47-609Z.json`
- Markdown: `.pi/reports/natural-edit-harness/natural-edit-2026-06-12T05-52-47-609Z.md`
- run dirs: `.pi/reports/natural-edit-runs/*__2026-06-12T05-52-47-609Z/`

## Summary

- Provider/model: `zai / glm-4.5-air`
- Natural scenarios: 25
- Both-lane rows: 50
- Correct rows: 35/50
- Accepted rows: 35/50
- Core correct: 19/25
- Blitz correct: 16/25
- Tokscale token match: 48/50 `ok/match=true`; 2 rows `missing/match=false`

Outcome counts:

- `core_mutated`: 18
- `blitz_mutated`: 15
- `noop`: 2
- `incorrect`: 15

## Failing rows

Rows that are not accepted:

- `structural-body / core` — incorrect; Tokscale missing
- `structural-body / blitz` — incorrect; Tokscale missing
- `no-op-idempotent / core` — incorrect
- `same-file-doc-comments / blitz` — incorrect
- `structural-add-guard / core` — incorrect
- `structural-add-guard / blitz` — incorrect
- `import-insertion / core` — incorrect
- `import-insertion / blitz` — incorrect
- `import-removal / blitz` — incorrect
- `import-order / blitz` — incorrect
- `local-symbol-rename / core` — incorrect
- `local-symbol-rename / blitz` — incorrect
- `no-op-format-already / blitz` — incorrect
- `ambiguous-multi-match-safety / core` — incorrect
- `ambiguous-multi-match-safety / blitz` — incorrect

## Interpretation

The pi-blitz sequential exact-op remediation fixed the earlier immediate blockers (`tiny-exact` and `same-file-multi`) and improved error surfacing, but the full natural matrix still fails the universal gate badly:

- Blitz does not yet pass natural import/doc-comment/rename/no-op/ambiguous safety rows.
- Core baseline also fails several natural rows, confirming the harness includes hard unscripted cases and that fair baseline/product-route work remains.
- Two structural rows lack Tokscale validation and therefore cannot be accepted even aside from correctness.

## Next remediation targets

Before any further provider matrices:

1. Inspect failing row JSONL/tool calls for Blitz failures.
2. Split failures into:
   - harness prompt/golden issues,
   - product route/tool-schema issues,
   - unsupported Blitz CLI capabilities,
   - expected safe no-op/decline accounting issues.
3. Fix no-op/idempotence and ambiguous safety behavior first because unsafe mutation or failure there blocks adversarial gates.
4. Add focused smoke tests for each repaired class before rerunning the full Zai matrix.

No universal or token-savings claim is supported by this report.
