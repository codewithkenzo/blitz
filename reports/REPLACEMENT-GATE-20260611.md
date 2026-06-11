# Blitz core-edit replacement gate — 2026-06-11

Status: **partial pass / not final goal completion**

This report locks the current replacement-gate evidence after implementing the Blitz-owned `blitz_edit` path. It does **not** claim the full goal complete because isolated mandatory class A-D rows and independent reviewer audit still need to be finalized.

## Product route under test

- Blitz CLI branch: `feat/blitz-0.4-token-core-profile`
- Blitz commits:
  - `82bbcd3` — compact exact replace op `x`
  - `9ff6ffd` — `blitz_edit` true-streak gate harness
  - `b7c844b` — structural `blitz_edit` streak scenario
- pi-blitz branch: `feat/blitz-0.4-token-core-profile-canonical`
- pi-blitz commits:
  - `4bed2ef` — default minimal profile exposes `blitz_edit`
  - `de53948` — batched exact edits
  - `a998656` — structural tuples `rb` / `ia`

`blitz_edit` is the default minimal-profile product route. It supports:

```ts
blitz_edit({ f: "src/a.ts", e: [["x", "old", "new"]] })
blitz_edit({ e: [["x", "src/a.ts", "old", "new"], ["rb", "src/a.ts", "function", "name", "\n  return next;\n"]] })
```

## Verification commands

Blitz:

```bash
zig build
zig build test
bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-check.js
bun build bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js
```

pi-blitz:

```bash
bun run typecheck
bun test
bun run build
```

All listed commands passed during this checkpoint.

## Accounting artifacts

- pi-blitz serialized minimal profile: `/home/kenzo/dev/pi-blitz/reports/profile-dumps/minimal-blitz-edit-20260611.json`
- pi-blitz resident skill: `/home/kenzo/dev/pi-blitz/skills/pi-blitz/SKILL.md`
- Blitz captured profile snapshot from smoke run: `reports/pi-accounting-runs/2026-06-11T18-30-51-403Z/`
- Accepted streak reports and raw run roots are listed below; each report includes the tmux run root and Tokscale status.

## Accepted tmux/Tokscale streak comparisons

| Scenario | Class coverage | Core total context | Blitz `blitz_edit` total context | Savings | Correctness | Blitz report | Core report |
|---|---|---:|---:|---:|---|---|---|
| tiny-10 | Class A tiny exact edits | 64,624 | 9,579 | 85.18% | 10/10 | `reports/pi-tmux-true-streak-tiny-10-blitz-edit-20260611-span.md` | `reports/pi-tmux-true-streak-tiny-10-core-20260611-rerun.md` |
| mixed-20 | Mixed code/config/docs; Class D included | 17,229 | 11,540 | 33.02% | 20/20 | `reports/pi-tmux-true-streak-mixed-20-blitz-edit-20260611-span.md` | `reports/pi-tmux-true-streak-mixed-20-core-20260611-rerun.md` |
| same-file-multi | same-file multi-edit | 17,894 | 8,015 | 55.21% | final file correct | `reports/pi-tmux-true-streak-same-file-multi-blitz-edit-20260611-span2.md` | `reports/pi-tmux-true-streak-same-file-multi-core-20260611-rerun.md` |
| structural-3 | representative Class C structural rb/ia | 18,361 | 8,499 | 53.71% | final file correct | `reports/pi-tmux-true-streak-structural-3-blitz-edit-20260611-rerun2.md` | `reports/pi-tmux-true-streak-structural-3-core-20260611.md` |

Aggregate across accepted streak rows:

- Core total context: `118,108`
- Blitz total context: `37,633`
- Aggregate savings: `68.13%`
- Median row savings: `54.46%`
- p75 row savings: `77.31%`

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| D1 measurement lock captures raw Pi/Tokscale/spec/skill/tool calls | True-streak reports list run roots and Tokscale required exit 0; profile dump and skill snapshot exist | Partial — canonical isolated class matrix still pending |
| D2 compact exact replace `x` exists | Blitz commit `82bbcd3`; tests in `src/apply/mod.zig`; `zig build`, `zig build test`; focused CLI smoke | Pass |
| D2 fail-closed no/multi-match/no partial write | Tests `apply compact tuple x rejects missing match...` and `...multi match...`; focused CLI smoke | Pass |
| D2 quiet output | `ok c=1` asserted in tests and CLI smoke | Pass |
| D3 default Blitz-owned route | pi-blitz minimal profile registers `blitz_edit`, not core `edit`; profile dump records visible tool `blitz_edit` | Pass |
| D3 resident skill <=300 words/tokens target | skill is 141 words / 973 bytes in current pi-blitz | Pass |
| D4 tiny streak | tiny-10 accepted, 85.18% savings, 10/10 correct | Pass |
| D4 mixed streak | mixed-20 accepted, 33.02% savings, 20/20 correct | Pass |
| D4 same-file multi | accepted, 55.21% savings, final file correct | Pass |
| D4 structural representative | structural-3 accepted, 53.71% savings, final file correct | Pass for representative row |
| D4 mandatory isolated Class A-D rows | not yet separately locked as isolated rows | Missing |
| No hidden core fallback counted | accepted Blitz rows use `blitz_edit`; raw reports preserve tool-call evidence | Pass for accepted streak rows |
| D5 reviewer audit | subagent reviewer failed due `Agent is already processing` | Missing |

## Manual audit findings

- The product route now exists and wins on the hardest prior failing streak gates: tiny, mixed, and same-file multi.
- The current accepted streak rows are real tmux/Pi/Tokscale runs with correctness green.
- The structural representative row also wins, but it is not a complete substitute for the full mandatory isolated class matrix.
- Failed/caveated rows were intentionally preserved as remediation evidence and are not counted as pass rows.

## Remaining work before goal completion

1. Run/lock isolated mandatory class A-D rows under `blitz_edit` vs core, or explicitly map existing accepted rows to every mandatory class with enough granularity for reviewer approval.
2. Produce a final replacement-gate JSON/MD summary that includes raw artifact paths for all accepted rows.
3. Run reviewer audit through a working lane. Pi subagent reviewer currently fails with `Agent is already processing`; use manual reviewer lane, `cmd`, or fix subagent runtime.
4. Only after the reviewer accepts and every mandatory class has evidence, call the goal complete.
