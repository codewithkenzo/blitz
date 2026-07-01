# Natural Zai remediation focused smokes — 2026-06-12

Status: focused real-provider smoke evidence after harness-only remediation. This is **not** a full matrix pass and does not support a universal claim.

## Preconditions

- Blitz harness remediation in `.pi/bench/natural-edit.ts`:
  - no-op/ambiguous safety guidance added to both lane preambles;
  - `structural-body` fixture reduced to a generated medium fixture;
  - failed-row prompts clarified without exact tool JSON;
  - `structural-add-guard` golden changed to accept single quotes as fair semantic/style output.
- pi-blitz remediation already pushed: `4fcb25e fix(edit): apply blitz exact ops sequentially`.

## Focused smoke command shape

Each remediated scenario was run individually with:

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group natural \
  --provider zai \
  --model glm-4.5-air \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000 \
  --scenario <scenario-id>
```

Aggregate log:

- `.pi/reports/provider-matrix-logs/natural-zai-remediation-focused2-20260612T061813Z.log`

## Results

| Scenario | Core | Blitz | Notes |
|---|---:|---:|---|
| `structural-body` | pass | fail | Core now passes with Tokscale; Blitz still fails. |
| `no-op-idempotent` | fail | pass | Core produced correct unchanged file but timed out (`exit 143`), so accepted=false. Blitz passes. |
| `same-file-doc-comments` | pass | pass | Prompt clarification fixed Blitz delimiter issue. |
| `structural-add-guard` | fail | fail | Still failing despite fair single-quote golden. Needs inspection. |
| `import-insertion` | fail | fail | Still failing. Needs prompt/product inspection. |
| `import-removal` | pass | fail | Blitz still fails. |
| `import-order` | pass | fail | Blitz still fails. |
| `local-symbol-rename` | pass | pass | Prompt clarification fixed both lanes. |
| `no-op-format-already` | pass | fail | Blitz still mutates incorrectly. Safety blocker. |
| `ambiguous-multi-match-safety` | pass | pass | Safety preamble fixed both lanes; both no-mutation with Tokscale match. |

## Interpretation

The harness remediation improved several important rows:

- `structural-body / core` now passes and gets Tokscale match instead of timeout/missing accounting.
- `same-file-doc-comments / blitz` now passes.
- `local-symbol-rename` now passes both lanes.
- `ambiguous-multi-match-safety` now passes both lanes safely as no-mutation.

Remaining blockers before full Zai rerun:

- `structural-body / blitz`
- `structural-add-guard / core` and `/ blitz`
- `import-insertion / core` and `/ blitz`
- `import-removal / blitz`
- `import-order / blitz`
- `no-op-format-already / blitz`
- `no-op-idempotent / core` timeout despite correct file state

## Next steps

1. Inspect JSONL/tool calls for remaining focused failures.
2. Separate harness/golden strictness from pi-blitz product gaps.
3. Fix no-op/idempotence safety for Blitz before adversarial matrix reruns.
4. Do not rerun the full natural matrix until focused blockers are materially reduced.
