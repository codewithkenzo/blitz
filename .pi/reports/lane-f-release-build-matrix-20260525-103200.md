# Lane F release build matrix evidence

Date (UTC): 20260525-103200  
Host: Linux x86_64  
Zig: 0.16.0  
Iterations per timing: 1  
Artifacts dir: /tmp/blitz-lane-f-release-build-matrix-20260525-103200

## Build matrix

| Label | Command | Status | Build ms | Binary bytes | Cold --version median ms | Doctor median ms | Notes |
|---|---|---:|---:|---:|---:|---:|---|
| `native-releasefast` | `zig build -Doptimize=ReleaseFast` | 0 | 76.386 | 11059360 | 1.377 | 3.420 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-103200/build-native-releasefast.log |
| `native-releasesmall` | `zig build -Doptimize=ReleaseSmall` | 0 | 67.689 | 5123424 | 1.244 | 3.262 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-103200/build-native-releasesmall.log |
| `x86_64-linux-musl-releasefast` | `zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast` | 0 | 56.976 | 11934624 | 1.083 | 3.176 | log: /tmp/blitz-lane-f-release-build-matrix-20260525-103200/build-x86_64-linux-musl-releasefast.log |

## C interop check

- Command: `grep -R --include='*.zig' -n '@cImport(' src build.zig`
- Result: none found

## Deferred evaluations

- Zig master/0.17-dev: not run by this script; optional until local toolchain exists and proves runtime or size win.
- `smp_allocator`: not enabled here. Repo AGENTS keeps Zig 0.16 stable and debug allocator/debug-safe policy; allocator switch needs isolated benchmark evidence before code change.
