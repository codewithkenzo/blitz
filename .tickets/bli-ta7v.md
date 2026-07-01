---
id: bli-ta7v
status: closed
deps: []
links: []
created: 2026-06-19T03:24:58Z
type: bug
priority: 1
assignee: Kenzo
tags: [blitz, 0.5, sprint-c, benchmark, core]
---
# Investigate Class C optimized core baseline lock failure


## Notes

**2026-06-19T03:25:07Z**

source: bli-o1pd rerun after k296. class-c-structural-10 core-optimized status=caveated; Tokscale matched; route edit; failed path structural-10.ts. Artifacts: .pi/reports/pi-tmux-true-streak-class-c-structural-10-core-optimized-20260619-rerun-after-k296.* and run root .pi/reports/current/pi-accounting-runs/20260619-replacement-gate-rerun-after-k296/class-c-structural-10-core-optimized. Gate stopped; no class-c blitz rerun in final lock.

**2026-06-19T03:46:26Z**

start: diagnosing class-c-structural-10 core-optimized rerun failure. Route=edit, Tokscale matched, structural-10.ts mismatch. Classify layer before any broad rerun.

**2026-06-19T03:49:08Z**

finding: classification B core-optimized prompt/tool-use bug. Artifact first edit oldText '+ 1' matched both node1 '+ 1' and node10 '+ 10', so edit refused first step while later steps succeeded; expected output was correct. Fix expands generated minimal spans until unique in current file, yielding '+ 1;' -> '* 2;' for Class C.

**2026-06-19T03:49:08Z**

verify: bun .pi/bench/true-streak.test.js passed; bun build .pi/bench/true-streak.ts --target=bun --outfile=/tmp/true-streak-check.js passed; focused class-c-structural-10 core-optimized row accepted with Tokscale match and expected/actual sha bf098d15725e76dd.
