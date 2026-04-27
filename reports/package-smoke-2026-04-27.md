# Package smoke — 2026-04-27

## CLI package

Command:

```bash
cd /home/kenzo/dev/blitz
npm pack --dry-run --json
```

Result: **failed**.

```text
Invalid package, must have name and version
```

Cause: `package.json` is still bench-only/private:

```json
{
  "name": "@codewithkenzo/blitz-bench",
  "private": true
}
```

Release blocker: add real CLI package metadata and package layout before publishing `@codewithkenzo/blitz`.

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

## CLI doctor

Command:

```bash
./zig-out/bin/blitz doctor
```

Result: **passed**.

Doctor now reports the actual command set including `apply`:

```text
commands: read, edit, batch-edit, rename, undo, doctor, apply
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

## Next packaging fix

Implement CLI npm package metadata before publish:

- package name: `@codewithkenzo/blitz`
- version aligned with CLI `0.0.1` / alpha tag decision
- `bin.blitz`
- packed files allowlist
- postinstall or optional dependency strategy for platform binary packages
- temp install smoke that runs `blitz doctor`
