# D5 Blitz matrix timeout continuation fix

Date: 2026-06-08
Branch: `feat/blitz-0.4-token-core-profile`

## Behavior change

`bench/pi-matrix.ts` keeps `--tokscale` strict when a session JSONL exists: `runTokScale()` still validates parser/Tokscale token totals and mismatches still throw.

When `--tokscale` is required but no session JSONL exists:

- If Pi run failed or timed out (`exitCode !== 0 || timedOut`), matrix no longer aborts.
- Row records empty Tokscale fields and detail `no session jsonl (run failed/timed out)`.
- Row failure stays visible through `exitCode`, `timedOut`, `correct=false`, and `failure`/row summary.
- If Pi run exits `0` with no session JSONL, harness still fails closed with `tokscale validation required but no session jsonl found`.

## Verification

- LSP/TS diagnostics: clean for `bench/pi-matrix.ts` after edit.
- Build: `bun build bench/pi-matrix.ts --target=bun --outfile=/tmp/pi-matrix-timeout-check.js` passed.
- Failure-path smoke: `bun bench/pi-matrix.ts --tokscale --pi-bin /bin/false --case medium-10k/wrap-body --lane core --iters 1 --runner spawn --keep-temp --json-out /tmp/pi-matrix-timeout-smoke.json --md-out /tmp/pi-matrix-timeout-smoke.md` passed. Output JSON row had `exitCodes: [1]`, `correctRate: 0`, null Tokscale metrics, and `tokScaleDetails: "no session jsonl (run failed/timed out)"`.
- Fail-closed smoke: `bun bench/pi-matrix.ts --tokscale --pi-bin /bin/true --case medium-10k/wrap-body --lane core --iters 1 --runner spawn --keep-temp` exited nonzero with `tokscale validation required but no session jsonl found`.

## Residual risk

No full matrix rerun performed. Smoke uses `/bin/false` and `/bin/true` to synthesize missing-session paths, not actual Pi timeout. Actual timeout path shares same guard via `r.timedOut`.
