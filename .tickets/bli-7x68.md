---
id: bli-7x68
status: closed
deps: []
links: []
created: 2026-06-19T01:30:52Z
type: task
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-b, languages, tree-sitter]
---
# 0.5B language capability matrix tests

Encode per-language exact vs structural capability matrix from research; distinguish direct text from AST support.

## Acceptance Criteria

Matrix tests/documentation cover TS/TSX/JS/JSX/Python/Go/Rust/JSON/JSONC/YAML/TOML/Markdown/HTML/CSS; unsupported structural routes decline; js/jsx AST decision is explicit; set_key jsonc gap recorded or fixed.


## Notes

**2026-06-19T02:05:39Z**

start: implementing language capability matrix tests/docs; preserving old evidence/report farm; no Sprint B provider/effect work.

**2026-06-19T02:10:27Z**

finding: pi-blitz 55fe155 adds durable language capability matrix for TS/TSX/JS/JSX/Python/Go/Rust/JSON/JSONC/YAML/TOML/Markdown/HTML/CSS; JS/JSX AST explicitly unsupported; JSONC set_key recorded unsupported; minimal structural aliases decline no-write.

**2026-06-19T02:10:27Z**

verify: pi-blitz bun test test/tool-profiles.test.ts PASS; bun run typecheck && bun test && bun run build PASS. Commit 55fe155 pushed to feat/blitz-0.4-token-core-profile-canonical.
