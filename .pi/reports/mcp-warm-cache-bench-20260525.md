# MCP warm cache bench — 2026-06-05T06:40:12.707Z

Command:

```bash
bun bench/scripts/mcp-warm-cache-bench.ts
```

Scope:

- Workspace: `/home/kenzo/dev/blitz`
- File: `README.md`
- Iterations: 25; first iteration dropped
- Cold: MCP subprocess with stateless Blitz CLI per call
- Warm: `BLITZ_MCP_WARM=1`; MCP-host doctor cache and bounded read cache keyed by same-fd SHA-256/content metadata fingerprint when safe pre/post fingerprints match, file is regular, input is within `BLITZ_MCP_WARM_MAX_HASH_BYTES`, and result is within `BLITZ_MCP_WARM_MAX_RESULT_BYTES`
- Mutation ops stayed stateless CLI fallback; no mutation result cache

Results:

| mode | operation | p50 ms | p95 ms |
|---|---:|---:|---:|
| cold | doctor | 3.133 | 3.568 |
| cold | read | 0.439 | 1.091 |
| warm | doctor | 0.110 | 0.185 |
| warm | read | 0.157 | 0.799 |

Conclusion: bounded MCP warm cache targets repeated safe `doctor` and `read` calls. Fingerprint guard reduces accidental stale reuse but is not a replacement for future same-fd daemon parsing under hostile concurrent writers. Rebenchmark larger safe-read files before default-on.
