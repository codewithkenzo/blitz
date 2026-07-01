---
id: bli-h3ta
status: closed
deps: []
links: []
created: 2026-06-20T06:00:43Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-g, tokens, tiny, pi-blitz, bench]
---
# 0.5G tiny exact break-even optimization

OpenAI tiny exact improved but remains +2.1% worse. Find last-mile prompt/schema/tool-arg/output savings so tiny simple rows beat or tie core under route-budget guard.

## Acceptance Criteria

Deterministic guard/report shows tiny exact route budget beats or ties core target, or documents irreducible floor with next concrete levers. No safety weakening; schema/skill/output guards remain passing.


## Notes

**2026-06-20T06:18:10Z**

start: preflight done. Blitz worktree /home/kenzo/dev/blitz-bli-h3ta and pi-blitz worktree /home/kenzo/dev/pi-blitz-bli-h3ta. Target OpenAI tiny exact +2.1%: Sprint F artifact shows Blitz lower output (50 vs core 58) but higher input (1540 vs 1500), so optimize input/schema/skill/prompt overhead without model reruns.

**2026-06-20T06:21:35Z**

finding: implemented deterministic input-visible overhead cuts without model reruns. pi-blitz tk/bli-h3ta-tiny-exact commit e94a904 trims minimal schema 690->666 bytes (-24) and resident skill 781->713 bytes (-68), locks tax caps to new floor; success/decline outputs unchanged 29/71. .pi/bench/natural-edit Blitz preamble 440->366 bytes (-74), tiny-exact Blitz prompt 895->821 bytes (-74), required safety phrases still pass.

**2026-06-20T06:21:35Z**

verify: pi-blitz pass: bun run check:tax (schema 666/666, skill 713/713, success 29/32, decline 71/80), bun run typecheck, bun test, bun run build. blitz pass: bun .pi/bench/natural-edit.ts --self-check-route-budget (deterministic floor recorded: coreBytes 890, blitzBytes 2312, residentBytes 1379, outputBytes 112, deltaBytes +1422, selected core), bun .pi/bench/natural-edit.ts --self-check-prompt-shapes (preamble 366, tiny prompt 821, safety checks pass), bun build .pi/bench/natural-edit.ts --target=bun --outfile=/tmp/natural-edit-check.js, git diff --check. zig build skipped: .pi/bench/docs only.

**2026-06-20T06:21:35Z**

done: deterministic overhead reduced by 166 visible bytes across pi-blitz schema/skill and Blitz preamble. Conservative route-budget guard still documents irreducible resident-schema floor rather than claiming break-even; next levers for bli-4tbc/future: lazy/discoverable resident skill, provider-side tool schema caching/accounting split, profile-specific skill omission for minimal exact rows, or core route for tiny exact until resident overhead disappears. No raw model runs/provider-wide runs.
