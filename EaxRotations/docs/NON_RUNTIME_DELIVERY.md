# Non-Runtime Delivery

This pass covers static/package work only. It does not include live in-game aura dumps or combat validation.

## Delivered

- Centralized additional Wago-verified TBC IDs in `shared/tbc_data_sylvanas.lua`:
  - common actions
  - racials
  - common crowd-control auras
  - Druid utility/forms/healing IDs
  - Hunter aspects, shots, traps, control, and utility IDs
- Added Sylvanas API-boundary helpers in `core_sylvanas.lua` for documented cancel and totem APIs.
- Removed direct class-file `core.*` usage caught by the static audit.
- Replaced the shell leveling test runner with `tests/run_leveling_tests.lua` so the package stays Lua/Markdown only.
- Added archive triage that compares old archive IDs against current class/spec Lua, central TBC data, Wago SpellName, and Wago ItemSparse.
- Added static behavior audit for known bad IDs, Lightning Shield legacy aliases, local consumable list drift, direct class-file core access, and TODO/FIXME markers.

## Generated Reports

- `docs/ARCHIVE_SPELL_ID_COMPARISON.md`
- `docs/ARCHIVE_TRIAGE.md`
- `docs/STATIC_BEHAVIOR_AUDIT.md`

## Current Non-Runtime Results

- Wago build: `2.5.4.42940`
- Wago sources:
  - `https://wago.tools/db2/SpellName/csv?build=2.5.4.42940`
  - `https://wago.tools/db2/ItemSparse/csv?build=2.5.4.42940`
- Static behavior findings: `0`
- Non Lua/Markdown files in `EaxRotations`: `0`
- Online TBC ID audit: pass

## Archive Triage Snapshot

The archive is not clean enough to bulk import. The triage report separates real candidates from bad archive data:

- already covered in current class/spec Lua
- covered centrally in shared TBC data
- cross-cutting common/consumable buckets
- candidate spells
- archive name mismatches
- IDs not present in the TBC Wago build

Archive IDs in `archive_name_mismatch` or `not_tbc_build` should not be ported without manual correction.

## Remaining Runtime Work

- Run `NS.dump_player_auras(...)` or `shared/aura_probe_sylvanas.lua` in-game for the affected Shaman modes.
- Compare the live local-player aura dump against `shared/tbc_data_sylvanas.lua`.
- Validate that switching leveling/enhancement/elemental/restoration routes through the intended playstyle in combat.
