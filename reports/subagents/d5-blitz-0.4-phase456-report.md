# D5 Blitz 0.4 Phase 4/5/6 report

Date: 2026-06-09
Status: Phase 4 partial implementation + local token comparison; Phase 5 deferred; Phase 6 benchmark/router boundary made explicit.

## Phase 4 — compact/freeform/custom path

Implemented in `/home/kenzo/dev/pi-blitz`:

- `pi_blitz_op` now accepts either `ops` JSON tuples or `s` compact script string.
- Script syntax: one tuple per line or semicolon, tab-separated fields, e.g. `rr<TAB>formatStatus<TAB>status.toLowerCase()<TAB>only`.
- Runtime translates script into existing compact tuple path, preserving alias validation and Blitz apply safety.
- Tests cover `rr` and `dk` script translation.

Local token comparison only (not savings claim):

Command:

```bash
cd /home/kenzo/dev/blitz && bun -e 'import { encoding_for_model } from "tiktoken"; const enc=encoding_for_model("gpt-4o"); const cases=[{name:"rr",json:JSON.stringify({f:"src/example.ts",ops:[["rr","formatStatus","status.toLowerCase()","only"]]}),script:JSON.stringify({f:"src/example.ts",s:"rr\tformatStatus\tstatus.toLowerCase()\tonly"})},{name:"dk",json:JSON.stringify({f:"src/example.ts",ops:[["dk",3,9,"remove"]]}),script:JSON.stringify({f:"src/example.ts",s:"dk\t3\t9\tremove"})}]; for (const c of cases){console.log(c.name, enc.encode(c.json).length, enc.encode(c.script).length, c.json, c.script)} enc.free();'
```

Output:

| Case | JSON tuple arg tokens | script field arg tokens | Delta |
|---|---:|---:|---:|
| `rr` | 24 | 22 | -2 |
| `dk` | 19 | 17 | -2 |

Evidence status: implemented + locally compared. No correctness/token savings claim from this local tokenizer comparison. Real Pi/Tokscale rows still required before adoption as preferred path. OpenAI custom/freeform Pi tool path not implemented: Pi current extension surface here is TypeBox JSON schema tool registration, not provider-native OpenAI custom/freeform tool exposure. `s` is therefore smallest safe prototype.

## Phase 5 — deterministic chunk-local merge spike

Deferred, not faked.

Current code reasons:

- Existing `compose_body` supports deterministic kept body islands, but it requires explicit anchors/segments, not AST-scoped chunk extraction to ~35-60 lines.
- Current apply target resolution returns target/body byte ranges, not a model-facing chunk window with stable chunk IDs and line-bound preconditions.
- No operation currently accepts keep-marker snippet (`//...`) and proves deterministic classification into anchors/splices before write.
- Adding this safely needs new IR, chunk window extraction, ambiguity errors, and tests across TS/Zig/Markdown-like comments; doing it inside this slice risks unsafe fuzzy merge.

Named follow-up phase: **Phase 5A — chunk-local merge IR**.

Minimum follow-up acceptance:

1. Add `merge_body_chunk`/compact alias only after chunk extraction API exists.
2. Target one symbol, emit 35-60 line chunk with stable prefix/suffix anchors.
3. Accept snippet with `//...` keep markers.
4. Fail closed on duplicate anchors, missing anchors, or chunk overflow.
5. Add Zig tests for success + ambiguous duplicate + missing marker.
6. Only then run Pi/Tokscale semantic rows to compare against core.

## Phase 6 — token-first router/integration boundary

Implemented benchmark/reporting boundary in `/home/kenzo/dev/blitz/bench/pi-matrix.ts`:

- Per-run JSON records now include `tokenRouteDecision` with token-first fields:
  - `contextSavingsPct`
  - `schemaTokensExpected`
  - `argTokensExpected`
  - `outputTokensExpected`
  - `fallbackContextTokensExpected`
  - `selectedBecause`
- `selectedBecause` explicitly says current harness lane/profile selection is not runtime core replacement proof.

Runtime integration boundary:

- Current runtime integration is **Pi extension profile/skill enforced**, not a core edit wrapper.
- `PI_BLITZ_TOOL_PROFILE=minimal` can expose only `pi_blitz_op`; this bounds model-visible tools before model call.
- No core-tool wrapper or automatic token oracle exists yet. Therefore Phase 6 replacement claim remains bounded: router proof is benchmark/report-level plus profile enforcement until a follow-up implements an edit facade/default wrapper.

Named follow-up phase: **Phase 6A — runtime edit facade/router**.

Minimum follow-up acceptance:

1. One familiar edit facade or Pi extension wrapper receives edit intent before model tool choice.
2. Facade chooses core/apply_patch/Blitz using measured resident schema+skill and arg estimates.
3. Non-selected Blitz routes include token reason.
4. Selected Blitz routes include paired baseline proof.

## Verification

pi-blitz:

- `bun run typecheck && bun test && bun run build` — passed before commit.

Blitz:

- `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-phase456-check.js` — passed after bench change.
- `zig build && zig build test` — passed.

## Commits

pi-blitz:

- `fe85e2d feat(op): support compact script field` pushed to `origin/feat/blitz-0.4-token-core-profile`.

Blitz:

- pending commit for bench token-route decision/report at report write time.

## Residual gaps

- No new real Pi/Tokscale accepted rows for Phase 4 script field; local tokenizer comparison only.
- Phase 5 deferred to Phase 5A with concrete code reasons.
- Phase 6 is bounded; no core replacement/default wrapper claim.
- Existing dirty files from main/user were present before this D5 slice: `reports/subagents/main-blitz-0.4-completion-audit-checklist.md` and one tmux session JSONL. Not staged by this report.
