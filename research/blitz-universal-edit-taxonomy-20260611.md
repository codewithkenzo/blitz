# Blitz universal edit taxonomy — 2026-06-11

Status: main-agent salvage report after researcher context overflow. Purpose: define benchmark-ready edit groups and failure classes for universal/default-route work.

## Definition

Universal means the default edit route beats core-only across broad real editing tasks by combining:

- Blitz success when deterministic/safe/cheap;
- explicit decline/fallback when unsupported/unsafe/ambiguous;
- honest accounting of all route-visible tokens;
- 100% correctness on accepted rows.

## Scenario groups

### A. Tiny exact edits

Examples:

- change one string literal;
- change one boolean;
- change one numeric constant;
- change one env/config flag;
- change a short markdown status line.

Risks:

- schema/tool overhead dominates;
- core single edit may be extremely cheap;
- model may call tool repeatedly instead of batching.

Acceptance:

- exact-only route or default route beats core on aggregate and each tiny row group;
- no hidden fallback counted as Blitz.

### B. Batch exact edits

Examples:

- 10 independent tiny replacements across files;
- same-file multi replace;
- mixed docs/config/code replacements.

Risks:

- repeated absolute paths;
- overly verbose prompt/tool args;
- partial success if one op fails.

Acceptance:

- atomic preview/apply; fail closed if any op invalid;
- one tool call preferred;
- total context lower than core.

### C. Anchor inserts

Examples:

- insert a log line after existing line;
- append a markdown section after marker;
- insert helper function after existing symbol;
- add test case after named test.

Risks:

- empty oldText insertion edge case;
- repeated anchor line;
- whitespace/newline formatting;
- anchor not found.

Acceptance:

- unique anchor required unless selector disambiguates;
- repeated anchor declines/fails closed;
- no mutation on ambiguity.

### D. Structural edits

Examples:

- replace function body;
- insert after function/class;
- replace return expression;
- wrap body in guard/try/catch;
- replace method in class;
- TSX component return/body edit.

Risks:

- same-name symbols of different kinds;
- overloads/multiple declarations;
- nested functions/classes;
- parser grammar misses language construct;
- comments/strings confusing symbol scan.

Acceptance:

- kind + name + occurrence/range disambiguation;
- fail closed on ambiguity;
- AST/brace validation before write.

### E. Imports and module wiring

Examples:

- add named import;
- remove unused import;
- convert default to named import;
- add side-effect import;
- update import path.

Risks:

- duplicate specifiers;
- style/order changes;
- type-only imports;
- mixed quote/semi style.

Acceptance:

- preserve style where possible;
- dedupe;
- no syntax break;
- route declines if parser unsupported.

### F. Renames/refactors

Examples:

- local function rename;
- variable rename within one file;
- exported symbol rename with import updates;
- prop rename in TSX component usage.

Risks:

- semantic scope needed;
- cross-file references;
- string/comment false positives;
- shadowed names.

Acceptance:

- exact scope proof or decline;
- cross-file changes atomic;
- no broad regex rename accepted without proof.

### G. Config formats

Examples:

- JSON boolean/string key;
- YAML nested key;
- TOML key;
- package.json script/version;
- TypeScript object-literal config.

Risks:

- duplicate keys;
- comments/trailing commas;
- nested path ambiguity;
- formatting preservation.

Acceptance:

- parse-aware where possible;
- fail closed on duplicate/ambiguous key path;
- format preserved enough to pass exact expected output or semantic validator.

### H. Docs/comments/text

Examples:

- append section;
- replace heading;
- update badge/version/status;
- edit comment block.

Risks:

- repeated headings;
- markdown formatting;
- no AST;
- exact anchor may be easier than semantic route.

Acceptance:

- exact anchor uniqueness;
- clear no-op if target already present;
- no accidental duplicate sections.

### I. Huge files / generated / minified

Examples:

- large TS file with many repeated literals;
- minified JS/CSS;
- generated lockfile;
- vendored files.

Risks:

- parser cost;
- repeated patterns;
- unsupported formatting;
- edits should often decline.

Acceptance:

- cost-aware route decides before sending huge old/new;
- generated/minified may require exact unique replace only;
- decline is acceptable if route-system beats core or safety requires it.

### J. No-op / idempotent requests

Examples:

- “make version 1.2.3” when already 1.2.3;
- add import already present;
- append section already present.

Risks:

- duplicate insertion;
- wasted tool call.

Acceptance:

- `noop` without mutation;
- low token overhead;
- correctness recognizes unchanged expected file.

### K. Ambiguous/unsafe requests

Examples:

- “change foo to bar” where foo appears 12 times;
- “update the helper” with multiple helpers;
- old text not found;
- two edits overlap.

Acceptance:

- fail closed or explicit clarify/decline;
- no mutation;
- fallback accounting explicit.

## Natural prompt templates

For each group, include prompts like:

- “In `file.ts`, change the greeting label from old to new.”
- “Add timing right after the order processing log.”
- “Replace `alpha`’s implementation so it returns `value * 2`.”
- “Update the config so debug is enabled.”
- “Add the missing React import and update the prop name.”
- “This should already be done; make sure the docs say Status: ready.”

Do not include exact JSON in natural rows. The model must choose route/tool.

## Failure taxonomy

- `schema_reject`: provider rejects tool schema.
- `tool_noncompliance`: model does not call required/default route.
- `multi_call_overhead`: model calls many times when one batch expected.
- `incorrect_mutation`: output file differs from expected.
- `unsafe_mutation`: file changed when route should decline/noop.
- `fallback_hidden`: core fallback occurred but counted as Blitz success.
- `token_loss`: correct but total context >= core.
- `tokscale_mismatch`: provider/Pi accounting cannot be reconciled.
- `timeout`: run exceeds wall budget.

## Minimum universal v1 matrix

Per mandatory provider:

- scripted regression: existing 6 rows;
- natural rows: at least 10 groups × 5 rows = 50 rows;
- adversarial safety rows: at least 20 rows;
- provider schema smoke before matrix.

Total minimum per provider: 76 rows.

## Reporting requirements

Report both:

1. **Blitz-op success subset** — rows where Blitz mutated files and beat equivalent core.
2. **Default-route system** — rows where route may decline/fallback but total route beats core-only.

Universal claim can only attach to the default-route system unless every primitive Blitz-op subset also beats core.
