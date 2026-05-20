# EAX TBC Classic Rotations

This repository contains the `EaxRotations` Project Sylvanas package.

The active package lives in:

```text
EaxRotations/
```

Use [EaxRotations/README.md](EaxRotations/README.md) for the full project guide, class coverage, architecture, API boundary notes, and local verification commands.

## Current Package Scope

- Lua source and tests
- Markdown documentation
- Shared Project Sylvanas runtime helpers
- Class modules for Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock, and Warrior
- Playstyles for tanking, healing, melee DPS, ranged DPS, pet utility, control, solo play, group play, and PvP-aware rules

## Local Verification

Run these checks from the repository root before shipping changes:

```powershell
Get-ChildItem -Path EaxRotations -Recurse -File -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }
Get-ChildItem -Path EaxRotations/tests -Filter 'test_*.lua' | Sort-Object Name | ForEach-Object { lua $_.FullName }
lua EaxRotations/tools/audit_online_tbc_ids.lua
lua EaxRotations/tools/audit_static_behavior.lua
lua EaxRotations/tools/triage_archive_spell_ids.lua
rg --files EaxRotations -g '!*.lua' -g '!*.md'
```

The last command should print no files.
