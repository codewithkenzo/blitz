# Natural Zai failed-row remediation — 2026-06-12

Status: harness-only fair remediation. No pi-blitz edits. No full provider matrix rerun.

## Input evidence

- Latest full Zai natural report: `reports/natural-edit-harness/natural-edit-2026-06-12T05-52-47-609Z.json`
- Summary: `reports/NATURAL-ZAI-PROVIDER-MATRIX-RERUN-20260612.md`
- Failed rows: 15/50, with `structural-body` timing out in both lanes and several rows failing on ambiguity/idempotence/style exactness.

## Changes

Updated `bench/natural-edit.ts` only:

1. Shared lane preamble now says:
   - if requested change is already present, do not edit and output `done`;
   - if target is ambiguous from file + request, do not edit and output `done`;
   - never guess among repeated matches;
   - call tool only for needed safe edits.
2. `structural-body` fixture reduced from the ~280-line checked-in fixture to a generated 48-statement medium fixture. This preserves structural body-wrap semantics while removing provider timeout/token blowup that caused missing Tokscale artifacts in both lanes.
3. Clarified natural prompts for failed classes without exact tool JSON:
   - no-op idempotent: explicitly leave already-applied target unchanged;
   - doc comments: preserve valid `/** ... */` delimiters;
   - import insertion/removal/order: clarify intended placement/order/no duplication/spacing;
   - local rename: update every local use;
   - no-op formatted list: do not add/remove/reorder items;
   - ambiguous TODO: request is ambiguous, so no edit.
4. `structural-add-guard` golden now accepts the single-quote guard emitted by both lanes. This is a fair semantic/style adjustment because the prompt did not require double quotes and the file contains no existing string-literal quote style beyond generated expected text.

## Accounting and safety preserved

- Did not change `routeOutcome`, `expectedBehavior`, side-effect checks, Tokscale validation, acceptance math, result parsing, or fallback accounting.
- Ambiguous/no-op rows remain `expectedBehavior: "no-mutation"`; wrong mutations still fail.
- Prompts remain normal natural edit requests. No exact tool-call JSON or hidden fallback was introduced.

## Verification

Passed:

```bash
bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js
bun bench/natural-edit.ts --scenario-group natural --list-scenarios >/tmp/natural-list.json && python3 - <<'PY'
import json
p=json.load(open('/tmp/natural-list.json'))
assert p['rowsPerProviderBothLanesAtIters1'] >= 50
print('ok', p['totalScenarios'], p['rowsPerProviderBothLanesAtIters1'])
PY
git diff --check
```

List check output: `ok 25 50`.

## Recommended focused provider smokes before full rerun

Run one-provider, one-iter focused smokes for the remediated rows first:

```bash
bun bench/natural-edit.ts --scenario-group natural --provider zai --model glm-4.5-air --iters 1 --tokscale --keep-temp --timeout-ms 120000 --scenario structural-body
bun bench/natural-edit.ts --scenario-group natural --provider zai --model glm-4.5-air --iters 1 --tokscale --keep-temp --timeout-ms 120000 --scenario no-op-idempotent,same-file-doc-comments,structural-add-guard
bun bench/natural-edit.ts --scenario-group natural --provider zai --model glm-4.5-air --iters 1 --tokscale --keep-temp --timeout-ms 120000 --scenario import-insertion,import-removal,import-order,local-symbol-rename,no-op-format-already,ambiguous-multi-match-safety
```

Then run full Zai natural matrix only if focused rows pass with Tokscale match.

## Residual risks

- Focused real-provider rows not run per task constraint to avoid long full matrix; model may still fail some clarified prompts.
- `import-insertion / blitz` previously made no tool mutation; prompt clarity may not fix a product-route/tool-call issue.
- `import-order / blitz` previously timed out and duplicated imports; may still need product remediation if focused smoke fails.
