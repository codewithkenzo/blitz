# Main handoff — Blitz 0.4 Phase 2/6 continuation

Date: 2026-06-09

## Current state

Goal continues from `docs/plans/START-0.4-context-token-core.md` + `docs/plans/PLAN-0.4-context-token-optimization.md`.

Phase 0/1 plus remediation are pushed:

- Blitz: `/home/kenzo/dev/blitz`, branch `feat/blitz-0.4-token-core-profile`, head `40bf394`.
- Canonical pi-blitz: `/home/kenzo/dev/pi-blitz`, branch `feat/blitz-0.4-token-core-profile-canonical`, tracking `origin/feat/blitz-0.4-token-core-profile`, head `53202df`.
- Clean companion worktree: `/home/kenzo/dev/pi-blitz-token-profile`, branch `feat/blitz-0.4-token-core-profile`, head `53202df`.

Canonical `/home/kenzo/dev/pi-blitz` dirty state from `spec/pi-blitz-v02-stream-ux` was preserved before switching:

- Patch: `reports/subagents/pi-blitz-canonical-dirty-preserve-20260609T023921Z.patch`
- Stash in canonical pi-blitz: `pre-blitz-0.4-canonical-preserve-20260609T023921Z`

## Next implementation slice

Proceed into Blitz 0.4 phases after first-slice evidence:

1. Phase 2: add `pi_blitz_op` compact alias tool in canonical pi-blitz.
2. Phase 4: compare compact JSON alias tool vs existing JSON schema path; reject freeform if not supported/cheaper.
3. Phase 5: if feasible in this slice, add deterministic chunk-local/keep-marker spike in Zig apply layer; otherwise produce explicit implementation plan and blocker.
4. Phase 6: make route decision/reporting token-first and use canonical pi-blitz path in final benchmark artifacts.

## Required evidence

- pi-blitz checks: `bun run typecheck && bun test && bun run build`.
- Blitz checks: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-phase2-check.js`, `zig build && zig build test`.
- Token proof from real Pi/Tokscale tmux runs using canonical `/home/kenzo/dev/pi-blitz/dist/index.js` and `/home/kenzo/dev/pi-blitz/skills/pi-blitz`.
- Reports must include correctness, Tokscale token match, arg/schema/skill/prompt/output/result/cache/total context, selected route/fallback reason, and caveats.

## Caveat

Do not claim core replacement until simple rows either beat/tie core after overhead or the actual runtime route/facade selects core/apply_patch with token proof, and structural rows preserve large wins.
