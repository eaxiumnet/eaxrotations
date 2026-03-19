# STRUCTURE - Directory Layout

## Root Level

```
C:\newbot\scripts\
├── README.md              -- Project overview
├── CHANGELOG.md           -- Version history
├── AGENTS.md              -- Handover document
├── EAX*/                  -- 27 spec folders
├── common/                -- Symlink/data file (plugin dependency)
├── core_lua/              -- Symlink/data file (plugin dependency)
├── docs/                  -- Documentation
├── .planning/             -- Planning artifacts
└── ext_rotation_*/       -- External rotations
```

## Spec Folders (27 total)

### Druid (3 specs)
```
EAXDruidBalance/
EAXDruidFeral/
EAXDruidRestoration/
```

### Hunter (3 specs)
```
EAXHunterBeastMastery/
EAXHunterMarksmanship/
EAXHunterSurvival/
```

### Mage (3 specs)
```
EAXMageArcane/
EAXMageFire/
EAXMageFrost/
```

### Paladin (3 specs)
```
EAXPaladinHoly/
EAXPaladinProtection/
EAXPaladinRetribution/
```

### Priest (3 specs)
```
EAXPriestDiscipline/
EAXPriestHoly/
EAXPriestShadow/
```

### Rogue (3 specs)
```
EAXRogueAssassination/
EAXRogueCombat/
EAXRogueSubtlety/
```

### Shaman (3 specs)
```
EAXShamanElemental/
EAXShamanEnhancement/
EAXShamanRestoration/
```

### Warlock (3 specs)
```
EAXWarlockAffliction/
EAXWarlockDemonology/
EAXWarlockDestruction/
```

### Warrior (3 specs)
```
EAXWarriorArms/
EAXWarriorFury/
EAXWarriorProtection/
```

## Per-Spec Structure

Each spec folder contains ~17 Lua files:

```
EAXWarriorArms/
├── main.lua              -- 826 lines, rotation logic
├── spells.lua            -- 113 lines, spell IDs
├── menu.lua              -- 118 lines, UI config
├── utils.lua             -- 837 lines, spec helpers
├── eax_utils.lua        -- Shared EAX utilities
├── interrupt_manager.lua-- 198 lines
├── defensive_manager.lua-- 79 lines
├── encounter_manager.lua-- 359 lines
├── ooc_manager.lua       -- 308 lines
├── leveling_manager.lua -- Leveling support
├── racial_manager.lua   -- Racial abilities
├── ttd_tracker.lua      -- Time-to-death
├── esp_renderer.lua     -- Visual overlay
├── plugin_info.lua     -- Metadata
├── header.lua           -- Banner
├── color.lua           -- Color helpers
├── ps_theme.lua        -- UI theme
├── EAXWarriorArms.toc  -- TOC file
└── README.md
```

## Key Locations

| Purpose | File |
|---------|------|
| Spell data | `*/spells.lua` |
| Rotation logic | `*/main.lua` |
| UI configuration | `*/menu.lua` |
| Shared managers | `*/interrupt_manager.lua`, `*/defensive_manager.lua`, etc. |
| Boss database | `*/encounter_manager.lua` |
| Visual overlay | `*/esp_renderer.lua` |

## Naming Conventions

- **Folder names**: `EAX` + ClassName + SpecName (e.g., `EAXWarriorArms`)
- **Files**: snake_case (e.g., `main.lua`, `spells.lua`)
- **Functions**: snake_case (e.g., `try_mortal_strike`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `EXECUTE_HP_THRESHOLD`)
- **Spec identifiers**: lowercase (e.g., "arms", "fury", "protection")
