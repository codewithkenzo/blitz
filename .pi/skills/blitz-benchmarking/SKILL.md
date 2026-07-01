---
name: blitz-benchmarking
description: Run, validate, and report blitz/pi-blitz token benchmarks using real Pi sessions, tmux pilot runs, and Tokscale validation. Load before any benchmark claim, report regeneration, or token-savings discussion in this repo.
triggers:
  - blitz bench
  - pi blitz benchmark
  - token benchmark
  - tokscale
  - tmux bench
  - benchmark report
  - token savings
tools:
  - read_file
  - terminal
  - write_file
inputs:
  required:
    - benchmark_goal
    - provider_model
  optional:
    - fixtures
    - report_path
    - run_root
outputs:
  - Tokscale-validated benchmark report
  - raw JSON results
  - tmux run artifacts
  - caveats and acceptance status
tags:
  - blitz
  - benchmarking
  - pi
  - tokscale
  - tmux
---

# Purpose

Keep Blitz benchmark claims honest: real Pi sessions, inspectable tmux runs, Tokscale validation, correctness-first reporting.

# When to load

- User asks to bench Blitz, pi-blitz, edit tools, token savings, or wall time.
- User mentions Tokscale, tmux benching, Pi shell args, or interactive piloting.
- Agent changes `bench/pi-matrix.ts`, benchmark fixtures, or report files.
- Agent writes or updates reports under `.pi/reports/pi-*.md/json`.

# Do not load when

- Pure Zig implementation/testing with no benchmark claim.
- Packaging-only work with no Pi benchmark/report impact.
- Generic Zig build issues; use `kenzo-zig` / `kenzo-zig-build` instead.

# Inputs

Required:
- provider/model, normally `zai` / `glm-4.5-air` unless user specifies otherwise.
- exact fixture scope: single row, tool family, blitz-only matrix, or core+blitz pair.
- intended report target: local baseline, tmux pilot report, or publishable report.

Optional:
- `--run-root` for persistent tmux artifacts.
- timeout policy.
- whether failed attempts should be preserved in report.

# Workflow

1. Preflight repo state.
   - Run `git status --short --branch --untracked-files=normal`.
   - Confirm no commit/push unless user explicitly approves.
   - Preserve existing report files unless user asks to regenerate them.
2. Build/install basics.
   - Run `zig build` before benchmarking fresh source.
   - Run `npm install -g .` when verifying package-installed `blitz` behavior.
   - Check `blitz --version` and `blitz doctor`.
3. Prefer tmux runner for method-locking.
   - Use `bench/pi-matrix.ts --runner tmux` for inspectable real Pi runs.
   - Keep `--tokscale` on for locked runs.
   - Use new report paths for new methods; do not overwrite baseline reports accidentally.
4. Require Tokscale validation.
   - `tokscale` must be installed and on PATH.
   - Compare harness parser token totals with Tokscale totals.
   - Treat `tokscale token match: yes` as token/session-count agreement, not cost agreement.
5. Treat correctness separately from accounting.
   - Token accounting can be valid while model output is wrong.
   - Do not publish savings claims from rows with correctness `< 100%`.
   - Record model variance, retries, timeout, and prompt drift as benchmark findings.
6. Pilot unstable rows interactively.
   - Use tmux panes/windows and per-run `prompt.md` / `command.sh` / logs.
   - Run one fixture at a time when rows show newline drift, retries, or timeouts.
   - Accept only green rows into publishable summaries; keep failed attempts as evidence.
7. Report with caveats.
   - Include provider/model, runner, run root, tmux session, timeout, Tokscale mode, cost source, correctness, and token-match status.
   - State whether report is baseline, exploratory, piloted, or publishable.

# Canonical commands

Smoke harness parse/build:

```bash
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
```

Fresh CLI sanity:

```bash
zig build
npm install -g .
command -v blitz
blitz --version
blitz doctor
```

Tokscale sanity:

```bash
tokscale --version
tokscale --json --light --client pi --today --benchmark --no-spinner
```

Single tmux smoke:

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case semantic/arrow-replace-return \
  --lane blitz \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out .pi/reports/pi-tmux-matrix-2026-05-25.md \
  --json-out .pi/reports/pi-tmux-matrix-2026-05-25.json
```

Targeted unstable-row pilot:

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --case medium-10k/wrap-body,medium-10k/insert-body-span \
  --lane blitz \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out /tmp/pi-tmux-targeted.md \
  --json-out /tmp/pi-tmux-targeted.json
```

Attach to inspect:

```bash
tmux list-sessions
tmux attach -t pi-bench-<timestamp>
```

# Output contract

Every benchmark report must include:
- provider and model;
- runner: `spawn` or `tmux`;
- run root and tmux session for tmux runs;
- Pi binary, pi-blitz extension path, and Blitz binary path source;
- Tokscale mode and token-match column;
- correctness per fixture;
- wall ms, input/output/cache tokens, tool-call arg tokens, Tokscale cost;
- failed attempts/timeout note when applicable;
- explicit status: exploratory, baseline, piloted, or publishable.

# Anti-patterns

- Do not push benchmark work before method is locked and user approves.
- Do not publish token savings when correctness is red.
- Do not treat Tokscale cost disagreement as parser failure when provider JSONL omits cost.
- Do not hide failed attempts; model variance is benchmark evidence.
- Do not rely only on spawned non-interactive harness when user asked for tmux/pilot mode.
- Do not overwrite `.pi/reports/pi-local-matrix-2026-05-25.*` unless user asks.
- Do not count generic tokenizer estimates as source of truth when Tokscale can validate real Pi session JSONL.
- Do not clean tmux panes/logs before user can inspect, unless user asks.

# References

- `references/tmux-tokscale-method.md`
- `.pi/reports/pi-tmux-bench-plan-2026-05-25.md`
- `.pi/reports/pi-local-matrix-2026-05-25.md`
- `.pi/reports/pi-tmux-matrix-2026-05-25.md`
