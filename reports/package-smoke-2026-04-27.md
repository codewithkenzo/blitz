# Package smoke — 2026-04-27

## CLI package

Command:

```bash
cd /home/kenzo/dev/blitz
npm pack --dry-run --json
```

Result: **passed** after adding package metadata and wrapper.

Package:

```text
@codewithkenzo/blitz@0.1.0-alpha.0
filename: codewithkenzo-blitz-0.1.0-alpha.0.tgz
size: ~2.5MB
unpackedSize: ~11.7MB
```

Packed files:

```text
LICENSE
NOTICE.md
README.md
bin/blitz
bin/blitz.js
docs/blitz.md
mcp/blitz-mcp.ts
package.json
```

## CLI temp install

Command shape:

```bash
npm pack --json
mkdir /tmp/blitz-install
cd /tmp/blitz-install
npm install /home/kenzo/dev/blitz/codewithkenzo-blitz-0.1.0-alpha.0.tgz
./node_modules/.bin/blitz doctor
```

Result: **passed**.

```text
blitz doctor
  version:     0.0.1
  stage:       v0.1
  tree-sitter: linked
  grammars:    rust ok, typescript ok, tsx ok, python ok, go ok
  commands:    read, edit, batch-edit, rename, undo, doctor, apply
```

## Pi extension package

Command:

```bash
cd extensions/pi-blitz
npm pack --dry-run --json
```

Result: **passed**.

Key output:

```text
@codewithkenzo/pi-blitz@0.0.1-alpha.0
filename: codewithkenzo-pi-blitz-0.0.1-alpha.0.tgz
size: 93957
unpackedSize: 521309
```

## Pi install

Command:

```bash
pi install /home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz
```

Result: **passed**.

```text
Installed /home/kenzo/dev/pi-plugins-repo-kenzo/.dmux/worktrees/dmux-1777009913426-opus47/extensions/pi-blitz
```

## Pi doctor tool smoke

Command shape:

```bash
pi --offline --print --no-context-files --no-prompt-templates \
  --provider openai-codex --model gpt-5.4-mini --thinking off \
  --extension extensions/pi-blitz/dist/index.js \
  --tools pi_blitz_doctor \
  "Use only pi_blitz_doctor. Call it exactly once. No prose."
```

Result: **passed** with exit code 0.

## MCP stdio package smoke

`mcp/blitz-mcp.ts` is included in the CLI package and exposed as `blitz-mcp`.

Manual framed JSON-RPC smoke passed in `reports/mcp-stdio-smoke-2026-04-27.md`.

## Remaining package release decisions

- Align package version with CLI doctor version (`0.1.0-alpha.0` vs doctor `0.0.1`).
- Decide whether first alpha ships embedded linux-x64-musl binary only or platform optional packages.
- Add a true postinstall/platform resolution script if using optional packages.
- Add a real automated MCP protocol smoke script.
