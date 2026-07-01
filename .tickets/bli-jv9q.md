---
id: bli-jv9q
status: closed
deps: []
links: []
created: 2026-06-19T08:21:24Z
type: task
priority: 0
assignee: Kenzo
tags: [blitz, 0.5, sprint-d, benchmark, blocker, gpt54-mini]
---
# 0.5D GPT alternate gate structural-3 core baseline failed


## Notes

**2026-06-19T08:21:32Z**

blocker: GPT-5.4-mini alternate gate stopped on structural-3/core-optimized. Core baseline row caveated: final file hash mismatch, Tokscale mismatch, two edit calls observed. First edit failed on ambiguous oldText for append anchor; second edit mutated file but expected hash still mismatched. Artifacts: .pi/reports/pi-tmux-true-streak-structural-3-core-optimized-20260619-gpt54-mini.{json,md}; .pi/reports/pi-accounting-runs/20260619-gpt54-mini/structural-3-core-optimized/. No rerun performed.

**2026-06-19T08:44:10Z**

fix contract: stabilize GPT-5.4-mini structural-3/core-optimized baseline. Diagnose artifact first. Preferred fix is prompt/harness row uniqueness: avoid ambiguous oldText append anchor, ensure expected output/hash and Tokscale parser account for exactly the attempted row. Add focused regression/self-check. Run focused structural-3/core-optimized only before any full GPT alternate rerun. Do not modify Blitz product behavior for this blocker unless artifact proves Blitz involved.

**2026-06-19T08:47:19Z**

fix: exactChangedSpan insertion anchors now expand backward to a unique suffix instead of using ambiguous closing brace line. Regression added for structural-3 append span: oldText is not '}\n', occurs once, and replacement produces expected output. Verification passed: self-check, build, bench/true-streak.test.js. Focused GPT row structural-3/core-optimized after-bli-jv9q accepted: correct=true, Tokscale match=true, tool=edit, status=accepted; artifacts .pi/reports/pi-tmux-true-streak-structural-3-core-optimized-20260619-gpt54-mini-after-bli-jv9q.{json,md}. Note model still split work after an initial batch miss, but parser/Tokscale matched and final file hash matched; original ambiguous anchor blocker removed.
