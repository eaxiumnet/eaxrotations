# STACK - Technology Stack

## Languages & Runtime

- **Primary Language**: Lua 5.x (pure Lua, no external dependencies)
- **Target Platform**: Project Sylvanas bot for TBC Classic WoW (version 2.4.3)
- **Execution Environment**: Sylvanas plugin system with embedded Lua runtime

## Dependencies

No external package manager. All dependencies are:
- Built into Sylvanas core (`core.*` API)
- Required from shared modules via `require()`

### Core Sylvanas APIs (injected at runtime)
```lua
core.object_manager     -- Unit/object tracking
core.spell_book        -- Spell book, cooldowns, ranges
core.menu              -- UI configuration
core.input             -- Spell/item casting
core.game_time         -- Time utilities
core.log               -- Logging
core.graphics          -- Notifications
core.inventory         -- Bag scanning
```

### Shared Module Dependencies
```lua
common/utility/key_helper
common/utility/auto_attack_helper
common/utility/spell_queue
common/utility/inventory_helper
common/utility/control_panel_helper
common/modules/buff_manager
common/modules/spell_queue
common/geometry/vector_2
common/color
```

## Configuration

- **Version**: 2.1.0 (per CHANGELOG.md)
- **Spec Count**: 27 specs across 9 classes
- **Repository**: https://github.com/eaxiumnet/eax-tbc-classic-rotations

## Key Libraries

| Library | Purpose |
|---------|---------|
| `ps_theme` | Custom UI theme (Space v4.0) with animated backgrounds |
| `spell_queue` | GCD-safe spell queuing system |
| `buff_manager` | Buff/debuff tracking via `get_buff_data` API |
| `auto_attack_helper` | Melee attack management |
| `key_helper` | Keybinding utilities |
| `enums` | Power types (COMBOPOINTS_TBC = 4) |

## Build/Deploy

No build step. Plugins are pure Lua files copied to Sylvanas scripts folder.
