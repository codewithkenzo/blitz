# Natural edit coverage expansion — 2026-06-12

Status: harness/scenario coverage slice only. No long provider matrix run.

## What changed

- `.pi/bench/natural-edit.ts` natural group now has 25 natural/user-like scenarios.
- At `--iters 1`, default both-lane execution (`core` + `blitz`) yields 50 natural rows per provider.
- `--list-scenarios` already reports:
  - `totalScenarios`
  - `rowsPerProviderPerLaneAtIters1`
  - `rowsPerProviderBothLanesAtIters1`
  - group/category counts
- Prompts remain natural requests, not exact tool JSON.
- Existing route outcome taxonomy, expectedBehavior metadata, side-effect guard, and Tokscale fail-closed acceptance were preserved.

## Natural category coverage

Required natural categories now covered:

- tiny exact natural edits
- mixed code/docs/config edits
- same-file multi edits
- structural body edits
- config/docs edits
- TSX/JSX prop/text edits
- import insertion/removal/order edits
- local symbol rename/refactor edits
- no-op/idempotence safety
- ambiguous/multi-match safety

## Cheap non-provider coverage assertion

```bash
bun .pi/bench/natural-edit.ts --scenario-group natural --list-scenarios > /tmp/natural-list.json
python3 - <<'PY'
import json
p=json.load(open('/tmp/natural-list.json'))
required=['tiny-natural','mixed-natural','same-file-natural','structural-natural','config/docs-natural','tsx/jsx-prop-text','import-insertion/removal/order','local-symbol-rename/refactor','no-op/idempotence','ambiguous/multi-match-safety']
missing=[r for r in required if r not in p['categories']]
assert p['totalScenarios'] >= 25, p['totalScenarios']
assert p['rowsPerProviderBothLanesAtIters1'] >= 50, p['rowsPerProviderBothLanesAtIters1']
assert not missing, missing
assert all(s['group']=='natural' for s in p['scenarios'])
print('ok', p['totalScenarios'], 'natural scenarios', p['rowsPerProviderBothLanesAtIters1'], 'both-lane rows/provider')
PY
```

Expected output:

```text
ok 25 natural scenarios 50 both-lane rows/provider
```

## Full natural matrix commands

Zai:

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

GPT-5.4-mini:

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group natural \
  --provider openai-codex \
  --model gpt-5.4-mini \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000
```

GPT-5.5:

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group natural \
  --provider openai-codex \
  --model gpt-5.5 \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000
```

## Verification run for this slice

```bash
bun build .pi/bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js
bun .pi/bench/natural-edit.ts --scenario-group natural --list-scenarios > /tmp/natural-list.json && python3 - <<'PY'
import json
p=json.load(open('/tmp/natural-list.json'))
required=['tiny-natural','mixed-natural','same-file-natural','structural-natural','config/docs-natural','tsx/jsx-prop-text','import-insertion/removal/order','local-symbol-rename/refactor','no-op/idempotence','ambiguous/multi-match-safety']
missing=[r for r in required if r not in p['categories']]
assert p['totalScenarios'] >= 25, p['totalScenarios']
assert p['rowsPerProviderBothLanesAtIters1'] >= 50, p['rowsPerProviderBothLanesAtIters1']
assert not missing, missing
assert all(s['group']=='natural' for s in p['scenarios'])
print('ok', p['totalScenarios'], 'natural scenarios', p['rowsPerProviderBothLanesAtIters1'], 'both-lane rows/provider')
PY
git diff --check
```

## Notes / risks

- This slice proves harness coverage capacity only; it does not prove provider correctness or token wins.
- Natural row count uses documented both-lane semantics: 25 scenarios × 2 lanes × 1 iter = 50 rows/provider.
- Full mandatory-provider natural matrices still need real Pi/tmux/Tokscale artifacts before any universal claim.
