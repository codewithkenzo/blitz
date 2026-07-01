---
id: bli-wwly
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: chore
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-a, packaging]
---
# 0.5A bench and package isolation guard

Prove bench/dev assets are excluded from language stats, npm root package, platform packages, installs, and runtime surfaces.

## Acceptance Criteria

git check-attr proves bench exclusion; npm pack dry-runs prove no bench/.pi/reports/dev farm in root tarball; platform tarballs contain only binary payload + metadata; release guard documented or scripted.


## Notes

**2026-06-19T01:42:56Z**

verify: pack isolation guard added in scripts/verify-package-isolation.js; npm run pack:verify PASS; git check-attr shows bench vendored and reports generated; root npm pack dry-run has forbidden=[]; platform dry-runs contain only bin/blitz or bin/blitz.exe plus package.json.
