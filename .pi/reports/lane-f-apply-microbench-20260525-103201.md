# Lane F apply microbench evidence

Date (UTC): 20260525-103201  
Binary: /home/kenzo/dev/blitz/zig-out/bin/blitz  
Iterations per dry-run case: 1  
Temp fixture dir: /tmp/blitz-apply-microbench-20260525-103201  
Artifacts dir: /tmp/blitz-lane-f-apply-microbench-20260525-103201

| Case | Command | Median wall ms | Status |
|---|---|---:|---:|
| replace_return dry-run | `blitz apply --edit - --json --dry-run` | 1.806 | 0 |
| try_catch dry-run | `blitz apply --edit - --json --dry-run` | 1.673 | 0 |
| replace_return apply smoke | `blitz apply --edit - --json` | n/a | 0 |

Notes:
- All mutations happen under `/tmp/blitz-apply-microbench-20260525-103201`.
- Dry-run requests include JSON `options.dryRun=true` plus CLI `--dry-run`.
- Last JSON/stdout and stderr artifacts are stored in `/tmp/blitz-lane-f-apply-microbench-20260525-103201`.
