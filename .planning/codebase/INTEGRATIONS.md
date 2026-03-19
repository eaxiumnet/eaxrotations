# INTEGRATIONS - External Services & APIs

## Game Integration

### Sylvanas Core API
The entire codebase integrates with Project Sylvanas bot via injected `core.*` namespace.

**Object Management**
```lua
core.object_manager.get_local_player()     -- Get player unit
core.object_manager.get_visible_objects() -- Get nearby units
core.object_manager.get_all_objects()     -- Get all units in memory
```

**Spell Book**
```lua
core.spell_book.is_spell_learned(spell_id)
core.spell_book.is_usable_spell(spell_id)
core.spell_book.get_spell_cooldown(spell_id)
core.spell_book.is_spell_in_range(spell_id, target, caster)
core.spell_book.is_current_spell(spell_id)
core.spell_book.get_spell_cast_time(spell_id)
core.spell_book.is_item_usable(item_id)
core.spell_book.has_item_range(item_id)
```

**Input/Casting**
```lua
core.input.use_item(item_id)              -- Use item from bags
core.input.set_target(unit)              -- Set target
spell_queue:queue_spell_target(spell_id, target, priority)
spell_queue:queue_spell_target_fast(spell_id, target, priority)
```

**UI/Menu**
```lua
core.menu.checkbox(default, key)
core.menu.keybind(default, toggle, key)
core.menu.slider_int(min, max, default, key)
core.menu.combobox(default, key)
core.menu.window(name)
```

**Game State**
```lua
core.time()                              -- Current timestamp
core.game_time()                          -- Game time
core.get_instance_type()                 -- "raid", "pvpzone", "none"
```

## Data Sources

### TBC Classic Spell Data
- Spell IDs hardcoded in `spells.lua` rank tables
- All 27 specs have complete rank tables (highest-to-lowest order)
- Buff/debuff ID tables for tracking

### TBC Classic Boss Database
- `encounter_manager.lua` contains full boss database
- Covers all TBC dungeons and raids:
  - Hellfire Citadel, Coilfang Reservoir, Auchindoun
  - Caverns of Time, Tempest Keep, Magister's Terrace
  - Karazhan, Gruul's Lair, Serpentshrine Cavern, The Eye
  - Hyjal Summit, Black Temple, Zul'Aman, Sunwell Plateau

### TBC Set Bonus Data
- `utils.lua` contains `TBC_SETS` table with item IDs
- Warbringer, WarbringerBattlegear, Ymirjar sets
- Multipliers: 2pc = 1.05, 4pc = 1.10

## No External Integrations

- No network APIs
- No databases
- No authentication systems
- No webhooks
- No cloud services
