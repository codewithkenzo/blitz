# D5 Blitz 0.4 Phase 5A report

Date: 2026-06-09
Status: implemented smallest deterministic chunk-local/body merge IR spike; no token-savings claim.

## Operation syntax

`merge_body_chunk` is an AST/body-scoped apply operation:

```json
{
  "version": 1,
  "file": "src/example.ts",
  "operation": "merge_body_chunk",
  "target": { "symbol": "mergeable" },
  "edit": {
    "snippet": "\n  const logged = true;\n  const base = value + 1;\n//...\n  return keep;\n"
  }
}
```

Rules:
- target must resolve to one editable symbol; operation edits only that symbol body.
- snippet must contain exactly one standalone keep marker line: `//...` or `#...`.
- Blitz picks last non-empty snippet line before marker and first non-empty snippet line after marker as literal anchors.
- Both anchors must occur exactly once in the resolved body.
- Output is `prefix + preserved old body span between anchors + suffix`.
- No fuzzy matching, no model fallback, no cross-file merge.

## Tests added

Focused Zig tests in `src/apply/mod.zig`:
- success: preserves deterministic old span between anchors and applies changed surrounding snippet text.
- duplicate/ambiguous anchor fail: rejects and leaves file unchanged.
- missing anchor fail: rejects and leaves file unchanged.
- malformed marker fail: rejects and leaves file unchanged.

`src/apply/patch.zig` rejects `merge_body_chunk` inside multi-body patch paths to keep scope single-symbol/body.

## Safety

Existing apply pipeline still provides:
- grammar/language lookup from file extension.
- parse-before safety for grammar-backed files.
- single target symbol resolution.
- parse-after validation before write.
- backup + atomic write on mutation.

## Verification

Passed:

```bash
zig build && zig build test
```

No `bench/` or TypeScript harness changes. `/home/kenzo/dev/pi-blitz` not touched.

## Limitations / ready for benchmarking?

Ready for Pi/Tokscale semantic smoke only as a deterministic spike, not as a general merge model.

Known limitations:
- Anchor selection is line-local around marker, not a full 35-60 line chunk extraction API.
- Changed lines nearest to marker cannot also be anchors; at least one unique unchanged line must remain immediately before and after marker.
- `#...` is accepted cheaply, but non-TS language behavior is not broadly benchmarked.
- No compact `pi-blitz` alias added in this slice; direct `pi_blitz_apply` / Blitz apply operation path should be used first.
- No token savings claim until real Pi/Tokscale rows exist.
