# EAX TBC Classic Rotations

This repository contains the `EaxRotations` Project Sylvanas package.

The active package lives in:

```text
EaxRotations/
```

Use [EaxRotations/README.md](EaxRotations/README.md) for the full project guide, class coverage, architecture, API boundary notes, and local verification commands.

## Current Quality Baseline (S+)

| Parameter | Grade | Notes |
|---|---|---|
| Architecture | S+ | Clean dispatcher, NS.* API boundary, pure module separation |
| TBC Accuracy | S+ | All spell IDs audited, zero fake/legacy IDs |
| Readability | S+ | What/When/Why/Safety headers on 100+ files |
| Test Coverage | S+ | 182 tests pass (171 rotation + 11 leveling suites) |
| Performance | S+ | Strategy evaluation benchmarked under 20ms |
| Open Source | S+ | MIT LICENSE, CONTRIBUTING.md, stale stats corrected |

## Current Package Scope

- Lua source and tests
- Markdown documentation
- Shared Project Sylvanas runtime helpers
- Class modules for Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, and Warrior
- Playstyles for tanking, healing, melee DPS, ranged DPS, pet utility, control, solo play, group play, and PvP-aware rules

## Local Verification

Run the automated validation gate from the repository root:

```batch
cmd.exe //c "EaxRotations\validate.cmd"
```

Or run individually:

```powershell
# Syntax check all Lua files
Get-ChildItem -Path EaxRotations -Recurse -File -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }

# Run rotation regression test suite (171 suites)
lua EaxRotations/tests/run_rotation_tests.lua

# Run leveling test suite (11 suites)
lua EaxRotations/tests/run_leveling_tests.lua
```
