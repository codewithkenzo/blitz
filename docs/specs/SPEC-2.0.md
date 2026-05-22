# Blitz 2.0 Spec — complementary future/check document

Date: 2026-05-22  
Status: restored complementary draft; **not active v0.2 scope**  
Active v0.2 spec: `specs/blitz-v0.2-hardening-and-parity.md`  
Purpose: future-facing checklist and consistency check for v0.2 hardening decisions.


## Non-authoritative guardrail update (2026-05-22)

Latest research: `research/blitz-v0.2-and-2.0-implementation-research-20260522.md`. This document is a consistency checklist only. It must not be used to rename, enlarge, or override the active v0.2 implementation scope.

Use it to ask future-facing questions while implementing v0.2:

- Are operation schemas versioned and discoverable without forcing a CLI major-version rename?
- Do result/error schemas expose stable `status`, `code`, ranges, validation, metrics, and optional hashes?
- Do multi-file ideas follow LSP-style ordered edits with preconditions and a defined failure policy?
- Are `fileHash` and `targetHash` preconditions designed before writable cross-file operations?
- Does every operation define payload fields, target range ownership, ambiguity behavior, idempotence/no-op behavior, parse policy, no-mutation failure behavior, and fixture coverage?
- Do benchmark reports remain correctness-first and label provider output tokens separately from tool-call argument tokens?

If this file conflicts with `specs/blitz-v0.2-hardening-and-parity.md`, the v0.2 spec wins for current implementation.

## Positioning

Blitz 2.0 should be treated as a long-range target, not current release scope. Current work remains v0.2: internal hardening, robustness, parity, structured edit reliability, MCP/tooling, grammar expansion, and benchmarks.

This document captures patterns that can guide v0.2 decisions without renaming or expanding v0.2 into 2.0.

## Thesis

Blitz should become a deterministic AST-scoped codemod engine for agents:

- standalone Zig 0.16 binary;
- vendored tree-sitter runtime + grammars;
- typed JSON edit operations;
- exact byte-range edits with AST target resolution;
- fail-closed validation;
- compact machine-readable results;
- measured token/time/correctness claims only.

## External pattern checks

| Pattern | Precedent | Check for Blitz |
|---|---|---|
| Typed transforms | OpenRewrite, jscodeshift | Prefer schema-backed ops over freeform snippets. |
| Do no harm | OpenRewrite | Ambiguity, stale hashes, parse failure => no mutation. |
| Versioned workspace edits | LSP `WorkspaceEdit` | Multi-file ops need file hashes/order/atomicity. |
| AST matching | tree-sitter, ast-grep, Semgrep | Resolve node/body range before text anchor matching. |
| Token-efficient edit formats | Aider | Agent payload should include changed text + anchors, not unchanged bodies. |
| Dry-run/autofix | Semgrep | Preview/apply must share engine. |
| Benchmark discipline | hyperfine, Go perf guidance | Correctness first; token claims only for correct outputs. |

## Future 2.0 contract ideas

### Versioning

- Keep CLI semver separate from edit IR schema if IR evolves faster.
- `blitz schema --json` should emit operation schema and examples.
- `blitz --version --json` should emit CLI version, schema version, git commit, Zig version, tree-sitter version, grammar versions.

### Preconditions

Future request shapes should support:

```ts
type BlitzPreconditions = {
  fileHash?: string;
  targetHash?: string;
  expectedSnippetHash?: string;
  allowDirty?: boolean;
};
```

Checks:

- `fileHash` mismatch rejects before parse/edit.
- `targetHash` mismatch rejects after target resolution, before mutation.
- Response includes old/new hashes when available.

### Result shape

Future result should remain compact and machine-readable:

```ts
type BlitzApplyResult = {
  status: "preview" | "applied" | "no_changes" | "rejected" | "needs_host_merge";
  command: string;
  operation: string;
  file: string;
  language: string;
  changed: boolean;
  code?: string;
  message?: string;
  validation: {
    parseBeforeClean: boolean;
    parseAfterClean: boolean;
    singleMatch?: boolean;
    hashMatched?: boolean;
    overlapFree?: boolean;
  };
  ranges: Array<{
    symbol?: string;
    nodeKind?: string;
    targetStart: number;
    targetEnd: number;
    editStart: number;
    editEnd: number;
  }>;
  metrics: {
    fileBytesBefore: number;
    fileBytesAfter: number;
    requestBytes: number;
    changedBytesBefore: number;
    changedBytesAfter: number;
    wallMs: number;
  };
  diffSummary: string;
  diff?: string;
};
```

### Stable error codes

Future-proof code set:

- `INVALID_JSON`
- `UNSUPPORTED_SCHEMA_VERSION`
- `UNSUPPORTED_OPERATION`
- `UNSUPPORTED_LANGUAGE`
- `FILE_NOT_FOUND`
- `OUTSIDE_WORKSPACE`
- `HASH_MISMATCH`
- `PARSE_ERROR_BEFORE`
- `PARSE_ERROR_AFTER`
- `SYMBOL_NOT_FOUND`
- `NO_MATCH`
- `AMBIGUOUS_MATCH`
- `OVERLAPPING_EDITS`
- `INVALID_IDENTIFIER`
- `INVALID_FIELD`
- `VALIDATION_FAILED`
- `IO_ERROR`

Agents should branch on `code`, not parse stderr.

## Operation set check

2.0 can validate whether v0.2 operation names remain coherent:

- `replace_body_span`
- `insert_body_span`
- `wrap_body`
- `compose_body`
- `set_body`
- `insert_after_symbol`
- `insert_before_symbol`
- `replace_return`
- `try_catch`
- `ensure_import`
- `remove_import`
- `rename_identifier`
- `multi_body`
- `patch` / compact tuple form
- `workspace_edit` (future multi-file lane)

For each operation, spec must define:

- exact payload fields;
- target range ownership;
- ambiguity behavior;
- idempotence behavior;
- parse policy;
- no-mutation failure behavior;
- tests/fixtures.

## Benchmark check

Never claim general savings from one handled case.

Required dimensions:

- correctness/golden pass;
- provider output tokens;
- tool-call arg tokens;
- total tokens/cost;
- wall time;
- model/provider/date;
- CLI commit/schema;
- retry/malformed rate;
- cold vs warm CLI timing where relevant.

Failed or malformed outputs count as failures, not savings wins.

## Relationship to v0.2

Use this doc to audit v0.2 choices:

- v0.2 Phase 1 maps to structure/schema/error-code foundations.
- v0.2 Phase 2 maps to robustness/fail-closed behavior.
- v0.2 Phase 3 maps to future multi-file/workspace-edit ideas.
- v0.2 benchmark gates should already follow 2.0 discipline.

Do **not** let this doc override `specs/blitz-v0.2-hardening-and-parity.md` for current implementation scope.
