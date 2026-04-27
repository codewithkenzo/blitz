# Research: compact edit ops vs core edit / fastedit-style payloads

## Question
What compact edit ops, schemas, and benchmark method give better token/speed behavior than core `edit` and fastedit-style marker payloads, without adding extra routing layers?

## Findings

1. `wrap_body` is strongest proven win for large structural edits.
   - Current repo has narrow `wrap_body` op in `src/cmd_apply.zig` and tests proving it preserves signature/body and parse-validates output.
   - Bench: 10KB `mediumCompute` wrap-body, `pi_blitz_wrap_body` = 85 provider output tokens / 65 tool-arg tokens vs core `edit` = 9,640 / 9,624, with 99.1% output-token savings and 99.3% arg-token savings. Generic `pi_blitz_apply.wrap_body` was slower and heavier at 202 / 168 tokens, so narrow tool beats generic router. [reports/structured-bench-results-2026-04-27.md](reports/structured-bench-results-2026-04-27.md), [reports/narrow-tools-bench-results-2026-04-27.md](reports/narrow-tools-bench-results-2026-04-27.md), [src/cmd_apply.zig](src/cmd_apply.zig)

2. `compose_body` / `multi_body` are the right shape for preserved-island multi-hunk edits, but current data shows correctness win more than savings win.
   - `compose_body` uses array segments: `{text}|{keep}` with `keep` either `"body"` or `{beforeKeep,afterKeep,includeBefore,includeAfter,occurrence}`. `multi_body` uses array of per-symbol ops. This is already a compact semantic IR compared with full-body rewrites or marker text.
   - Bench: `pi_blitz_compose_body` = 246 / 208 tokens, better than generic apply (281 / 247), but core comparator for this fixture was incorrect, so no savings-vs-core claim yet. `pi_blitz_multi_body` solved 3-edit same-file case; core used fewer tokens but missed golden, so again correctness win only. [src/cmd_apply.zig](src/cmd_apply.zig), [reports/narrow-tools-bench-results-2026-04-27.md](reports/narrow-tools-bench-results-2026-04-27.md), [reports/multibody-bench-smoke-2026-04-27.md](reports/multibody-bench-smoke-2026-04-27.md)

3. Tiny exact-span patches still favor core `edit`; do not force structured path.
   - `replace_body_span`/`insert_body_span` are good semantic ops, but current bench shows tiny unique tail edit still slightly cheaper on core: 60 / 44 tokens vs `pi_blitz_replace_body_span` 67 / 46.
   - Rule: route exact unique line patch to core. Use structured ops when core would need large span context, preserve islands, wrap bodies, or do same-file multi-hunk edits. [reports/structured-bench-results-2026-04-27.md](reports/structured-bench-results-2026-04-27.md), [reports/narrow-tools-bench-results-2026-04-27.md](reports/narrow-tools-bench-results-2026-04-27.md)

## Sources
- `src/cmd_apply.zig` — current structured op implementations: `replace_body_span`, `insert_body_span`, `wrap_body`, `compose_body`, `multi_body`, `insert_after_symbol`.
- `docs/fastedit-splice-algorithm.md` — fastedit-style deterministic splice notes, context-anchor / marker semantics.
- `bench/llm-pi.ts` — authentic Pi benchmark method: identical prompts, core vs blitz lane, session JSONL extraction, provider output/input/cost, tool-arg tokenization with `cl100k_base`.
- `bench/llm-tokens.ts` — token-comparison harness: core `{file,oldText,newText}` vs blitz `{file,replace|after,snippet}`, full-symbol / realistic / minimal baselines.
- `reports/structured-bench-results-2026-04-27.md` — narrow-tool results; wrap-body win, small exact-span loss, compose no core savings claim.
- `reports/narrow-tools-bench-results-2026-04-27.md` — narrow tools cut overhead vs generic apply.
- `reports/multibody-bench-smoke-2026-04-27.md` — multi_body correctness-only result.
- `reports/pi-matrix-general-summary-2026-04-27.md` — route-aware aggregate; Blitz wins only where structural edit needs it.

## Version / Date Notes
- Date observed: 2026-04-27.
- Bench results are model/provider specific (`openai-codex/gpt-5.4-mini` in reported runs). Re-run if model, tokenizer, or Pi tool routing changes.
- Generic `pi_blitz_apply` is already improved by narrow tools; claims about savings should prefer narrow-tool data, not generic apply data.
- Incorrect runs should count as zero savings. Do not compare against a wrong core baseline as if it were a win.

## Open Questions
- Need large, correct multi-body benchmark where core is also correct to prove `multi_body` token ROI, not just correctness.
- Need similar correct-core benchmark for `compose_body` on a bigger preserve-islands case.
- Need explicit measured comparison for tuple/array op schemas vs current object schemas; current repo only proves array-shaped `segments`/`edits` inside JSON objects, not a true tuple ABI.
- Need decide whether semantic op names should stay verbose (`wrap_body`) or collapse into denser tuple/enum forms for even lower tool-arg tokens.

## Recommendation
Ship narrow semantic tools first, not a generic router.

- Keep direct tools for `wrap_body`, `compose_body`, `multi_body`, `replace_body_span`, `insert_body_span`.
- Use tuple/array payloads only where they lower prompt overhead without losing strict validation, e.g. `edits: [...]` and `segments: [...]` already work well.
- For product routing: core `edit` for tiny exact unique patches; Blitz-style structured ops for wrap/preserve-islands/multi-hunk edits.
- Benchmark with correct-only rows, same prompt, same model, provider output + tool-arg tokens + wall time + cost, and mark incorrect runs as zero-savings.
