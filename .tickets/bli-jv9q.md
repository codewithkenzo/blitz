---
id: bli-jv9q
status: open
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

blocker: GPT-5.4-mini alternate gate stopped on structural-3/core-optimized. Core baseline row caveated: final file hash mismatch, Tokscale mismatch, two edit calls observed. First edit failed on ambiguous oldText for append anchor; second edit mutated file but expected hash still mismatched. Artifacts: reports/pi-tmux-true-streak-structural-3-core-optimized-20260619-gpt54-mini.{json,md}; reports/pi-accounting-runs/20260619-gpt54-mini/structural-3-core-optimized/. No rerun performed.
