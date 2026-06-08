# D5 Blitz 0.4 first slice

## Completed
- pi-blitz `PI_BLITZ_TOOL_PROFILE=minimal|semantic|structural|admin|full` implemented.
- `minimal` labeled `minimal-v0`; exposes existing compact `pi_blitz_patch` only. No `pi_blitz_op` Phase 2 work.
- Package-local tool-spec dump utility added: `bun scripts/dump-tool-specs.ts --profile <profile> --out <path>`.
- Blitz bench harness captures Phase 0 accounting artifacts and fields: visible tools, serialized tool specs/tokens, resident skill snapshot/tokens, tokenizer metadata, prompt/input/cache totals from session parser, tool arg tokens, output/result payload tokens, Tokscale/session paths when available, residual input reconciliation, selected route/profile.
- Added profile variants via `--tool-profile` / `PI_BLITZ_TOOL_PROFILE`; defaults now point at `/home/kenzo/dev/pi-blitz-token-profile` companion worktree.
- Added `--dump-accounting-only` non-provider smoke mode.

## Branches / Commits
- pi-blitz-token-profile: `feat/blitz-0.4-token-core-profile` @ `094a117` (`origin/feat/blitz-0.4-token-core-profile`)
- blitz: `feat/blitz-0.4-token-core-profile` @ `02c6497` (`origin/feat/blitz-0.4-token-core-profile`)

## Files Changed
### /home/kenzo/dev/pi-blitz-token-profile
- `index.ts`
- `package.json`
- `bun.lock`
- `src/tool-profiles.ts`
- `scripts/dump-tool-specs.ts`
- `test/tool-profiles.test.ts`

### /home/kenzo/dev/blitz
- `bench/pi-matrix.ts`
- `reports/pi-accounting-runs/d5-first-slice-smoke3/skill.minimal.md`
- `reports/pi-accounting-runs/d5-first-slice-smoke3/tokenizer.minimal.json`
- `reports/pi-accounting-runs/d5-first-slice-smoke3/tool-specs.minimal.json`

## Verification
### pi-blitz-token-profile
- `bun install && bun run typecheck && bun test && bun run build` — passed after deps install. Bun reported blocked postinstalls; no package publish/install behavior changed.

### blitz
- `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js` — passed before and after formatting follow-up.
- `bun bench/pi-matrix.ts --dump-accounting-only --tool-profile minimal --artifact-root reports/pi-accounting-runs/d5-first-slice-smoke3 --no-tokscale` — passed; captured raw accounting artifacts without provider/Pi matrix.
- `zig build` / `zig build test` not run; Zig/source behavior unchanged.

## Raw Artifact Paths
- `reports/pi-accounting-runs/d5-first-slice-smoke3/tool-specs.minimal.json`
- `reports/pi-accounting-runs/d5-first-slice-smoke3/skill.minimal.md`
- `reports/pi-accounting-runs/d5-first-slice-smoke3/tokenizer.minimal.json`

## Missing / Not Run
- Full Pi/Tokscale matrix not run; slice was plumbing/smoke only, no publishable token-savings evidence claimed.
- Tokscale session JSON paths remain populated only for real Pi runs; dump-only smoke has no session JSON by design.
- `minimal-v0` is existing compact patch wrapper, not Phase 2 `pi_blitz_op`.

## Spec/TK/Memory Notes
- No durable memory update needed.
- No optimized replacement/router-selected savings claim made.
