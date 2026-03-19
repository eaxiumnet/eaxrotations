# ARCHITECTURE - Architecture Analysis

## Current Architecture

```
EAX Spec Folder (×27)
├── main.lua          -- Rotation logic, on_update loop
├── spells.lua        -- Spell ID rank tables
├── utils.lua        -- Casting helpers, targeting, set bonuses
├── menu.lua         -- ImGui configuration
├── interrupt_manager.lua   -- Priority interrupt (duplicate ×27)
├── defensive_manager.lua    -- HP-threshold defensives (duplicate ×27)
├── encounter_manager.lua    -- Boss database (duplicate ×27)
├── ooc_manager.lua         -- OOC utilities (duplicate ×27)
├── leveling_manager.lua   -- Leveling support
├── racial_manager.lua     -- Racial abilities
├── ttd_tracker.lua      -- Time-to-death
├── esp_renderer.lua     -- Visual overlay
├── ps_theme.lua        -- UI theme
└── EAXClassSpec.toc   -- TOC file
```

**Key problem**: 27 near-identical copies of shared managers. Maintenance nightmare.

## Reference Architecture: Tempest

Tempest uses SimC APL parsing with native execution:
1. Load `.simc` action priority list
2. Parse into internal state machine
3. Evaluate conditions every tick
4. Execute highest-priority available action

**Advantage**: Mathematically optimal, easy to update from simc data
**EAX approach**: Hardcoded Lua conditionals (more portable, no parser needed)

## Required Architecture Changes

### 1. Shared Module Extraction

Extract these to `common/eax_shared/`:
```
common/eax_shared/
├── interrupt_manager.lua  -- Single source of truth
├── defensive_manager.lua   -- Single source of truth
├── encounter_manager.lua   -- Single source of truth
├── ooc_manager.lua        -- Single source of truth
├── set_bonus.lua         -- Dynamic set bonus scanner
└── dps_meter.lua        -- Integrated DPS tracking
```

Each spec then requires the shared module. Updates propagate instantly.

### 2. Rotation Priority Tables

Move spell priority lists from `main.lua` to `spells.lua` or a new `rotation.lua`:

```lua
-- Warrior Arms rotation table
ROTATION_PRIORITY = {
    { name = "charge",     check = "pre_combat",  spell = "charge" },
    { name = "overpower",  check = "dodge_recent", spell = "overpower" },
    { name = "mortal_strike", check = "cooldown", spell = "mortal_strike" },
    { name = "execute",     check = "below_20pct", spell = "execute" },
    { name = "whirlwind",  check = "cd_and_rage", spell = "whirlwind" },
    { name = "slam",       check = "swing_ready", spell = "slam" },
    { name = "battle_shout", check = "no_buff",   spell = "battle_shout" },
}
```

This enables:
- Simpler main loop: evaluate table, execute first available
- Easier rotation tuning (data, not code)
- Future: could parse simc output into this format

### 3. Swing Timer Library

For Warrior/Rogue/Hunter specs, extract swing timing to a shared helper:

```lua
common/eax_shared/swing_timer.lua

-- Returns: "ready" | "pending" | "clipping"
swing_timer.get_state(me, weapon_count)
swing_timer.get_ms_until_swing(me, weapon_count)
swing_timer.is_safe_to_queue(me, cast_time_ms, weapon_count)
```

### 4. Set Bonus Scanner

Replace hardcoded `TBC_SETS` table with dynamic scanning:

```lua
common/eax_shared/set_bonus.lua

-- Returns multiplier for a set name
set_bonus.get_multiplier(me, "Warbringer")
set_bonus.get_multiplier(me, "Colossus")

-- Or: query all active set bonuses
set_bonus.get_all_active(me)
```

Use `me:get_item_at_inventory_slot()` to scan equipped items, match against set item IDs.

## Build Order

Dependencies between components:

```
1. Shared module extraction (foundation)
   ↓
2. Set bonus scanner (critical missing feature)
   ↓
3. Rotation priority tables (makes tuning easier)
   ↓
4. Swing timer library (Warrior/Rogue/Hunter specs)
   ↓
5. DoT clip prevention (Warlock/Druid/Priest)
   ↓
6. DPS meter (benchmarking)
   ↓
7. Consumables automation (polish)
```

## Data Flow (Proposed)

```
Sylvanas Tick
    │
    ├── esp_renderer.on_render()
    │
    └── on_update()
        │
        ├── Toggle Check
        ├── OOC Manager (shared)
        ├── Mode Detection
        ├── Set Bonus Scanner (shared)
        ├── Target Finder
        ├── Rotation Evaluator
        │   └── for each priority in ROTATION_PRIORITY
        │       if check_function() then cast() end
        ├── Interrupt Manager (shared)
        └── Defensive Manager (shared)
```

## Component Boundaries

| Component | Reads | Writes |
|-----------|-------|--------|
| main.lua | spells.lua, utils.lua, shared managers | Rotation decisions |
| utils.lua | core APIs | Cached spell IDs, set multipliers |
| shared managers | core APIs | Class-specific state |
| esp_renderer | menu, runtime state | Visual overlay |
| menu.lua | core.menu | Config state |
