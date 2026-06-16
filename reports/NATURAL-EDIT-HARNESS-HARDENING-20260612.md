# Natural edit harness hardening — 2026-06-12

Scope: `bench/natural-edit.ts` audit/reporting hardening only. No provider smoke run.

## Changes

- JSON run rows now include provider/model plus lane/scenario/iter audit identity.
- Session JSONL artifact now reports path + sha256 hash.
- Provenance remains per row: extension path, skill path, visible tools, tool profile.
- Tokscale audit object added per row: mode, status, match, deltas, totals, details.
- `--tokscale` added as alias for `--tokscale-mode validate`.
- Natural harness now parses Pi session JSONL assistant-message usage totals independently: input, output, cache read, cache write, message count, and cost.
- Tokscale validation now compares Tokscale token/message totals against parser totals, records `status: "ok" | "mismatch"`, exact `match`, and per-field deltas.
- Accepted rows fail closed when Tokscale validation requested and Tokscale is missing, fails, lacks token totals, or parser totals mismatch.
- Route outcome accounting stays explicit; fallback is not inferred from failures or lane labels.
- Markdown report now summarizes accepted/correct/timed-out counts, route breakdown, and Tokscale status counts.

## Verification

Required build gate:

```bash
bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js
```

Result recorded in task response.

## Caveats

- Parser self-check was run against an existing committed natural run JSONL; no provider auth needed.
- No long provider smoke was run for this slice per task constraint.
