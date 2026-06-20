# PLAN-0.5E — Provider-language quick survey

Date: 2026-06-20
Parent epic: `bli-6uqs`
Plan ticket: `bli-l415`

## Purpose

Run a bounded across-the-board survey to learn realistic token savings and failure patterns across providers, languages, and common edit classes.

This is product telemetry, not a final replacement claim.

## Non-goals

- Do not claim universal/default replacement from this survey.
- Do not rerun rows until green.
- Do not run full provider × all edit-type matrix.
- Do not modify product code during the survey run.
- Do not count fallback/decline/noop as Blitz success.

## Providers/models

Initial survey providers should be whatever is currently authenticated and stable in Pi. Suggested set:

| Provider lane | Model | Purpose |
|---|---|---|
| Zai | `glm-4.5-air` | Current strongest locked evidence lane. |
| OpenAI/Codex | `gpt-5.4-mini` | Known alternate lane with prior core-baseline blocker; useful to retest representative rows. |
| Anthropic/Claude | repo/Pi available default, if authenticated | Provider-shape diversity. |
| Gemini | repo/Pi available default, if authenticated | Provider-shape diversity and malformed-call behavior. |
| xAI/Grok | available Grok model, if authenticated | Composer/Grok behavior check. |

If a provider is not authenticated or quota-limited, record `provider_blocked` and continue. Do not spend time fixing auth in survey ticket.

## Languages/files

Use small fixtures only.

Language/file groups:

- TypeScript `.ts`
- TSX `.tsx`
- JavaScript `.js`
- JSX `.jsx`
- Python `.py`
- Go `.go`
- Rust `.rs`
- JSON `.json`
- JSONC `.jsonc`
- YAML `.yaml`
- TOML `.toml`
- Markdown `.md`
- HTML `.html`
- CSS `.css`
- Plain text `.txt`

## Edit classes

Do a compact representative slice, not all E01-E18 for every provider.

Required rows per provider:

| Class | File groups | Expected behavior |
|---|---|---|
| tiny exact | `.ts`, `.json`, `.md` | success |
| same-file multi exact | `.ts` | success |
| structural function body replace | `.ts`, `.js` | success if supported by current minimal route |
| structural insert-after function | `.ts`, `.js` | success if supported by current minimal route |
| config set/key or exact config edit | `.json`, `.yaml`, `.toml` | success or explicit unsupported classification |
| doc/comment edit | `.md`, `.ts` comment | success |
| safety ambiguous | `.ts` | decline/no mutation |
| safety no-match/stale | `.ts` | decline/no mutation |
| unsupported structural | `.md` or `.txt` | decline/no mutation |

Optional rows if time remains:

- import edit `.ts`
- local rename `.ts`
- CSS exact `.css`
- HTML exact `.html`
- Python exact `.py`
- Go exact `.go`
- Rust exact `.rs`

## Row cap

Hard cap:

- maximum 8 required rows per provider;
- maximum 5 providers;
- maximum 40 model rows total.

If this is too expensive, reduce provider count first. Keep Zai + GPT minimum if possible.

## Required row fields

Each row must record:

- provider/model;
- language/file group;
- edit class;
- lane/tool/profile;
- route outcome;
- correctness;
- mutation/no-mutation;
- Tokscale/accounting status;
- core tokens;
- Blitz tokens;
- delta percent;
- failure reason;
- artifact path.

## Pass/fail language

This survey does not pass/fail Exodia.

Allowed outputs:

- `survey_green` — row succeeded and token accounting valid.
- `survey_red_product` — product/tool correctness issue.
- `survey_red_harness` — prompt/harness/fixture/accounting issue.
- `survey_red_provider` — provider/auth/quota/tool-shape issue.
- `survey_unsupported` — unsupported by current declared scope.

## Stop rules

Stop the survey only on systemic issue:

- provider auth/quota blocks all rows for that provider;
- harness scenario misroutes fixtures;
- Tokscale/accounting broken globally;
- hidden fallback detected;
- file mutation escapes workspace.

Do not stop for a single row failure. Record it and continue within cap unless it indicates systemic corruption.

## Artifacts

Suggested output:

- `reports/PROVIDER-LANGUAGE-SURVEY-20260620.md`
- `reports/PROVIDER-LANGUAGE-SURVEY-20260620.json`
- raw per-row artifacts under `reports/pi-accounting-runs/20260620-provider-language-survey/`

## After survey

Run `bli-05rl` triage:

- product bugs → tk tickets;
- harness bugs → tk tickets;
- provider quirks → provider matrix notes;
- token wins/losses → roadmap;
- unsupported scope → explicit non-claim wording.
