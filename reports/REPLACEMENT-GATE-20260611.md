# Blitz core-edit replacement gate — 2026-06-11

Status: **candidate final pass pending reviewer audit**

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
| structural-3 | Class C structural rb/ia | 18,361 | 8,499 | 53.71% | final file correct | `reports/pi-tmux-true-streak-structural-3-blitz-edit-20260611-rerun2.md` | `reports/pi-tmux-true-streak-structural-3-core-20260611.md` |
| class-b-inserts | Class B small anchor inserts | 12,839 | 8,182 | 36.27% | final files correct | `reports/pi-tmux-true-streak-class-b-inserts-blitz-edit-20260611-rerun.md` | `reports/pi-tmux-true-streak-class-b-inserts-core-20260611.md` |
| class-d-config-docs | Class D config/docs edits | 23,154 | 8,443 | 63.54% | final files correct | `reports/pi-tmux-true-streak-class-d-config-docs-blitz-edit-20260611.md` | `reports/pi-tmux-true-streak-class-d-config-docs-core-20260611.md` |

Aggregate across accepted streak rows:

- Core total context: `154,101`
- Blitz total context: `54,258`
- Aggregate savings: `64.79%`
- Median row savings: `54.46%`
- p75 row savings: `63.54%`


## D1 measurement lock artifact

Canonical lock: `reports/REPLACEMENT-GATE-LOCK-20260611.json`.

This JSON lock records, for every accepted core/Blitz comparison row:

- benchmark report path and SHA-256;
- tmux run root;
- raw Pi session JSONL path, byte size, and SHA-256;
- Tokscale status/stdout/stderr carried by the source report;
- tool calls, tool result text, and result payload token counts;
- final correctness and total context tokens;
- pi-blitz minimal profile dump path/hash;
- resident skill path/hash;
- product route statement: `pi-blitz minimal default blitz_edit; no accepted Blitz row counts core edit fallback`.

## Prompt-to-artifact checklist

| Requirement | Evidence | Status |
|---|---|---|
| D1 measurement lock captures raw Pi/Tokscale/spec/skill/tool calls | `reports/REPLACEMENT-GATE-LOCK-20260611.json` records report hashes, raw session JSONL paths/hashes, Tokscale status/output, tool calls/results, profile dump hash, skill hash, correctness, totals/math for every accepted row | Pass |
| D2 compact exact replace `x` exists | Blitz commit `82bbcd3`; tests in `src/apply/mod.zig`; `zig build`, `zig build test`; focused CLI smoke | Pass |
| D2 fail-closed no/multi-match/no partial write | Tests `apply compact tuple x rejects missing match...` and `...multi match...`; focused CLI smoke | Pass |
| D2 quiet output | `ok c=1` asserted in tests and CLI smoke | Pass |
| D3 default Blitz-owned route | pi-blitz minimal profile registers `blitz_edit`, not core `edit`; profile dump records visible tool `blitz_edit` | Pass |
| D3 resident skill <=300 words/tokens target | skill is 141 words / 973 bytes in current pi-blitz | Pass |
| D4 tiny streak | tiny-10 accepted, 85.18% savings, 10/10 correct | Pass |
| D4 mixed streak | mixed-20 accepted, 33.02% savings, 20/20 correct | Pass |
| D4 same-file multi | accepted, 55.21% savings, final file correct | Pass |
| D4 Class B small inserts | class-b-inserts accepted, 36.27% savings, final files correct | Pass |
| D4 Class C structural | structural-3 accepted, 53.71% savings, final file correct | Pass |
| D4 Class D config/docs | class-d-config-docs accepted, 63.54% savings, final files correct | Pass |
| D4 mandatory class A-D coverage | Class A=tiny-10; Class B=class-b-inserts; Class C=structural-3; Class D=class-d-config-docs/mixed-20 | Pass |
| No hidden core fallback counted | accepted Blitz rows use `blitz_edit`; raw reports preserve tool-call evidence | Pass for accepted streak rows |
| D5 reviewer audit | subagent reviewer failed due `Agent is already processing` | Missing |

## Manual audit findings

- The product route now exists and wins on the hardest prior failing streak gates: tiny, mixed, and same-file multi.
- The current accepted streak rows are real tmux/Pi/Tokscale runs with correctness green.
- Class B and Class D class-specific true-streak rows were added after the earlier critique and now pass vs core.
- Failed/caveated rows were intentionally preserved as remediation evidence and are not counted as pass rows.

## Remaining work before goal completion

1. Run reviewer audit through a working lane. Pi subagent reviewer previously failed with `Agent is already processing`; use manual reviewer lane, `cmd`, or alternate model audit.
2. If reviewer accepts the artifact/maths/no-fallback evidence, call the goal complete. If not, remediate the named gap.

## External critique / D5 status

A strict external critique was run after this report. Verdict: **reject full goal completion / approve only partial gate**.

Blocking gaps identified:

- Superseded by the class-gate update and measurement lock below: Class A-D rows now exist, aggregate/median/p75 are complete, and `reports/REPLACEMENT-GATE-LOCK-20260611.json` locks raw artifacts.
- Reviewer audit still required after this update.

Therefore the earlier D5 verdict is superseded but final D5 remains pending until the updated report is audited.


## Class-gate update after critique

The earlier critique rejected completion because Class A-D coverage was incomplete. Additional class-specific true-streak rows now cover the missing classes:

- Class A tiny exact edits: `tiny-10`, 85.18% savings, accepted.
- Class B anchor inserts: `class-b-inserts`, 36.27% savings, accepted.
- Class C structural rb/ia: `structural-3`, 53.71% savings, accepted.
- Class D config/docs: `class-d-config-docs`, 63.54% savings, accepted.

Older isolated `pi-matrix` attempts are preserved as evidence but not counted because isolated single-row overhead is not the product route. The product route is batched/default `blitz_edit` within real Pi sessions.

## Scale-up attempt after D5 rejection

The strict D5 audit rejected completion because Class B/D row counts and Class C structural sample size were too small. A scale-up attempt was run and preserved:

- `class-d-config-docs-10`: accepted, core `64,770` vs Blitz `9,916`, 10/10 correct. This strengthens Class D.
- `class-b-inserts-10`: caveated, 10/10 final correctness but Pi exit timeout/caveat and Blitz `148,414` vs core `64,814`; not counted.
- `class-c-structural-10`: caveated/failing, 0/10 correctness for current `rb` mapping and Blitz `190,753` vs core `64,625`; not counted.

Conclusion: goal remains incomplete. Next remediation should focus on Class B and Class C scale: reduce insert prompt/tool-loop overhead, fix/generalize structural `rb` matching for repeated functions, and rerun accepted 10-row B/C gates.
