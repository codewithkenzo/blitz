# Compact IR streak / fallback benchmark addendum

Date: 2026-06-11
Repo branch: `feat/blitz-0.4-token-core-profile`
Purpose: address the independent auditor's remaining benchmark coverage findings after implementation remediation.

## Auditor gaps addressed

The previous audit rejected completion because these explicit benchmark requirements lacked evidence:

- compact-Zig product-real mixed edit streak;
- tiny edit streak, not just one tiny row;
- marker-merge row for compact `mn` / `merge_body_chunk`;
- explicit fallback row.

This addendum records product-real Pi/tmux/Tokscale runs for those gaps. It does not claim default readiness or token savings.

## Run roots

```text
.pi/reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z
.pi/reports/pi-tmux-runs/compact-zig-ir-mn-fix-20260611T155221Z
.pi/reports/pi-tmux-runs/compact-zig-ir-mixed-seq-20260611T155319Z
```

Provider/model: `zai / glm-4.5-air`.

Blitz compact lane command shape:

```text
pi --offline -p --no-context-files --no-prompt-templates --provider zai --model glm-4.5-air --thinking off \
  --no-extensions --extension /home/kenzo/dev/pi-blitz/dist/index.js \
  --skill /home/kenzo/dev/pi-blitz/skills/pi-blitz --tools pi_blitz_op @prompt.md
```

Router fallback lane command shape uses `--tools pi_blitz_route_edit` and `PI_BLITZ_TOOL_PROFILE=router`.

Tokscale was run for each row by copying the session JSONL into `<run>/tokscale-home/.pi/agent/sessions/` and saving `<run>/tokscale-home.json`.

## Tiny edit streak

Three product-real compact Blitz `rb` rows ran successfully in sequence. Each used exactly one `pi_blitz_op` call and exited 0 with the expected edited file.

Run root: `.pi/reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z`

| row | tool | operation | exit | intended result |
|---|---|---|---:|---|
| `tiny-streak-1__blitz` | `pi_blitz_op` | `[["rb","function","smallTarget",snippet]]` | 0 | `smallTarget` returns `"hello " + name.toUpperCase()` |
| `tiny-streak-2__blitz` | `pi_blitz_op` | `[["rb","function","smallTarget",snippet]]` | 0 | same |
| `tiny-streak-3__blitz` | `pi_blitz_op` | `[["rb","function","smallTarget",snippet]]` | 0 | same |

Core comparison rows also exist in the same run root for `tiny-streak-1__core`, `tiny-streak-2__core`, and `tiny-streak-3__core`.

## Mixed edit streak

A clean sequential compact Blitz mixed streak was run with one row per supported compact edit family:

Run root: `.pi/reports/pi-tmux-runs/compact-zig-ir-mixed-seq-20260611T155319Z`

| row | tool calls | compact op | exit | final file evidence |
|---|---:|---|---:|---|
| `mixed-seq-rb__blitz` | 1 | `rb` body replace | 0 | `smallTarget` body changed to `return "hello " + name.toUpperCase();` |
| `mixed-seq-ia__blitz` | 1 | `ia` insert after symbol | 0 | `beta()` inserted after `alpha()` |
| `mixed-seq-mn__blitz` | 1 | `mn` marker merge | 0 | `const logged = true;` merged before preserved body |

Observed compact tool args:

```json
{"f":"work/sample.ts","ops":[["rb","function","smallTarget","\n  return \"hello \" + name.toUpperCase();\n"]]}
```

```json
{"f":"work/sample.ts","ops":[["ia","function","alpha","\nexport function beta(): number {\n  return 2;\n}\n"]]}
```

```json
{"f":"work/sample.ts","ops":[["mn","function","mergeable","\n  const logged = true;\n  const base = value + 1;\n//...\n  return keep;\n"]]}
```

Tokscale summaries for the clean sequential Blitz rows:

| row | Pi usage input | Pi usage output | Pi cacheRead | Tokscale file |
|---|---:|---:|---:|---|
| `mixed-seq-rb__blitz` | 133 | 209 | 3587 | `mixed-seq-rb__blitz/tokscale-home.json` |
| `mixed-seq-ia__blitz` | 119 | 302 | 3604 | `mixed-seq-ia__blitz/tokscale-home.json` |
| `mixed-seq-mn__blitz` | 130 | 314 | 3604 | `mixed-seq-mn__blitz/tokscale-home.json` |

## Marker-merge row

Initial marker-merge attempts in `compact-zig-ir-streak-20260611T155040Z` intentionally remain preserved as failed attempts: the provided snippet tried to modify the trailing anchor line and Blitz correctly returned a no-match/`blitz-error` rather than mutating unsafely.

A corrected product-real marker-merge row succeeded:

Run root: `.pi/reports/pi-tmux-runs/compact-zig-ir-mn-fix-20260611T155221Z`

| row | lane | tool | exit | calls | final file evidence | Tokscale file |
|---|---|---|---:|---:|---|---|
| `marker-merge-valid__blitz` | Blitz | `pi_blitz_op` | 0 | 1 | `const logged = true;` inserted while preserving base/keep/return lines | `marker-merge-valid__blitz/tokscale-home.json` |
| `marker-merge-valid__core` | core | `edit` | 0 | 1 | equivalent final semantic file | `marker-merge-valid__core/tokscale-home.json` |

Observed successful marker-merge compact args:

```json
{"f":"work/sample.ts","ops":[["mn","function","mergeable","\n  const logged = true;\n  const base = value + 1;\n//...\n  return keep;\n"]]}
```

Tokscale summary for successful marker merge:

| row | Pi usage input | Pi usage output | Pi cacheRead | Tokscale input | Tokscale output | Tokscale cacheRead | Tokscale messages | Tokscale cost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `marker-merge-valid__blitz` | 119 | 372 | 3600 | 187 | 508 | 7690 | 2 | 0.00082690 |
| `marker-merge-valid__core` | 128 | 700 | 3553 | 146 | 838 | 7933 | 2 | 0.00118899 |

## Explicit fallback row

Run root: `.pi/reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z`

Row: `fallback-decline__router`

The prompt called `pi_blitz_route_edit` with no `ops`/`s` payload:

```json
{"f":"work/sample.ts","r":"auto","fallbackContextTokensExpected":1000}
```

Observed tool result text:

```text
pi-blitz route declined: no-write terminal. selected=apply_patch. next=use external core/apply_patch. reason=no Blitz ops/s payload; use core/apply_patch with exact patch or oldText/newText
```

The row exited 0, invoked `pi_blitz_route_edit` exactly once, left the file unchanged, and saved Tokscale at:

```text
.pi/reports/pi-tmux-runs/compact-zig-ir-streak-20260611T155040Z/fallback-decline__router/tokscale-home.json
```

Tokscale summary:

| row | Pi usage input | Pi usage output | Pi cacheRead | Tokscale input | Tokscale output | Tokscale cacheRead | Tokscale messages | Tokscale cost |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `fallback-decline__router` | 3717 | 186 | 43 | 3768 | 376 | 3988 | 2 | 0.00128684 |

## Honest status

These rows satisfy the previously missing benchmark coverage categories:

- tiny edit streak: present (`tiny-streak-1/2/3`);
- mixed compact edit streak: present (`mixed-seq-rb/ia/mn`);
- marker-merge compact row: present (`marker-merge-valid`);
- explicit fallback row: present (`fallback-decline__router`).

The evidence still supports only a candidate/fallback posture. It does not justify enabling Blitz as default core edit replacement yet, because broader token totals remain mixed and provider/cache behavior varies by row.
