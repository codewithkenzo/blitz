# MCP warm cache bench — 2026-05-25T13:46:16.768Z

Command:

```bash
bun bench/scripts/mcp-warm-cache-bench.ts
```

Scope:

- Workspace: `/home/kenzo/dev/blitz`
- File: `README.md`
- Iterations: 75; first iteration dropped
- Cold: MCP subprocess with stateless Blitz CLI per call
- Warm: `BLITZ_MCP_WARM=1`; MCP-host doctor cache and read cache keyed by SHA-256 file bytes when file is regular and within `BLITZ_MCP_WARM_MAX_HASH_BYTES`
- Mutation ops stayed stateless CLI fallback; no mutation result cache

Results:

| mode | operation | p50 ms | p95 ms |
|---|---:|---:|---:|
| cold | doctor | 3.513 | 4.668 |
| cold | read | 0.646 | 1.656 |
| warm | doctor | 0.091 | 0.286 |
| warm | read | 0.131 | 0.685 |

Conclusion: bounded MCP warm cache targets repeated safe `doctor` and `read` calls. Rebenchmark larger safe-read files before default-on.
