# Local Gap Report: blitz + pi-blitz (repo-local exploration)

Date: 2026-04-27
Scope: `/home/kenzo/dev/blitz` and `/home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz`

## 1) Current blast/edit pipeline mapping

### Blitz CLI pipeline
- `src/main.zig`
  - command dispatch: `read`, `edit`, `batch-edit`, `rename`, `undo`, `doctor`
  - `dispatchEdit` parses `--snippet`, exactly one of `--after`/`--replace`, optional `--json`
  - `dispatchBatch` parses `--edits -` JSON array
- `src/cmd_edit.zig`
  - `runEdit` resolves language via extension, reads file, calls `edit_support.applyToSource`, writes backup, atomic write, emits plain/text or JSON metrics when `--json`
  - JSON lane includes `lane="direct"|"marker"`, token estimates from `metrics.computePayloadEstimate`
- `src/edit_support.zig`
  - `applyToSource` parse tree → resolve symbol with `symbols.findEditableSymbolNode` → body replacement range via `replacementRangeFor` → normalize snippet → optional splice via `splice.maybeSplice` → incremental parse validation (`validateEditedSourceIncremental`) → return replacement and parse timing
  - symbol matching is strict declaration-kind recursion (`function_declaration`, `method_declaration`, `class_declaration`, etc.) and field `name`
- `src/cmd_batch.zig`
  - parses JSON edits, applies sequentially on in-memory working copy, hard-fails on first error, single backup+write at end
- `src/backup.zig` single-depth SHA-keyed rollback per canonical path; `undo` reads latest backup and restores

### Pi extension pipeline
- `extensions/pi-blitz/index.ts`
  - loads config, registers 6 tools
- `extensions/pi-blitz/src/tools.ts`
  - `edit` → canonicalize path → spawn `blitz edit <file> --snippet - --replace|--after <sym> --json`
  - per-path lock via `mutex.withLock` around mutating tools
  - parses success JSON to `usedMarkers` metric
- `extensions/pi-blitz/src/doctor.ts`
  - cached `blitz doctor` probe + version floor parsing
- `src/tool-runtime.ts`
  - Effect boundary, soft errors become `isError` tool results; hard errors throw

## 2) Splice semantics (implemented)
- Module `src/splice.zig`
  - marker parse supports **exactly one marker per snippet**
  - comment styles allowed via lang styles from `edit_support.commentStylesFor`
  - marker forms:
    - strict: `// ... existing code ...`, `# ...`, `/* ... */`
    - strict anchor: `// @keep`, `// @keep lines=N`
  - if zero markers: splice returns `null` => direct replacement
  - if >1 marker or mixed styles/errors: returns `MarkerGrammarInvalid`/`AmbiguousAnchor`/`AnchorNotFound`
  - merge strategy = text LCS over split lines + context-block diff; `existing` requires preserved lines >0; `keep` requires exact keep_count preserved from deletion window
- `src/edit_support.zig` does not auto-fallback on marker errors; hard errors bubble to CLI and abort edit
- `src/edit_support.zig` normalization:
  - braces stripped (`normalizeBraceBodySnippet`), then marker/splice pass
  - signature-preserving behavior exists only when snippet/body is in/around function block shape

## 3) CLI tool API map
- Blitz CLI args
  - `blitz edit <file> --snippet - --replace <symbol>`
  - `blitz edit <file> --snippet - --after <symbol>`
  - `blitz batch-edit <file> --edits <json>`
  - `blitz rename`, `blitz undo`, `blitz doctor`, `blitz read`
- JSON output shape in `cmd_edit.runEdit` contains
  - mode/lane/metrics counters, bytes before/after, `usedMarkers`, token-estimate deltas, `wallMs`
- Pi tools (`extensions/pi-blitz/src/tools.ts` + SKILL)
  - `pi_blitz_read`, `pi_blitz_edit`, `pi_blitz_batch`, `pi_blitz_rename`, `pi_blitz_undo`, `pi_blitz_doctor`
  - schema: `file` max 4096, `snippet` max 65536, `symbol` up to 512, batch max 64 items, aggregate bytes 256KB

## 4) TypeBox schema (exact)
- `pathSchema`, `snippetSchema`, `replaceSymbolSchema`, `afterSymbolSchema`, `renameSymbolSchema` in `extensions/pi-blitz/src/tools.ts`
- edit tool runtime validation: exactly-one-of `after`/`replace`, snippet byte-cap recheck
- error reasons in classification:
  - CLI stderr/exit mapped → `BlitzSoftError { reason: no-undo-history|no-occurrences|no-references|blitz-error }`
  - no explicit parse/merge hard reason mapping for marker failures beyond generic blitz-error text

## 5) Benchmark harness map
- `bench/run.ts`
  - microbench direct vs marker, exact output assertions, token estimate by bytes/4, thresholds from `bench/regression-thresholds.json`
- `bench/llm-tokens.ts`
  - real tokenizer (cl100k) payload compare for tool calls: core `{file,oldText,newText}` vs blitz `{file,replace|after,snippet}`
  - anchors: full symbol + realistic (3-context) + minimal
- `bench/llm-pi.ts`
  - real Pi runs with identical prompts + optional same skill in blitz lane; parses JSONL usage + tool-call args token count
  - blitz guidance injected for marker cases (`// ... existing code ...`)
- `bench/deep-small-target.ts`, `bench/deep-large-symbol.ts`
  - pathologic baseline where token gain can be muted when core old/new span is already small

## 6) Tests/docs coverage status
- Blitz tests: all embedded in `src/*` plus `src/test_all.zig` aggregator. No separate `tests/` cases (directory empty).
- Pi extension tests: `extensions/pi-blitz/test/smoke.test.ts` only (effect errors/lock behavior, no end-to-end CLI tool invocation).
- Docs: `docs/blitz.md`/`docs/fastedit-splice-algorithm.md` describe broader v0.2 roadmap and fallback semantics not fully wired locally.

## 7) Why marker/body-only often fails to show drastic savings in real runs
1) **Baseline mismatch in real token comparisons**
   - Real Pi bench (`bench/llm-pi.ts`) compares provider-session output, not just tool arg string.
   - Core lane prompt+tool behavior can already operate on narrower contexts than full-file; small symbol edits can have low delta between core and blitz args.
2) **Marker contract too brittle for model variance**
   - parser rejects mixed styles, multiple markers, ambiguous placements, and missing anchor windows.
   - no local deterministic recovery: marker failure aborts edit (no host-merge fallback on the same call path).
3) **Savings model diluted by real body sizes**
   - When target symbols are already small (`deep-small-target`, small fixture), blitz savings vs full-symbol core are naturally bounded.
4) **Tool-call overhead / host strategy drift**
   - If prompt framing still encourages “full correctness snippets” or repeated unchanged context, model may emit near-old/new-size snippets despite marker guidance.
5) **Docs/plumbing mismatch increases misalignment risk**
   - `cli.zig` help/doctor text and README still label broad areas scaffold/pre-alpha; guidance source of truth is split and partly stale.

## 8) Concrete gaps (local-only fixes)
- Wire `fallback.zig` / needs_host_merge payload path into `cmd_edit` for deterministic “recoverable” failures.
- Extend splice acceptance/ambiguity policy (multi-marker tolerant modes or structured retry prompt payloads) or surface structured retry signals instead of hard fail.
- Integrate config values (`defaultTimeoutMs`, `cacheDir`, `trustedExternalPaths`) from extension `loadConfig` into `runBlitz` and path canonicalization.
- Add integration tests for `pi_blitz_edit` marker success/failure and end-to-end `blast`-style fallback payload parsing.
- Unify version/help/docs signals: remove stale “scaffold” strings in `src/cli.zig` and `README.md` to reduce prompt/tool mismatch.
- Add coverage for `--json` marker-path correctness and malformed-marker failure classification in both layers.
