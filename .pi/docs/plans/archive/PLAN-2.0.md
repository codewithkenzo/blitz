# Blitz 2.0 Plan — complementary future/check plan

Date: 2026-05-22  
Status: restored complementary draft; **not active v0.2 execution plan**  
Active v0.2 spec: `.pi/docs/plans/archive/blitz-v0.2-hardening-and-parity.md`  
Companion check spec: `.pi/docs/plans/archive/SPEC-2.0.md`


## 2026-05-22 future/check usage rules

Latest research: `.pi/research/archive/blitz-v0.2-and-2.0-implementation-research-20260522.md`. Treat this plan as a post-v0.2 audit lane only. Do not dispatch active builders from this file unless the user explicitly scopes future/2.0 work.

For current v0.2 implementation, use this file only to check that:

1. schema/versioning choices will not block future `blitz schema --json` or `blitz --version --json`;
2. stable result/error fields can later add hashes without breaking wrappers;
3. cross-file operations remain preview/gated until LSP-style ordering, hash preconditions, all-range validation, and failure handling exist;
4. benchmark artifacts include raw JSON plus markdown summaries with N/model/date/commit/task class;
5. operation names stay coherent across CLI, Pi, MCP, docs, and skill prompts.

Active builder tickets should still be derived from `.pi/docs/plans/archive/blitz-v0.2-hardening-and-parity.md`, not this plan.

## Purpose

Keep a future-facing checklist so v0.2 hardening does not paint Blitz into a corner. This is not a release plan for current work. Current implementation should still follow v0.2 phases.

## Current baseline notes

- CLI entry: `src/main.zig`.
- Structured apply engine: `src/cmd_apply.zig`.
- Existing ops include: `replace_body_span`, `insert_body_span`, `wrap_body`, `compose_body`, `insert_after_symbol`, `set_body`, `multi_body`, `patch`.
- Existing safety includes: parse-before/after, backup, per-file lock, atomic write, workspace guard.
- Active docs: `.pi/docs/plans/archive/blitz-v0.2-hardening-and-parity.md`, `.pi/reports/archive/history/blitz-v02-ergonomics-plan.md`.

## Use as v0.2 audit checklist

### 1. Schema/versioning readiness

Ask during v0.2 Phase 1:

- Does CLI expose enough schema metadata for Pi/MCP wrappers?
- Are operation names stable and documented?
- Are errors machine-readable with stable codes?
- Are default responses compact and diff opt-in?

Possible future tasks:

- `blitz schema --json`
- `blitz --version --json`
- JSON Schema docs for Pi/MCP wrappers

### 2. Preconditions and validation readiness

Ask during v0.2 robustness work:

- Can callers pass file/target hash preconditions?
- Does dry-run use same engine as apply?
- Do failures happen before lock/backup/write?
- Does multi-edit resolve all ranges before mutation?

Possible future tasks:

- full-file SHA-256 precondition;
- target-span SHA-256 precondition;
- old/new hash fields in result;
- dry-run/apply parity tests.

### 3. Operation coherence

Audit every supported op for:

- exact payload schema;
- target/body/node ownership;
- match defaults (`only` unless occurrence supplied);
- idempotence/no-op behavior;
- parse-after policy;
- ambiguity/no-match behavior;
- fixture coverage.

High-value future-first ops:

- `wrap_body`
- `replace_return`
- `try_catch`
- `multi_body`
- `ensure_import`
- `rename_identifier`

### 4. Language support maturity

Before broader release claims:

- document per-language declaration kinds;
- document body extraction rules;
- test strings/comments exclusion;
- test duplicate/nested symbols;
- test parse-error baseline;
- mark unsupported constructs clearly.

This maps to v0.2 grammar config work.

### 5. Pi/MCP wrapper maturity

Agent-facing rule:

- narrow tools for high-ROI ops;
- generic `apply` escape hatch;
- schema mirrors CLI;
- compact output by default;
- no regex-based success/error classification when JSON `code` exists.

### 6. Benchmark and claim maturity

Before any public broad claim:

- deterministic CLI golden tests pass;
- live Pi/model tests have N, model, date, commit;
- failed/malformed calls included in correctness rate;
- provider output tokens separate from tool-call arg tokens;
- simple core-favored cases reported honestly.

## Future implementation lanes after v0.2

### Lane A — schema/error/result hardening

Owner: `d5`

Deliverables:

- stable JSON error codes;
- schema export command;
- compact structured result v2;
- no regex classification in wrappers.

Gate:

```bash
zig build test
```

### Lane B — hash preconditions and idempotence

Owner: `d5`

Deliverables:

- `fileHash` and target hash checks;
- idempotence fields for wrapper/import ops;
- dry-run/apply parity tests.

Gate:

```bash
zig build test
```

### Lane C — operation expansion

Owner: `d5`

Candidates:

- first-class `replace_return`;
- first-class `try_catch`;
- `insert_before_symbol`;
- import ensure/remove;
- stronger multi-body conflict diagnostics.

Gate:

```bash
zig build test
```

### Lane D — workspace/multi-file preview

Owner: `d5`, review required

Deliverables:

- LSP-inspired ordered file edit schema;
- dry-run-only preview initially;
- file hash preconditions required;
- all-or-nothing write only after dedicated gates.

Gate:

- dry-run works across files;
- no write path until reviewer approval.

### Lane E — benchmark harness maturity

Owner: `d5` + `researcher`

Deliverables:

- raw JSON bench output;
- env metadata;
- live Pi matrix reports;
- regression thresholds.

Gate:

- markdown report generated from raw JSON;
- claims cite N/model/date/commit.

## Deferred unless user explicitly scopes it

- Renaming current v0.2 to 2.0.
- Writable multi-file workspace edits.
- Raw tree-sitter query rewrite exposed to agents.
- Formatter/linter integrations requiring external toolchains.
- Hosted model fallback.

## Reminder

Current implementation source of truth remains:

- `.pi/docs/plans/archive/blitz-v0.2-hardening-and-parity.md`
- `.pi/reports/archive/history/blitz-v02-ergonomics-plan.md`

This file is a complementary check, not current sprint authority.
