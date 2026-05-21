# EaxRotations — Quick Reference

**Project:** EaxRotations TBC Classic Rotation Framework
**Version:** 2.0.0-Tier4 | **Last Updated:** 2026-05-15
**Full context:** see [AGENTS.md](AGENTS.md)

## Architecture (30 seconds)

```
EaxRotations/
├── main.lua / main_sylvanas.lua   # Bootstrap / Dispatcher
├── core_sylvanas.lua              # NS.* runtime boundary
├── load_order_sylvanas.lua        # Module load order
├── shared/                        # 46 cross-class modules
├── classes/<class>/               # Per-class (9 classes, 31 talent specs + 2 extra playstyles + 9 leveling = 40 registered)
│   ├── class_sylvanas.lua         # Registration
│   ├── schema_sylvanas.lua        # Settings
│   ├── middleware_sylvanas.lua     # Shared class behavior
│   └── <spec>_sylvanas.lua        # Rotation strategies
└── tests/                         # 55 regression tests
```

## Key Rules

- Only `.lua` and `.md` files belong in EaxRotations
- TBC spells only (patch 2.4.3) — never add WotLK/Cata abilities
- All casts through `NS.spell_ready` / `NS.try_cast`
- Settings from `context.settings`, never captured at load time
- Every file: readability header (What/When/Why/Safety/Decision)

## Verification

```powershell
# Syntax
Get-ChildItem -Recurse -Filter '*.lua' | ForEach-Object { luac -p $_.FullName }

# Tests
Get-ChildItem tests -Filter 'test_*.lua' | ForEach-Object { lua $_.FullName }
```
