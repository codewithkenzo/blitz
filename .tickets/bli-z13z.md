---
id: bli-z13z
status: open
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
