# `blitzd` warm-worker protocol (Lane E design)

Status: protocol definition plus bounded MCP-host warm cache. No Zig daemon implementation exists yet. Current MCP server defaults to stateless `blitz --workspace-root <root> ...` via `spawnSync` for each tool call. When `BLITZ_MCP_WARM=1`, the MCP host caches safe `doctor` output and `read` results keyed by canonical file path plus SHA-256 file bytes. Mutations still use stateless CLI fallback and mutation results are never cached.

## Goals

- Remove cold CLI startup and repeated parser/grammar load cost for repeated agent calls.
- Preserve CLI as safe stateless fallback for crash, timeout, version mismatch, or security rejection.
- Keep mutation semantics at least as strict as current `read`, `apply`, `doctor`, and route-explain CLI commands.

## Transport

Full `blitzd` v1 would use stdio JSONL:

- one UTF-8 JSON object per line;
- max frame size: 1 MiB default, configurable downward by host;
- no partial/multi-line JSON messages;
- stdout reserved for protocol responses/events;
- stderr reserved for diagnostics only, never parsed as protocol data.

JSONL is chosen over custom binary framing because Blitz requests are small, human-debuggable, and easy for MCP/Pi hosts to proxy. If future large diffs exceed frame limits, add explicit file-backed artifacts rather than increasing default frame size.

## Message shape

Every request:

```json
{
  "id": "req-1",
  "method": "read",
  "workspaceRoot": "/abs/workspace",
  "timeoutMs": 30000,
  "params": {}
}
```

Every response:

```json
{
  "id": "req-1",
  "ok": true,
  "result": {},
  "elapsedMs": 4,
  "worker": { "pid": 12345, "version": "0.1.0-alpha.10", "cacheEpoch": 7 }
}
```

Every error:

```json
{
  "id": "req-1",
  "ok": false,
  "error": {
    "code": "PathEscapesWorkspace",
    "message": "path escapes workspace",
    "retryable": false,
    "fallbackAllowed": false
  },
  "elapsedMs": 1
}
```

Error codes must be stable strings. Hosts may show `message`, but routing/retry logic must use `code`, `retryable`, and `fallbackAllowed`.

## Methods

### `doctor`

Request params:

```json
{
  "includeCache": true
}
```

Response result:

```json
{
  "version": "0.1.0-alpha.10",
  "treeSitter": { "runtime": "0.26.9", "abi": 15, "minCompatibleAbi": 13 },
  "commands": ["read", "apply", "doctor"],
  "workspaceRoot": "/abs/workspace",
  "cache": {
    "parserCount": 3,
    "queryCount": 8,
    "openTreeCount": 4,
    "epoch": 7
  }
}
```

### `read`

Request params:

```json
{
  "file": "src/main.zig",
  "fileHash": "sha256:optional-known-current-hash",
  "maxBytes": 1048576
}
```

Response result mirrors current CLI `blitz read` JSON/source summary when JSON mode exists; until then, result may contain current text summary:

```json
{
  "file": "src/main.zig",
  "fileHash": "sha256:actual-hash",
  "language": "zig",
  "summary": "..."
}
```

### `apply`

Request params:

```json
{
  "request": {
    "version": 1,
    "file": "src/main.zig",
    "operation": "patch",
    "edit": { "ops": [["replace_return", "main", "0"]] },
    "options": { "route": "auto" }
  },
  "precondition": {
    "fileHash": "sha256:required-current-hash",
    "mtimeNs": 1710000000000000000
  },
  "dryRun": false,
  "includeDiff": false
}
```

Response result:

```json
{
  "changed": true,
  "file": "src/main.zig",
  "oldHash": "sha256:before",
  "newHash": "sha256:after",
  "routeDecision": { "route": "blitz", "reasonCode": "structural_high_confidence" },
  "diff": null
}
```

`apply` must reject mutation if current hash differs from `precondition.fileHash`. `mtimeNs` is advisory only because timestamp precision varies; hash is authoritative.

### `explain`

Request params:

```json
{
  "request": { "version": 1, "file": "README.md", "operation": "replace_unique", "edit": {} }
}
```

Response result:

```json
{
  "routeDecision": {
    "route": "core_edit",
    "reasonCode": "unsupported_or_core_favored",
    "confidence": "high"
  },
  "wouldMutate": false
}
```

`explain` must never mutate and is equivalent to current `apply --route explain --dry-run` behavior.

## Workspace root and path policy

- Host supplies one absolute `workspaceRoot` at worker start and repeats it per request.
- Worker resolves root through realpath at startup.
- All file params may be relative to root or absolute paths within root.
- Worker resolves existing ancestor realpath, then appends missing suffix, matching current MCP `bindPath` behavior.
- Reject paths whose normalized realpath-relative form is empty only when operation requires a file, starts with `..`, or is absolute after `relative(root, path)`.
- Reject symlink escapes, UNC/device paths, NUL bytes, and paths exceeding platform limits.
- Do not follow final symlink for mutation unless final resolved target remains under root.
- Error `PathEscapesWorkspace` must set `fallbackAllowed: false`; fallback CLI must not be attempted for security rejections.

## File hash and precondition policy

- Use SHA-256 over exact file bytes as canonical `fileHash` string: `sha256:<lowerhex>`.
- Mutating methods require `precondition.fileHash` unless host explicitly sets `allowUnconditional: true`; default host policy should never set it for agent edits.
- If hash mismatch, return `PreconditionFailed` with actual hash and `fallbackAllowed: false`.
- Dry-run requests should include hash when caller has it, but may run without hash.
- Response from `read`, `apply`, and failed hash checks should include actual current hash when safe.

## Lock and mutation policy

- Single worker may process reads concurrently only after implementation proves parser/cache thread safety; v1 should process requests serially.
- Mutations acquire per-canonical-file exclusive lock.
- Lock spans: re-stat/read, hash precondition check, parse/plan, write temp file, fsync if supported, atomic rename/write, post-parse validation, response.
- No two mutations to same file may overlap.
- Cross-file ops are out of scope for v1. If added later, lock files in lexical canonical path order to avoid deadlocks.
- On crash mid-mutation, worker must leave either original file or complete new file; no partial writes.

## Parser/query cache lifecycle

- Cache key: language id, grammar ABI/version, file canonical path, file hash, parse options.
- Parser instances and compiled queries may be retained per language.
- Parsed trees may be retained per file hash; any hash change invalidates tree.
- Any mutation success increments `cacheEpoch` and invalidates stale tree entries for that file.
- External file changes are detected by hash/mtime check before cached tree reuse.
- Memory limits: host sets max cached bytes/trees; worker evicts least-recently-used entries.
- Idle timeout drops trees first, then queries/parsers, then exits if no requests arrive.

## Timeout, crash, and fallback

Host owns worker lifecycle. Current `BLITZ_MCP_WARM=1` cache path has no worker process; cache fallback is internal: cache miss, oversized hash input (`BLITZ_MCP_WARM_MAX_HASH_BYTES`, default 1 MiB), or process restart falls back to current stateless CLI for safe `doctor`/`read`. Path escape errors are raised before fallback. Mutation tools (`blitz_patch`, `blitz_try_catch`, `blitz_replace_return`, `blitz_undo`) always call stateless CLI and clear any cached read for that canonical file.

Future daemon lifecycle:

- per-request timeout defaults to current MCP timeout (`BLITZ_MCP_TIMEOUT_MS`, 30s);
- if worker does not answer before timeout, host kills worker process and may call stateless CLI for non-mutating requests or safe dry-runs;
- for mutation timeout, fallback allowed only if no mutation lock was acquired or worker confirms no write started;
- after crash/timeout during mutation, host must re-read file hash before any retry;
- protocol/security errors set `fallbackAllowed: false`;
- unsupported method/version mismatch may set `fallbackAllowed: true`.

Fallback command shape remains current stateless CLI:

```sh
blitz --workspace-root "$WORKSPACE" read "$FILE"
blitz --workspace-root "$WORKSPACE" apply --edit - --json
blitz --workspace-root "$WORKSPACE" doctor
```

## Security review checklist

Before enabling `blitzd` by default:

- [ ] Path traversal tests cover `..`, symlink escape, broken symlink ancestor, absolute path outside root, NUL byte, and root-as-file.
- [ ] Mutating requests require file hash preconditions by default.
- [ ] Hash mismatch never falls back to stateless CLI mutation.
- [ ] JSON frame max size and nesting/depth limits reject resource-exhaustion payloads.
- [ ] Unknown methods/fields fail closed or are ignored only by documented compatibility rules.
- [ ] Worker env is minimal: no network credentials required, update checks disabled, root fixed.
- [ ] Stderr diagnostics redact workspace/home paths when surfaced through MCP.
- [ ] Mutation lock tests prove no overlapping writes to same file.
- [ ] Crash/timeout tests prove no partial writes and require hash refresh before retry.
- [ ] Cache invalidation tests cover external file edits, successful worker edits, failed edits, and grammar/version changes.
- [ ] Benchmarks report cold CLI vs warm worker p50/p95 and include security rejection cases.
