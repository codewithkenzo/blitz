# Live Pi tmux simulation — 2026-04-27

Run directory: `/tmp/pi-blitz-live-CMOlPw`
Model/provider: `openai-codex/gpt-5.4-mini`
Task: wrap the entire body of `mediumCompute` in try/catch.

## Setup

Both lanes used direct `pi --offline --print` commands, not the benchmark wrapper.

Core lane:

- `--no-skills`
- `--no-extensions`
- `--tools edit`

Blitz lane:

- `--no-extensions`
- `--extension <pi-blitz dist/index.js>`
- `--skill <pi-blitz skill>`
- `--tools pi_blitz_wrap_body`

Both prompts included the same original file content inline.

## Raw session files

Core:

- `/tmp/pi-blitz-live-CMOlPw/core/sessions/2026-04-27T12-55-58-527Z_019dcf02-c53f-754e-a173-e75f0e7d4c58.jsonl`

Blitz:

- `/tmp/pi-blitz-live-CMOlPw/blitz/sessions/2026-04-27T12-58-23-545Z_019dcf04-fbb9-749e-b335-852d26a2601f.jsonl`

## Results parsed from Pi JSONL

| Lane | Tool | Provider input | Provider output | Cache read | Cost | Tool calls | Tool arg tokens |
|---|---|---:|---:|---:|---:|---:|---:|
| core | `edit` | 6,887 | 9,636 | 0 | $0.0485 | 2 | 14,851 total |
| blitz | `pi_blitz_wrap_body` | 7,460 | 86 | 6,656 | $0.0065 | 1 | 66 |

Core emitted two `edit` calls in the session:

- first call: 5,227 arg tokens
- second call: 9,624 arg tokens

Blitz emitted one call:

```json
{"file":"/tmp/pi-blitz-live-CMOlPw/blitz/work/medium.ts","symbol":"mediumCompute","before":"\n  try {","after":"  } catch (error) {\n    console.error(error);\n    throw error;\n  }\n","indentKeptBodyBy":2}
```

That `pi_blitz_wrap_body` arg payload was 206 chars / 66 `cl100k_base` tokens.

## Correctness

Final files:

- `/tmp/pi-blitz-live-CMOlPw/core/work/medium.ts`
- `/tmp/pi-blitz-live-CMOlPw/blitz/work/medium.ts`

Both contain:

- `try {` after function open
- all original arithmetic statements inside try
- `catch (error)` block
- `console.error(error);`
- `throw error;`

Both final files have same byte length: `10584`.

## Interpretation

The large savings are real for this run in the narrow sense that they came from actual Pi session JSONL provider usage and actual tool-call arguments.

But the reason is not Zig being magically better. The reason is representation:

- core `edit` had to emit a huge `oldText`/`newText` payload for a 10KB function body.
- Blitz emitted only the semantic operation: wrap symbol body with before/after strings.

## Caveats

- Core process appeared to hang after writing/session logging, and was manually killed after the core tool calls were visible and the file was correctly edited.
- Core emitted two tool calls, so total arg tokens are even worse than the previous single-call benchmark. Comparing Blitz against only core's second call still shows 9,624 → 66 arg tokens.
- Blitz lane had cache read reported (`6656`), while core did not. Public claims must report input/cache separately from output.
- This is still one live run, not an N≥5 matrix.
- This supports the scoped claim only: large structural body-wrap edits can save ~99% output/tool-arg tokens by using semantic edit ops.
