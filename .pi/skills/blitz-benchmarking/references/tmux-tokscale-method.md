# Blitz tmux + Tokscale benchmark method

Date: 2026-05-25
Status: repo-local benchmark method; use before publishing Blitz token/wall-time claims.

## Method tiers

### 1. Spawn baseline

`bench/pi-matrix.ts` default runner uses child-process spawn. It is fast and good for harness iteration, parser checks, and baseline reports.

Use when:
- validating harness parser changes;
- smoke testing prompt/tool coverage;
- generating non-publish exploratory reports.

Do not use as sole evidence when user asks for interactive/piloted benching.

### 2. Tmux runner

`--runner tmux` launches real Pi commands in tmux windows and leaves artifacts inspectable.

Per-run artifacts live under:

```text
.pi/reports/pi-tmux-runs/<timestamp>/<fixture>__<lane>__<iter>/
├── command.sh
├── exit.json
├── prompt.md
├── sessions/
├── stderr.log
├── stdout.log
└── work/<fixture file>
```

`command.sh` should show a normal Pi shell invocation:

```bash
/home/kenzo/.local/bin/pi \
  --offline \
  -p \
  --no-context-files \
  --no-prompt-templates \
  --provider zai \
  --model glm-4.5-air \
  --thinking off \
  --session-dir '<run>/sessions' \
  --no-extensions \
  --extension /home/kenzo/dev/pi-blitz/dist/index.js \
  --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz \
  --tools '<narrow pi_blitz_* tool>' \
  @'<run>/prompt.md'
```

`@prompt.md` was verified locally with Pi and avoids shell-quoting huge prompts.

### 3. Interactive pilot mode

Use when full matrix runs show model variance, newline drift, retries, or timeouts.

Rules:
- run one fixture or one small fixture group at a time;
- inspect `prompt.md`, `command.sh`, JSONL tool args, and edited file;
- keep failed attempts as run artifacts;
- accept only rows with correctness `100%`, exit `0`, and Tokscale token match `yes` into publishable summary;
- mention failed attempts as model/prompt variance, not CLI failure unless stderr/tool error proves CLI failure.

## Tokscale validation

Tokscale validates Pi session JSONL totals independently of the harness parser.

Required command shape inside harness:

```bash
tokscale \
  --home <temp-home-containing-.pi/agent/sessions> \
  --client pi \
  --json \
  --light \
  --benchmark \
  --no-spinner
```

Match means:
- input tokens match;
- output tokens match;
- cache read/write match;
- message count matches.

Match does **not** mean provider cost matches when Pi JSONL has `cost=0` but Tokscale can price the model. Reports should call this `tokscale token match`, not generic `matches parser`.

## Correctness gate

A row is publishable only when all are true:

- exact file matches expected golden;
- `exitCode === 0`;
- `timedOut === false`;
- Tokscale token match is `yes`;
- row used intended tool name;
- prompt/tool-call args are saved in run root.

If token match is `yes` but correctness is `0%`, accounting is valid but benchmark result is not publishable as successful edit.

## Known variance from 2026-05-25

Observed with `zai/glm-4.5-air`:

- `wrap_body` sometimes loops/retries until timeout despite exact JSON guidance.
- `insert_body_span` may drop leading newline/indent in inserted text.
- `try_catch` may compress `console.error(error); throw error;` onto one line unless exact JSON forces `\n`.
- `patch insert_after` may drop leading `\n  ` without exact JSON.

Treat these as prompt/model variance. The CLI/tool can still be working.

## Report status labels

Use one of:

- **exploratory** — method/harness under test; failures expected.
- **baseline** — spawn runner or first tmux run, useful but not publishable.
- **piloted** — tmux rows accepted after inspection/retry; publishable with caveats.
- **publishable** — full stated fixture scope green in one agreed method, with Tokscale validation and saved artifacts.

## Cleanup policy

Do not delete tmux sessions or run roots before user has chance to inspect.

Allowed cleanup after user approval:

```bash
tmux kill-session -t pi-bench-<timestamp>
/bin/rm -rf .pi/reports/pi-tmux-runs/<timestamp>
```

Do not use bare `rm` in this environment if shell aliases route it through missing wrappers; use `/bin/rm` when cleanup is approved.
