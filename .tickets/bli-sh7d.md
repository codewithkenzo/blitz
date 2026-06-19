---
id: bli-sh7d
status: closed
deps: []
links: []
created: 2026-06-19T04:42:24Z
type: feature
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-c, structural]
---
# Implement minimal Class C structural success for default route


## Notes

**2026-06-19T04:42:29Z**

scope: Implement Class C structural edit success for default/minimal replacement route, not fallback. Supported first slice: TypeScript/JavaScript function body replacement by function name () and insertion after function declaration () where unique and parser-supported. Must fail closed on unsupported language, ambiguous symbol, parse error, or multi-match; no mutation on decline. Add tests for route truth, no hidden core/apply_patch fallback, rollback/no mutation, and final-lock class-c-structural-10 success.

**2026-06-19T04:42:34Z**

correction: supported first slice is TypeScript/JavaScript function body replacement by function name, shaped as rb/function/name/body, plus insertion after function declaration shaped as ia/function/name/text, where target is unique and parser-supported. Fail closed on unsupported language, ambiguous symbol, parse error, or multi-match; no mutation on decline.

**2026-06-19T04:48:11Z**

start: executing minimal Class C structural success only. Scope TS/JS rb/function/name/body + ia/function/name/text through default/minimal blitz_edit; fail closed on unsupported/ambiguous/parse/multi-match; no qgz1 until o1pd passes.

**2026-06-19T04:57:44Z**

verify: pi-blitz bun run typecheck && bun test && bun run build passed. blitz zig build && zig build test passed. Focused CLI JS rb smoke passed via zig-out/bin/blitz apply compact rb on .js. Tests added/updated for TS/JS rb success, TS/JS ia success, class-c rb batch success, structural failure no mutation, unsupported Python no mutation, minimal token guard.
