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
