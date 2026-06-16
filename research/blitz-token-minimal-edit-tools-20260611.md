# Blitz token-minimal edit tool patterns — 2026-06-11

Status: main-agent salvage report after researcher context overflow. Inputs: existing Blitz reports, GPT-5.4-mini rerun, web-search findings on tool-tax/lazy schemas, and partial failed researcher output about structured edit tools.

## Core observation

The biggest wins came from removing resident tool tax and batching operations into one `blitz_edit` call. Remaining savings should focus on reducing:

1. visible schema tokens;
2. resident skill tokens;
3. prompt/tool-choice tokens for unscripted requests;
4. tool-call arg tokens, especially repeated absolute paths;
5. output/result tokens;
6. repeated model loops.

## Patterns worth adopting

### 1. Split exact-only from advanced structural tool

Current `blitz_edit` supports `x`, `rb`, and `ia` in one generic schema. That works but makes tiny exact rows pay for structural affordances.

Candidate profile:

- `blitz_x`: exact replacements only.
  - Shape A: `{f:string,e:[[old,new]]}`
  - Shape B: `{f:string,s:string}` where `s` is tab/newline DSL.
- `blitz_edit`: structural/mixed route with `rb`, `ia`, config ops, etc.
- `blitz_admin`/verbose tools hidden from default.

Gate criterion: tiny rows must improve vs current GPT-5.4-mini tiny savings of 24%.

### 2. Path dictionaries

Current tool calls often repeat absolute paths in every tuple:

```json
{"e":[["x","/long/path/a.ts","old","new"], ...]}
```

Better:

```json
{"p":["a.ts","b.ts"],"e":[[0,"x","old","new"],[1,"x","old","new"]]}
```

Or same-file default:

```json
{"f":"a.ts","e":[["x","old","new"],["x","old2","new2"]]}
```

The harness should stop forcing absolute paths for product-route rows unless Pi path safety requires them. The runtime can resolve relative paths against cwd and still reject escapes.

### 3. DSL string for maximum provider compatibility

OpenAI rejects tuple schemas, and complex `anyOf` still costs tokens. A string DSL may be both cheaper and more provider-portable:

```json
{"f":"a.ts","s":"x\told\tnew\nx\told2\tnew2"}
```

Pros:

- tiny schema;
- no tuple-schema compatibility issue;
- low output/args for repeated ops;
- runtime parser already exists in compact ops (`pi_blitz_op` lineage).

Cons:

- model escaping mistakes;
- harder structured validation by provider;
- less self-documenting.

Mitigation: keep short examples in tool description and strict runtime parse errors.

### 4. Structured object ops for natural prompts

For unscripted prompts, object ops may be easier for models than DSL:

```json
{"f":"a.ts","x":[["old","new"],["old2","new2"]]}
{"f":"a.ts","rb":[["function","name","body"]]}
```

This avoids op strings in every tuple and gives each op a homogeneous array property.

### 5. Output minimization

Current default output is `ok c=N`, which is already good. Potential variants:

- `ok N`
- `noop`
- `err CODE`
- `decline CODE`

Do not emit diffs/JSON in default profile. Debug output belongs behind admin/verbose flag.

### 6. Lazy tool/profile loading

Research on tool tax/lazy schema loading points to dynamic tool gating: avoid injecting large catalogs and only expose top-k relevant tools. Blitz already moved from 17 visible tools to one minimal route; universal route should preserve this:

- default: one small route tool;
- exact-only profile for high-confidence exact edits;
- admin/debug tools only requested explicitly;
- provider-specific schema compatibility profile if needed.

### 7. Deterministic Zig inference to shrink args

Use Zig to infer more from smaller args:

- symbol body replacement from `{k,n,text}`;
- insert after symbol from `{k,n,text}`;
- config key update from `{key,value}`;
- return expression update from `{symbol,expr}`;
- import insert/delete from module/specifier;
- JSX prop/text edit from component/prop/text;
- no-op detection.

The more Zig can infer safely, the less old/new text the model sends.

## Patterns from structured edit tools

Partial researcher output captured a Unity MCP structured edit tool with operations like:

- `replace_method`
- `insert_method`
- `delete_method`
- `anchor_insert`
- `anchor_replace`

Useful lessons:

- high-level structural ops are model-friendly;
- validation levels (`basic` vs `standard`) are valuable;
- anchor-based operations cover cases where symbol AST is not enough;
- atomic multi-edit transaction matters;
- operation names can be verbose, but Blitz can alias them (`rb`, `ia`, `ak`, etc.) after skill/tool docs teach them.

## Concrete next experiments

1. **Exact-only tool experiment**
   - Add `blitz_x` or `blitz_edit` profile variant with exact-only schema.
   - Run tiny-10 on Zai, GPT-5.4-mini, GPT-5.5.

2. **Relative path experiment**
   - Modify harness/product route to use cwd-relative paths where safe.
   - Compare args tokens and total context.

3. **DSL vs JSON experiment**
   - Expose `s` compact script in minimal default profile.
   - Run exact/mixed/same-file rows.

4. **Object-op schema experiment**
   - Try `{f,x,rb,ia}` object properties with homogeneous arrays.
   - Compare model compliance in natural prompts.

5. **Output micro experiment**
   - Compare `ok c=N` vs `ok N` vs empty success if Pi allows.

## Anti-patterns

- Do not add many always-visible tools; tool catalog tax will erase gains.
- Do not trust schema constraints for correctness; runtime validation must own safety.
- Do not count fallback as Blitz success.
- Do not claim universal based only on exact scripted JSON prompts.
