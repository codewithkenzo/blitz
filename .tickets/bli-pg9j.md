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

**2026-06-16T01:46:08Z**

landed: committed+pushed mini route remediation pass evidence. Latest blitz commit preserves focused five bad-row reruns and full GPT-5.4-mini adversarial route rerun reports/natural-edit-harness/natural-edit-2026-06-16T01-42-53-372Z.json: 22/22 accepted, 22/22 correct, 22/22 Tokscale match, decline=22, fallback=0, visible pi_blitz_route_edit/router. Report top profile and MD Results route accounting verified as router/decline.

**2026-06-16T01:49:48Z**

verified: GPT-5.5 adversarial route full run reports/natural-edit-harness/natural-edit-2026-06-16T01-46-21-353Z.json: 22/22 accepted, 22/22 correct, 22/22 Tokscale match, route decline=22, fallback=0, visible pi_blitz_route_edit/router, top profile router.

**2026-06-16T01:54:06Z**

natural route failure: GPT-5.4-mini natural route report reports/natural-edit-harness/natural-edit-2026-06-16T01-50-55-622Z.json has 25 rows, 25 Tokscale match, but only 3 accepted/3 correct. All routeOutcome=decline; mutation rows failed because model emitted common op alias , route declined as UNSUPPORTED_OPERATION/no internal fallback. This is product/schema/prompt remediation input; preserve artifacts.

**2026-06-16T01:54:13Z**

natural route failure detail: GPT-5.4-mini natural route report reports/natural-edit-harness/natural-edit-2026-06-16T01-50-55-622Z.json has 25 rows, 25 Tokscale match, but only 3 accepted/3 correct. All routeOutcome=decline; mutation rows failed because model emitted common op alias replace, route declined as UNSUPPORTED_OPERATION/no internal fallback. Product/schema/prompt remediation needed; artifacts preserved next.

**2026-06-16T01:55:27Z**

review passed: reviewer 09f5681f accepted route remediation evidence. Adversarial route artifacts for Zai, GPT-5.4-mini, GPT-5.5 all 22/22 accepted/correct/Tokscale, decline=22 fallback=0; caveat remains all-decline is safety evidence only, not Blitz-success/token-win evidence. Next audit should cover non-adversarial route Blitz-success rows and optimized-core token comparisons.

**2026-06-16T01:56:24Z**

natural failure inventory sent to D5 5967c825: from mini natural route failed report, unsupported aliases were replace x19, rename x2, insert x1, delete x1, reorder x1. Priority remains safe replace exact alias; broader aliases only if obvious/low-risk, otherwise decline explicitly.

**2026-06-16T01:58:35Z**

D5 focused rerun diagnostics after replace alias normalization: tiny-exact still declined because model used replace with line numbers [2,4,new] and route normalized to ru, causing ru find must be non-empty; mixed-config-doc selected blitz with two replace exact ops but outcome incorrect (likely dry-run only p=true no applied file? needs inspect); same-file-multi declined because multi-op pi_blitz_op only supports rb/ib/wb in one request after multiple replace ops. These are next natural-route blockers if D5 stops after replace alias only.

**2026-06-16T02:12:31Z**

handoff: D5 5967c825 completed pi-blitz route replace alias slice and pushed fc0d2cd `fix(edit): accept route replace aliases`. Focused GPT-5.4-mini route evidence after fc0d2cd: mixed-config-doc passes at reports/natural-edit-harness/natural-edit-2026-06-16T02-07-31-715Z.json; tiny-exact still declines on unstable replace range form `["replace",4,3,...]` at T02-07-27; same-file-multi still declines on unsupported `insert_after` alias at T02-07-37. Spawned D5 6d547bde for next narrow remediation: safe tiny-exact line/range support + insert_after alias, no hidden fallback, focused reruns + commit/push if fixed.

**2026-06-16T06:05:16Z**

handoff: focused GPT-5.4-mini route rerun after previous alias slice was unblocked but incorrect for tiny-exact and mixed-config-doc. tiny-exact line-range replace prepended body line and left old return; mixed-config-doc line-1 whole-file replace prepended new file and left old tail; same-file-multi passed. Spawned D5 f246b783 to fix line/range replacement semantics, keep no-hidden-fallback, rerun 3 focused rows, commit/push if verified.

**2026-06-16T06:08:04Z**

finding: focused route reruns after line/range fix show tiny-exact and mixed-config-doc passing, but same-file-multi latest report reports/natural-edit-harness/natural-edit-2026-06-16T06-07-12-052Z declines. GPT-5.4-mini used pi_blitz_route_edit with s=<entire desired file>, r=blitz, p=true,d=true; router parsed s as unsupported compact script and declined no-write. D5 f246b783 is still active; intercom cannot reach non-interactive worker.

**2026-06-16T06:10:18Z**

verify: pi-blitz route line alias remediation landed/pushed at 815f00d fix(edit): normalize route line aliases. Main verified local HEAD and origin feat/blitz-0.4-token-core-profile both 815f00d. Focused GPT-5.4-mini route reruns pass for tiny-exact, mixed-config-doc, same-file-multi: reports natural-edit-2026-06-16T06-08-44-971Z, T06-08-50-390Z, T06-08-56-070Z all accepted/correct/filesMatch/Tokscale routeOutcome=blitz. D5 f246b783 still finalizing acceptance output.

**2026-06-16T06:13:42Z**

handoff: after pi-blitz 815f00d, focused mandatory-provider spot checks show GPT-5.4-mini and GPT-5.5 pass tiny-exact/mixed-config-doc/same-file-multi route rows, but Zai only tiny-exact passes. Zai mixed-config-doc declines on odd ops including unsupported alias 'string' plus JSON-array s old/new; Zai same-file-multi declines on replace/insert/wrap aliases with ordinal args. Spawned D5 c66f3283 to add safe Zai alias normalization, keep no-hidden-fallback, verify Zai 3 focused rows + GPT-5.4-mini same-file regression, commit/push if green.

**2026-06-16T06:15:16Z**

review: reviewer 5df25f00 blocked pi-blitz 815f00d despite focused GPT rows passing. No hidden core/apply_patch found and p:true preview-then-apply is real, but fail-closed blockers: broad non-script s accepted as line-1 replacement/snippet corruption risk; header-line aliases remap to next line and may corrupt signature edits. Sent findings to active D5 c66f3283 Zai slice; next fix must add negative tests for snippet s and header/signature replacement.

**2026-06-16T06:18:26Z**

finding: D5 c66f3283 got pi-blitz unit gates green but Zai focused route still fails 3/3 after changes. Latest failed reports: tiny-exact T06-16-49 (unsupported alias smallTarget with s function snippet), mixed-config-doc T06-16-55 (unsupported CONFIG.logLevel and no-payload declines), same-file-multi T06-17-05 (unsupported alias 4,8 with English script). GPT-5.4-mini same-file regression T06-17-16 still passes. Current pi-blitz dirty: src/tools.ts and test/apply-runtime.test.ts; no commit accepted.

**2026-06-16T06:20:00Z**

finding: D5 c66f3283 latest Zai focused rerun improved mixed-config-doc to pass (T06-19-20 route=blitz) but tiny-exact and same-file-multi still decline with new shapes. tiny-exact T06-19-16 args ops [[smallTarget,2,3,7]], s smallTarget.name=name.toUpperCase(); same-file-multi T06-19-29 args [[adjust,10,return base + 1;],[emit,16,const markerUpper...],[risky,25,try...]], s symbol-colon lines. These remain safe declines; GPT-5.4-mini regression still green.

**2026-06-16T06:21:33Z**

finding: latest D5 c66f3283 Zai rerun after unit gates: tiny-exact passes; mixed-config-doc declines after index.html changed but config.ts stayed info due replace of quoted key string mismatch; same-file-multi route=blitz but incorrect because insert_after produced same-line insertion () and removed expected blank lines. These are actual route semantics/format blockers, not Zai rate-limit. D5 still active, pi-blitz dirty at 815f00d.

**2026-06-16T06:23:51Z**

cleanup: interrupted/paused D5 c66f3283 after repeated unsafe/incorrect Zai route attempts. Acceptance rejected; dirty pi-blitz changes in src/tools.ts/test/apply-runtime.test.ts were reverted to clean pushed 815f00d. Rationale: latest changes made Zai rows route=blitz but incorrect and regressed smoke tests; keep safe baseline before next narrow fix.

**2026-06-16T06:30:36Z**

landed: pi-blitz safety remediation commit 2d67786 pushed. Fixes reviewer 815f00d blockers: non-script s now file-guarded whole-file only; snippet s declines no-write; header/signature line replacement declines instead of body remap. Verification: pi-blitz typecheck/test/build passed; GPT-5.4-mini focused route reports T06-29-14/19/24 all accepted/correct/filesMatch/Tokscale routeOutcome=blitz. Artifact: /tmp/pi-subagents-uid-1000/d5-route-safety-remediation.md

**2026-06-16T07:13:01Z**

Zai/provider-shape remediation slice complete in pi-blitz: pushed da602c5 (normalize guarded provider route shapes). Evidence: D5 report /tmp/pi-subagents-uid-1000/d5-zai-provider-shape-remediation.md; pi-blitz apply-runtime 37/37; GPT-5.4 focused route rows 07-10-42/07-10-51/07-10-56 accepted+correct+filesMatch+Tokscale routeOutcome=blitz. Current Zai glm-4.5-air focused rows 07-09-35/07-09-39/07-11-17 classified as safe no-write declines with Tokscale match for unsupported/invalid unstable provider shapes; no auth/rate-limit; no hidden fallback; no benchmark artifacts committed.

**2026-06-16T07:13:48Z**

Evidence curation checkpoint: final accepted refs for this slice are pi-blitz commits d31f3e5 and da602c5, D5 reports /tmp/pi-subagents-uid-1000/d5-exported-signature-route-safety.md and /tmp/pi-subagents-uid-1000/d5-zai-provider-shape-remediation.md, reviewer blocker /tmp/pi-subagents-uid-1000/reviewer-pi-blitz-70b6f1f.md, and focused report timestamps called out in notes. Report artifact farm under reports/natural-edit-harness remains uncommitted by design; no benchmark artifacts should be committed for this slice. Universal claim remains blocked pending broad natural/adversarial/provider matrices under Tokscale/accounting.
