---
id: bli-z13z
status: closed
deps: []
links: []
created: 2026-06-19T19:05:40Z
type: task
priority: 0
assignee: Kenzo
tags: [blitz, 0.5, sprint-d, benchmark, blocker, harness]
---
# 0.5D Zai gate all-edit-types scenario misroutes to tiny-10


## Notes

**2026-06-19T19:05:48Z**

blocker: Zai after-bli-t3cl gate ran without provider quota failure, but requested all-edit-types-gate rows produced reports whose scenario field is tiny-10. That means E06/E07/E10/E11/E12 materialized success fixtures were not actually counted/executed by the focused gate. Existing successful row artifacts are preserved; no rerun performed. Need harness scenario selection/validation fix before another lock.

**2026-06-19T21:57:00Z**

start: fixing true-streak all-edit-types-gate scenario mismatch harness only. Preflight self-check currently passes despite prior artifacts showing all-edit-types-gate emitted scenario=tiny-10; no provider/model rerun.

**2026-06-19T22:00:07Z**

fix: root cause was true-streak scenario resolver ternary missing explicit all-edit-types-gate branch, so valid --scenario all-edit-types-gate fell through to tinyScenario(). Harness now uses exhaustive resolveScenario(), asserts requested==resolved before run, adds allEditTypes report metadata with requested/resolved scenario + E-class rows, and self-check/test guard against all-edit-types-gate resolving/emitting tiny-10. Verification passed: self-check, bench/true-streak.test.js, and Bun build to /tmp/true-streak-check.js. No provider/model/Pi rerun.
