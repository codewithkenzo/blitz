# Lane F apply microbench evidence

Date (UTC): p95-releasefast-20260525-132131  
Binary: /home/kenzo/dev/blitz/zig-out/bin/blitz  
Iterations per dry-run case: 50  
Temp fixture dir: /tmp/blitz-apply-microbench-p95-releasefast-20260525-132131  
Artifacts dir: /tmp/blitz-lane-f-apply-microbench-p95-releasefast-20260525-132131

| Case | Command | Median wall ms | p95 wall ms | Status |
|---|---|---:|---:|---:|
| replace_return dry-run | `blitz apply --edit - --json --dry-run` | 2.000 | 3.865 | 0 |
| try_catch dry-run | `blitz apply --edit - --json --dry-run` | 1.802 | 2.405 | 0 |
| replace_return apply smoke | `blitz apply --edit - --json` | n/a | n/a | 0 |

Notes:
- All mutations happen under `/tmp/blitz-apply-microbench-p95-releasefast-20260525-132131`.
- Dry-run requests include JSON `options.dryRun=true` plus CLI `--dry-run`.
- p95 uses nearest-rank over numeric ascending sample files: rank = ceil(0.95 * N).
- Last JSON/stdout and stderr artifacts are stored in `/tmp/blitz-lane-f-apply-microbench-p95-releasefast-20260525-132131`.
