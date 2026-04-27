# Research: Blitz release path — Zig 0.17, tree-sitter C interop, npm prebuilts, Pi shipping, edit-tool comparators

## Question

Should Blitz move to Zig 0.17 now? What changes would materially improve token/correctness beyond current `wrap_body` and patch-style structured apply, and what should be deferred? Also: confirm tree-sitter C interop/static linking path, npm prebuilt binary package conventions, Pi extension shipping conventions, and comparable edit-tool patterns.

## Findings

1. **Do not move release branch to Zig 0.17 yet.**
   - Zig download page shows only `master` (dated 2026-04-26) and `0.16.0` as tagged release; no `0.17.0` tag is published yet. That means 0.17 is still moving target / master-line, not release-line. [https://ziglang.org/download/]
   - Zig devlog for 2026 shows ongoing master changes like type-resolution redesign, incremental compilation fixes, `std.Io` work, and package-management workflow tweaks; useful, but still master-only surface. [https://ziglang.org/devlog/2026/?20260213=]
   - Repo already pins `.zig-version` to `0.16.0` and docs/AGENTS say stay on Zig 0.16.0 stable. `[.zig-version]`, `[AGENTS.md]`, `[README.md]`.

2. **Tree-sitter integration is already aligned with 0.16-style static linking and should stay that way for release.**
   - `build.zig` statically links vendored `tree-sitter` C core and each grammar `.c` file through `root_module.addCSourceFile`, `addIncludePath`, `link_libc = true`, and `linkLibrary(...)`. `[build.zig]`
   - `docs/tree-sitter-c-api-subset.md` defines a tiny extern-only C ABI surface (no `@cImport`) for parser/tree/query/node APIs. That matches 0.16 release guidance in repo docs that `@cImport` is future-deprecated. `[docs/tree-sitter-c-api-subset.md]`, `[docs/blitz.md §4.3]`
   - Benefit: single static binary, no runtime C deps, deterministic ABI boundary, easy cross-compile. Risk: any tree-sitter C API or grammar drift must be tracked by vendored tags + CI matrix. `[build.zig]`, `[docs/blitz.md §4.3]`

3. **Biggest token/correctness wins come from narrow structured ops, not from bigger `patch`/`wrap_body`.**
   - Current measured results show `pi_blitz_wrap_body` on a 10KB body edit cut provider output tokens from 9,640 to 85 and tool-arg tokens from 9,624 to 65 vs core `edit` (99%+ savings) while staying correct. `[reports/narrow-tools-bench-results-2026-04-27.md]`
   - Same report says generic `pi_blitz_apply.wrap_body` was worse than narrow `pi_blitz_wrap_body`; narrower tool surface materially reduced prompt/arg overhead. `[reports/narrow-tools-bench-results-2026-04-27.md]`
   - For small exact tail edits, core `edit` still wins. So Blitz should target structural edits that preserve large spans, not replace core text patching universally. `[reports/structured-bench-results-2026-04-27.md]`

## Sources

### Repo-local
- `README.md` — current product summary, install notes, 0.16 pin.
- `AGENTS.md` — repo rules: stay on Zig 0.16.0 stable, no `@cImport` for new code.
- `build.zig` — static tree-sitter + vendored grammars link path.
- `docs/blitz.md` — release spec, Zig 0.16 alignment, Pi extension shape, benchmark policy.
- `docs/tree-sitter-c-api-subset.md` — extern-only tree-sitter ABI subset.
- `docs/fastedit-splice-algorithm.md` — fastedit-style relative-indent / patch / fallback behavior reference.
- `src/cmd_apply.zig` — current apply op surface; `replace_body_span`, `insert_body_span`, `wrap_body` implemented; `compose_body`, `insert_after_symbol`, `multi_body` still stubbed unsupported in current code path.
- `reports/apply-ir-impl-summary.md` — structured apply slice summary.
- `reports/structured-bench-results-2026-04-27.md` — authenticated wrap-body and small-edit comparisons.
- `reports/narrow-tools-bench-results-2026-04-27.md` — narrow tool vs generic apply delta.
- `reports/patch-payload-synthetic-2026-04-27.md` — synthetic patch payload savings.

### Official / upstream URLs
- Zig download page: https://ziglang.org/download/
- Zig 0.16 release notes: https://ziglang.org/download/0.16.0/release-notes.html
- Zig 2026 devlog: https://ziglang.org/devlog/2026/?20260213=
- tree-sitter C API docs source referenced by repo: https://raw.githubusercontent.com/tree-sitter/tree-sitter/master/lib/include/tree_sitter/api.h
- Aider splice reference: https://raw.githubusercontent.com/Aider-AI/aider/main/aider/coders/search_replace.py
- Continue lazy replace reference: https://raw.githubusercontent.com/continuedev/continue/main/core/edit/lazy/replace.ts
- ast-grep scan docs: https://ast-grep.github.io/reference/cli/scan.html
- Coccinelle semantic patches: https://coccinelle.gitlabpages.inria.fr/website/sp.html
- npm package metadata:
  - esbuild 0.28.0: https://registry.npmjs.org/esbuild/0.28.0
  - @biomejs/biome 2.4.13: https://registry.npmjs.org/@biomejs/biome/2.4.13
  - rolldown 1.0.0-rc.17: https://registry.npmjs.org/rolldown/1.0.0-rc.17

## Version / Date Notes

- Repo date context: 2026-04-27.
- Zig: 0.16.0 is current tagged release; master build on download page is dated 2026-04-26. No 0.17 tag yet. [https://ziglang.org/download/]
- npm prebuilt examples reflect current versions at research time: esbuild 0.28.0, Biome 2.4.13, Rolldown 1.0.0-rc.17.
- Blitz docs contain a few future-facing design claims (e.g. `compose_body`, `insert_after_symbol`) that are not fully implemented in current `src/cmd_apply.zig`; treat spec/report mismatch as a drift warning.
- Bench numbers are point-in-time and task-specific; do not generalize beyond handled cases.

## Open Questions

1. When should Blitz re-baseline on Zig 0.17 master? Only after a tagged 0.17 release, or earlier on a side branch?
2. Which structured ops should ship first if `compose_body`/`insert_after_symbol` remain stubs: `replace_body_span`, `insert_body_span`, `wrap_body`, or a narrower `multi-hunk compose`?
3. Do we want a `pi_blitz_apply` umbrella tool, or only narrow tools? Bench data suggests narrow tools reduce token overhead.
4. For unsupported languages, should fallback payload stay text-only or move to JSON IR sooner?
5. Which Pi extension install story is acceptable for alpha: source-build local binary first, or platform prebuilts first?

## Recommendation

- **Stay on Zig 0.16 for release branch.** 0.17 is not tagged yet and master is still moving; benefits are real but not release-stable. Use 0.17 only in exploratory branch after CI passes and tree-sitter static link remains clean.
- **Ship narrow structured ops first.** Highest value: `replace_body_span`, `insert_body_span`, `wrap_body`, and a real `compose_body`/preserve-islands path. These are the strongest token/correctness multipliers for large-symbol edits.
- **Defer fuzzy/semantic extras until structured ops are solid.** Fuzzy recovery ladders, broad multi-file editing, and general structural query rewrite should wait until single-file structured ops pass reliable benchmarks and parse-clean gates.
- **Keep tree-sitter static-link + extern ABI.** It fits single-binary release goals and avoids `@cImport` churn.
- **Use npm optionalDependencies platform packages.** That is the dominant pattern in esbuild/Biome/Rolldown and fits Blitz prebuilt binaries.
