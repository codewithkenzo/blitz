# Structured multi-edit plan

Status: design-first, not implemented yet.

## Why this is high ROI

Single structured ops already win when core edit would repeat large unchanged code. Multi-edit should win harder when a task touches several symbols or several anchored spans: one compact semantic payload, one parse/validation/write, one undo snapshot.

## Proposed CLI API

Keep `blitz apply --edit - --json` as the stable entry. Add operation:

```json
{
  "operation": "multi_body",
  "file": "src/app.ts",
  "edits": [
    {
      "symbol": "loadUser",
      "op": "replace_body_span",
      "find": "return null;",
      "replace": "return user;",
      "occurrence": "last"
    },
    {
      "symbol": "saveUser",
      "op": "insert_body_span",
      "anchor": "await db.save(user);",
      "position": "after",
      "text": "\n  await audit(user.id);"
    },
    {
      "symbol": "handleRequest",
      "op": "wrap_body",
      "before": "\n  try {",
      "after": "  } catch (error) {\n    logger.error(error);\n    throw error;\n  }\n",
      "indentKeptBodyBy": 2
    }
  ]
}
```

## Proposed Pi narrow tool

`pi_blitz_multi_body({ file, edits, dry_run?, include_diff? })`

Edit item union should be compact and purpose-built:

- `{ symbol, op: "replace_body_span", find, replace, occurrence? }`
- `{ symbol, op: "insert_body_span", anchor, position, text, occurrence? }`
- `{ symbol, op: "wrap_body", before, after, indentKeptBodyBy? }`
- `{ symbol, op: "compose_body", segments }`

Do not expose generic `target`/`edit` nesting in Pi narrow tool.

## Semantics

- Same-file only for v0.1.
- Resolve every symbol and body range against original source before mutation.
- For each edit, produce concrete byte range + replacement bytes.
- Reject overlapping byte ranges.
- Sort ranges descending by start byte before applying.
- Validate final source once with tree-sitter full parse.
- Store one undo snapshot before write.
- Fail closed: no partial write if any op fails.

## Error cases

- unknown symbol → reject whole multi-edit
- ambiguous anchor → reject whole multi-edit
- anchor not found → reject whole multi-edit
- overlapping edits → reject whole multi-edit
- parse failure after composed source → reject whole multi-edit

## Bench cases before implementation

1. `multi/three-symbol-tail`
   - Three functions, one return replacement each.
   - Core likely emits 3 edit calls or one big old/new text payload.
   - Blitz emits one compact `pi_blitz_multi_body` call.

2. `multi/same-symbol-two-spans`
   - Insert after seed init and before return.
   - Compare against `compose_body` and core.

3. `multi/wrap-plus-insert`
   - Wrap one large function and insert audit call in another.

4. `multi/ambiguous-fail-closed`
   - One edit has duplicated anchor with `occurrence: "only"`.
   - Expected: no mutation, structured error.

## Success criteria

- Correctness: 100% for deterministic cases.
- One tool call in Blitz lane.
- No partial writes in negative cases.
- Token ROI beats current separate narrow calls on multi-symbol tasks.

## Claim discipline

Do not claim multi-edit savings until N≥5 Pi-through-LLM matrix confirms:

- provider output tokens
- tool arg tokens
- input/cache tokens
- wall time
- cost
- malformed/retry rate
- correctness
