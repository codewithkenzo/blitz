# Research: MCP stdio setup patterns for TS/npm CLIs

## Question
What is current practical setup for MCP stdio package launch in TypeScript/npm CLIs across Claude Desktop / Claude Code / Cursor / Codex / Pi-style agents, and what README/package patterns should `@codewithkenzo/blitz` use?

## Findings
1. **Host config shape differs; do not reuse one JSON snippet everywhere.**
   - **Claude Desktop / Claude Code** use `mcpServers` in MCP config. Claude Code project scope lives in repo-root `.mcp.json`; user/local scope lives in `~/.claude.json`. Claude Code supports env expansion in `.mcp.json` with `${VAR}` and `${VAR:-default}` and `claude mcp add` supports `--transport stdio`, `--env`, `--scope`, and `--` separator. Sources: https://code.claude.com/docs/en/mcp ; https://code.claude.com/docs/en/debug-your-config ; https://code.claude.com/docs/en/claude-directory.md ; https://code.claude.com/docs/en/settings.
   - **Cursor / VS Code** use `mcp.json` with top-level `servers`, not `mcpServers`. STDIO entries need `type: "stdio"`, `command`, optional `args`, `env`, `envFile`; Cursor/VS Code support `${workspaceFolder}` and similar interpolation. Sources: https://cursor.com/docs/mcp ; https://code.visualstudio.com/docs/copilot/customization/mcp-servers ; https://code.visualstudio.com/docs/copilot/reference/mcp-configuration.
   - **Codex** does **not** use JSON for this; it uses `~/.codex/config.toml` or `.codex/config.toml` with `[mcp_servers.<name>]`. CLI path is `codex mcp add <name> --env ... -- <stdio command>`. Sources: https://developers.openai.com/codex/mcp/ ; https://developers.openai.com/codex/config-reference ; https://developers.openai.com/codex/config-sample.

2. **`npx` / `bunx` launch syntax is standardized enough to document once, but exact flags matter.**
   - `npx` supports `npx --package=<pkg> -- <cmd> [args...]`; flags must come before positional args. `--package` is required when binary name differs from package name or package has multiple bins. Source: https://docs.npmjs.com/cli/v11/commands/npx and https://docs.npmjs.com/cli/v11/configuring-npm/package-json/.
   - `bunx` is Bun’s `npx` analog. `bunx -p <pkg> <bin>` is the right pattern when bin name differs from package name. Bun respects shebangs; `--bun` must come before executable name if forcing Bun runtime. Sources: https://bun.sh/docs/pm/bunx.

3. **npm bin entries should be executable wrapper files; raw TS bin is not the normal portable pattern.**
   - npm docs say `bin` maps command name to a local file and that file should start with `#!/usr/bin/env node`; npm then links/symlinks it on install. If package has multiple bins, `npm exec`/`npx` only infers one automatically when there is a single bin or a bin that matches package name. Source: https://docs.npmjs.com/cli/v11/configuring-npm/package-json/.
   - MCP stdio spec says server is launched as subprocess, stdin/stdout carry JSON-RPC, stderr is for logs only; stdout must stay clean. Source: https://modelcontextprotocol.io/specification/latest/basic/transports.
   - Current repo follows this partly: `bin/blitz.js` is a Node wrapper, while `mcp/blitz-mcp.ts` is a Bun-shebang stdio server with `BLITZ_WORKSPACE` path-escape guard. Sources: `bin/blitz.js`, `mcp/blitz-mcp.ts`, `docs/blitz.md`, `README.md`.

## Sources
- `README.md` (MCP server section; npx/bunx examples; Pi extension section)
- `docs/blitz.md` (MCP stdio server section; workspace env guard)
- `bin/blitz.js`
- `mcp/blitz-mcp.ts`
- https://docs.npmjs.com/cli/v11/configuring-npm/package-json/
- https://docs.npmjs.com/cli/v11/commands/npx
- https://bun.sh/docs/pm/bunx
- https://modelcontextprotocol.io/specification/latest/basic/transports
- https://code.claude.com/docs/en/mcp
- https://code.claude.com/docs/en/debug-your-config
- https://code.claude.com/docs/en/claude-directory.md
- https://code.claude.com/docs/en/settings
- https://cursor.com/docs/mcp
- https://code.visualstudio.com/docs/copilot/customization/mcp-servers
- https://code.visualstudio.com/docs/copilot/reference/mcp-configuration
- https://developers.openai.com/codex/mcp/
- https://developers.openai.com/codex/config-reference
- https://developers.openai.com/codex/config-sample

## Version / Date Notes
- Docs fetched 2026-04-27.
- Claude Code docs use current 2026 scope model: local/project/user; older docs/blogs may still say project/global. Prefer current official docs.
- Cursor/VS Code use `servers` in `mcp.json`; older community posts often show `mcpServers`. Treat those as stale unless host docs say otherwise.
- npm `npx` docs now recommend `npm exec`/`npx` syntax with `--package` and `--` separator; older standalone `npx` examples can be stale.

## Open Questions
- Should `@codewithkenzo/blitz` ship a JS shim for `blitz-mcp` bin, or keep Bun-shebang TS entry and document Bun as required runtime?
- Do we want separate snippets for Claude Code project scope, Claude Desktop, Cursor, and Codex, since config file shape differs (`mcpServers`, `servers`, TOML)?
- Should README mention Windows-specific launcher fallback for any host that shells through `cmd /c` or similar?

## Recommendation
- README: make **Bun-backed MCP launch** the canonical path (`bunx -p @codewithkenzo/blitz blitz-mcp`) and add host-specific config blocks.
- README: show **Claude Code** with `.mcp.json` + `mcpServers`, **Cursor** with `.cursor/mcp.json` + `servers`, **Codex** with `config.toml`, and **Pi** with its extension install/config path.
- Package: keep `blitz` CLI wrapper as JS/bin; for MCP, prefer a published executable wrapper over raw `.ts` if wanting best `npx`/Windows portability. Keep `BLITZ_WORKSPACE` absolute and explicit in examples.
