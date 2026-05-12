# EaxRotations Sylvanas API Edition

Last reviewed: 2026-04-27

## Summary

EaxRotations is a TBC rotation addon built for Project Sylvanas. Live code is
bound to the local Project Sylvanas API in `api/` and the local documentation
mirror in `apidocs/`.

The public project identity is EaxRotations.

## Current State

| Area | State |
| --- | --- |
| Classes | All 9 classes converted: Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, Warrior. |
| Runtime API | Uses `NS.*` wrappers over Project Sylvanas `api/` modules. |
| External runtime calls | Not allowed in live code. Static API lint passes. |
| Post-TBC cleanup | non-TBC+ spells are removed or documented as unavailable where relevant. |
| Cast path | `NS.try_cast()` owns rotation casting. Legacy cast queues are not used. |
| Time source | `NS.time_now()` is the project time helper; stale `GetTime()` call sites were swept. |
| Branding | Plugin metadata, menus, windows, logs, and exports use EaxRotations/Eax branding. |
| Tests | 16/16 standalone Lua 5.1 suites pass on 2026-04-27. |

## Load Path

Project Sylvanas loads `header.lua` and `main.lua`. The bootstrap in `main.lua`
requires the EaxRotations modules explicitly:

```text
header.lua
main.lua
  core_sylvanas.lua
  helpers_sylvanas.lua
  explain_helpers_sylvanas.lua
  optimizer.lua
  damage_meter_sylvanas.lua
  dashboard_sylvanas.lua
  debug_log_sylvanas.lua
  api_probe_sylvanas.lua
  sim_constants_sylvanas.lua
  shared/*
  main_sylvanas.lua
  classes/<class>/*
```

`load_order_sylvanas.lua` is documentation and status metadata. The actual
runtime order is the `require()` sequence in `main.lua`.

## Runtime Boundary

Most class files should only need:

- `NS.CreateSpell`
- `NS.GetPlayer`
- `NS.GetTarget`
- `NS.try_cast`
- `NS.import_helpers`
- `NS.GetAPIModule`
- `NS.rotation_registry`
- `context.settings`

If a class needs a lower-level API call, prefer adding a focused wrapper in
`core_sylvanas.lua` so the Project Sylvanas boundary stays centralized.

## Tests

Preferred:

```bash
make test
make check
```

Windows fallback used for this cleanup:

```powershell
Get-ChildItem EaxRotations/tests -Filter test_*.lua | ForEach-Object {
    lua.exe $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "failed: $($_.Name)" }
}
```

Verified on 2026-04-27: 16/16 suites passed.
