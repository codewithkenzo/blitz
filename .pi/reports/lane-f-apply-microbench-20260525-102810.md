# Lane F apply microbench evidence

Date (UTC): 20260525-102810  
Binary: /home/kenzo/dev/blitz/zig-out/bin/blitz  
Iterations per dry-run case: 5  
Temp fixture dir: /tmp/blitz-apply-microbench-20260525-102810  
Artifacts dir: /tmp/blitz-lane-f-apply-microbench-20260525-102810

| Case | Command | Median wall ms | Status |
|---|---|---:|---:|
| replace_return dry-run | `blitz apply --edit - --json --dry-run` | 1.485 | 0 |
| try_catch dry-run | `blitz apply --edit - --json --dry-run` | 1.499 | 0 |
| replace_return apply smoke | `blitz apply --edit - --json` | n/a | 0 |

Notes:
- All mutations happen under `/tmp/blitz-apply-microbench-20260525-102810`.
- Dry-run requests include JSON `options.dryRun=true` plus CLI `--dry-run`.
- Last JSON/stdout and stderr artifacts are stored in `/tmp/blitz-lane-f-apply-microbench-20260525-102810`.
