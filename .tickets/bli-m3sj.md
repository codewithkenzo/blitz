---
id: bli-m3sj
status: open
deps: [bli-cca2, bli-91kk, bli-4aff, bli-1sab, bli-t3cl, bli-jv9q, bli-z13z]
links: []
created: 2026-06-19T06:41:57Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-d, benchmark, tokscale]
---
# 0.5D focused all edit-type lock run

Run one bounded all edit-type proof on zai/glm-4.5-air after plan and harness rows are ready.

## Acceptance Criteria

Paired core vs Blitz rows for all agreed edit classes have correctness, route truth, Tokscale match, resident schema/skill accounting, artifact manifest, and token deltas. Stop on systemic failure; no rerun fishing.


## Notes

**2026-06-19T06:52:47Z**

blocker: D5 closed bli-91kk with E06,E07,E10-E18 placeholders. Added deps bli-4aff and bli-1sab; do not run focused lock until placeholders are runnable or explicitly policy-blocked.

**2026-06-19T07:52:12Z**

start: focused Sprint D all edit-type lock run. One bounded run only; no rerun fishing. Preflight green; preserving preexisting .tickets/bli-pg9j.md/report farm.

**2026-06-19T07:54:46Z**

blocked: one bounded focused lock attempt stopped at first row tiny-10/core-optimized due provider usage limit before tool calls. No rerun. Created blocker bli-t3cl. Artifacts under reports/pi-accounting-runs/20260619-all-edit-type-lock/tiny-10-core-optimized and reports/pi-tmux-true-streak-tiny-10-core-optimized-20260619-all-edit-type-lock.{json,md}.

**2026-06-19T08:13:36Z**

still blocked: quota reset time has not passed; bli-t3cl remains open. No lock rerun performed.

**2026-06-19T08:16:51Z**

alternate gate start: user approved GPT-5.4-mini while Zai quota blocker bli-t3cl remains open. This is provider-scoped alternate evidence, not replacement for original Zai gate unless user accepts later. Artifacts use gpt54-mini suffix. Provider/model: openai-codex/gpt-5.4-mini; Pi args keep --thinking off via harness.

**2026-06-19T08:21:32Z**

alternate GPT-5.4-mini gate stopped on stop-rule at structural-3/core-optimized: core baseline incorrect + Tokscale mismatch. Created blocker bli-jv9q. Zai blocker bli-t3cl remains open. No rerun and no bli-hndl start.

**2026-06-19T19:01:29Z**

resume: Zai provider available again; bli-t3cl closed as external quota blocker. Running one bounded original Zai/glm-4.5-air focused gate with after-bli-t3cl artifact suffix. No rerun fishing.

**2026-06-19T19:05:48Z**

blocked: Zai after-bli-t3cl run completed provider rows, but validation found all-edit-types-gate reports identify scenario=tiny-10. Gate cannot pass because materialized E06/E07/E10/E11/E12 rows were not proven. Created blocker bli-z13z. No rerun and no claim audit.
