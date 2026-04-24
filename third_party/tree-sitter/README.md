# tree-sitter core

Vendored into `third_party/tree-sitter/`. Populated by ticket **d1o-qphx**.

## Target layout

```
third_party/tree-sitter/
├── lib/
│   ├── include/
│   │   └── tree_sitter/
│   │       └── api.h         ← public C header
│   └── src/
│       ├── lib.c             ← the unified C implementation
│       └── ...other internal .c/.h (tracked via lib.c includes)
└── LICENSE                    ← MIT
```

## Upstream

- Repo: https://github.com/tree-sitter/tree-sitter
- License: MIT
- Target version: latest stable release ≥ 0.24 (pin in commit message when vendored)

## build.zig integration

See `build.zig` for the static-link commented-out block. In short:
- `addCSourceFiles` with `files = &.{"lib.c"}`, `flags = &.{"-std=c11"}`
- `addIncludePath` on `third_party/tree-sitter/lib/include`
- `link_libc = true`
- link into `root_module`
