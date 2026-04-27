# blitz v0.2 ergonomics/token-savings redesign — spec-first implementation plan

Status: proposed  
Date: 2026-04-27  
Scope: plan/report only; no implementation files changed  
Primary repo: `/home/kenzo/dev/blitz`  
Companion repo/worktree: `/home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47`  
Skills loaded/read: `kenzo-execution-preferences`, `kenzo-tk-cli`, `kenzo-blueprint-architect`, `kenzo-zig`, `kenzo-zig-build`

## Linked anchors

- Canonical spec: `pi-rig/docs/architecture/blitz.md`
- Local mirror: `blitz/docs/blitz.md`
- Current implementation docs: `blitz/docs/fastedit-splice-algorithm.md`, `blitz/docs/tree-sitter-c-api-subset.md`
- Current CLI areas: `src/cmd_edit.zig`, `src/edit_support.zig`, `src/splice.zig`, `src/symbols.zig`, `src/metrics.zig`, `bench/run.ts`, `bench/llm-pi.ts`, `bench/llm-tokens.ts`
- Current Pi extension areas: `extensions/pi-blitz/src/tools.ts`, `extensions/pi-blitz/index.ts`, `extensions/pi-blitz/skills/pi-blitz/SKILL.md`, `extensions/pi-blitz/README.md`
- tk epic: `d1o-dnod` — blitz v0.1 + pi-blitz
- tk active benchmark task: `d1o-gso9` — Benchmark harness + first 10-case run
- tk v0.2 children to re-scope/link:
  - `d1o-1ep6` — Layer B fuzzy anchor recovery ladder
  - `d1o-ptf1` — Layer C structural tree-sitter query rewrites
  - `d1o-5hm9` — multi-edit + rename-all

Recommended tk links to add after this plan is accepted:

```txt
d1o-gso9 links += blitz/reports/blitz-v02-ergonomics-plan.md#benchmark-methodology
d1o-1ep6 links += blitz/reports/blitz-v02-ergonomics-plan.md#phase-2-structured-body-ops-before-fuzzy
d1o-ptf1 links += blitz/reports/blitz-v02-ergonomics-plan.md#phase-3-previewdiff-validation-and-structural-ir
d1o-5hm9 links += blitz/reports/blitz-v02-ergonomics-plan.md#phase-4-batchmulti-after-single-op-reliability
```

## Goal

Redesign blitz v0.2 around model-reliable, structured edit operations that create drastic output-token savings without relying on vague marker discipline or misleading benchmark claims.

Concrete target:

1. Models should call a narrow, typed operation instead of inventing a full replacement body for medium/huge symbols.
2. Common large-symbol edits should send only changed text plus deterministic keep/range instructions.
3. Every write should be previewable, parse-validated, diff-validated, and fail closed on ambiguity.
4. Benchmarks should distinguish:
   - deterministic tool payload size,
   - real provider `usage.output`,
   - tool-call argument tokens,
   - correctness rate,
   - wall time,
   - cost.
5. Public docs should make no broad savings/reliability claims until authentic Pi-driven gates pass.

## Current findings

### What exists now

- `blitz edit --replace <symbol>` replaces the **body range** for brace languages and Python block bodies. It preserves outer declaration/signature when snippet is body-only, but also normalizes snippets that include braces/signature.
- Marker splice exists in `src/splice.zig`; supports `// ... existing code ...`, shorthand ellipsis, `// @keep`, and `// @keep lines=N` with local golden tests.
- Pi extension exposes `pi_blitz_edit(file, snippet, after|replace)` plus batch/rename/undo/read/doctor.
- Metrics JSON estimates payload savings vs full-symbol / realistic-anchor / minimal-anchor baselines, mostly byte-based.
- Local microbench is correctness-gated (`bench/run.ts`) but synthetic.
- Authentic Pi bench exists (`bench/llm-pi.ts`) and extracts provider usage + tool-call args. Provided context: small case shows wins; medium/huge cases are unreliable.

### Main v0.2 problem

Current LLM-facing API is still too free-form:

```ts
pi_blitz_edit({ file, replace: "mediumCompute", snippet: "..." })
```

Model must infer whether snippet means:

- whole declaration,
- body only,
- marker splice,
- tail replacement,
- wrap body,
- insertion around preserved body.

For large symbols this invites bad calls: repeat too much unchanged code, use invalid marker shape, mix signature/body modes, or fail golden output. Marker syntax saves tokens only when model chooses exactly right shape.

v0.2 should move from **text marker ergonomics** to **structured body edit IR**.

## Non-goals

- No public “40–50% savings” or “huge files reliable” claim from bytes/4 estimates.
- No full-file rewrite lane; use Pi core `edit`/`write` for full-file changes.
- No unbounded fuzzy repair that can silently edit wrong spans.
- No default multi-file writes before single-file structured ops pass gates.
- No silent migration away from existing v0.1 CLI/Pi tools; keep them backward-compatible but de-emphasized.
- No new runtime dependency, Python, local model, or hosted apply model.

## Plan

### Phase 0 — spec reset before code

Update canonical spec first, then mirror into blitz.

Files:

- `pi-rig/docs/architecture/blitz.md`
- `blitz/docs/blitz.md`
- Optional active plan/spec split if desired:
  - `blitz/docs/specs/SPEC-v02-structured-edit.md`
  - `blitz/docs/plans/PLAN-v02-structured-edit.md`

Spec changes:

1. Reframe v0.2 as **structured edit ergonomics + authentic benchmark gates**.
2. Move Layer B fuzzy and Layer C query rewrites behind structured op reliability.
3. Define stable JSON edit IR and result schema.
4. Define benchmark claim policy.
5. Add deprecation/compat note: v0.1 `edit` stays; v0.2 agents should prefer `apply`/structured ops.

Acceptance:

- Spec states exact operation names, required/optional fields, ambiguity rules, and failure behavior.
- Spec links `d1o-gso9`, `d1o-1ep6`, `d1o-ptf1`, `d1o-5hm9` to specific sections.
- README/skill copy labels current savings as local evidence only.

### Phase 1 — new structured edit IR

Add a CLI JSON entrypoint, proposed:

```bash
blitz apply --edit - [--dry-run] [--json] [--diff-context N]
```

Core IR shape:

```ts
type BlitzApplyRequest = {
  version: 1;
  file: string;
  operation:
    | "set_body"
    | "replace_body_span"
    | "insert_body_span"
    | "wrap_body"
    | "compose_body"
    | "insert_after_symbol";
  target: {
    symbol: string;
    kind?: "function" | "method" | "class" | "variable" | "type";
    range?: "body" | "node";
  };
  edit: OperationPayload;
  options?: {
    dryRun?: boolean;
    requireParseClean?: boolean;
    requireSingleMatch?: boolean;
    diffContext?: number;
  };
};
```

Exact operation payloads:

```ts
type SetBody = {
  body: string;               // body only; no signature
  indentation?: "preserve" | "normalize";
};

type ReplaceBodySpan = {
  find: string;               // exact text inside target body
  replace: string;
  occurrence: "only" | "first" | "last" | number;
};

type InsertBodySpan = {
  anchor: string;             // exact text inside target body
  position: "before" | "after";
  text: string;
  occurrence: "only" | "first" | "last" | number;
};

type WrapBody = {
  before: string;             // e.g. "try {\n"
  after: string;              // e.g. "\n} catch ..."
  keep: "body";
  indentKeptBodyBy?: number;  // language-aware spaces/tabs
};

type ComposeBody = {
  segments: Array<
    | { text: string }
    | { keep: KeepRange }
  >;
};

type KeepRange =
  | { range: "body" }
  | { beforeKeep?: string; afterKeep?: string; includeBefore?: boolean; includeAfter?: boolean; occurrence?: "only" | "first" | "last" | number }
  | { startLine?: number; endLine?: number }; // line range relative to body, dry-run friendly, not first choice

type InsertAfterSymbol = {
  code: string;
};
```

Why this shape:

- Tail change in 100k function becomes tiny and exact:

```json
{
  "version": 1,
  "file": "huge.ts",
  "operation": "replace_body_span",
  "target": { "symbol": "hugeCompute", "range": "body" },
  "edit": { "find": "return total;", "replace": "return total + 1;", "occurrence": "last" }
}
```

- Wrap body becomes tiny and avoids repeating unchanged code:

```json
{
  "version": 1,
  "file": "medium.ts",
  "operation": "wrap_body",
  "target": { "symbol": "mediumCompute", "range": "body" },
  "edit": {
    "before": "try {\n",
    "keep": "body",
    "after": "\n} catch (error) {\n  console.error(error);\n  throw error;\n}",
    "indentKeptBodyBy": 2
  }
}
```

- Marker-like preserve with explicit before/after keep:

```json
{
  "operation": "compose_body",
  "target": { "symbol": "handleRequest", "range": "body" },
  "edit": {
    "segments": [
      { "keep": { "beforeKeep": "const method = req.method.toUpperCase();", "includeBefore": true, "afterKeep": "const method = req.method.toUpperCase();", "includeAfter": true, "occurrence": "only" } },
      { "text": "\nif (method === \"OPTIONS\") {\n  return new Response(null, { status: 204 });\n}\n" },
      { "keep": { "beforeKeep": "if (method !== \"GET\" && method !== \"POST\")", "includeBefore": true, "afterKeep": "return new Response(\"not found\", { status: 404 });", "includeAfter": true, "occurrence": "only" } }
    ]
  }
}
```

Design rule: model sends changed text and explicit anchors; blitz owns range extraction, composition, indentation, parse validation, write.

Acceptance:

- All operations are exact enums; invalid enum exits non-zero / Pi hard schema error.
- `requireSingleMatch` default true for `find`/anchors unless occurrence specified.
- Ambiguous anchors fail closed without mutating disk.
- `target.range: "body"` remains default for `set_body`, `replace_body_span`, `insert_body_span`, `wrap_body`, `compose_body`.
- `target.range: "node"` exists only for rare declaration-level transforms.

### Phase 2 — structured body ops before fuzzy

Implementation order should favor deterministic structured ops over fuzzy recovery:

1. `replace_body_span`
   - bounded inside resolved symbol body;
   - exact byte match;
   - occurrence semantics;
   - parse validate after edit.
2. `insert_body_span`
   - exact anchor;
   - position before/after;
   - newline/indent preservation.
3. `wrap_body`
   - preserve complete body;
   - indent kept body by fixed amount;
   - language-specific brace/Python behavior.
4. `compose_body`
   - segment engine: concatenate text + extracted keep ranges;
   - support `keep: { range: "body" }` first;
   - add `beforeKeep/afterKeep` once simple path passes.
5. Keep current marker splice as compatibility layer, not primary v0.2 prompt path.

Only after these pass should `d1o-1ep6` fuzzy ladder start. Fuzzy matching must be opt-in per operation:

```json
"options": { "matchMode": "exact" }
```

Future:

```json
"options": { "matchMode": "normalized_whitespace" | "relative_indent" }
```

Acceptance:

- No fuzzy match is used by default.
- No operation edits outside target symbol body unless operation is `insert_after_symbol` or target range explicitly `node`.
- Existing v0.1 tests stay green.

### Phase 3 — preview/diff validation and structural result schema

`blitz apply --json` should return stable JSON for both preview and apply:

```ts
type BlitzApplyResult = {
  status: "preview" | "applied" | "no_changes" | "rejected" | "needs_host_merge";
  command: "apply";
  operation: BlitzApplyRequest["operation"];
  file: string;
  symbol: string;
  language: string;
  dryRun: boolean;
  changed: boolean;
  validation: {
    parseBeforeClean: boolean;
    parseAfterClean: boolean;
    goldenExpected?: boolean;
    singleMatch?: boolean;
    rejectedReason?: string;
  };
  ranges: {
    targetStart: number;
    targetEnd: number;
    bodyStart?: number;
    bodyEnd?: number;
    editStart: number;
    editEnd: number;
  };
  metrics: {
    fileBytesBefore: number;
    fileBytesAfter: number;
    requestBytes: number;
    changedBytesBefore: number;
    changedBytesAfter: number;
    wallMs: number;
  };
  diff?: string;              // omitted by default for token savings; include with --diff
  diffSummary?: string;       // always compact
};
```

Validation rules:

- Parse current file first.
- Apply in memory.
- Parse candidate file.
- If current parsed clean and candidate has new parse errors: reject, no write.
- If `dryRun`: no backup/write; return preview result + compact diff summary.
- If `apply`: backup + atomic write only after validation.
- Diff default: compact summary only (`+N/-M`, touched line range, operation). Full unified diff only when `--diff` or Pi tool `includeDiff: true`.

Acceptance:

- Preview and apply use same engine.
- Result JSON can be parsed by Pi extension with no regex fallback.
- CLI text output can remain for old commands, but new `apply --json` is canonical.

### Phase 4 — Pi extension tool redesign

Prefer a new tool over overloading `pi_blitz_edit`:

```ts
pi_blitz_apply({ file, operation, target, edit, dryRun?, includeDiff? })
```

Keep old tool:

- `pi_blitz_edit` remains for compatibility.
- Skill should recommend `pi_blitz_apply` for medium/huge and marker-like edits.
- Tool description should include concrete one-line examples for each operation.

Model-reliability schema rules:

- `operation` enum required.
- `target.symbol` required and described as symbol name only.
- `edit` object shape should be discriminated if Pi schema support allows; otherwise split into multiple narrower tools:
  - `pi_blitz_replace_body_span`
  - `pi_blitz_insert_body_span`
  - `pi_blitz_wrap_body`
  - `pi_blitz_compose_body`
- If TypeBox/Pi cannot enforce discriminated unions cleanly, choose **multiple narrow tools**. Reliability > API elegance.

Recommended v0.2 Pi surface:

1. `pi_blitz_apply` for advanced/explicit operation enum.
2. Optional narrow aliases if model confusion persists in authentic bench:
   - `pi_blitz_body_replace`
   - `pi_blitz_body_patch`
   - `pi_blitz_body_wrap`
3. `pi_blitz_preview` is not separate; use `dryRun: true`.

Skill prompt update:

- For one-line change inside big symbol: use `replace_body_span`.
- For wrap body: use `wrap_body`, never repeat body.
- For adding code near exact line: use `insert_body_span`.
- For complex preserved islands: use `compose_body` with `keep` ranges.
- If no exact anchor known: call `pi_blitz_read` first or use core edit; do not guess.

Acceptance:

- Authentic bench shows model picks correct operation for small, medium, huge cases.
- Tool errors explain the correct operation shape in one concise sentence.
- No result text claims savings unless result correctness is known.

### Phase 5 — benchmark methodology

#### Benchmark lanes

Use three separate benches; never mix their claims.

1. **Deterministic CLI correctness/latency**
   - No LLM.
   - Applies fixed JSON requests to fixtures.
   - Golden exact output compare.
   - Parse clean compare.
   - Wall time median of 5+ reps.

2. **Tokenizer payload bench**
   - No LLM.
   - Tokenize exact JSON tool-call arguments using `cl100k_base` and, where possible, provider tokenizer.
   - Compare against core edit payload variants:
     - full-symbol old/new;
     - realistic anchor old/new (3-line context);
     - minimal diff window.
   - Claim only “tool-call argument tokens,” not model output tokens.

3. **Authentic Pi-driven model bench**
   - Uses `pi -p` with isolated tool sets.
   - Core lane: only core `edit`.
   - Blitz lane: only `pi_blitz_apply` (+ maybe `pi_blitz_read` for discovery-specific cases, tracked separately).
   - Same provider, model, thinking setting, prompt template, session-dir capture.
   - Extract:
     - provider `usage.input`, `usage.output`, cache read/write, cost;
     - tool-call args JSON;
     - tool-call args tokens via tokenizer;
     - correctness vs golden;
     - wall time;
     - number of tool calls;
     - fallback/no-op/rejected states.

#### Required v0.2 cases

Minimum before public claims:

1. small one-line body change (`set_body` or `replace_body_span`)
2. medium 10k tail change (`replace_body_span`, `occurrence: "last"`)
3. huge 100k tail change (`replace_body_span`, `occurrence: "last"`)
4. medium wrap body (`wrap_body`, `keep: "body"`)
5. medium insert after exact body anchor (`insert_body_span`)
6. medium preserve islands (`compose_body` with beforeKeep/afterKeep)
7. multi-hunk same symbol (`compose_body` multiple text/keep segments)
8. insert after symbol (`insert_after_symbol`)
9. unsupported/ambiguous anchor fail-closed case
10. legacy marker splice regression case

Cross-file import/rename from old 10-case matrix should stay tracked but not gate the structured single-file ergonomics redesign until Phase 4 passes.

#### Gate policy

Correctness gates:

- CLI deterministic bench: 100% golden for all supported structured ops.
- Apply/preview parity: preview diff applied manually equals apply output.
- Parse: no new parse errors when original parse clean.
- Fail-closed: ambiguous/missing anchors produce no file mutation.

Authentic Pi gates:

- Small/medium/huge tail cases: ≥90% correct over at least 5 runs per lane/model before any reliability claim.
- Wrap/compose cases: ≥80% correct for alpha, ≥90% for public claim.
- Failed or incorrect blitz runs count as **0 savings** in aggregate and are reported in table.
- No aggregate token-savings headline unless every included row reaches minimum correctness threshold.

Token gates:

- `replace_body_span` on huge tail: tool-call args ≤10% of core full-symbol payload and ≤50% of realistic anchor payload.
- `wrap_body`: tool-call args ≤20% of core full-symbol payload.
- No v0.2 op should be worse than core realistic anchor by >10% unless reported as regression.

Latency gates:

- Keep existing small-file target: <20–25ms median for <5KB deterministic CLI path.
- For 100k fixtures, report measured wall time; do not claim sub-20ms.

Claim language:

- Use “observed in local Pi-driven bench on <date/model/iters>”.
- Avoid “drastic” in public docs until gates pass; use exact percentages per case.
- Label tokenizer payload estimates separately from provider `usage.output`.

### Phase 6 — batch/multi after single-op reliability

Only after `pi_blitz_apply` is reliable:

- Add `blitz apply --edits -` for multiple structured edits in one file.
- Add `blitz multi-edit --file-edits -` using same IR objects.
- Sort canonical paths for locks.
- Dry-run/preview default for cross-file.
- Atomicity: backup all files before write; on failure, restore all touched files.

This should re-scope `d1o-5hm9`: multi-edit should use structured IR, not legacy snippets.

Acceptance:

- 10-file dry-run outputs compact per-file summaries.
- Real write requires explicit `apply: true` / `--apply`.
- Failure in any file leaves all files unchanged.

## Files/Areas

### blitz repo

- `docs/blitz.md` — mirror after canonical spec update.
- `src/cli.zig` — parse `apply` command and JSON stdin.
- `src/cmd_apply.zig` (new) — command runner.
- `src/edit_ir.zig` (new) — request/result structs, enum parser, validation.
- `src/body_ops.zig` (new) — deterministic body range operations.
- `src/edit_support.zig` — share body range + parse validation helpers.
- `src/symbols.zig` — ensure kind hints and duplicate behavior are explicit.
- `src/metrics.zig` — add request/tool-call byte/token fields; stop framing bytes/4 as real output tokens.
- `src/splice.zig` — keep as legacy marker compatibility.
- `bench/structured-run.ts` (new) — deterministic structured ops bench.
- `bench/llm-tokens.ts` — add structured apply payload cases.
- `bench/llm-pi.ts` — replace blitz lane from `pi_blitz_edit` to `pi_blitz_apply`; count incorrect as 0 savings.
- `bench/regression-thresholds.json` — split deterministic vs authentic thresholds.

### pi-rig / pi-blitz

- `docs/architecture/blitz.md` — canonical spec.
- `extensions/pi-blitz/src/tools.ts` — add `pi_blitz_apply`, schemas, result parser.
- `extensions/pi-blitz/index.ts` — register new tool.
- `extensions/pi-blitz/skills/pi-blitz/SKILL.md` — new operation-selection rules.
- `extensions/pi-blitz/README.md` — no public claims until gates pass.
- `extensions/pi-blitz/test/*` — stub binary tests for new command args and error paths.

## Skills/Agents

Recommended agents/owners:

1. **Spec owner / architect** — skills: `kenzo-execution-preferences`, `kenzo-tk-cli`, `kenzo-blueprint-architect`
   - Update canonical spec + mirror.
   - Link tk tickets.
   - Freeze IR v1 before implementation.
2. **Zig implementation agent** — skills: `kenzo-zig`, `kenzo-zig-build`
   - Implement `apply`, JSON IR, body ops, validation, result schema.
3. **Pi extension agent** — skills: `kenzo-pi-flow-stack`, `kenzo-bun`, `kenzo-tk-cli`
   - Add `pi_blitz_apply` schema/runtime and skill guidance.
4. **Benchmark agent** — skills: `kenzo-bun`, `kenzo-testing-stack`, `kenzo-execution-preferences`
   - Build deterministic/tokenizer/authentic bench lanes and reports.
5. **Review agent** — skills: `kenzo-codex-review` or Marko-style read-only review
   - Check spec compliance first, then code quality, then benchmark honesty.

Preflight/worktree isolation:

- Required if implementation starts while pi-rig and blitz branches differ.
- Use separate worktrees/branches for `blitz` CLI and `pi-blitz` extension changes.
- Keep canonical spec change in companion repo synchronized with blitz mirror in same final PR/sprint boundary.

## Risks

| Risk | Impact | Mitigation |
|---|---:|---|
| Complex `pi_blitz_apply` schema still confuses model | high | Split into narrower tools if authentic bench shows wrong op selection. |
| `compose_body` becomes mini-language too broad | high | Ship only `keep: body` + exact `find` ops first; add beforeKeep/afterKeep after tests. |
| Anchor text appears multiple times | high | Default `requireSingleMatch`; require explicit occurrence for duplicates; fail closed. |
| Wrap indentation differs by language | medium | Start with TS/JS/Go/Rust brace bodies; Python wrap requires separate acceptance. |
| Preview/apply result too verbose harms savings | medium | Diff omitted by default; compact summary always; full diff opt-in. |
| Bench prompt overfits examples | medium | Include withheld fixtures; vary symbol names; report prompt text with results. |
| Bytes/4 estimates mistaken for model tokens | high | Separate deterministic bytes, tokenizer args tokens, provider usage output in all tables. |
| v0.2 scope balloons into query/fuzzy/multi-file | high | Gate phases: structured ops first, fuzzy/query/multi after reliability. |

## Verification

Plan/report verification completed:

- Read requested skills: `kenzo-execution-preferences`, `kenzo-tk-cli`.
- Read repo context: `AGENTS.md`, `README.md`, `docs/blitz.md`, canonical `pi-rig/docs/architecture/blitz.md`.
- Inspected tk context: `d1o-dnod`, `d1o-gso9`, `d1o-1ep6`, `d1o-ptf1`, `d1o-5hm9`, plus completed v0.1 tasks.
- Inspected current implementation surfaces and benches.
- No implementation files edited.

Future implementation verification:

```bash
# blitz repo
zig build
zig build test
bun bench/structured-run.ts
bun bench/llm-tokens.ts
bun bench/llm-pi.ts --model claude-haiku-4-5 --iters 5

# pi-blitz extension
cd /home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz
bun run typecheck
bun test
bun run build
```

For JS/TS quality gates in pi-blitz, use repo-owned scripts now (`bun run typecheck`, `bun test`, `bun run build`). Do not introduce oxlint/oxfmt/tsz migration silently.

## Open questions

1. Should v0.2 expose one `pi_blitz_apply` with operation enum, or multiple narrow tools for reliability? Recommendation: start one tool, split if authentic bench shows model confusion.
2. Should `replace_body_span.find` support regex? Recommendation: no for v0.2; exact text only.
3. Should line ranges relative to body be allowed? Recommendation: only for dry-run/debug initially; prefer exact anchors.
4. Should `wrap_body` support Python in first cut? Recommendation: only if dedicated fixtures pass; brace languages first.
5. Should apply default to dry-run in Pi? Recommendation: no for small deterministic ops; yes/confirm for multi-file/cross-file later.
6. Should `needs_host_merge` remain exit 0 for `apply`? Recommendation: yes, but only after returning compact scope payload and no mutation.

## Anything Missed / Review Next

- Run or review latest authentic Pi bench output if available; current report relies on provided context that small wins but medium/huge unreliable.
- Decide `pi_blitz_apply` vs narrow tools before implementation.
- Update canonical spec before writing code.
- Link tk tickets to accepted spec/report anchors.
- Add benchmark result report template so future numbers cannot be cherry-picked or mislabeled.
