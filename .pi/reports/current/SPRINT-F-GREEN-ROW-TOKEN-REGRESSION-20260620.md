# Sprint F green-row token regression diagnosis

Status: existing-artifact diagnosis only. No benchmark/model reruns.

## Sources

- Sprint D lock: `.pi/reports/archive/history/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-z13z.json`
- Provider-language survey: `.pi/reports/current/PROVIDER-LANGUAGE-SURVEY-20260620.json`
- Raw run root: `.pi/reports/current/pi-accounting-runs/20260620-provider-language-survey/`

## Headline

Sprint D passed because Blitz replaced large core prompts/results with compact one-call `blitz_edit`: aggregate **10565 fewer context tokens** across 7 paired scenario rows.

Provider-language green rows lost because survey rows are smaller/simple and prompt/input overhead dominated: aggregate **+4790 tokens** across 14 green rows (**input +3298, output -44, cache +1536**).

Structural-body reds excluded from green-row token diagnosis; fixed separately under `bli-7yuu`/`bli-caly`.

## Component aggregates

| Set | Lane | schema | skill | prompt | tool args | output | cache read | result payload | residual input | total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Sprint D lock | core | 0 | 0 | 6724 | 3790 | 4332 | 15104 | 2686 | 8763 | 34923 |
| Sprint D lock | blitz | 2450 | 1876 | 3508 | 3341 | 3479 | 12032 | 175 | 1620 | 24358 |
| Sprint D delta | blitz-core | 2450 | 1876 | -3216 | -449 | -853 | -3072 | -2511 | -7143 | -10565 |
| Survey green ALL | core | 0 | 0 | 2798 | 1130 | 1411 | 8832 | 267 | 11267 | 24308 |
| Survey green ALL | blitz | 5866 | 3752 | 4212 | 1149 | 1367 | 10368 | 333 | 5807 | 29098 |
| Survey green ALL delta | blitz-core | 5866 | 3752 | 1414 | 19 | -44 | 1536 | 66 | -5460 | 4790 |
| Survey green openai-codex | core | 0 | 0 | 1399 | 470 | 602 | 0 | 78 | 8739 | 10740 |
| Survey green openai-codex | blitz | 2933 | 1876 | 2106 | 476 | 595 | 0 | 150 | 5569 | 12986 |
| Survey green openai-codex delta | blitz-core | 2933 | 1876 | 707 | 6 | -7 | 0 | 72 | -3170 | 2246 |
| Survey green zai | core | 0 | 0 | 1399 | 660 | 809 | 8832 | 189 | 2528 | 13568 |
| Survey green zai | blitz | 2933 | 1876 | 2106 | 673 | 772 | 10368 | 183 | 238 | 16112 |
| Survey green zai delta | blitz-core | 2933 | 1876 | 707 | 13 | -37 | 1536 | -6 | -2290 | 2544 |

## Row deltas

| Provider | Scenario | core | blitz | delta | input Δ | output Δ | cache Δ | prompt Δ | args Δ | result payload Δ |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| openai-codex | ambiguous-multi-match-safety | 716 | 884 | 168 | 168 | 0 | 0 | 101 | 0 | 0 |
| openai-codex | docs-heading-update | 1482 | 1824 | 342 | 347 | -5 | 0 | 101 | -7 | 14 |
| openai-codex | mixed-json-ts | 1663 | 1914 | 251 | 292 | -41 | 0 | 101 | -18 | 3 |
| openai-codex | same-file-multi | 2038 | 2490 | 452 | 402 | 50 | 0 | 101 | 48 | 14 |
| openai-codex | structural-add-guard | 1732 | 2082 | 350 | 351 | -1 | 0 | 101 | -3 | 14 |
| openai-codex | tiny-exact | 1552 | 1894 | 342 | 347 | -5 | 0 | 101 | -7 | 14 |
| openai-codex | tsx-button-prop-text | 1557 | 1898 | 341 | 346 | -5 | 0 | 101 | -7 | 13 |
| zai | ambiguous-multi-match-safety | 890 | 1005 | 115 | 115 | 0 | 0 | 101 | 0 | 0 |
| zai | docs-heading-update | 1855 | 2061 | 206 | 98 | -20 | 128 | 101 | -10 | 14 |
| zai | mixed-json-ts | 2008 | 2464 | 456 | 230 | 98 | 128 | 101 | 98 | 28 |
| zai | same-file-multi | 2499 | 2709 | 210 | 228 | -18 | 0 | 101 | -17 | 14 |
| zai | structural-add-guard | 2255 | 3571 | 1316 | 292 | 0 | 1024 | 101 | 6 | -34 |
| zai | tiny-exact | 2005 | 2183 | 178 | 84 | -34 | 128 | 101 | -2 | 14 |
| zai | tsx-button-prop-text | 2056 | 2119 | 63 | -2 | -63 | 128 | 101 | -62 | -42 |

## Diagnosis

1. **Resident tax remains fixed per Blitz row.** Sprint D amortized schema/skill over large multi-edit prompts. Survey rows are tiny/simple; fixed resident/tool overhead has no room to pay back.
2. **Prompt delta changed sign.** Sprint D Blitz prompt was much smaller than core (delta -3216); survey prompt delta is positive (1414) because provider-language prompts include the same source/context plus Blitz-specific tool instructions.
3. **Tool args still help sometimes, not enough.** Sprint D args delta -449; survey args delta 19. Small exact/doc/tsx edits do not replay enough unchanged code for Blitz to win.
4. **Output/result payload is already compact.** Survey output delta -44; result payload delta 66. This is not main regression source.
5. **Cache behavior differs by provider.** OpenAI survey rows had cache delta 0; Zai green rows added cache +1536, mostly from structural/additional cached prompt/tool context.

## Follow-up implementation notes

- Route tiny/simple green survey rows to core unless Blitz prompt/schema tax is reduced or exact-op prompt becomes smaller than core.
- Add deterministic token guards for minimal resident schema, resident skill, success output, error output, and prompt templates before new claims.
- Optimize provider-language survey prompts/row shapes separately; do not claim until remeasured.
- Keep structural-body correctness fix separate from token claims; correctness red invalidates savings rows.

## Caveats

- Component split for provider survey is derived from existing JSONL + tokenizer replay, not provider-native component labels. Aggregate input/output/cache totals match report JSON; component labels are diagnostic.
- Resident schema/skill counts use available artifacts at diagnosis time: schema 419, skill 268; Sprint D lock recorded schema 350, skill 268.
