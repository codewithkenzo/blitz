# Research: MCP config snippets and AI coding tool UX priorities

## Question
What are current best-practice MCP config snippet patterns for Claude Code/Claude Desktop, VS Code/Cursor, and Codex, and what UX priorities should Blitz emphasize for AI coding tools: install friction, stream-readable tool results, progress updates, safety, token-savings proof?

## Findings
1. Claude Code best default is CLI-first install, then project-scoped JSON. Official docs show `claude mcp add [options] <name> -- <command> [args...]`, with `--transport stdio|http|sse`, `--scope local|project|user`, and env vars via `--env`. Project config lives in `.mcp.json` as `mcpServers`; user/local config lives in `~/.claude.json`. Docs also note output token limits/warnings for MCP tool results and env expansion in `.mcp.json`. Sources: https://docs.anthropic.com/en/docs/claude-code/mcp/ ; https://docs.anthropic.com/en/docs/claude-code/settings ; https://docs.anthropic.com/en/docs/claude-code/cli-usage

2. Claude Desktop docs now steer toward Desktop Extensions, not hand-edited JSON, for most users. Anthropic help says desktop extensions make local MCP setup much easier, support Node/Python/binary servers, auto-encrypt `sensitive: true` fields, and use `.mcpb` packaging / extension install flows. Use manual `claude_desktop_config.json` only as legacy fallback / compatibility path. Sources: https://support.anthropic.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop ; https://support.anthropic.com/en/articles/11503834-building-custom-integrations-via-remote-mcp-servers

3. VS Code/Codex favor explicit config files plus sandbox/approval controls; Cursor public docs are thinner. VS Code MCP docs use top-level `servers`, `type: "stdio"`, `command`, `args`, `env`, optional `envFile`, and `${workspaceFolder}`; they also document sandboxing local stdio servers and workspace vs user profile config. Codex MCP docs use `codex mcp add ...` for quick install and `[mcp_servers.<name>]` in `~/.codex/config.toml` or project `.codex/config.toml`, with `command`, `args`, `env`, `env_vars`, and `cwd`. Cursor public docs expose MCP pages, but the clearest official snippet surfaced was raw `mcpServers` JSON with `command` + `args`; treat Cursor-specific syntax as needing current-app verification before quoting in docs. Sources: https://code.visualstudio.com/docs/copilot/reference/mcp-configuration ; https://code.visualstudio.com/docs/copilot/customization/mcp-servers ; https://developers.openai.com/codex/mcp ; https://developers.openai.com/codex/config-basic ; https://docs.cursor.com/docs/mcp ; https://docs.cursor.com/en/cli/mcp

## Sources
- https://docs.anthropic.com/en/docs/claude-code/mcp/
- https://docs.anthropic.com/en/docs/claude-code/settings
- https://docs.anthropic.com/en/docs/claude-code/cli-usage
- https://support.anthropic.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop
- https://support.anthropic.com/en/articles/11503834-building-custom-integrations-via-remote-mcp-servers
- https://code.visualstudio.com/docs/copilot/reference/mcp-configuration
- https://code.visualstudio.com/docs/copilot/customization/mcp-servers
- https://developers.openai.com/codex/mcp
- https://developers.openai.com/codex/config-basic
- https://docs.cursor.com/docs/mcp
- https://docs.cursor.com/en/cli/mcp
- https://developers.openai.com/api/docs/guides/token-counting
- https://developers.openai.com/api/docs/guides/prompt-caching

## Version / Date Notes
- Research date: 2026-04-28.
- Anthropic Claude Code / Desktop docs and OpenAI Codex docs are live docs; syntax and scope names can drift. Recheck before shipping snippets.
- Cursor docs were sparse / partially localized in search results; verify current UI or docs before hardcoding Cursor-specific guidance.
- VS Code MCP docs were current and explicit as of fetch date.

## Open Questions
- Does Cursor now expose a stable, English MCP config page with exact snippet syntax, or should Blitz docs keep Cursor under a “follows VS Code-style MCP JSON” note until verified in-app?
- For Claude Desktop, should Blitz docs de-emphasize direct `claude_desktop_config.json` entirely and recommend desktop extension packaging first for non-developers?
- Do we want one canonical Blitz MCP snippet per client, or one primary snippet plus short client-specific deltas to reduce doc maintenance?

## Recommendation
Update `docs/blitz-v0.2-stream-ux-hardening-plan.md` Workstream C to:
- lead with copy/paste install commands, not env theory;
- show Claude Code CLI add first, then `.mcp.json` project snippet;
- note Claude Desktop desktop extensions / `.mcpb` as preferred user path;
- show VS Code workspace `mcp.json` and Codex CLI/TOML side by side;
- keep Cursor wording conservative until exact current syntax is rechecked;
- add token-savings proof only when measured, using token-counting / benchmark references, not in every stream result.
