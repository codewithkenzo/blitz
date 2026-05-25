# Pi tmux bench runner plan

Date: 2026-05-25
Status: plan only; no implementation edits; do not commit/push until method locked.

## Goal

Add inspectable/resumable tmux runner for existing Pi matrix bench while preserving current spawn runner, current Tokscale validation, current report files, and current benchmark claims.

## Recommended design

Smallest low-risk path: extend `bench/pi-matrix.ts` with `--runner spawn|tmux` (default `spawn`). Do not fork/duplicate fixture/report logic into a new script.

Tmux mode:

- one tmux session per harness run: `pi-bench-<timestamp>`;
- one window per fixture/lane/iteration;
- persistent per-run dir under `reports/pi-tmux-runs/<timestamp>/<safe-fixture>__<lane>__<iter>/`;
- files per run:
  - `work/<fixture>` copied fixture under edit;
  - `prompt.md` full prompt for inspection;
  - `command.sh` exact Pi shell command wrapper;
  - `stdout.log`, `stderr.log` via `tee`;
  - `exit.json` status/wall-ms/timedOut metadata;
  - `sessions/` Pi `--session-dir` JSONL tree;
- harness waits for `exit.json`, then reuses current `findSessionFile`, `parseSession`, correctness compare, and `runTokScale` path.

Prompt passing decision: write prompt to `prompt.md`; `command.sh` passes final prompt arg as `"$(cat prompt.md)"`. Do not depend on undocumented `@prompt.md` unless `pi --help` confirms support. This avoids giant shell-quoted prompt text while still invoking Pi with normal positional `<prompt>`.

Pi command shape in `command.sh`:

```bash
/home/kenzo/.local/bin/pi -p \
  --provider zai \
  --model glm-4.5-air \
  --session-dir "$RUN_DIR/sessions" \
  --no-context-files \
  --thinking off \
  --no-prompt-templates \
  <lane extension/skill/tool args> \
  "$(cat "$RUN_DIR/prompt.md")"
```

Use same lane args as current `piArgs()` to avoid benchmark drift:

- core: `--no-skills --no-extensions --tools edit`
- blitz: `--no-extensions --extension <dist/index.js> --skill <skills/pi-blitz> --tools <narrow tool list>`

Preserve existing `--offline` if current spawn runner uses it; only remove after explicit approval because that changes baseline semantics.

Output/report strategy:

- keep `reports/pi-local-matrix-2026-05-25.md/json` untouched as baseline;
- first tmux run writes new files, e.g. `reports/pi-tmux-matrix-2026-05-25.md/json`;
- add `Runner: tmux` and `Run root: ...` header only to new tmux reports;
- JSON payload may add `runner`, `runRoot`, and per-run `sessionDir/stdoutLog/stderrLog/commandFile` without changing existing row metrics.

Timeout/interactivity:

- print attach command before each wait: `tmux attach -t <session>` and target window name;
- set `remain-on-exit on` so panes stay inspectable;
- on harness timeout, do not silently kill Pi in tmux mode; mark timedOut and leave session/window alive unless an explicit future `--tmux-kill-on-timeout` flag is approved.

## Non-goals

- No deletion/regeneration of existing baseline report.
- No public token-savings claim updates until tmux method approved.
- No pi-blitz extension/schema changes.
- No CI default switch to tmux.
- No prompt-file `@prompt.md` dependency unless Pi documents it.

## Files/Areas

- `bench/pi-matrix.ts` — add runner arg, tmux runner implementation, run-root/log/session metadata, minimal async/sync wait changes.
- `package.json` — optional convenience script: `bench:pi-tmux`: `bun bench/pi-matrix.ts --runner tmux`.
- `reports/pi-local-matrix-2026-05-25.md/json` — baseline, must remain untouched.
- `reports/pi-tmux-matrix-*.md/json` — new tmux report outputs after approval/run.
- `reports/pi-tmux-runs/*` — persistent run dirs/logs/session JSONL.

## Tasks

1. Preflight
   - Confirm dirty tree; coordinate with current owner before edits.
   - No commit/push.
   - Prefer dedicated worktree/branch for implementation because `bench/pi-matrix.ts`, `package.json`, and reports are already dirty.
   - Confirm `tmux -V`, `pi --help`, `tokscale --version` locally.

2. Add runner config
   - Parse `--runner` default `spawn`.
   - Parse `--run-root` default only for tmux: `reports/pi-tmux-runs/<timestamp>`.
   - Include runner/runRoot in console + md/json headers.

3. Preserve spawn path
   - Rename existing `runPi` to `runPiSpawn` with no behavior change.
   - Keep default `bun bench/pi-matrix.ts` output compatible.

4. Add tmux path
   - Create run dir/session dir/log files.
   - Write `prompt.md` and executable `command.sh`.
   - Start tmux session/window with `bash command.sh`.
   - Capture stdout/stderr via `tee`.
   - Write `exit.json` atomically enough for harness wait.
   - Keep session/window after exit.

5. Reuse current parsing/validation
   - After tmux exit, call existing `findSessionFile(sessionDir)`.
   - Call existing `parseSession` and `runTokScale` unchanged.
   - Read edited target and compare to `expectedFile` unchanged.

6. Report safely
   - Default tmux report path should be caller-supplied via `--md-out/--json-out`.
   - Docs/commands use new `pi-tmux-*` filenames.
   - Do not overwrite `pi-local-*` unless user approves.

## Acceptance

- `--runner` omitted behaves like current spawn runner.
- `--runner tmux` creates tmux session/window and persistent per-run dir.
- Each tmux run dir contains `prompt.md`, `command.sh`, `stdout.log`, `stderr.log`, `exit.json`, `sessions/**.jsonl`, and edited work file.
- `command.sh` visibly invokes Pi with `-p`, provider/model/session-dir, no-context/no-templates/thinking flags, lane extension/skill/tools, and prompt from `prompt.md`.
- Harness parses same session JSONL fields as spawn and Tokscale `matchesParser` remains `yes` when `--tokscale` is used.
- Existing `reports/pi-local-matrix-2026-05-25.md/json` unchanged.
- New tmux report uses same metrics table plus tmux metadata.
- Timeout leaves tmux pane/logs/session dir inspectable.

## Owners / Agents / Skills

- Planner: pi planning sub-agent; plan only.
- Implementation: delegated coding agent, isolated from dirty baseline.
- Main agent: approves method, runs manual provider bench, decides report regeneration.
- Skills: `kenzo-execution-preferences`, `kenzo-blueprint-architect`, `kenzo-tk-cli`, Bun/TS bench runner, tmux shell orchestration, Pi/Tokscale bench domain.

## Verification

Fast local gates:

```bash
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
tmux -V
tokscale --version
/home/kenzo/.local/bin/pi --help >/tmp/pi-help.txt
```

Single-case tmux smoke after implementation:

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
  --md-out reports/pi-tmux-matrix-2026-05-25.md \
  --json-out reports/pi-tmux-matrix-2026-05-25.json
```

Manual inspection during smoke:

```bash
tmux attach -t pi-bench-<timestamp>
ls reports/pi-tmux-runs/<timestamp>/*
cat reports/pi-tmux-runs/<timestamp>/*/exit.json
```

Full tmux baseline only after method approval:

```bash
bun bench/pi-matrix.ts \
  --runner tmux \
  --provider zai \
  --model glm-4.5-air \
  --lane blitz \
  --iters 1 \
  --timeout-ms 120000 \
  --tokscale \
  --md-out reports/pi-tmux-matrix-2026-05-25.md \
  --json-out reports/pi-tmux-matrix-2026-05-25.json
```

## Risks

- Shell `$(cat prompt.md)` strips trailing newline; expected harmless, but note in report metadata.
- Very large prompt still counts toward OS argv limit; current huge fixture should remain below limit, but verify with `huge-100k` before full run.
- Tmux timeouts can leave live provider calls; visible by design, but user must kill/continue manually.
- `--offline` drift: removing it would change current baseline; keep until approved.
- Dirty working tree can lose baseline if implementation overwrites report paths; require preflight.

## Open questions

- Does Pi officially support `@prompt.md`? If yes, switch command prompt arg to `@prompt.md` after approval.
- Should tmux timeout default leave Pi alive (recommended) or send Ctrl-C for parity with spawn?
- Should full approved run include core+blitz pairwise, or match current blitz-only baseline first?
- Should `--run-root` support parse-only resume of completed runs in first implementation, or remain follow-up?

## Linked spec / tk anchors

- Spec: `specs/blitz-v0.2-hardening-and-parity.md` → Benchmark claim policy: correctness first; report model/date/N/tokens/wall/cost.
- Future-check: `docs/plans/PLAN-2.0.md` → benchmark artifacts include raw JSON + markdown summaries.
- Baseline report: `reports/pi-local-matrix-2026-05-25.md`.
- tk: unavailable in repo (`tk list` failed: no `.tickets` dir); no child ticket linked.

## Anything missed / should review next

- Confirm Pi prompt-file support before locking final command format.
- Inspect one real tmux run JSONL path layout against current `findSessionFile`.
- Decide timeout/kill semantics before full-cost run.
- Decide whether implementation should add parse-only resume support now or after first smoke.
