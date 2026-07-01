# Semantic narrow tool smoke — 2026-04-27

Provider/model: `openai-codex/gpt-5.4-mini`
Mode: direct Pi print session with source extension dist, tool-restricted.

## `pi_blitz_try_catch`

Command shape:

```bash
pi --offline --print --no-context-files --no-prompt-templates \
  --provider openai-codex --model gpt-5.4-mini --thinking off \
  --extension extensions/pi-blitz/dist/index.js \
  --tools pi_blitz_try_catch \
  "Use only pi_blitz_try_catch ..."
```

Result: exit 0, file mutated correctly.

```ts
function handle(value: number): number {
  try {
    const doubled = value * 2;
    return doubled;
  } catch (error) {
    console.error(error);
    throw error;
  }
}
```

## `pi_blitz_replace_return`

Command shape:

```bash
pi --offline --print --no-context-files --no-prompt-templates \
  --provider openai-codex --model gpt-5.4-mini --thinking off \
  --extension extensions/pi-blitz/dist/index.js \
  --tools pi_blitz_replace_return \
  "Use only pi_blitz_replace_return ..."
```

Result: exit 0, file mutated correctly.

```ts
function handle(value: number): number {
  const doubled = value * 2;
  return value + 1;
}
```

These were smoke checks for tool availability and model-call shape, not benchmark rows. Token/cost claims require session JSONL parsing in `bench/pi-matrix.ts`.
