# Natural edit harness hardening — 2026-06-12

Scope: `bench/natural-edit.ts` audit/reporting hardening only. No provider smoke run.

## Changes

- JSON run rows now include provider/model plus lane/scenario/iter audit identity.
- Session JSONL artifact now reports path + sha256 hash.
- Provenance remains per row: extension path, skill path, visible tools, tool profile.
- Tokscale audit object added per row: mode, status, match, deltas, totals, details.
- `--tokscale` added as alias for `--tokscale-mode validate`.
- Accepted rows fail closed when Tokscale validation requested and Tokscale is missing, fails, lacks token totals, or parser totals/deltas are unavailable.
- Route outcome accounting stays explicit; fallback is not inferred from failures or lane labels.
- Markdown report now summarizes accepted/correct/timed-out counts, route breakdown, and Tokscale status counts.

## Verification

Required build gate:

```bash
bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js
```

Result recorded in task response.

## Caveats

- Natural harness does not parse Pi session token totals independently yet, so requested Tokscale validation returns `status: "mismatch"`, `match: false`, and `deltas: null`; accepted rows fail closed rather than inventing token matches.
- No long provider smoke was run for this slice per task constraint.
