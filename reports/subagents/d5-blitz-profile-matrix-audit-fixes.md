# D5 Blitz profile matrix audit fixes

Date: 2026-06-08
Branch: `feat/blitz-0.4-token-core-profile`
Blitz commit: `9d99132` (`Make Pi matrix tool profiles fail closed`), newer than `a472df3`.

## Completed

- `bench/pi-matrix.ts` now validates fixture-selected Blitz tools against selected `--tool-profile` visible tool specs before running Pi.
- Unsupported profile/tool mismatch fails closed with explicit error. Example: `minimal` + `semantic/arrow-replace-return` rejects `pi_blitz_replace_return` because minimal exposes only `pi_blitz_patch`.
- Added `--artifact-profiles <profile[,profile]|all>` for lightweight raw profile artifact capture.
- Dump-only/profile artifact capture now writes per requested profile:
  - `tool-specs.<profile>.json`
  - `skill.<profile>.md`
  - `tokenizer.<profile>.json`
- Default artifact capture still includes selected `--tool-profile`.
- No token-savings/core-replacement claims made.

## Files Changed

- `bench/pi-matrix.ts`
- `reports/subagents/d5-blitz-profile-matrix-audit-fixes.md`

## Verification

Passed:

```bash
bunx tsc --noEmit --allowImportingTsExtensions --moduleResolution bundler --module esnext --target esnext --types node bench/pi-matrix.ts
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-profile-check.js
rm -rf /tmp/blitz-profile-artifacts-minimal && bun bench/pi-matrix.ts --dump-accounting-only --tool-profile minimal --artifact-root /tmp/blitz-profile-artifacts-minimal --no-tokscale
rm -rf /tmp/blitz-profile-artifacts-all && bun bench/pi-matrix.ts --dump-accounting-only --tool-profile minimal --artifact-profiles all --artifact-root /tmp/blitz-profile-artifacts-all --no-tokscale && ls /tmp/blitz-profile-artifacts-all
```

Expected fail-closed smoke:

```bash
bun bench/pi-matrix.ts --case semantic/arrow-replace-return --lane blitz --tool-profile minimal --artifact-root /tmp/blitz-profile-artifacts-minimal-mismatch --no-tokscale
```

Observed error:

```text
error: tool profile minimal does not expose requested Blitz tools: pi_blitz_replace_return
```

Artifact proof:

```text
/tmp/blitz-profile-artifacts-minimal:
skill.minimal.md
tokenizer.minimal.json
tool-specs.minimal.json

/tmp/blitz-profile-artifacts-all:
skill.admin.md
skill.full.md
skill.minimal.md
skill.semantic.md
skill.structural.md
tokenizer.admin.json
tokenizer.full.json
tokenizer.minimal.json
tokenizer.semantic.json
tokenizer.structural.json
tool-specs.admin.json
tool-specs.full.json
tool-specs.minimal.json
tool-specs.semantic.json
tool-specs.structural.json
```

## Remaining START/PLAN Blockers Not Run

- Full 12-pair Pi/Tokscale matrix not run.
- Tokscale reconciliation/session JSON not produced in this task; dump-only smoke has no Pi session JSON by design.
- `zig build` not run.
- `zig build test` not run.
- Phase 2 `pi_blitz_op` not implemented; `minimal-v0` remains existing `pi_blitz_patch` profile.
- No publishable token-savings rows; no core-replacement claim.

## Spec/TK/Memory Notes

- No durable memory update needed.
- Report evidence updated to current Blitz commit including `bench/pi-matrix.ts` profile-aware changes.
