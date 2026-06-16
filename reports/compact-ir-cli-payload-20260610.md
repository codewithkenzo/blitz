# Compact IR CLI payload/token benchmark-only evidence

Date: 2026-06-10
Status: benchmark-only CLI payload/token evidence; not product-real Pi/Tokscale evidence; not default-ready evidence.

## Method

Script: `bun bench/compact-ir-cli-payload.ts`
Command under test: `zig-out/bin/blitz apply --edit - --json`
Cases: representative `rb` replace-body and `ia` insert-after-symbol TypeScript fixtures created under `/tmp`.
Token count: repo-local `bench/llm-tokenizer.ts` rough cl100k payload token count. This is payload-only tokenizer evidence, not provider/Tokscale accounting.
Pi core comparison: equivalent `functions.edit`-style payload JSON bytes/tokens only. Core payloads were not executed here, no Pi session used, no Tokscale used.

## Results

| case | lane | req bytes | req tokens | output bytes | output tokens | correct | omits routeDecision/metrics/diffSummary |
|---|---|---:|---:|---:|---:|---|---|
| rb | compact_cli | 141 | 57 | 243 | 79 | true | true |
| rb | verbose_apply | 169 | 54 | 1121 | 323 | true | false |
| rb | pi_core_payload_only | 114 | 42 | n/a | n/a | not-run | n/a |
| ia | compact_cli | 138 | 49 | 251 | 81 | true | true |
| ia | verbose_apply | 200 | 59 | 1128 | 325 | true | false |
| ia | pi_core_payload_only | 197 | 61 | n/a | n/a | not-run | n/a |

## Fixture run details

### rb: replace body via compact rb/set_body

- Compact stdout: `{"ok":true,"status":"applied","op":"set_body","file":"/tmp/blitz-rb-payload-dNSnif/compact-rb.ts","symbol":"compact","changed":true,"parse":true,"ranges":{"targetStart":0,"targetEnd":63,"bodyStart":41,"bodyEnd":62,"editStart":41,"editEnd":62}}`
- Verbose output has bloat fields: routeDecision, metrics, diffSummary
- Compact output has bloat fields: none

### ia: insert after symbol via compact ia

- Compact stdout: `{"ok":true,"status":"applied","op":"insert_after_symbol","file":"/tmp/blitz-ia-payload-YYmUOU/compact-ia.ts","symbol":"first","changed":true,"parse":true,"ranges":{"targetStart":0,"targetEnd":38,"bodyStart":0,"bodyEnd":38,"editStart":38,"editEnd":38}}`
- Verbose output has bloat fields: routeDecision, metrics, diffSummary
- Compact output has bloat fields: none

## Caveats

- Benchmark-only CLI evidence: compact IR is measured through local Blitz CLI, not exposed as a product-real Pi tool route in `/home/kenzo/dev/pi-blitz`.
- No tmux matrix, provider run, Pi JSONL, or Tokscale validation occurred in this slice.
- Core row is payload-only JSON comparison for equivalent transformation, not executed core edit output or provider-visible session total.
- Default-ready/product-real Pi claims remain blocked until compact route is exposed in Pi, benchmarked with real Pi/tmux/Tokscale, and compared against core across accepted correct rows.

## Next step

Expose compact CLI IR through an explicit Pi route/tool in `/home/kenzo/dev/pi-blitz` only in a later authorized slice, then run true Pi/tmux/Tokscale compact-vs-core rows before any default-readiness claim.

