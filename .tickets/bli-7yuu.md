---
id: bli-7yuu
status: closed
deps: []
links: [bli-caly]
created: 2026-06-20T04:59:33Z
type: bug
priority: 0
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-f, structural, pi-blitz]
---
# 0.5F structural-body default route fix

Implement product fix for provider-independent structural-body survey red, linked to bli-caly.

## Acceptance Criteria

Default/minimal structural-body fixture passes for supported rb/function/name/body shape; OpenAI old/new rb shape either normalizes safely or declines with provider/classification reason; formatting expected output matches; focused Zai+GPT evidence or documented provider guard; no hidden fallback.


## Notes

**2026-06-20T05:01:30Z**

start: Sprint F structural-body default-route fix. Preflight: blitz branch feat/blitz-0.4-token-core-profile dirty .tickets/bli-pg9j.md + report farm; pi-blitz branch feat/blitz-0.4-token-core-profile-canonical dirty untracked research/. No blocked tickets. Scope: no benchmark/model reruns.

**2026-06-20T05:05:46Z**

done: pi-blitz commit 4c5b5aacef02d9ae20f8e349548a00c1a00893a4 fixes minimal rb function/name/body newline preservation and normalizes rb old/new whole-function shape to exact edit. Verification passed in /home/kenzo/dev/pi-blitz: typecheck, tests, build. LSP errors: 0 for src/tools.ts + test/tool-profiles.test.ts. No benchmark/model reruns.
