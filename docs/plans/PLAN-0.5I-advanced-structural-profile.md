# PLAN-0.5I — Advanced structural profile

Date: 2026-06-20
Ticket: `bli-53tr`
Status: design-only, no model/provider runs

## Source evidence

Inputs used:

- `docs/plans/PLAN-0.5I-token-moonshot.md`
- `reports/SPRINT-I-ZERO-RESIDENT-MINIMAL-SURFACE-20260620.md`
- `reports/SPRINT-I-ROUTE-OPTIMIZER-TOKEN-TARGET-MATH-20260620.md`
- `docs/plans/PLAN-0.5I-compact-ir-v2.md`
- existing `docs/blitz.md` structured apply policy

Non-claim boundary: this plan defines future lock requirements. It does not claim structural savings, does not run providers, and does not add structural `rb` back to the minimal profile.

## Goal

Advanced structural profile gives Blitz a separate, explicit route for AST/symbol-aware edits after minimal exact routing is stable.

It exists for edits where unchanged-code replay is expensive or unsafe:

- symbol body replace;
- insert after symbol;
- import edit;
- local rename;
- wrap/delete/append block.

Minimal/default profile remains exact-first. Structural ops in minimal profile must decline fail-closed with no mutation.

## Product boundary

Profiles:

| Profile | Resident/default | Ops | Claim lane |
| --- | --- | --- | --- |
| minimal | yes | `x` exact, optional guarded `i`/`d`, structural decline | simple/core replacement gate |
| advanced | no, explicit/lazy | `rb`, `ia`, `im`, `lr`, `wb`, structural helpers | separate structural gate |
| verbose/admin | no | diagnostics, full diff, doctor, debug, undo | no token claim unless measured separately |

Rule: advanced profile never increases minimal resident schema/skill tax.

## Accepted tuple shapes

Advanced profile uses compact IR v2 envelope plus advanced-only aliases.

### `rb` — replace symbol body

Same file default:

```json
{"f":"src/a.ts","e":[["rb","function","makeThing","return x;\n"]]}
```

Path dictionary:

```json
{"p":["src/a.ts"],"e":[[0,"rb","function","makeThing","return x;\n"]]}
```

Anchor dictionary:

```json
{"f":"src/a.ts","a":["makeThing"],"r":["return x;\n"],"e":[["rb","function",0,0]]}
```

Required fields:

- file via per-edit path, `p` ref, or top-level `f`;
- symbol kind;
- symbol name/anchor;
- new body text.

Validation:

- symbol kind must be supported for language;
- symbol resolves exactly once in file;
- replacement body parses or passes language-specific body validation where available;
- indentation normalized deterministically;
- no mutation if parser unavailable for that language/kind.

### `ia` — insert after symbol declaration

```json
{"f":"src/a.ts","e":[["ia","function","makeThing","\nexport const other = 1;\n"]]}
```

Validation:

- target symbol resolves exactly once;
- inserted text parses as valid sibling node where parser supports it;
- blank-line policy applied after insertion;
- no insertion into generated/minified files unless explicit advanced override exists later.

### `im` — import edit

Add named import:

```json
{"f":"src/a.ts","e":[["im","add","@pkg/foo","Foo"]]}
```

Remove named import:

```json
{"f":"src/a.ts","e":[["im","rm","@pkg/foo","Foo"]]}
```

Validation:

- import style supported for language/module system;
- dedupe existing import;
- preserve quote/semi style;
- sort only if repo/language rule known; otherwise append minimally.

### `lr` — local rename

```json
{"f":"src/a.ts","e":[["lr","oldName","newName","function","makeThing"]]}
```

Fields:

- old identifier;
- new identifier;
- scope kind/name, optional but recommended.

Validation:

- scope resolves exactly once;
- every rewritten reference belongs to same lexical binding;
- no export/API rename unless explicit global rename mode exists later;
- reject shadowing ambiguity.

### `wb` — wrap block / node

```json
{"f":"src/a.ts","e":[["wb","function","makeThing","try {","} catch (err) { throw err; }"]]} 
```

Validation:

- wrapper must parse after insertion;
- no semantic success if formatting/parsing fails;
- advanced-only until enough provider-shape evidence exists.

## Provider normalization rules

Normalize input before validation only for syntax noise, not semantic intent.

Allowed normalization:

- op aliases case-folded to lowercase: `RB` → `rb`;
- long op names mapped to aliases: `replaceBody` → `rb` only in advanced profile;
- path refs accepted as numbers or numeric strings if unambiguous;
- kind aliases mapped per language: `fn` → `function`, `method` stays method;
- symbol refs trim surrounding whitespace;
- replacement line endings normalize to `\n` internally, write back preserving file dominant EOL;
- optional tuple object form accepted for compatibility:

```json
{"op":"rb","file":"src/a.ts","kind":"function","name":"makeThing","body":"return x;\n"}
```

Rejected normalization:

- fuzzy symbol names;
- inferred missing file when multiple files are loaded;
- converting exact text op into structural op;
- converting unsupported structural op into exact replacement;
- accepting prose commands as operations;
- accepting body replacement when symbol match count != 1;
- automatic global rename from local rename.

Provider-shape tests must include:

- tuple/direct strings;
- tuple dictionary refs;
- object form;
- wrong arity;
- wrong op in minimal profile;
- numeric string refs;
- multiline replacement bodies;
- markdown-fenced replacement text, expected reject unless caller stripped fences.

## Formatting normalization

Formatting goal: preserve local style, never hide semantic drift.

Rules:

1. Detect dominant EOL: LF/CRLF.
2. Detect indentation unit in target region: tabs, 2 spaces, 4 spaces.
3. For `rb`, indent replacement body relative to body depth, not column 0.
4. Preserve opening/closing braces from existing symbol unless tuple explicitly targets full node in future mode.
5. For `ia`, insert at sibling boundary with existing blank-line style.
6. For `im`, preserve quote/semi style from nearest import group.
7. Run parser validation after normalization where language parser exists.
8. If parse fails after normalization, reject with `fmt` or `parse`, no mutation.

Do not run repo formatter automatically in advanced profile lock gate. Formatter can mask wrong insertion and adds route noise. Future verbose/admin mode may provide opt-in format command.

## Language capability matrix

Initial lock should be narrow. Prefer green subset over broad weak claim.

| Language | Parser status | `rb` | `ia` | `im` | `lr` | `wb` | Lock recommendation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TypeScript/TSX | vendored tree-sitter | function/method/class methods | yes | ES imports | local lexical only | future | first lock target |
| JavaScript/JSX | vendored tree-sitter | function/method/class methods | yes | ES/CJS cautious | local lexical only | future | first/second target |
| Zig | repo core language, parser availability TBD | function only after parser lock | maybe | n/a | local only later | future | separate gate |
| Python | grammar likely available only if vendored | function/class method | yes | import/from import later | local only later | future | later |
| Go | grammar likely available only if vendored | func/method | yes | import block later | local only later | future | later |
| Rust | grammar likely available only if vendored | fn/impl method | yes | use edit later | local only later | future | later |
| Markdown/JSON/YAML | structural AST not relevant | no | no | no | no | no | route to exact/core |

Capability metadata must be queryable by route selector:

```json
{"lang":"ts","ops":{"rb":["function","method"],"ia":["function","class"],"im":["esm-add","esm-rm"],"lr":["local"]}}
```

Unsupported language/op returns `op`/`parse` decline, no mutation.

## Failure taxonomy

Compact advanced output uses same v2 output format with structural-specific reason codes.

| Code | Meaning | Mutates |
| --- | --- | --- |
| `op` | op unavailable in active profile/language | no |
| `shape` | malformed tuple/object | no |
| `path` | file path rejected | no |
| `parse` | parser unavailable or parse failed | no |
| `kind` | symbol kind unsupported | no |
| `missing` | symbol/import/reference not found | no |
| `ambig` | multiple candidate symbols/imports/refs | no |
| `scope` | local rename scope/binding unsafe | no |
| `fmt` | formatting normalization failed validation | no |
| `overlap` | structural ranges overlap batch edit | no |
| `semantic` | validation detected likely wrong binding/node | no |
| `write` | write failed after validation | maybe partial, include file list |

Success output:

```json
{"ok":1,"op":"rb","m":1,"f":1}
```

Decline output:

```json
{"ok":0,"op":"rb","r":"ambig","n":2}
```

Minimal profile structural decline:

```json
{"ok":0,"op":"rb","r":"op"}
```

## Future lock gate

Advanced structural profile cannot enter selector/default until all gates pass.

### Gate C0 — implementation safety

- structural ops unavailable from minimal/default resident profile;
- unsupported structural ops decline, no mutation;
- exact route behavior unchanged;
- workspace path guard + atomic/no-partial policy tested.

### Gate C1 — provider-shape lock

Bounded provider-shape fixture set, no benchmark fishing:

- at least 3 providers/models or user-selected target set;
- tuple direct, tuple dict, object form;
- multiline body;
- wrong arity;
- unsupported minimal structural op;
- ambiguous symbols;
- parser failure.

Acceptance: provider emits parseable intended shape or route declines. No semantic-near-miss success.

### Gate C2 — language subset lock

Initial subset recommendation:

- TypeScript + JavaScript only;
- `rb` for function/method;
- `ia` for function/class symbol;
- `im` add/remove named ES import only if style tests pass.

Acceptance: repo fixtures prove parse/format/range correctness for each supported kind.

### Gate C3 — token evidence lock

- real Pi sessions;
- Tokscale validation;
- green-only rows;
- forced-advanced and route-selected reported separately;
- minimal exact portfolio reported separately;
- failed attempts preserved;
- no universal claim.

Required wording:

- allowed: "advanced structural profile saves X on green TS/JS structural rows in this locked fixture set";
- forbidden: "Blitz structurals are universally cheaper";
- forbidden: "minimal profile supports rb".

### Gate C4 — router integration

Selector may choose advanced only when:

- user/task explicitly permits advanced structural route;
- file language/op is in capability matrix;
- predicted old/new replay cost exceeds advanced resident+arg+output cost by configured margin;
- safety confidence is deterministic;
- fallback/core route remains available.

## Minimal profile non-regression guard

Add tests/checks when implemented:

- minimal schema has no `rb` implementation text beyond compact decline semantics;
- minimal skill does not advertise structural body replace as available;
- `rb` in minimal returns `ok:0,r:"op"` and no mutation;
- route selector never sends structural op to minimal as success path;
- resident byte/token budget cannot grow because advanced profile exists.

## Acceptance checklist

- Defines strict accepted tuple shapes.
- Defines provider normalization rules.
- Defines formatting normalization rules.
- Defines language capability matrix.
- Defines failure taxonomy.
- Defines future lock gate.
- Keeps structural `rb` advanced-only.
- No model/provider runs performed.
- No universal savings claim made.
