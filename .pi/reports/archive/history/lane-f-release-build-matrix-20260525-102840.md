# Lane F release build matrix evidence

Date (UTC): 20260525-102840  
Host: Linux x86_64  
Zig: 0.16.0  
Iterations per timing: 3  
Artifacts dir: /tmp/blitz-lane-f-release-build-matrix-20260525-102840

## Build matrix

| Label | Command | Status | Build ms | Binary bytes | Cold --version median ms | Doctor median ms | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| `native-releasefast` | `zig build -Doptimize=ReleaseFast` | 0 | 79.197 | 11059360 | 1.320 | 3.338 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-102840/build-native-releasefast.log |
| `native-releasesmall` | `zig build -Doptimize=ReleaseSmall` | 0 | 78.446 | 5123424 | 1.195 | 3.273 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-102840/build-native-releasesmall.log |
| `x86_64-linux-musl-releasefast` | `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast` | 0 | 61.127 | 11934624 | 1.068 | 3.238 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-102840/build-x86_64-linux-musl-releasefast.log |

## C interop check

- Command: `grep -R --include='*.zig' -n '@cImport(' src build.zig`
- Result: none found

## Deferred evaluations

- Zig master/0.17-dev: not run by this script; optional until local toolchain exists and proves runtime or size win.
- `smp_allocator`: not enabled here. Repo AGENTS keeps Zig 0.16 stable and debug allocator/debug-safe policy; allocator switch needs isolated benchmark evidence before code change.
