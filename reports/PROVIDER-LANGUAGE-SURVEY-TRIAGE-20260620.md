# Provider-language survey triage — 2026-06-20

Status: triage complete. No benchmark reruns. No implementation changes.

Source survey:

- Report: `reports/PROVIDER-LANGUAGE-SURVEY-20260620.md`
- JSON: `reports/PROVIDER-LANGUAGE-SURVEY-20260620.json`
- Raw artifacts: `reports/pi-accounting-runs/20260620-provider-language-survey/`
- Survey ticket: `bli-bhyc` (closed)
- Triage ticket: `bli-05rl`
- Follow-up product bug: `bli-caly`

## Executive verdict

- 32 raw model runs; Tokscale ok+matched **32/32**.
- Timeouts: **0**.
- Undeclared side effects: **0**.
- Survey rows: **14 survey_green**, **2 survey_red_product**.
- Product bug: **structural-body** failed in Blitz on both providers; provider-independent scenario failure.
- Harness bug: none found that invalidates accounting/correctness. Reporting caveat: original provider medians include red rows; triage token summary below is green-only.
- Provider quirks: OpenAI/Codex chose unsupported `rb` old/new shape; Zai chose supported `rb/function/name/body` but exposed Blitz body-splice formatting bug.
- Unsupported scope: Claude/Gemini/Grok not run; auth stability out of bounded survey scope.
- Token claim: **no positive token-savings claim from this survey**. Green rows show Blitz correctness/route coverage, but all green rows used more runtime tokens than core.

## Classification

### Product bugs

| Scenario | Providers | Classification | Evidence | Follow-up |
|---|---:|---|---|---|
| `structural-body` | 2/2 | product bug / default-route structural robustness | both Blitz rows `survey_red_product`; core rows correct; Tokscale matched; no side effects | `bli-caly` |

Structural-body raw evidence:

- `zai/glm-4.5-air`
  - Artifact: `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-body__blitz__0__2026-06-20T04-40-35-535Z`
  - Tool call used supported structural shape: `rb`, `medium.ts`, `function`, `mediumCompute`, `<body>`.
  - `blitz_edit` returned `ok c=1 files=1`.
  - Final file started `function mediumCompute(seed: number): number {  try {` and ended `}}`; expected brace/newline layout was not preserved.
  - Root cause class: Blitz structural body replacement/splice formatting bug.

- `openai-codex/gpt-5.4-mini`
  - Artifact: `reports/pi-accounting-runs/20260620-provider-language-survey/natural-edit-runs/structural-body__blitz__0__2026-06-20T04-42-29-348Z`
  - Tool call used unsupported `rb` old-function/new-function shape instead of `rb/function/name/body`.
  - `blitz_edit` declined: `unsupported_structural_op_minimal no_mutation=true use core/apply_patch or PI_BLITZ_TOOL_PROFILE=structural`.
  - Final file remained unwrapped.
  - Root cause class: model/tool-shape robustness gap in default route; should fail closed with clearer classification or guide provider toward supported shape.

This is provider-independent at scenario level, not one-provider variance. Same fixture class failed on both providers, with different exposed subcauses.

### Harness bugs

None found that invalidates survey results.

- Tokscale matched parser totals on all 32 runs.
- Raw artifacts and session JSONL exist for red rows.
- Core/blitz route truth preserved; no hidden core/apply_patch fallback counted as Blitz success.
- No side effects/timeouts.

Reporting caveat, not blocker: original provider summary reports median/min/max over all rows, including red rows. Triage token claims below use green rows only.

### Provider quirks

- OpenAI/Codex produced a high-token old/new `rb` call for structural-body. Tool correctly declined under minimal/default structural rules; result is red because scenario expected a successful body wrap.
- Zai produced compact supported structural `rb/function/name/body`; that made runtime tokens lower for red structural-body, but correctness failed. Exclude from positive token claims.
- Both providers handled seven other scenarios correctly, including exact edits, JSON+TS, TSX, docs, same-file multi, safety no-op, and structural-add-guard.

### Unsupported / not-run scope

- Claude, Gemini, Grok were not run. Reason in JSON: bounded row budget + auth stability not established; no auth repair attempted.
- No universal provider/language claim allowed from this survey.
- Survey covered two providers and eight scenarios only.

## Green-only token summary

Positive delta = Blitz used more runtime tokens than core. Red rows excluded.

| Provider/model | Green rows | Core tokens | Blitz tokens | Total delta | Median row delta | Min | Max | Blitz token wins |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `openai-codex/gpt-5.4-mini` | 7 | 10,740 | 12,986 | +20.9% | +22.0% | +15.1% | +23.5% | 0/7 |
| `zai/glm-4.5-air` | 7 | 13,568 | 16,112 | +18.8% | +11.1% | +3.1% | +58.4% | 0/7 |
| **Total** | **14** | **24,308** | **29,098** | **+19.7%** | — | — | — | **0/14** |

Interpretation:

- This survey does **not** prove token savings for green rows.
- The only negative row delta was Zai `structural-body` (-21.1%), but that row was red/product incorrect and is excluded.
- Current default Blitz path still pays overhead on simple/mixed/doc/TSX green rows.
- Token opportunity remains: make structural body correct with compact `rb`, shrink resident overhead, route simple rows to core when Blitz cannot beat core.

## Roadmap implications

1. Fix `bli-caly` before counting structural-body as green or using its token delta.
2. Add/keep green-only aggregate reporting for future survey summaries; red rows stay visible but cannot feed savings claims.
3. Keep simple-row token work focused on routing/overhead, not correctness-only wins.
4. Next provider expansion should run only after auth stability is preflighted; otherwise classify as unsupported/not-run, not failure.
5. Any future claim must name provider/model/profile/scenarios and exclude red rows.

## Closure criteria for `bli-05rl`

- Product bug filed: `bli-caly`.
- Classifications complete: product, harness, provider quirks, unsupported scope, token opportunities.
- Triage report written.
- No unresolved classification remains.
