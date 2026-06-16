# D5 true same-session streak — 2026-06-10

Status: implemented, run, verified, pushed. Verdict: not default-ready.

## Scope

- Repo: `/home/kenzo/dev/blitz`
- Branch: `feat/blitz-0.4-token-core-profile`
- No `/home/kenzo/dev/pi-blitz` edits.
- Baseline/fallback: Pi core `edit` only.
- Codex/OpenAI `apply_patch`: out of scope.

## Implementation

Added `bench/true-streak.ts`, separate from `bench/pi-matrix.ts`.

Runner behavior:

- creates scenario worktree under `reports/pi-tmux-runs/true-streak-*`;
- writes one ordered multi-edit prompt;
- launches one Pi command in tmux with one `--session-dir`;
- supports lanes:
  - `core` → Pi core `edit` only, no skills/extensions;
  - `router` → `pi_blitz_route_edit` only, using existing `/home/kenzo/dev/pi-blitz/dist/index.js` and skill;
- supports scenarios:
  - `tiny-10`;
  - `mixed-20`;
  - `same-file-multi`;
- parses session JSONL for provider usage, tool calls, arg tokens, result payload tokens;
- runs Tokscale against copied session JSONL when `--tokscale` is set;
- writes JSON + Markdown report per run.

## Reports generated

Summary:

- `reports/pi-tmux-true-streak-summary-20260610-d5.json`
- `reports/pi-tmux-true-streak-summary-20260610-d5.md`

Per-run reports:

- `reports/pi-tmux-true-streak-tiny-10-core-20260610-d5.{json,md}`
- `reports/pi-tmux-true-streak-tiny-10-router-20260610-d5.{json,md}`
- `reports/pi-tmux-true-streak-mixed-20-core-20260610-d5.{json,md}`
- `reports/pi-tmux-true-streak-mixed-20-router-20260610-d5.{json,md}`
- `reports/pi-tmux-true-streak-same-file-multi-core-20260610-d5.{json,md}`
- `reports/pi-tmux-true-streak-same-file-multi-router-20260610-d5.{json,md}`

Raw run roots preserved under:

- `reports/pi-tmux-runs/true-streak-2026-06-10T06-19-38-581Z`
- `reports/pi-tmux-runs/true-streak-2026-06-10T06-21-10-699Z`
- `reports/pi-tmux-runs/true-streak-2026-06-10T06-22-46-312Z`
- `reports/pi-tmux-runs/true-streak-2026-06-10T06-24-48-530Z`
- `reports/pi-tmux-runs/true-streak-2026-06-10T06-25-11-305Z`
- `reports/pi-tmux-runs/true-streak-2026-06-10T06-25-55-499Z`

## Token results

| Scenario | Core total | Router total | Delta vs core | Savings vs core | Correct | Tokscale |
|---|---:|---:|---:|---:|---|---|
| 10 tiny/core-like edits | 75,042 | 81,720 | -6,678 | -8.9% | yes | pass |
| 20 mixed language/config/markdown/code edits | 176,422 | 247,024 | -70,602 | -40.0% | yes | pass |
| same-file multi-edit | 18,429 | 25,374 | -6,945 | -37.7% | yes | pass |

All accepted rows: exit 0, no timeout, correctness yes, Tokscale exit 0.

## Commands run

- `bun build bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js` — passed.
- `command -v pi; command -v tokscale; tmux -V` — passed; pi/tokscale/tmux present.
- `bun bench/true-streak.ts --scenario tiny-10 --lane core --provider zai --model glm-4.5-air --timeout-ms 180000 --tokscale --json-out reports/pi-tmux-true-streak-tiny-10-core-20260610-d5.json --md-out reports/pi-tmux-true-streak-tiny-10-core-20260610-d5.md` — passed, accepted.
- `bun bench/true-streak.ts --scenario tiny-10 --lane router --provider zai --model glm-4.5-air --timeout-ms 180000 --tokscale --json-out reports/pi-tmux-true-streak-tiny-10-router-20260610-d5.json --md-out reports/pi-tmux-true-streak-tiny-10-router-20260610-d5.md` — passed, accepted.
- `bun bench/true-streak.ts --scenario mixed-20 --lane core --provider zai --model glm-4.5-air --timeout-ms 240000 --tokscale --json-out reports/pi-tmux-true-streak-mixed-20-core-20260610-d5.json --md-out reports/pi-tmux-true-streak-mixed-20-core-20260610-d5.md` — passed, accepted.
- `bun bench/true-streak.ts --scenario same-file-multi --lane core ... && bun bench/true-streak.ts --scenario same-file-multi --lane router ...` — passed, accepted both.
- `bun bench/true-streak.ts --scenario mixed-20 --lane router --provider zai --model glm-4.5-air --timeout-ms 300000 --tokscale --json-out reports/pi-tmux-true-streak-mixed-20-router-20260610-d5.json --md-out reports/pi-tmux-true-streak-mixed-20-router-20260610-d5.md` — passed, accepted.
- `bun build bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js && bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js && git diff --check` — passed.

`zig build && zig build test` not run: no Zig/source behavior changes.

## Caveats / risks

- `schemaTokens=0` because current Pi JSONL does not expose serialized resident core/tool schema separately; residual provider input is reported as `residualInputTokens`.
- True sequential proof here is one Pi process/session with ordered tool calls from one prompt, not multiple interactive user turns.
- Router rows are benchmark-only `pi_blitz_route_edit` runs, not product-real runtime fallback.

## Verdict

Not default-ready. True same-session sequential evidence says Pi core `edit` remains cheaper for tiny, mixed, and same-file multi streaks. Blitz/router needs further schema/skill/cache overhead reduction or product-real routing before any default-cheaper claim.
