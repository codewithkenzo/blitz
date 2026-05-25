# Blitz v0.2 final CLI verification + micro-benchmark

Date: 2026-05-25
Commit baseline before commit: `main...origin/main` with final v0.2 apply failure-contract fixes staged after verification.
Binary: `zig-out/bin/blitz`

## Verification

Commands run after final apply failure-contract fixes:

```bash
zig build test
zig build
zig-out/bin/blitz --version
zig-out/bin/blitz doctor
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
```

Results:

- `zig build test` — pass
- `zig build` — pass
- `zig-out/bin/blitz --version` — `blitz 0.1.0-alpha.10`
- `zig-out/bin/blitz doctor` — pass; rust/typescript/tsx/python/go grammars ok
- `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast` — pass

## CLI smoke

Success path:

- Operation: `apply --json` compact `patch` with `replace_return`
- Result: `status:"applied"`, `operation:"patch"`
- File changed as expected: `return value + 1;`

Rejection path:

- Operation: `set_body` with invalid integer `edit.body`
- Result: exit `1`, structured JSON `status:"rejected"`, `code:"INVALID_FIELD"`
- File unchanged

## Local micro-benchmark

Command:

```bash
bun run bench
```

Output:

```text
# blitz vs core edit — correctness + micro-benchmark

Binary:    /home/kenzo/dev/blitz/zig-out/bin/blitz
Iterations per case: 5
Generated: 2026-05-25T04:18:04.673Z

Regression thresholds (direct lane): max wall 25ms, min savings 5%
Using thresholds from /home/kenzo/dev/blitz/bench/regression-thresholds.json if present.

| Lane   | Case                      | core (oldT+newT) | blitz (snippet+sym) | saved | %     | wall ms (median) |
|--------|---------------------------|------------------|---------------------|-------|-------|------------------|
| direct | small/wrap-try-catch      | 50               | 43                  | 7     | 14.0% | 1.8              |
| direct | medium/add-options-method | 332              | 197                 | 135   | 40.7% | 1.0              |
| direct | large/add-rate-limit      | 748              | 424                 | 324   | 43.3% | 1.7              |
| marker | marker/analyze-values     | 620              | 104                 | 516   | 83.2% | 1.3              |

Direct-swap aggregate: ~41.2% output-token reduction, median wall-time ~1.7ms / case.
Marker aggregate: ~83.2% output-token reduction, median wall-time ~1.3ms / case.
Overall aggregate: ~56.1% output-token reduction, median wall-time ~1.5ms / case.
PASS: benchmark regression gate satisfied.

Notes:
- Tokens are bytes/4 estimate, not real tokenizer output.
- Direct lane = full-body replace; marker lane = preserved-region splice.
- Wall-time excludes LLM round-trip; it is binary spawn + parse + write.
```

## Notes

- Benchmark is local deterministic micro-bench, not provider-token benchmark.
- Public claims should keep correctness and token categories separate.
