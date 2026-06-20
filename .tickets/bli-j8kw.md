---
id: bli-j8kw
status: closed
deps: []
links: []
created: 2026-06-20T06:00:43Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-g, baseline, bench]
---
# 0.5G structural-body core baseline stability

Sprint F impact survey had Zai Blitz structural-body green but Zai core baseline red. Classify and stabilize core baseline prompt/fixture for structural-body so future comparisons are valid.

## Acceptance Criteria

Root cause recorded from artifacts. Harness/prompt/fixture fix or explicit caveat prevents ambiguous/unstable core baseline. Regression/self-check added where possible. No Blitz product behavior change unless evidence requires it.

## Notes

**2026-06-20T06:10:22Z**

start: preflight done. Implementation isolated in /home/kenzo/dev/blitz-bli-j8kw on tk/bli-j8kw-core-baseline. Root artifact: Zai core structural-body red used two exact edits at function start/end, leaving middle body unindented; classify/stabilize harness baseline, no Blitz product behavior unless artifact proves it.

**2026-06-20T06:14:07Z**

finding: Sprint F Zai core structural-body red artifact natural-edit-runs/structural-body__core__0__2026-06-20T05-42-46-674Z shows edit tool call tool-a95d0b1be8b44d299a23f6889b03d11e replaced only first block (function header + let total) and final block (return + brace). ToolResult succeeded, but final medium.ts lines 4-51 retained two-space 'total +=' indentation outside canonical try indentation. Classified as core prompt/fixture ambiguity, not Blitz product fault.

**2026-06-20T06:14:07Z**

verify: tightened structural-body prompt to require all original two-space statements become four spaces inside try and reject start/end-only edits; extended --self-check-prompt-shapes with structural prompt guard, canonical indentation guard, and start/end-only anti-pattern rejection. Pass: bun bench/natural-edit.ts --self-check-prompt-shapes; bun build bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js; git diff --check. No model runs; zig build skipped (bench TS prompt/self-check only).
