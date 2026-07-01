# AGENTS.md — bench

Bench harness rules for Blitz token/context measurement. Read `../AGENTS.md` first.

## Purpose

`.pi/bench/` contains Bun/TypeScript benchmark harnesses, fixtures, token accounting, Pi matrix runners, and regression thresholds.

## Skills to load

- `.pi/skills/blitz-benchmarking` — required before editing `.pi/bench/pi-matrix.ts`, running Pi/tmux rows, writing reports, or making token-savings claims.
- `kenzo-bun` — Bun runtime/script patterns when editing TypeScript harness code.

## Commands

```bash
bun .pi/bench/run.ts                    # local benchmark harness
bun .pi/bench/llm-tokens.ts             # LLM/token accounting helper
bun .pi/bench/pi-matrix.ts              # Pi matrix runner; prefer documented tmux mode for locked runs
bun .pi/bench/pi-matrix.ts --tokscale   # Tokscale validation when method requires it
```

Also run root gates when Zig behavior changes:

```bash
zig build
zig build test
```

## Token benchmark rules

- NEVER claim token savings from wall time, byte size, or intuition.
- Token reports must include: resident tool schema, resident skill text, prompt/input/cache, tool args, model output, result payload, total model-visible context.
- Locked rows require real Pi artifacts, correctness status, wall time, tokenizer metadata, raw run dirs, and Tokscale residual reconciliation.
- Preserve failed attempts separately from accepted rows. Do not overwrite baselines unless explicitly asked.
- Simple/tiny edit rows matter most for Blitz 0.4; structural-only wins do not prove core-edit replacement.
- If Blitz loses tokens, report route fallback to core/apply_patch or explain correctness need.

## Files

- `pi-matrix.ts` — primary real Pi matrix runner.
- `llm-tokenizer.ts`, `llm-tokens.ts` — tokenizer/accounting helpers.
- `patch-payloads.ts` — edit payload comparisons.
- `fixtures/`, `fixtures-llm/` — benchmark fixtures; keep deterministic.
- `regression-thresholds.json` — thresholds; update only with evidence.

## Anti-patterns

- No unverified “savings” language.
- No benchmark-only router behavior presented as product runtime behavior.
- No deleting raw tmux/Pi run artifacts to make reports cleaner.
- No broad fixture churn mixed with harness logic changes.
