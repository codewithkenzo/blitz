# Research: Zig bleeding-edge perf for standalone CLI

## Question
What Zig 0.16 stable vs master/0.17-dev offers for build/runtime perf in a standalone CLI like Blitz 0.3?

## Findings
- **0.16 is already big CLI win**: `std.process.Init` + `std.Io` make app IO explicit; 0.16 makes all input/output go through an `Io` instance. `Io.Threaded` is feature-complete; `Io.Evented` exists but experimental. `std.testing.io` exists for tests. Sources: https://ziglang.org/download/0.16.0/release-notes.html , https://ziglang.org/documentation/master/
- **Build/dev cycle speed on master**: master docs say `zig build --watch -fincremental` is stable enough to use, and `--time-report`/`--webui` expose per-step compile timing. Devlog says LLVM incremental comp now works too. Sources: https://ziglang.org/devlog/2026/ , https://ziglang.org/learn/build-system/
- **Runtime/size knobs**: `Debug`, `ReleaseSafe`, `ReleaseFast`, `ReleaseSmall` remain core knobs; 0.16 build docs expose `standardOptimizeOption`, `--release`, and target/cpu controls. `ReleaseFast` + `smp_allocator` is Zig’s intended fast path; `ReleaseSmall` best for tiny distro binaries. Sources: https://ziglang.org/learn/build-system/ , https://ziglang.org/download/0.16.0/release-notes.html
- **Allocator + mmap gains**: 0.16 renamed `GeneralPurposeAllocator` to `DebugAllocator` and rewrote it for fewer mappings; `std.mem.Allocator.remap` + `mremap` landed earlier (0.14) for cheaper growth. Good for buffers/caches. Sources: https://ziglang.org/download/0.16.0/release-notes.html , https://ziglang.org/download/0.14.0/release-notes.html
- **Cross/static distro path**: Zig ships musl 1.2.5 source and builds static musl for selected targets; 0.16 support table is broad, with x86_64-linux tier 1 and many tier 2 targets. Good fit for static CLI release tarballs. Source: https://ziglang.org/download/0.16.0/release-notes.html
- **SIMD/mem search**: Zig still exposes SIMD vectors and optimizes with `ReleaseFast`; 0.16 mem API renamed “index of” to “find”. I found no first-class PGO workflow in official docs. Sources: https://ziglang.org/learn/overview/ , https://ziglang.org/download/0.16.0/release-notes.html
- **Master/0.17-dev extras**: devlog shows lazy field analysis (namespace types no longer drag unrelated fields), `zig libc` shares compilation unit for smaller/faster static libc, and `std.Io.Evented` io_uring/GCD implementations landed but still have perf caveats. Sources: https://ziglang.org/devlog/2026/

## Sources
- https://ziglang.org/download/0.16.0/release-notes.html
- https://ziglang.org/documentation/master/
- https://ziglang.org/learn/build-system/
- https://ziglang.org/devlog/2026/
- https://ziglang.org/download/0.14.0/release-notes.html
- https://ziglang.org/learn/overview/

## Version / Date Notes
- `master` docs page dated **2026-05-24**; treat as **0.17-dev / bleeding edge**. Source: https://ziglang.org/download/
- 0.16.0 released **2026-04-14** (release notes dated 2026-04-13/14). Source: https://ziglang.org/news/0.16.0-released/
- Devlog items used here are from **2026-01..05**; `std.Io.Evented` still marked experimental and one post calls out unresolved perf degradation. Source: https://ziglang.org/devlog/2026/

## Open Questions
- Any official PGO/PGO-like workflow in Zig 0.17-dev? I found LTO/time-report/watch, not PGO.
- Any real-world benchmark for Blitz-like CLI: 0.16 `ReleaseFast` vs `ReleaseSmall` vs master?
- Can Blitz tolerate `std.Io.Evented` perf risk, or stick with `Io.Threaded` for now?

## Recommendation
- **Blitz 0.3**: ship on **0.16 stable** unless you need incremental compile/watch or latest `std.Io` work.
- Build **dev** with `--watch -fincremental --time-report`; ship **prod** with `ReleaseFast` first, `ReleaseSmall` for tiny static distro build.
- Use `DebugAllocator` in debug/safe, `smp_allocator` in release, static **musl** for Linux release artifacts.
- Avoid `std.Io.Evented` in prod until perf caveat clears.
- Move any C interop to build system (`addTranslateC`) now; `@cImport` is deprecated in 0.16.
