# Pi/tmux/Tokscale true same-session sequential streak evidence

Date: 2026-06-10
Status: exploratory; not default-ready proof
Baseline/fallback: Pi core `edit` only. Codex/OpenAI `apply_patch` out of scope.

## Method

- Runner: `.pi/bench/true-streak.ts`.
- Each row is one real Pi command in one tmux session/window and one `--session-dir`.
- Prompt contains an ordered edit sequence; model keeps calling the selected edit tool until steps complete.
- Tokscale runs against copied Pi session JSONL for each row.
- Raw artifacts are preserved under `.pi/reports/pi-tmux-runs/true-streak-*`.
- Router rows use `/home/kenzo/dev/pi-blitz/dist/index.js` and `pi_blitz_route_edit`; pi-blitz repo was not edited.

## Cumulative comparison

| Scenario | Lane | Correct | Tokscale | Wall ms | schema | skill | prompt | args | output | cache read | cache write | result payload | residual input | total context |
|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 tiny/core-like edits | core edit | yes | pass | 85,988 | 0 | 0 | 1,419 | 820 | 2,011 | 67,487 | 0 | 500 | 4,125 | 75,042 |
| 10 tiny/core-like edits | router/blitz | yes | pass | 86,139 | 0 | 580 | 1,593 | 789 | 1,737 | 73,920 | 0 | 753 | 3,890 | 81,720 |
| 20 mixed language/config/markdown/code edits | core edit | yes | pass | 114,593 | 0 | 0 | 2,641 | 1,538 | 2,604 | 162,582 | 0 | 974 | 8,595 | 176,422 |
| 20 mixed language/config/markdown/code edits | router/blitz | yes | pass | 142,751 | 0 | 580 | 2,967 | 1,923 | 4,164 | 238,189 | 0 | 1,523 | 1,124 | 247,024 |
| same-file multi-edit | core edit | yes | pass | 22,144 | 0 | 0 | 461 | 348 | 616 | 17,129 | 0 | 144 | 223 | 18,429 |
| same-file multi-edit | router/blitz | yes | pass | 33,822 | 0 | 580 | 516 | 366 | 1,019 | 19,895 | 0 | 250 | 3,364 | 25,374 |

## Deltas vs core

| Scenario | Router total | Core total | Delta vs core | Savings vs core | Verdict |
|---|---:|---:|---:|---:|---|
| 10 tiny/core-like edits | 81,720 | 75,042 | -6,678 | -8.9% | core cheaper |
| 20 mixed language/config/markdown/code edits | 247,024 | 176,422 | -70,602 | -40.0% | core cheaper |
| same-file multi-edit | 25,374 | 18,429 | -6,945 | -37.7% | core cheaper |

## Raw report files

- `.pi/reports/archive/history/pi-tmux-true-streak-tiny-10-core-20260610-d5.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-tiny-10-router-20260610-d5.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-mixed-20-core-20260610-d5.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-mixed-20-router-20260610-d5.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-same-file-multi-core-20260610-d5.json`
- `.pi/reports/archive/history/pi-tmux-true-streak-same-file-multi-router-20260610-d5.json`

## Caveats

- `schemaTokens=0` because current Pi JSONL does not expose serialized resident core/tool schema separately; unclassified provider input is carried as `residualInputTokens`.
- True sequential here means one Pi process/session with ordered tool calls from one prompt, not multiple user turns in an interactive TUI.
- Router/blitz rows are benchmark-only `pi_blitz_route_edit` runs, not product-real default fallback.

## Verdict

Not default-ready. True same-session evidence shows core edit remains cheaper for tiny, mixed, and same-file multi edit streaks. Blitz/router still useful for targeted structural/semantic cases, but current route is not default-cheaper for realistic edit streaks.
