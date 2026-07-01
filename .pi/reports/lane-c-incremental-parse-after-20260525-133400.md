# Lane C incremental parse-after evidence

Date (UTC): 20260525-133400  
Fixture bytes: 103277  
Operation: `apply patch replace_return` dry-run on a single target near file start  
Iterations: 40

| Metric | Median ms | p95 ms |
|---|---:|---:|
| parseAfter phase | 11.000 | 13.000 |
| total wall | 25.000 | 28.000 |

Notes:
- Metrics are from Blitz JSON `metrics.phaseMs.parseAfter`; this exercises the incremental parse-after validation path for strict single-range apply ops.
- p95 uses nearest-rank over sorted samples.
- This is timing evidence only, not a semantic replacement for changed-range fail-closed tests.

Raw parseAfter samples: 14, 11, 12, 13, 11, 11, 12, 11, 11, 13, 11, 11, 11, 11, 11, 11, 11, 11, 12, 11, 12, 11, 12, 12, 11, 11, 13, 11, 11, 12, 12, 11, 12, 12, 11, 11, 11, 11, 11, 11
