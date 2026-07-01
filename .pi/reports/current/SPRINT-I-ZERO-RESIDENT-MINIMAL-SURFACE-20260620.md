# Sprint I — Zero-resident / minimal surface investigation

Date: 2026-06-20
Ticket: `bli-cwfj`
Status: deterministic guarded trim + limitation report

## Inputs

No provider/model benchmark loops ran. Evidence used:

- `.pi/reports/current/SPRINT-F-GREEN-ROW-TOKEN-REGRESSION-20260620.json`
- `.pi/reports/archive/history/ALL-EDIT-TYPE-GATE-LOCK-20260619-after-z13z.json`
- current `/home/kenzo/dev/pi-blitz` source schema/skill surfaces
- `bun run check:tax` and `bun scripts/dump-tool-specs.ts`

## Current resident floor

Existing token-accounted artifacts:

| Source | Schema tokens | Skill tokens | Resident total |
| --- | ---: | ---: | ---: |
| Sprint F regression current | 419 | 268 | 687 |
| Sprint D lock baseline | 350 | 268 | 618 |
| All-edit-type gate Blitz rows | 350 | 268 | 618 |

Current pi-blitz deterministic byte surfaces after this slice:

| Surface | Current bytes | Guard |
| --- | ---: | ---: |
| minimal serialized schema (`check:tax`) | 624 | <= 666 |
| minimal `blitz_edit` tool object | 564 | <= 666 |
| resident skill text | 569 | <= 569 |
| success output | 29 | <= 32 |
| structural decline output | 71 | <= 80 |

Other current profile byte sizes from `dump-tool-specs`:

| Profile | Tools | JSON bytes | Tool bytes by name |
| --- | ---: | ---: | --- |
| minimal | 1 | 1283 | `blitz_edit=564` |
| router | 1 | 2640 | `pi_blitz_route_edit=1354` |
| semantic | 4 | 6911 | `op=882`, `patch=1085`, `try_catch=932`, `replace_return=1089` |
| structural | 4 | 7943 | `op=882`, `replace_body_span=1223`, `multi_body=1257`, `patch=1085` |
| admin | 4 | 2569 | `read=302`, `rename=601`, `undo=446`, `doctor=179` |
| full | 17 | 30903 | largest: `pi_blitz_apply=2686`, `pi_blitz_edit=1389`, `route=1354` |

## Reduction implemented

Resident skill text was trimmed in `/home/kenzo/dev/pi-blitz/skills/pi-blitz/SKILL.md`.

- Before measured source bytes: 637
- After measured source bytes: 569
- Reduction: 68 bytes (`10.7%` of skill text)
- Guard tightened from `<=713` to `<=569` in:
  - `/home/kenzo/dev/pi-blitz/scripts/check-tax-guards.ts`
  - `/home/kenzo/dev/pi-blitz/test/tool-profiles.test.ts`

Safety preserved in resident skill:

- `x` exact old/new remains explicit.
- no/multi-match fail-closed remains explicit.
- minimal `x`-only scope remains explicit.
- structural `rb` decline remains explicit.
- no hidden fallback remains explicit.
- token-claim evidence requirement remains explicit.

## Exact limitation blocking true zero resident

True zero resident is impossible while `blitz_edit` is exposed in current Pi extension model:

1. Pi receives registered tool definitions up front for active extension/profile.
2. `PI_BLITZ_TOOL_PROFILE=minimal` already registers only one tool, `blitz_edit`.
3. Even one exposed tool creates non-zero resident schema tax.
4. Skill text is separate resident prompt/context when the pi-blitz skill is loaded.
5. pi-blitz code can choose which tools register at extension startup, but cannot make `blitz_edit` schema disappear for one tiny edit and reappear later inside the same model-visible tool set.

Therefore:

- zero-schema route for tiny exact means do not expose pi-blitz for that request/session, or select core before loading/exposing Blitz;
- zero-skill route means do not load `skills/pi-blitz/SKILL.md` for tiny/core-selected requests;
- both require router/session/profile orchestration outside the single minimal `blitz_edit` tool schema.

## Workaround / next strategy

Recommended zero-resident strategy:

1. Keep default tiny exact route on core when route budget says core cheaper.
2. Use session/profile orchestration:
   - core-only context for tiny exact rows;
   - `PI_BLITZ_TOOL_PROFILE=minimal` only when selector predicts Blitz tie/win;
   - `PI_BLITZ_TOOL_PROFILE=structural` only for explicit advanced structural tasks.
3. Do not load pi-blitz skill text for core-selected tiny rows.
4. Keep `blitz_edit` resident skill at minimal terse rules only.
5. Add future harness guard that compares selected route resident tax:

```text
selectedResidentTax =
  selectedRoute === core ? 0 : blitzSchemaTokens + blitzSkillTokens
```

Current route selector work (`bli-qn4t`) is prerequisite: if OpenAI tiny exact selects core, its pi-blitz resident tax should be zero in a true routed session/profile, not counted as a forced-Blitz loss.

## Remaining reduction candidates

Safe/small remaining candidates:

- Trim minimal schema descriptions further. Current minimal schema is 624 bytes with 42 bytes of guard headroom.
- Reduce decline output below 71 bytes only if parsers/tests keep `no_mutation=true` and decline reason.
- Split skill into `pi-blitz-minimal` and advanced docs later, if Pi skill loading can target only one.

Not safe in this slice:

- Removing `rb` decline wording from schema/skill entirely: provider may retry structural ops instead of fail-closed.
- Registering router/full profiles by default: increases resident tax.
- Claiming zero resident from byte counts alone: token-accounted proof still needs future selected-route Pi/Tokscale telemetry.

## Acceptance notes

This slice implements one deterministic guarded reduction and documents why true zero resident must be solved by route/profile orchestration, not by the current minimal tool schema alone.
