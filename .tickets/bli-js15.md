---
id: bli-js15
status: closed
deps: []
links: []
created: 2026-06-20T06:32:52Z
type: task
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [pi-blitz, token-core, strict-gate]
---
# 0.5H demote structural rb from minimal default scope

## Acceptance Criteria

minimal/default claim scope excludes rb/structural-body unless strict supported tuple shape passes deterministic validation
unsupported/malformed rb shapes decline clearly
docs/.pi/reports/skills do not imply structural replacement in minimal profile
exact/simple/config/doc route remains default focus


## Notes

**2026-06-20T06:32:52Z**

start: preflight done. blitz branch feat/blitz-0.4-token-core-profile has preserved dirty .tickets/bli-pg9j.md + report farm; pi-blitz branch feat/blitz-0.4-token-core-profile-canonical has untracked .pi/research/. No model/provider telemetry allowed.

**2026-06-20T06:36:40Z**

decision: minimal/default blitz_edit now declines rb/ia structural aliases in minimal profile with unsupported_structural_op_minimal and no_mutation=true; exact/simple/config/doc/tiny multi remains default focus.

**2026-06-20T06:36:40Z**

verify: pi-blitz bun run check:tax && bun run typecheck && bun test && bun run build passed. Tax: minimal-schema 624/666, resident-skill 637/713, success-output 29/32, decline-output 71/80. Tests: 91 pass, 0 fail.

**2026-06-20T06:39:34Z**

verify: pi-blitz gates passed in main: bun run check:tax && bun run typecheck && bun test && bun run build; LSP errors 0 for src/tools.ts + test/tool-profiles.test.ts; git diff --check passed. pi-blitz commit 0e7c608 pushed. Blitz docs/ticket only; no Zig source touched, no model telemetry run.
