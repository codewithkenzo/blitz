# Blitz provider tool-schema compatibility research — 2026-06-11

Status: main-agent salvage report after researcher failures/context overflow. Sources: live web search, local GPT-5.4-mini failure artifacts, pi-blitz schema dump.

## Why this matters

The first GPT-5.4-mini `blitz_edit` rows failed before any edit because OpenAI/Codex rejected the visible function schema:

```text
Invalid schema for function 'blitz_edit': ... is not of type 'object', 'boolean'
```

The rejected shape was a tuple-array schema where `items` was an array of positional schemas. Zai accepted it; OpenAI/Codex did not. This proves provider schema compatibility is part of the universal gate.

## Findings

### OpenAI / Codex

OpenAI tool/function parameters are JSON-Schema-like but not full JSON Schema. Examples and docs emphasize top-level `type: "object"`, `properties`, `required`, and commonly `additionalProperties:false`.

Important compatibility rules for Blitz:

- Avoid tuple schemas: `items: [{...}, {...}]` is rejected. Use homogeneous `items: { ... }`.
- Avoid `$defs`/`$ref` in visible tool schemas unless tested per provider.
- Do not rely on generation honoring all constraints like `pattern`, `maxLength`, `examples`, or complex unions. Keep runtime validation authoritative.
- Prefer a simple object schema with shallow properties over deeply nested unions/tuples.

Current OpenAI-compatible `blitz_edit` visible schema dump after pi-blitz fix:

```json
{
  "type": "object",
  "required": ["e"],
  "properties": {
    "f": { "minLength": 1, "maxLength": 4096, "type": "string" },
    "e": {
      "minItems": 1,
      "maxItems": 64,
      "type": "array",
      "items": {
        "minItems": 3,
        "maxItems": 5,
        "description": "OpenAI-compatible edit tuple...",
        "type": "array",
        "items": {
          "description": "Compact op tuple item.",
          "anyOf": [
            { "maxLength": 65536, "type": "string" },
            { "type": "number" },
            { "type": "boolean" }
          ]
        }
      }
    }
  }
}
```

This works on GPT-5.4-mini but is likely not minimal.

### Anthropic / Claude

Anthropic tool use supports JSON Schema-like `input_schema`, including arrays with an `items` schema. Public docs and SDK utilities emphasize `type`, `properties`, `required`, and `items`. Tuple-form positional arrays are not a safe assumption for a universal route; use homogeneous arrays or object lists.

Strict tool use requires valid schemas and may be less forgiving. Runtime validation should still be authoritative.

### Gemini / Google-style providers

Gemini/OpenAPI-compatible tool schemas often require OpenAPI-ish schema subsets. Historical issues in coding agents show incompatibility around unsupported schema keywords and complex constructs. Treat Gemini as requiring its own provider smoke before universal claims.

### Zai

Zai accepted the original tuple schema and all required gate rows, but relying on Zai permissiveness created the OpenAI portability bug. Universal schema must target the strictest supported provider subset, not the most permissive.

## Recommendations

1. **Provider-safe default schema**
   - Top-level object only.
   - Shallow properties.
   - Homogeneous arrays only.
   - No positional tuple schemas in visible schema.
   - No `$ref`, `$defs`, complex `oneOf`/`anyOf` unless tested. Current `anyOf` works on GPT-5.4-mini but should be measured; a string-only DSL may be smaller and safer.

2. **Runtime validation over schema precision**
   - Keep visible schema generic.
   - Validate op names, tuple lengths, file bounds, and snippet sizes in pi-blitz runtime and Blitz CLI.
   - Fail closed with concise errors.

3. **Provider compatibility gate**
   - Every default tool profile change must run at least one smoke row per mandatory provider before any benchmark matrix.
   - A provider schema rejection is a hard gate failure.

4. **Schema minimization candidates**
   - Replace tuple array `e` with a compact DSL string `s`, e.g. `x\tfile\told\tnew\nrb\tfile\tf\tname\tbody`.
   - Or expose exact-only object: `{f:string, x:[[old,new]]}` for tiny rows.
   - Or path dictionary: `{p:["a.ts"], e:[[0,"x","old","new"]]}`.
   - Compare by real Pi/Tokscale, not schema byte length alone.

## Sources / anchors

- OpenAI function-calling docs: tools use JSON-Schema-like object parameters.
- StackOverflow/OpenAI community reports: array tuple `items` array rejected; `items` must be schema object/boolean.
- Anthropic tool-use docs/cookbook/SDK: arrays use `items` schema; tuple-form not a universal assumption.
- Local artifacts:
  - `reports/pi-tmux-true-streak-gpt54mini-tiny-10-blitz-edit-20260611-rerun.md` — pre-fix schema rejection.
  - `reports/GPT54MINI-BLITZ-EDIT-GATE-20260611.md` — post-fix passing GPT-5.4-mini gate.
  - `/tmp/minimal-openai-compatible.json` generated from pi-blitz schema dump during this session.
