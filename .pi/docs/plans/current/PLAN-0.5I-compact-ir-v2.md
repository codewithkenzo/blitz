# PLAN-0.5I — Compact IR v2 design

Date: 2026-06-20
Ticket: `bli-fu5w`
Status: design-only, no model/provider runs

## Source evidence

Inputs used:

- `.pi/docs/plans/current/PLAN-0.5I-token-moonshot.md`
- `.pi/reports/current/SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md`
- `.pi/reports/current/SPRINT-I-ROUTE-OPTIMIZER-TOKEN-TARGET-MATH-20260620.md`
- existing `.pi/docs/product/blitz.md` structured apply policy

Non-claim boundary: estimates below are byte/count budgets from proposed payload shapes. They are not Tokscale/session savings claims.

## Goal

Compact IR v2 reduces model-visible per-call args/result overhead for common green edit classes without weakening exact safety.

Primary target rows:

1. batched exact config/doc/source edits;
2. same-file multi-edit rows;
3. repeated file/anchor rows;
4. future large exact rows where core old/new replay grows.

Minimal profile stays exact-only plus fail-closed structural decline. Structural body replace remains advanced-only.

## Design principles

- One resident minimal surface.
- No unchanged-code replay when a shorter exact locator is available.
- File path and anchor repetition must be dictionary-compressible.
- Every mutation remains deterministic, exact, non-overlapping, and no-op safe.
- Compact success output must be parseable enough for router telemetry.
- Backward compatibility keeps current tuple/object payloads valid.

## IR v2 envelope

Canonical compact envelope:

```json
{"f":"src/a.ts","a":["old"],"e":[["x",0,"new"]],"o":"m"}
```

Fields:

| Field | Meaning | Required | Notes |
| --- | --- | --- | --- |
| `f` | top-level default file | optional | applies to edits without per-edit file |
| `p` | path dictionary | optional | array of paths; edit file can be integer index |
| `a` | anchor/source dictionary | optional | array of repeated oldText/anchors/symbol names |
| `r` | replacement dictionary | optional | array of repeated replacement strings |
| `e` | edit tuples | required | compact mixed edit list |
| `o` | output mode | optional | `m` minimal, `s` summary, `v` verbose |
| `v` | IR version | optional | omitted means v2-compatible auto-detect after v2 ships |

Recommended default for minimal profile: omit `v` to save bytes while parser detects v2 tuple shapes. Use `v:2` only for debugging/transition tests.

## Operation aliases

Accepted op aliases:

| Alias | Long op | Minimal profile | Advanced profile | Notes |
| --- | --- | --- | --- | --- |
| `x` | exact replace | yes | yes | one exact oldText/newText replacement |
| `i` | insert exact | yes, guarded | yes | exact anchor insertion; requires side `b`/`a` or tuple shape |
| `d` | exact delete | yes, guarded | yes | oldText must match exactly once unless explicit count |
| `rb` | replace symbol body | no, decline | yes | structural advanced-only |
| `ia` | insert after symbol | no, decline | yes | structural advanced-only |
| `im` | import edit | no, decline | yes/future | advanced-only until locked |
| `lr` | local rename | no, decline | yes/future | advanced-only until locked |

Minimal profile behavior for unsupported structural aliases: reject with compact decline, no mutation, `no_mutation=true`.

## Tuple shapes

### Minimal exact shapes

Same file via top-level `f`:

```json
{"f":"a.ts","e":[["x","old","new"]]}
```

Dictionary oldText:

```json
{"f":"a.ts","a":["old"],"e":[["x",0,"new"]]}
```

Dictionary oldText and replacement:

```json
{"f":"a.ts","a":["old"],"r":["new"],"e":[["x",0,0]]}
```

Path dictionary:

```json
{"p":["a.ts","b.ts"],"e":[[0,"x","oldA","newA"],[1,"x","oldB","newB"]]}
```

Mixed explicit path plus anchor dictionary:

```json
{"p":["a.ts","b.ts"],"a":["OLD"],"e":[[0,"x",0,"NEW"],[1,"x",0,"NEW"]]}
```

### Insert/delete exact shapes

Insert after exact anchor:

```json
{"f":"a.ts","a":["anchor"],"e":[["i",0,"after","a"]]}
```

Insert before exact anchor:

```json
{"f":"a.ts","a":["anchor"],"e":[["i",0,"before","b"]]}
```

Delete exact text:

```json
{"f":"a.ts","a":["obsolete"],"e":[["d",0]]}
```

`i`/`d` stay optional in minimal lock. If provider shape tests show confusion, keep minimal `x` only and route insert/delete through current explicit object forms or core.

## File defaults and dictionaries

Resolution order:

1. per-edit file path string;
2. per-edit path dictionary index from `p`;
3. top-level default `f`;
4. reject `missing_file`.

Dictionary refs:

- integer in oldText/anchor slot resolves through `a`;
- integer in replacement slot resolves through `r`;
- path integer resolves through `p` only in file position;
- negative, fractional, out-of-range, or wrong-position refs reject.

No implicit fuzzy anchor lookup. Dictionary refs compress repeated exact strings only; they do not change matching semantics.

## Multi-edit batching

Batch semantics:

1. parse entire envelope;
2. resolve files/anchors/replacements;
3. group by file;
4. load each file once;
5. resolve all exact ranges against original file contents;
6. reject whole batch on any error by default;
7. reject overlapping ranges;
8. apply ranges in descending offset order;
9. atomic write per changed file.

Default atomicity: all-or-nothing across files. If cross-file atomic write cannot be guaranteed on platform, perform preflight-only full validation, then write files; on write failure emit `partial_write_error` with changed file list. Minimal profile should avoid multi-file unless atomicity is implemented or explicitly marked.

Optional future field:

```json
{"mode":"best_effort"}
```

Not in minimal v2. It invites silent partial mutation.

## Compact output taxonomy

Output mode `m` is default minimal result.

### Success

```json
{"ok":1,"m":2,"f":1}
```

Fields:

- `ok:1` success;
- `m` mutations applied;
- `f` changed file count.

### No-op

```json
{"ok":1,"m":0,"r":"already"}
```

Allowed reasons:

- `already` replacement already present and old text absent in an idempotent pattern;
- `empty` edit list empty and allowed by caller profile.

### Decline / safety reject

```json
{"ok":0,"r":"ambig","n":3}
```

Reason codes:

| Code | Meaning | Mutates |
| --- | --- | --- |
| `missing` | oldText/anchor not found | no |
| `ambig` | exact locator matched more than allowed | no |
| `overlap` | resolved edit ranges overlap | no |
| `shape` | invalid tuple/envelope shape | no |
| `ref` | invalid dictionary/path ref | no |
| `path` | path outside workspace/guard | no |
| `op` | unsupported op in active profile | no |
| `parse` | language/parser needed but unavailable | no |
| `fmt` | formatting normalization failed | no |
| `write` | write failed after validation | maybe partial, must include file list |

Minimal output must keep enough data for telemetry: success/failure, mutation count, file count, reason code, optional match count.

Verbose output remains opt-in via `o:"v"` and can include ranges, diff summary, validation details, and old result JSON for compatibility tests.

## Exact safety validation

Hard validation:

- workspace path guard before file read;
- UTF-8/text guard unless binary mode explicitly supported later;
- every exact oldText/anchor must match exactly once by default;
- explicit `count` may allow N matches only for all intended occurrences;
- unchanged replacement that creates no diff returns no-op, not success mutation;
- edits resolve on original content, not sequentially mutated content;
- overlaps reject whole batch;
- unsupported structural op in minimal rejects, never approximates;
- no fuzzy symbol/regex/AST fallback for `x`, `i`, or `d`.

Optional v2 field for repeated exact replacements:

```json
{"f":"a.ts","e":[["x","old","new",{"c":3}]]}
```

`c` means expected match count. Omit means `1`. `c:"all"` not allowed in minimal profile; too easy to over-edit.

## Backward compatibility

Compatibility rules:

1. Existing current tuple form remains valid:
   - `{"e":[["x","file","old","new"]]}`
   - `{"f":"file","e":[["x","old","new"]]}`
2. Existing object/long-form operations remain valid in full/advanced profiles.
3. Unknown top-level compact fields reject in minimal strict mode unless prefixed as telemetry-only future fields.
4. `rb`/`ia` remain recognized op names so minimal can decline deterministically instead of parse-failing into retry loops.
5. Output consumers accept both old result JSON and compact v2 result during transition.
6. Route selector may prefer core for singleton tiny exact if estimated Blitz args+output exceed core.

Migration path:

- phase 1: parser accepts v2 behind hidden/internal test flag;
- phase 2: pi-blitz emits v2 for selected rows only;
- phase 3: compact result mode default for minimal profile;
- phase 4: old verbose output requires `o:"v"`.

## Byte/token budget estimates

These are deterministic payload byte counts plus conservative token-estimate bands. They are planning estimates, not benchmark evidence.

| Scenario | Current-ish payload | v2 payload | Byte delta | Token-estimate implication |
| --- | ---: | ---: | ---: | --- |
| same-file one exact, no dict | `{"e":[["x","src/a.ts","old","new"]]}` = 36B | `{"f":"src/a.ts","e":[["x","old","new"]]}` = 42B | +6B | v2 loses unless top-level file reused or schema simpler |
| same-file two exact edits | two full path tuples ≈ 67B | top-level `f` ≈ 57B | -10B | small win from path reuse |
| two files, repeated oldText | explicit old twice ≈ 83B | `p` + `a` refs ≈ 67B | -16B | win grows with anchor length |
| 10 config/doc edits, one file | full path each ≈ path*10 + text | `f` once + 10 compact tuples | removes 9 path copies | likely best near-term class |
| repeated 80B anchor 5 times | anchor replay 400B | `a` once + 5 int refs ≈ 105B | about -295B | plausible large arg win if model produces refs correctly |
| compact success output | old JSON result often 150B+ | `{"ok":1,"m":2,"f":1}` = 20B | -130B+ | result payload tax drops materially |

Budget guard proposal:

- singleton tiny exact: v2 must route to core unless predicted `args + output + resident` <= core by at least 8 tokens;
- same-file batch: v2 allowed when at least 2 edits or old/anchor length >= 32B;
- dictionary mode: allowed when repeated path/anchor/ref saves at least 24B pre-tokenization;
- compact output: minimal success output target <= 32B, decline output target <= 64B;
- minimal resident schema must not grow beyond Sprint I zero-resident headroom without explicit gate.

## Provider-shape risks

Known risks:

- integer refs in string slots may confuse providers;
- tuple arity variants can cause off-by-one shape errors;
- `i` side parameter may drift (`after` vs `a`);
- dictionary payload may be less natural than direct exact replacement for tiny rows.

Mitigations:

- start v2 with `x` only;
- accept direct strings and refs in same parser;
- reject wrong shape with `shape`, no mutation;
- add provider-shape fixtures before making selector choose dictionary mode;
- keep core route for tiny/singleton rows.

## Acceptance checklist

- Covers aliases, file defaults, dictionaries/anchor refs, multi-edit batching, compact output taxonomy, exact safety validation, backward compatibility, budget estimates.
- No model/provider runs performed.
- No universal savings claim made.
- Structural `rb` remains advanced-only.
