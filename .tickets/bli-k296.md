---
id: bli-k296
status: closed
deps: []
links: []
created: 2026-06-19T03:03:17Z
type: bug
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-c, benchmark, structural]
---
# Fix Class C structural blitz_edit final-lock correctness


## Notes

**2026-06-19T03:03:23Z**

source: bli-o1pd 20260619 final lock. class-c-structural-10 blitz-edit returned status=caveated; Tokscale matched; route tool=blitz_edit; failed path structural-10.ts hash f641a38b60761f57 != expected bf098d15725e76dd. Artifacts under reports/pi-accounting-runs/20260619-replacement-gate/class-c-structural-10-blitz-edit and reports/pi-tmux-true-streak-class-c-structural-10-blitz-edit-20260619-final-lock.*

**2026-06-19T03:11:17Z**

start: diagnosing failed 20260619 class-c-structural-10 blitz_edit lock row. Route truth/Tokscale OK; correctness mismatch only. No broad gate rerun until focused fix verified.

**2026-06-19T03:16:33Z**

finding: Artifact shows blitz_edit returned explicit decline text: unsupported_structural_op_minimal no_mutation=true. structural-10.ts remained unchanged; mismatch was harness/final-lock classification expecting structural mutation under minimal profile despite Sprint A quarantine. Root cause: bench/true-streak.ts only classified final file equality, not intentional minimal structural decline.

**2026-06-19T03:16:33Z**

verify: pi-blitz focused test added for exact 10-rb class-c batch; bun run typecheck && bun test passed in pi-blitz. Blitz true-streak classifier test/build passed. Focused class-c blitz-edit row rerun only (not broad gate): status=declined, Tokscale match yes/zero deltas, route=blitz_edit, no_mutation=true.
