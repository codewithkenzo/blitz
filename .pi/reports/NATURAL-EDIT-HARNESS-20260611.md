# Natural edit harness

**First slice** — unscripted Pi-driven benchmark for natural user prompts.

## What it is

A lightweight harness (`bench/natural-edit.ts`) that defines 6 natural edit
scenarios and runs each through Pi core and Pi blitz lanes using normal
free-form prompts (no exact JSON guidance). It:

- Spawns `pi` with each lane's tool configuration
- Parses file-level correctness by comparing output SHA256 against expected
- Classifies outcomes into the taxonomy: `blitz_mutated`, `core_mutated`,
  `noop`, `decline_or_no_mutation`, `incorrect`
- Writes a JSON report and a Markdown report per run
- Preserves artifacts when `--keep-temp` is passed

## 6 scenarios

| ID | Description | Idempotent |
|---|---|---|
| `tiny-exact` | Replace a single unique return line in a 3-line function | no |
| `mixed-config-doc` | Two edits across different files (TS config + HTML title) | no |
| `same-file-multi` | Three edits in the same file (return replace, anchor insert, wrap body) | no |
| `structural-body` | Wrap ~280-line function body in try/catch without naming exact text | no |
| `no-op-idempotent` | File already has the target change; model should detect nothing to do | yes |
| `ambiguous-repeated-anchor` | Replace only the last of 3 identical return statements | no |

## Usage

```bash
bun bench/natural-edit.ts                     # full run, 1 iter each
bun bench/natural-edit.ts --iters 3           # 3 iterations per scenario
bun bench/natural-edit.ts --lane core         # core lane only
bun bench/natural-edit.ts --scenario tiny     # single scenario filter
bun bench/natural-edit.ts --keep-temp         # preserve run artifacts
bun bench/natural-edit.ts --verbose           # detailed per-iter logging
```

## Output

Reports go to `.pi/reports/natural-edit-harness/natural-edit-<stamp>.json` and
`.md`. Artifacts (when `--keep-temp` is used) go to
`.pi/reports/natural-edit-runs/`.

## Taxonomy mapping

| Outcome label | Meaning |
|---|---|
| `blitz_mutated` | Blitz lane, all files match expected, exit 0 |
| `core_mutated` | Core lane, all files match expected, exit 0 |
| `noop` | Idempotent scenario, files unchanged, exit 0 |
| `decline_or_no_mutation` | Non-zero exit without timeout (model declined or tool errored) |
| `incorrect` | Files don't match expected, or timed out |

## First smoke result — Zai tiny-exact

A first smoke was run:

```bash
bun bench/natural-edit.ts --provider zai --model glm-4.5-air --scenario tiny-exact --iters 1 --keep-temp --verbose
```

Report: `.pi/reports/natural-edit-harness/natural-edit-2026-06-11T21-34-44-939Z.md`

Result: **not accepted**.

- core lane: `decline_or_no_mutation`, exit `143`, 0/1 correct
- blitz lane: `decline_or_no_mutation`, exit `143`, 0/1 correct
- artifacts preserved under `.pi/reports/natural-edit-runs/`

This smoke proves
 the harness can launch and preserve artifacts, but it also exposes first remediation needs before rows can be counted:

1. timeout/exit handling should mark `timedOut` consistently instead of only exit 143;
2. file correctness collection appears to read an empty/missing output path after timeout (`gotSha` empty), so artifact path handling needs audit;
3. natural prompt/tool configuration needs tuning so at least tiny exact completes under both lanes.

These failed smoke rows are preserved as evidence and are not counted as accepted universal proof.
