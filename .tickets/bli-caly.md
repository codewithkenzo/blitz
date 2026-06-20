---
id: bli-caly
status: open
deps: []
links: [bli-05rl, bli-7yuu]
created: 2026-06-20T04:54:06Z
type: bug
priority: 1
assignee: Kenzo
parent: bli-6uqs
tags: [blitz, 0.5, sprint-e, structural, product]
---
# Fix provider-independent structural-body survey red

Provider-language survey 20260620 found structural-body Blitz red on both zai/glm-4.5-air and openai-codex/gpt-5.4-mini. Triage root cause: default/minimal structural body path is not robust across provider tool-call shapes. Zai rb/function/name/body applied but collapsed function-brace/newline formatting, causing expected mismatch. OpenAI/Codex emitted unsupported old/new rb shape under minimal-v0; tool declined no mutation. Provider-independent scenario failure; not counted as token saving.

## Acceptance Criteria

structural-body survey fixture passes for default Blitz route with supported rb/function/name/body shape; unsupported rb shapes fail closed with clear route/provider classification; brace/newline body replacement preserves expected formatting; focused evidence includes at least Zai and OpenAI/Codex or documented provider-specific prompt/schema guard; no hidden core/apply_patch fallback counted as Blitz.
