# GPT-5.4-mini Blitz edit gate rerun — 2026-06-11

Status: **pass for required gate matrix after OpenAI schema fix**

Provider/model: `openai-codex/gpt-5.4-mini`
Product route: pi-blitz minimal default `blitz_edit`
Schema fix: pi-blitz commit `21ed3f3` (`fix(schema): make blitz edit OpenAI compatible`) plus format commit `4d2528e`.

## Why this rerun happened

The first GPT-5.4-mini Blitz rows failed before editing because OpenAI rejected tuple-array JSON schema:

```text
Invalid schema for function 'blitz_edit': ... is not of type 'object', 'boolean'
```

D5 fixed the visible schema to be OpenAI-compatible while preserving the runtime tuple contract (`x`, `rb`, `ia`). After that, the full required matrix below passed.

## Accepted GPT-5.4-mini rows

| Scenario | Core total context | Blitz total context | Savings | Correctness | Blitz report | Core report |
|---|---:|---:|---:|---|---|---|
| tiny-10 / Class A | 12,132 | 9,220 | 24.00% | 10/10 | `reports/pi-tmux-true-streak-gpt54mini-tiny-10-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-tiny-10-core-20260611-rerun.md` |
| mixed-20 | 16,726 | 11,148 | 33.35% | 20/20 | `reports/pi-tmux-true-streak-gpt54mini-mixed-20-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-mixed-20-core-20260611-rerun.md` |
| same-file-multi | 17,080 | 7,576 | 55.64% | final file correct | `reports/pi-tmux-true-streak-gpt54mini-same-file-multi-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-same-file-multi-core-20260611-rerun.md` |
| class-b-inserts-10 / Class B | 14,212 | 9,300 | 34.56% | 10/10 | `reports/pi-tmux-true-streak-gpt54mini-class-b-inserts-10-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-class-b-inserts-10-core-20260611-rerun.md` |
| class-c-structural-10 / Class C | 132,450 | 9,380 | 92.92% | final file correct | `reports/pi-tmux-true-streak-gpt54mini-class-c-structural-10-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-class-c-structural-10-core-20260611-rerun.md` |
| class-d-config-docs-10 / Class D | 12,032 | 8,860 | 26.36% | 10/10 | `reports/pi-tmux-true-streak-gpt54mini-class-d-config-docs-10-blitz-edit-20260611-schemafix.md` | `reports/pi-tmux-true-streak-gpt54mini-class-d-config-docs-10-core-20260611-rerun.md` |

## Aggregate

- Core total context: `204,632`
- Blitz total context: `55,484`
- Aggregate savings: `72.89%`
- Median row savings: `33.96%`
- p75 row savings: `55.64%`
- Every required row/class beats core.

## Important caveat

This proves GPT-5.4-mini compatibility for the scripted required gate matrix, not literally every possible edit. The “universal” claim should mean: `blitz_edit` can replace core for the accepted default edit classes/gates and now works on both Zai and GPT-5.4-mini. Broader natural-edit coverage still needs additional unscripted/adversarial rows.
