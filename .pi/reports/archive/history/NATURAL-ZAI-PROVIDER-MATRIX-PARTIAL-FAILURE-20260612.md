# Natural Zai provider matrix partial failure — 2026-06-12

Status: failed/caveated provider-matrix attempt preserved for remediation evidence. This is **not** a passing benchmark report and must not be used for universal/token-savings claims.

## Command attempted

```bash
bun .pi/bench/natural-edit.ts \
  --scenario-group natural \
  --provider zai \
  --model glm-4.5-air \
  --iters 1 \
  --tokscale \
  --keep-temp \
  --timeout-ms 120000
```

Log:

- `.pi/reports/provider-matrix-logs/natural-zai-glm-4.5-air-20260612T053812Z.log`

Preserved partial run artifacts:

- `.pi/reports/natural-edit-runs/tiny-exact__core__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/tiny-exact__blitz__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/mixed-config-doc__core__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/mixed-config-doc__blitz__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/same-file-multi__core__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/same-file-multi__blitz__0__2026-06-12T05-38-12-299Z/`
- `.pi/reports/natural-edit-runs/structural-body__core__0__2026-06-12T05-38-12-299Z/`

## Observed partial outcomes before stop

From the log:

```text
✓ tiny-exact / core: core_mutated (1/1 correct)
✗ tiny-exact / blitz: incorrect (0/1 correct)
✓ mixed-config-doc / core: core_mutated (1/1 correct)
✓ mixed-config-doc / blitz: blitz_mutated (1/1 correct)
✓ same-file-multi / core: core_mutated (1/1 correct)
✗ same-file-multi / blitz: incorrect (0/1 correct)
```

The run was stopped after preserving artifacts because repeated Blitz failures were causing timeout/retry loops and the attempt was no longer useful as a passing provider matrix.

## Failure evidence

### `tiny-exact / blitz`

Session JSONL:

- `.pi/reports/natural-edit-runs/tiny-exact__blitz__0__2026-06-12T05-38-12-299Z/work/sessions-blitz/2026-06-12T05-38-21-651Z_019eba56-a753-70de-a1f2-7a27142e4fdb.jsonl`

The model called `blitz_edit` with a 3-item `x` tuple and no top-level `f`:

```json
{"e":[["x","return \"hi \" + name;","return \"hello \" + name.toUpperCase();"]]}
```

`blitz_edit` requires `f` for 3-item tuples. Result: no file mutation, row incorrect.

### `same-file-multi / blitz`

Session JSONL:

- `.pi/reports/natural-edit-runs/same-file-multi__blitz__0__2026-06-12T05-38-12-299Z/work/sessions-blitz/2026-06-12T05-38-44-670Z_019eba57-013d-7d7c-b979-ba3b635c40bd.jsonl`

The model repeatedly called:

```json
{
  "f":"multi.ts",
  "e":[
    ["x","return base;","return base + 1;"],
    ["x","const marker = value;","const marker = value;\n  const markerUpper = value.toUpperCase();"],
    ["x","return value;","try {\n    return value;\n  } catch (error) {\n    throw error;\n  }"]
  ]
}
```

The tool result returned only:

```text
pi-blitz blitz-error:
```

The empty error text caused model retry churn until timeout. Direct reproduction against Blitz `apply --edit - --json --dry-run` showed `UNSUPPORTED_OPERATION` for the grouped exact-replace payload, while simple exact replacements can pass. This is a product/harness remediation input:

- `blitz_edit` should return actionable structured error text, not empty `blitz-error:`.
- The default route must avoid retry loops on unsupported grouped exact-replace payloads.
- Batched exact replacements need either product support or explicit fallback/decline accounting; fallback must not count as Blitz success.

## Next remediation target

Before rerunning mandatory provider matrices:

1. Harden `blitz_edit` guidance/schema or harness preamble so 3-item exact tuples include top-level `f`, or prefer 4-item tuples consistently.
2. Fix empty `pi-blitz blitz-error:` output so provider retry loops have a clear non-retryable reason.
3. Decide/implement route behavior for grouped same-file exact replacements: true Blitz support, explicit decline, or explicit fallback accounting.
4. Rerun a small smoke (`tiny-exact` and `same-file-multi`, Blitz lane only) before restarting the full Zai natural matrix.
