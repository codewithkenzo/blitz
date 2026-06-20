# Provider-language quick survey — 2026-06-20

**Status:** exploratory product telemetry, not a final claim.

Ticket: `bli-bhyc`  
Plan: `docs/plans/PLAN-0.5E-provider-language-survey.md`  
Raw artifacts: `reports/pi-accounting-runs/20260620-provider-language-survey`  
Harness: `bench/natural-edit.ts spawn harness, --tokscale --keep-temp, core vs blitz lanes`

## Summary

- Raw model runs: **32** / cap 40
- Provider/scenario pairs: **16**
- Tokscale ok+matched: **32/32**
- Timeouts: **0**
- Runs with undeclared side effects: **0**
- Systemic stop triggered: **no**

- `openai-codex/gpt-5.4-mini`: 7/8 survey_green, 1 survey_red_product, median token delta 21.9% (min 5.3%, max 23.5%).
- `zai/glm-4.5-air`: 7/8 survey_green, 1 survey_red_product, median token delta 10.0% (min -21.1%, max 58.4%).

Provider lanes not run: Claude/Gemini/Grok were not included; auth stability was not established within the bounded row budget, and no auth repair was attempted.

## Row table

| Provider | Scenario | Language/file | Edit class | Status | Blitz correct | Blitz route | Core tokens | Blitz tokens | Delta | Failure / note | Artifact |
|---|---|---|---|---|---:|---|---:|---:|---:|---|---|
| `openai-codex/gpt-5.4-mini` | `ambiguous-multi-match-safety` | TypeScript .ts | safety ambiguous repeated anchor | `survey_green` | true | `noop` | 716 | 884 | 23.5% | safety no-mutation accepted | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/ambiguous-multi-match-safety__blitz__0__2026-06-20T04-43-36-321Z` |
| `openai-codex/gpt-5.4-mini` | `docs-heading-update` | Markdown .md | doc edit | `survey_green` | true | `blitz_success` | 1482 | 1824 | 23.1% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/docs-heading-update__blitz__0__2026-06-20T04-43-18-195Z` |
| `openai-codex/gpt-5.4-mini` | `mixed-json-ts` | JSON .json + TypeScript .ts | config set/key across files | `survey_green` | true | `blitz_success` | 1663 | 1914 | 15.1% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/mixed-json-ts__blitz__0__2026-06-20T04-43-08-077Z` |
| `openai-codex/gpt-5.4-mini` | `same-file-multi` | TypeScript .ts | same-file multi exact / mixed local edits | `survey_green` | true | `blitz_success` | 2038 | 2490 | 22.2% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/same-file-multi__blitz__0__2026-06-20T04-42-02-006Z` |
| `openai-codex/gpt-5.4-mini` | `structural-add-guard` | TypeScript .ts | structural insert at function start | `survey_green` | true | `blitz_success` | 1732 | 2082 | 20.2% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-add-guard__blitz__0__2026-06-20T04-42-56-245Z` |
| `openai-codex/gpt-5.4-mini` | `structural-body` | TypeScript .ts | structural function body wrap | `survey_red_product` | false | `incorrect` | 6524 | 6869 | 5.3% | Blitz row incorrect: model/tool produced no accepted structural-body mutation; expected file mismatch. | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-body__blitz__0__2026-06-20T04-42-29-348Z` |
| `openai-codex/gpt-5.4-mini` | `tiny-exact` | TypeScript .ts | tiny exact unique return-line replace | `survey_green` | true | `blitz_success` | 1552 | 1894 | 22.0% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/tiny-exact__blitz__0__2026-06-20T04-41-52-663Z` |
| `openai-codex/gpt-5.4-mini` | `tsx-button-prop-text` | TSX .tsx | JSX prop/text exact edit | `survey_green` | true | `blitz_success` | 1557 | 1898 | 21.9% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/tsx-button-prop-text__blitz__0__2026-06-20T04-43-27-328Z` |
| `zai/glm-4.5-air` | `ambiguous-multi-match-safety` | TypeScript .ts | safety ambiguous repeated anchor | `survey_green` | true | `noop` | 890 | 1005 | 12.9% | safety no-mutation accepted | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/ambiguous-multi-match-safety__blitz__0__2026-06-20T04-41-44-520Z` |
| `zai/glm-4.5-air` | `docs-heading-update` | Markdown .md | doc edit | `survey_green` | true | `blitz_success` | 1855 | 2061 | 11.1% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/docs-heading-update__blitz__0__2026-06-20T04-41-24-769Z` |
| `zai/glm-4.5-air` | `mixed-json-ts` | JSON .json + TypeScript .ts | config set/key across files | `survey_green` | true | `blitz_success` | 2008 | 2464 | 22.7% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/mixed-json-ts__blitz__0__2026-06-20T04-41-12-627Z` |
| `zai/glm-4.5-air` | `same-file-multi` | TypeScript .ts | same-file multi exact / mixed local edits | `survey_green` | true | `blitz_success` | 2499 | 2709 | 8.4% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/same-file-multi__blitz__0__2026-06-20T04-39-49-313Z` |
| `zai/glm-4.5-air` | `structural-add-guard` | TypeScript .ts | structural insert at function start | `survey_green` | true | `blitz_success` | 2255 | 3571 | 58.4% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-add-guard__blitz__0__2026-06-20T04-40-57-651Z` |
| `zai/glm-4.5-air` | `structural-body` | TypeScript .ts | structural function body wrap | `survey_red_product` | false | `incorrect` | 6865 | 5419 | -21.1% | Blitz row incorrect: wrapped body but collapsed opening/closing brace newlines; expected file mismatch. | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-body__blitz__0__2026-06-20T04-40-35-535Z` |
| `zai/glm-4.5-air` | `tiny-exact` | TypeScript .ts | tiny exact unique return-line replace | `survey_green` | true | `blitz_success` | 2005 | 2183 | 8.9% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/tiny-exact__blitz__0__2026-06-20T04-39-35-477Z` |
| `zai/glm-4.5-air` | `tsx-button-prop-text` | TSX .tsx | JSX prop/text exact edit | `survey_green` | true | `blitz_success` | 2056 | 2119 | 3.1% |  | `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/tsx-button-prop-text__blitz__0__2026-06-20T04-41-36-922Z` |

## Notes

- Positive delta means Blitz used more runtime input/output/cache tokens than core in this single paired row; negative means fewer. These are telemetry rows, not final savings claims.
- `structural-body` failed in Blitz for both providers: Zai mutated with brace/newline mismatch; OpenAI/Codex did not produce the expected structural wrap. Both are preserved as red product rows; not rerun.
- All Tokscale validations matched Pi JSONL parser totals. No hidden fallback was counted as Blitz success.
- Raw per-run reports live under `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-harness/`; work/session artifacts live under `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/`.
