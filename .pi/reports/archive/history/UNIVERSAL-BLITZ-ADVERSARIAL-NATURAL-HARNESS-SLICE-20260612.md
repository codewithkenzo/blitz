# Universal Blitz adversarial natural harness slice — 2026-06-12

Status: implementation slice only. No provider matrix run.

## What changed

- `.pi/bench/natural-edit.ts` now separates scenario groups with `--scenario-group natural|adversarial|safety|all`.
- Default remains `natural`, preserving existing cheap natural harness behavior unless adversarial rows are requested.
- `--list-scenarios` prints a non-provider coverage summary and exits before Pi/provider calls.
- Adversarial group defines 22 natural/user-like safety rows, enough for >=20 rows per provider at `--iters 1`.
- Scenario metadata records `group`, `categories`, and `expectedBehavior`; JSON/Markdown reports include group/category/expectation coverage.
- Adversarial rows explicitly use `expectedBehavior: "no-mutation"` so unchanged safety rows classify as `safety_no_mutation`/`noop`, not Blitz/core mutation success.
- WorkDir side-effect guard snapshots files before/after each Pi run and records undeclared created/deleted/changed paths (path + status/hash only, no contents).
- No-mutation rows with undeclared side effects fail `outcome`/`correct`/`accepted`, even when declared scenario files remain unchanged.
- Existing `routeOutcome` accounting and Tokscale fail-closed accepted gating were preserved; accepted no-mutation rows require a `noop` route outcome and never count as Blitz/core success.

## Adversarial categories covered

Required categories covered by the 22-row adversarial group:

- ambiguous anchors
- no-op/idempotence
- stale context / old text absent
- path boundary / symlink / traversal
- repeated matches
- generated/minified files
- unsupported refactors
- conflicting edits
- prompt/tooling attacks

Additional safety classes included:

- formatting/index drift
- multi-turn context switching
- import/usage graph refactor
- file lifecycle edits
- schema spoofing
- unsupported/binary-ish file encodings
- incomplete intent / clarify
- huge repeated anchors
- case-collision paths

## Cheap verification commands

Build/type smoke:

```bash
bun build .pi/bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js
```

Adversarial coverage/side-effect guard self-check without provider calls:

```bash
bun .pi/bench/natural-edit.ts --scenario-group adversarial --list-scenarios
```

Optional scripted assertion:

```bash
bun .pi/bench/natural-edit.ts --scenario-group adversarial --list-scenarios > /tmp/natural-edit-adversarial-list.json
python3 - <<'PY'
import json
p=json.load(open('/tmp/natural-edit-adversarial-list.json'))
required=['ambiguous-anchors','no-op/idempotence','stale-context','path-boundary','symlink/traversal','traversal','repeated-matches','generated/minified-files','unsupported-refactors','conflicting-edits','prompt/tooling-attacks']
missing=[r for r in required if r not in p['categories']]
non_no_mutation=[s['id'] for s in p['scenarios'] if s.get('expectedBehavior') != 'no-mutation']
assert p['totalScenarios'] >= 20, p['totalScenarios']
assert not missing, missing
assert not non_no_mutation, non_no_mutation
print('ok', p['totalScenarios'], 'adversarial no-mutation scenarios')
PY
```

## Smoke matrix commands

Cheap adversarial smoke, one provider/model/lane, Tokscale off by default unless requested:

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group adversarial \
  --scenario adv-noop-idempotent-1 \
  --lane blitz \
  --provider zai \
  --model glm-4.5-air \
  --iters 1 \
  --timeout-ms 60000 \
  --keep-temp
```

Full per-provider adversarial matrix shape (repeat for each mandatory provider/model):

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group adversarial \
  --provider zai \
  --model glm-4.5-air \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000

bun .pi/bench/natural-edit.ts \
  --scenario-group adversarial \
  --provider openai-codex \
  --model gpt-5.4-mini \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000

bun .pi/bench/natural-edit.ts \
  --scenario-group adversarial \
  --provider openai-codex \
  --model gpt-5.5 \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000
```

Expected rows per provider at `--iters 1`:

- adversarial scenarios: 22
- per-provider per-lane rows: 22
- per-provider both-lane rows: 44

## Notes / risks

- This slice defines matrix coverage; it does not prove route correctness or token wins.
- No long provider matrix was run by design.
- Adversarial rows now carry explicit `expectedBehavior: "no-mutation"`; future route policy may still add richer expected outcomes (`decline`, `clarify`, `fallback`) once product route emits explicit telemetry.
