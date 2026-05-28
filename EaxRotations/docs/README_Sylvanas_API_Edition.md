# EaxRotations Sylvanas API Edition

Last reviewed: 2026-05-21

## Summary

EaxRotations is a TBC rotation framework for Project Sylvanas. Live code
is bound to the local Project Sylvanas API in `api/` and the local
documentation mirror in `apidocs/`.

The public project identity is EaxRotations.

## Current State

| Area | State |
| --- | --- |
| Classes | All 9 classes: Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior |
| Playstyles | 29 talent specs + 2 extra (caster, kebab) + 9 leveling = 40 registered |
| Runtime API | Uses `NS.*` wrappers over Project Sylvanas `api/` modules |
| External runtime calls | Not allowed in live code. Static API lint passes |
| Post-TBC cleanup | non-TBC spells removed or documented as unavailable |
| Cast path | `NS.try_cast()` owns rotation casting |
| Time source | `NS.time_now()` is the project time helper |
| Branding | Plugin metadata, menus, windows, logs, and exports use EaxRotations/Eax branding |
| Tests | ~110 suites (100 rotation entries [99 unique] + 11 leveling) |
| Docs | `README.md`, `AGENTS.md`, `docs/TECHNICAL_GUIDE.md` |

## Load Path

Project Sylvanas loads `header.lua` and `main.lua`. `main.lua` requires the
EaxRotations modules explicitly; `load_order_sylvanas.lua` is documentation-only.

```text
header.lua
main.lua
  common/izi_sdk
  core_sylvanas.lua        -- creates _G.EaxRotations
  helpers_sylvanas.lua
  explain_helpers_sylvanas.lua
  optimizer.lua
  shared/* (~24 modules)
  main_sylvanas.lua        -- dispatcher
  classes/<class>/class_sylvanas.lua
  classes/<class>/schema_sylvanas.lua
```

## Runtime Boundary

Most class files should only need:

- `NS.GetPlayer`
- `NS.GetTarget`
- `NS.try_cast`
- `NS.buff_up`
- `NS.import_helpers`
- `NS.rotation_registry`
- `context.settings`

If a class needs a lower-level API call, prefer adding a wrapper in
`core_sylvanas.lua` so the boundary stays centralized.

## Tests

```powershell
# Rotation tests (100 entries, 99 unique)
lua EaxRotations/tests/run_rotation_tests.lua

# Leveling tests (11 entries)
lua EaxRotations/tests/run_leveling_tests.lua

# Syntax check all files
Get-ChildItem EaxRotations -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName }
```

Verified on 2026-05-21: all entries run, 99 unique rotation test files exist.

## Technical Guide

For the complete technical guide covering boot sequence, tick trace, all 40
playstyles, settings lifecycle, and how to modify a rotation, see:
`docs/TECHNICAL_GUIDE.md`.
