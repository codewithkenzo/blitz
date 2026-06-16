---
id: bli-pg9j
status: open
deps: []
links: []
created: 2026-06-15T18:38:10Z
type: task
priority: 1
assignee: Kenzo
tags: [blitz, benchmark, goal-mq9zabo4]
---
# Stabilize natural edit harness equivalence and Zai focused smokes


## Notes

**2026-06-15T18:38:16Z**

start: continuing Goal mq9zabo4. Loaded blitz benchmark skill and tmux/Tokscale method. Current uncommitted slice is bench/natural-edit.ts prompt/golden remediation plus preserved Zai focused smoke reports; structural-add-guard still format-variant unstable (block vs one-line guard) and blitz can timeout.

**2026-06-15T18:39:33Z**

finding: current natural harness has 25 natural + 22 adversarial scenarios. Focused Zai reruns after prompt/golden remediation show import-order/no-op-format/idempotent pass, structural-body pass, but structural-add-guard is format-variant unstable and import-removal blitz still has blank-line/space regression; import-insertion blitz had a timeout attempt. Spawned D5 0576c8f8 to add explicit alternate expected-output evidence for fair variants without global whitespace loosening.

**2026-06-15T18:43:07Z**

verify: d5 subagent added explicit per-file afterAlternates support in bench/natural-edit.ts, structural-add-guard block-guard alternate only, JSON/MD matchedExpected evidence, self-check --self-check-alternates passed, bun build passed. No commit.

**2026-06-15T18:43:12Z**

verify: bun build bench/natural-edit.ts passed after alternate-output harness changes; --self-check-alternates exits 0 and shows canonical + block-guard accepted while bad whitespace regression rejected. Focused Zai structural-add-guard now accepted both lanes with Tokscale match true; focused import-removal remains failing both lanes due extra blank/space inside run body or leading blank line, so needs prompt/route remediation next.

**2026-06-15T18:45:07Z**

handoff: spawned D5 ce3556ad to remediate import-removal prompt/scenario only. Focused smokes now passing both lanes with Tokscale match: structural-add-guard, import-insertion, import-order, no-op-format-already. Import-removal remains the only known focused Zai prompt-remediation failure before rerunning full natural matrix.

**2026-06-15T18:49:34Z**

verify: latest focused Zai import-removal smoke reports both lanes accepted=true with Tokscale match true at reports/natural-edit-harness/natural-edit-2026-06-15T18-48-45-644Z.json. All previously focused remediated rows now have green focused smokes: structural-add-guard, import-insertion, import-removal, import-order, no-op-format-already, no-op-idempotent.

**2026-06-15T18:49:50Z**

verify: import-removal prompt remediated. Build passed. Focused Zai import-removal report reports/natural-edit-harness/natural-edit-2026-06-15T18-48-45-644Z.json accepted both lanes, Tokscale match true; no alternate added and known whitespace regression remains rejected in prior artifacts.

**2026-06-15T18:57:51Z**

full natural Zai matrix after focused remediation: latest report reports/natural-edit-harness/natural-edit-2026-06-15T18-50-07-578Z.json has 47/50 accepted. Remaining failures: structural-body/blitz timeout no mutation, same-file-doc-comments/blitz changed JSDoc close to **/ instead of */, structural-loop-body/blitz no-op. Core accepted 25/25. Blitz accepted 22/25 and accepted-row token total still worse than core, so correctness remediation is next before route/token work.

**2026-06-15T19:02:48Z**

finding: D5 1d0efeae fixed structural-body and structural-loop-body focused Zai smokes, but same-file-doc-comments still fails Blitz after two prompt attempts (first invalid **/ delimiter, second left return beta unchanged). Spawned D5 9d03d6fb for one final exact-two-text-updates natural prompt attempt; no matching loosening allowed.

**2026-06-15T19:06:16Z**

verify: line-comment remediated same-file-doc-comments focused Zai smoke now passes both lanes with Tokscale match true (latest reports natural-edit-2026-06-15T19-05-34-662Z and T19-05-14). Running full natural Zai matrix next to verify 50/50.

**2026-06-15T19:15:41Z**

full natural Zai rerun after line-comment change regressed to 43/50 accepted at reports/natural-edit-harness/natural-edit-2026-06-15T19-06-21-966Z.json. Failures: structural-body/blitz timeout, no-op-idempotent/core timeout despite correct file, same-file-doc-comments/blitz no-op, structural-add-guard/blitz double-quote guard, structural-loop-body/blitz no-op, import-insertion/core imported formatTitle from ./render, local-helper-rename/blitz renamed definition but not use. Several had focused greens, so next slice must separate stochastic timeout/tool-choice variance from prompt/golden issues.

**2026-06-15T20:41:46Z**

Full natural Zai after restored alternates: reports/natural-edit-harness/natural-edit-2026-06-15T20-27-20-767Z.json accepted 43/50; core 25/25, blitz 18/25. Blitz failures: same-file-multi no-op/incomplete, structural-body timeout no mutation, structural-loop-body no-op, import-insertion no-op, import-removal whitespace/blank-line drift, import-order duplicate alpha/missing zed timeout, no-op-format-already syntax drift. Focused smokes before full were green for structural-add-guard, same-file-doc-comments, import-insertion, local-helper-rename.

**2026-06-15T20:50:10Z**

Interrupted D5 0df4c272 after focused smoke loop appeared stalled/no process while subagent stayed running. Partial changes: blitz bench/natural-edit.ts restored alternates/reporting; pi-blitz src/tools.ts minimal blitz_edit description clarified. Local verification after interrupt passed: blitz build, self-check-alternates, git diff --check, pi-blitz typecheck/test/build. Focused after partial change: structural-loop-body blitz 1/1; same-file-multi 0/1; structural-body 0/1 timeout; import-insertion 0/1 timeout. Need continue with narrower remediation.

**2026-06-16T00:41:16Z**

verify: after prompt/tool-stop clarification, focused Zai smokes pass with Tokscale match for structural-add-guard blitz, import-removal core, and import-removal blitz (reports natural-edit-2026-06-16T00-40-47/52/58Z). Running full natural Zai matrix next.

**2026-06-16T00:49:27Z**

verify: latest full natural Zai improved to 49/50 accepted (report natural-edit-2026-06-16T00-41-20-671Z); only same-file-multi blitz missed closing brace. Prompt clarified closing-brace replacement; focused same-file-multi blitz now accepted with Tokscale match at natural-edit-2026-06-16T00-48-58-875Z. Running full natural Zai again.

**2026-06-16T00:56:10Z**

verify: full natural Zai matrix is now 50/50 accepted/correct with Tokscale match 50/50 at reports/natural-edit-harness/natural-edit-2026-06-16T00-49-32-836Z.json. Core 25/25, blitz 25/25; no timeouts. Token accounting still shows blitz visibleTotal 73631 vs core 54725, so this is correctness-only remediation, not route/token win.

**2026-06-16T00:59:33Z**

handoff: spawned D5 322e8a36 in /home/kenzo/dev/pi-blitz to implement atomic batched blitz_edit with rollback semantics, tests, typecheck/test/build, commit+push. Main will avoid running Pi benchmarks against pi-blitz dist while that builder may mutate dist.

**2026-06-16T01:00:29Z**

finding: adversarial harness currently has 22 scenarios / 44 rows per provider across required safety categories (ambiguous anchors, no-op/idempotence, stale context, path traversal/symlink, repeated matches, generated/minified, unsupported refactors, conflicting edits, prompt/schema attacks, huge/case-collision). No adversarial reports have been run yet.

**2026-06-16T01:06:26Z**

verify: D5 completed pi-blitz atomic batched blitz_edit slice: commit 42ff677e pushed to origin/feat/blitz-0.4-token-core-profile; typecheck/test/build pass. Atomicity: preview all safe units, snapshot touched files under sorted locks, sequential apply without nested locks, rollback snapshots on later failure; no core/apply_patch fallback.

**2026-06-16T01:17:18Z**

handoff: spawned D5 f0bb8592 in /home/kenzo/dev/blitz to add/remediate default route/adversarial safety lane in natural-edit harness. Context: adversarial minimal/core run natural-edit-2026-06-16T01-12-29-187Z only 19/44 accepted; NUL escaping dirty change prevents adv-binary-ish spawn crash; D5 may keep/improve/revert policy and should commit/push verified route-lane slice.

**2026-06-16T01:24:42Z**

review: reviewer ebcc438b failed acceptance parse but produced concrete atomicity blockers for pi-blitz 42ff677: hard later apply exceptions/timeouts skip rollback after snapshots; rollback-failure output overclaims restored all files; tests mock orchestration more than real same/cross success semantics. Treat atomicity as not fully benchmark-safe until remediated.

**2026-06-16T01:25:12Z**

handoff: spawned D5 9426da2c in /home/kenzo/dev/pi-blitz to remediate reviewer atomicity blockers: hard apply exceptions/timeouts rollback, truthful rollback-failure output, stronger same/cross/rollback tests, typecheck/test/build, commit+push.

**2026-06-16T01:29:09Z**

verify: default route adversarial Zai lane passed 22/22 accepted/correct with Tokscale match 22/22 at reports/natural-edit-harness/natural-edit-2026-06-16T01-25-55-558Z.json. Route profile/tools recorded as pi_blitz_route_edit/router via /home/kenzo/dev/pi-blitz/dist/index.js; route outcome breakdown decline=22, blitz=0, fallback=0. NUL prompt escaping prevents adv-binary-ish spawnSync crash.

**2026-06-16T01:29:25Z**

route evidence: D5 f0bb produced Zai adversarial route report reports/natural-edit-harness/natural-edit-2026-06-16T01-25-55-558Z.json: 22/22 accepted, 22/22 correct, 22/22 Tokscale match; visible profile pi_blitz_route_edit/router from /home/kenzo/dev/pi-blitz/dist/index.js; route counts decline=22, fallback=0. Needs integration/commit and interpretation: safety pass, but all-decline means no Blitz-success subset for adversarial.

**2026-06-16T01:32:58Z**

landed: committed+pushed Blitz adversarial route lane slice in /home/kenzo/dev/blitz. Commit adds route lane/tool provenance/session probing and preserves Zai adversarial route report reports/natural-edit-harness/natural-edit-2026-06-16T01-25-55-558Z.json plus 22 raw route run dirs. Verification: diff check+bench build passed; report audit 22/22 accepted, 22/22 correct, 22/22 Tokscale match, route decline=22, fallback=0, visible pi_blitz_route_edit/router.

**2026-06-16T01:33:17Z**

landed: pi-blitz atomicity remediation completed by D5 9426da2c. Commit ea515e5 pushed to origin/feat/blitz-0.4-token-core-profile: hard batch failures roll back, rollback-failure output truthful, strengthened tests. Verification reported passed: typecheck, package tests, build, blitz smoke, focused apply-runtime tests. Main verified local HEAD and remote both ea515e5.

**2026-06-16T01:37:22Z**

provider evidence: openai-codex gpt-5.4-mini adversarial route full run reports/natural-edit-harness/natural-edit-2026-06-16T01-34-36-097Z.json: 22 rows, 22 correct, 22 Tokscale match, but only 17 accepted. Five rows selected routeOutcome=blitz with pi-blitz blitz-error UNSUPPORTED_OPERATION despite no mutation/correct safety outcome: adv-noop-idempotent-1/2, adv-stale-context-1, adv-generated-minified-1, adv-incomplete-intent-1. This is route product/accounting remediation input; preserve failed artifacts.

**2026-06-16T01:38:20Z**

landed: committed+pushed failed GPT-5.4-mini adversarial route evidence in /home/kenzo/dev/blitz as 371f910b reports: preserve mini adversarial route failure. Preserves report reports/natural-edit-harness/natural-edit-2026-06-16T01-34-36-097Z.json and 22 raw route dirs: 22 correct/22 Tokscale, 17 accepted, 5 unsupported-operation routeOutcome=blitz failures. D5 39c78f99 is remediating pi-blitz route unsupported/no-op behavior.

**2026-06-16T01:39:17Z**

reviewer 3b7dd57b audit result: pi-blitz atomicity remediation passes. Route raw JSON/JSONL counters pass, but Scope B blocking report-honesty issues: top-level report toolProfile says full while route row provenance says router; MD Results table displays scenario outcome noop instead of actual routeOutcome decline. Need fix report writer/regenerate affected route reports before relying on artifacts.

**2026-06-16T01:40:58Z**

fixed reviewer report-honesty blockers in blitz: bench/natural-edit.ts now derives top-level toolProfile from observed row provenance and ScenarioResult dominant routeOutcome from iteration routeOutcome counts. Patched preserved Zai and GPT-5.4-mini route reports: top toolProfile=router; MD Results table shows actual routeOutcome (Zai decline; mini decline/blitz). Verified git diff --check and bun build bench/natural-edit.ts.

**2026-06-16T01:41:38Z**

landed: committed+pushed route report accounting fix 5ee1897a. Fixes top-level toolProfile derivation and ScenarioResult routeOutcome aggregation; patched preserved Zai and GPT-5.4-mini route reports. Verification: both reports top profile=router; MD Results route values match JSON; diff check and bench build passed.

**2026-06-16T01:45:14Z**

landed/verified: pi-blitz route unsupported/no-write remediation completed by D5 39c78f99. Commit 3dd5063 pushed to origin/feat/blitz-0.4-token-core-profile: unsupported compact aliases and UNSUPPORTED_OPERATION no-write errors become explicit route decline/noop with no internal core/apply_patch fallback. D5 verification passed typecheck/tests/build and focused 5 bad GPT-5.4-mini route scenarios. Main reran full GPT-5.4-mini adversarial route: reports/natural-edit-harness/natural-edit-2026-06-16T01-42-53-372Z.json = 22/22 accepted, 22/22 correct, 22/22 Tokscale match, decline=22, fallback=0, visible pi_blitz_route_edit/router.
