# Sprint G Post-fix Focused Telemetry — 2026-06-20

Status: exploratory telemetry, **not** a final claim.

Raw root: `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix`

Constraints: 8/12 raw model runs, Tokscale required (8/8 matched), no rerun fishing.

## Pair summary

| Provider/model | Scenario | Core | Blitz | Delta | Status |
|---|---|---:|---:|---:|---|
| openai-codex/gpt-5.4-mini | structural-body | green 6588 | red 6588 | 0 (0%) | blitz_red |
| openai-codex/gpt-5.4-mini | tiny-exact | green 1554 | green 1556 | 2 (0.1%) | both_green |
| zai/glm-4.5-air | structural-body | green 6927 | red 13651 | 6724 (97.1%) | blitz_red |
| zai/glm-4.5-air | tiny-exact | green 2054 | green 1769 | -285 (-13.9%) | both_green |

## Notes

- Telemetry only; not a final token-savings claim.
- OpenAI tiny-exact moved from +2.1% worse in Sprint F to +0.1% worse here; still not break-even.
- Zai tiny-exact was both-green and Blitz cheaper by 13.9%.
- Zai core structural-body is green after baseline prompt stabilization.
- OpenAI structural-body Blitz remains strict red because output is canonical except missing final newline (semantic near-miss).
- Zai structural-body Blitz remains red; model emitted an unsupported/incorrect 4-tuple old/new-ish rb shape that duplicated let total outside try.

## Rows

| Provider/model | Scenario | Lane | Correct | Route | Tokens | Input | Output | Cache | Tokscale | Run dir |
|---|---|---|---|---|---:|---:|---:|---:|---|---|
| openai-codex/gpt-5.4-mini | structural-body | blitz | no | incorrect | 6588 | 1780 | 1736 | 3072 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/structural-body__blitz__0__2026-06-20T06-25-43-344Z` |
| openai-codex/gpt-5.4-mini | structural-body | core | yes | core_fallback | 6588 | 1774 | 1742 | 3072 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/structural-body__core__0__2026-06-20T06-25-22-191Z` |
| openai-codex/gpt-5.4-mini | tiny-exact | blitz | yes | blitz_success | 1556 | 1506 | 50 | 0 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/tiny-exact__blitz__0__2026-06-20T06-25-17-449Z` |
| openai-codex/gpt-5.4-mini | tiny-exact | core | yes | core_fallback | 1554 | 1499 | 55 | 0 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/tiny-exact__core__0__2026-06-20T06-25-13-030Z` |
| zai/glm-4.5-air | structural-body | blitz | no | incorrect | 13651 | 4711 | 3436 | 5504 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/structural-body__blitz__0__2026-06-20T06-26-46-435Z` |
| zai/glm-4.5-air | structural-body | core | yes | core_fallback | 6927 | 2889 | 1734 | 2304 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/structural-body__core__0__2026-06-20T06-26-24-000Z` |
| zai/glm-4.5-air | tiny-exact | blitz | yes | blitz_success | 1769 | 964 | 37 | 768 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/tiny-exact__blitz__0__2026-06-20T06-26-18-216Z` |
| zai/glm-4.5-air | tiny-exact | core | yes | core_fallback | 2054 | 1185 | 101 | 768 | match | `.pi/reports/current/pi-accounting-runs/20260620-sprint-g-postfix/natural-edit-runs/tiny-exact__core__0__2026-06-20T06-26-10-967Z` |

## Caveats

- Structural-body Blitz rows are red; do not use them for savings claims.
- Strict-format failures (including semantic near-miss missing final newline) remain failures, not successes.
- `bli-js15` follow-up policy: minimal/default scope is exact/simple/config/doc/tiny multi; structural `rb` / structural-body moves to future advanced or explicit structural route unless strict supported tuple validation lands.
- Tiny-exact OpenAI is effectively near break-even but still +2 tokens; no universal/default claim.
- This run used merged local pi-blitz dist from `e94a904`; build output is not a source commit.
