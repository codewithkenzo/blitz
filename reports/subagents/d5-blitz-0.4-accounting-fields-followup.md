# D5 follow-up — Blitz 0.4 Phase 0 accounting fields

Date: 2026-06-08
Branch: `feat/blitz-0.4-token-core-profile`

## Scope

Focused bench-only repair in `bench/pi-matrix.ts` for explicit Phase 0 accounting field names. No `pi-blitz` worktree touched. No token-savings/core-replacement claims.

## Changes

- Added per-lane `promptTokens` from actual `prompt` string passed to Pi via `countTokens(prompt)`.
- Added `sessionFile` to lane/run records from real discovered Pi session JSONL path.
- Added run JSON accounting aliases/fields:
  - `schemaTokens`
  - `skillTokens`
  - `promptTokens`
  - `argTokens`
  - `outputTokens`
  - `cacheRead`
  - `cacheWrite`
  - `resultPayloadTokens`
  - `residualInputTokens`
  - `totalContextTokens`
- Added row median equivalents with same plan names.
- Updated Markdown table to visibly include schema/skill/prompt/arg/output/cache/result/residual/total context columns.
- Updated Phase 0 payload session path list to use real `sessionFile` values instead of session dirs.

## Verification

Commands passed:

```bash
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
rm -rf /tmp/blitz-accounting-followup
bun bench/pi-matrix.ts --dump-accounting-only --tool-profile minimal --artifact-root /tmp/blitz-accounting-followup --no-tokscale
test -s /tmp/blitz-accounting-followup/tool-specs.minimal.json
test -s /tmp/blitz-accounting-followup/skill.minimal.md
test -s /tmp/blitz-accounting-followup/tokenizer.minimal.json
```

Artifact files confirmed:

- `/tmp/blitz-accounting-followup/tool-specs.minimal.json`
- `/tmp/blitz-accounting-followup/skill.minimal.md`
- `/tmp/blitz-accounting-followup/tokenizer.minimal.json`

## Residual risk

- Dump-only smoke does not create Pi session JSONL, so `sessionFile` stays absent there by design.
- No real Pi/Tokscale matrix run performed; outside focused repair scope.
