# Lane F apply microbench evidence

Date (UTC): p95-final-20260525-132013  
Binary: /home/kenzo/dev/blitz/zig-out/bin/blitz  
Iterations per dry-run case: 30  
Temp fixture dir: /tmp/blitz-apply-microbench-p95-final-20260525-132013  
Artifacts dir: /tmp/blitz-lane-f-apply-microbench-p95-final-20260525-132013

| Case | Command | Median wall ms | p95 wall ms | Status |
|---|---|---:|---:|---:|
| replace_return dry-run | `blitz apply --edit - --json --dry-run` | 9.839 | 10.979 | 0 |
| try_catch dry-run | `blitz apply --edit - --json --dry-run` | 9.876 | 10.962 | 0 |
| replace_return apply smoke | `blitz apply --edit - --json` | n/a | n/a | 0 |

Notes:
- All mutations happen under `/tmp/blitz-apply-microbench-p95-final-20260525-132013`.
- Dry-run requests include JSON `options.dryRun=true` plus CLI `--dry-run`.
- p95 uses nearest-rank over numeric ascending sample files: rank = ceil(0.95 * N).
- Last JSON/stdout and stderr artifacts are stored in `/tmp/blitz-lane-f-apply-microbench-p95-final-20260525-132013`.
