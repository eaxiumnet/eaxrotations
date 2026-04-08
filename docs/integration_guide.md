# EAX Integration Guide for Sylvanas TBC Classic Rotations

**Version**: 1.0.0  
**Last Updated**: 2026-04-07  
**Applies To**: All 27 EAX TBC Classic spec plugins

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Middleware Integration Guide](#2-middleware-integration-guide)
3. [Dashboard Integration Guide](#3-dashboard-integration-guide)
4. [PvP Menu Integration Guide](#4-pvp-menu-integration-guide)
5. [Migration Checklist](#5-migration-checklist)
6. [Testing Instructions](#6-testing-instructions)

---

## 1. Executive Summary

### System Architecture

The EAX rotation framework provides Sylvanas-compatible libraries:

| Component | Library | Purpose |
|-----------|---------|---------|
| `middleware.lua` | `libraries/middleware.lua` | Cross-cutting rotation concerns (healthstones, potions, racials) |
| `dashboard.lua` | `libraries/dashboard.lua` | Combat HUD with resource bars, cooldowns, buffs/debuffs |
| `compat.lua` | `libraries/compat.lua` | Compatibility layer for core utilities |

### What's Available Now

**Middleware System** (`libraries/middleware.lua`):
- Priority-based execution (higher priority = executes first)
- Pre-built factories for common patterns:
  - `middleware.healthstone(spell_id, threshold_pct)`
  - `middleware.healing_potion(item_id, threshold_pct)`
  - `middleware.mana_potion(item_id, threshold_pct)`
  - `middleware.defensive_racial(spell_id, threshold_pct)`
  - `middleware.offensive_racial(spell_id)`
  - `middleware.emergency_heal(spell_id, threshold_pct, requires_combo_points)`
  - `middleware.self_buff(spell_id, buff_id, ooc_only)`
- Force command integration (burst/defensive)
- GCD gating support

**Dashboard System** (`libraries/dashboard.lua`):
- Resource bar (rage/energy/mana/focus)
- Cooldown tracking with visual icons
- Buff/debuff monitoring
- IZI SDK integration for spell icons
- 10Hz throttled updates
- EAX-compatible theming

**Compatibility Layer** (`libraries/compat.lua`):
- Safe menu access with nil guards
- Context builder for combat state
- Settings cache (50ms throttle)
- Force flag system
- Spell helper wrappers

### Migration Path for Other Specs

All 27 specs should use:
1. **Middleware** for healthstones, potions, and racials (replaces manual checks in rotation)
2. **Dashboard** for combat visualization (optional but recommended)
3. **PvP Menu** for PvP-specific settings (melee specs, hunters)

---

## 2. Middleware Integration Guide

### Priority Levels Reference

```lua
local PRIORITY = {
    FORM_RESHIFT = 500,      -- Druid form management
    EMERGENCY_HEAL = 400,    -- Self-heals (Frenzied Regen, etc.)
    RECOVERY_ITEMS = 300,    -- Healthstones, healing potions
    MANA_RECOVERY = 280,     -- Mana potions
    SELF_BUFFS = 150,        -- Self-cast buffs
    OFFENSIVE_CDS = 100,     -- Offensive cooldowns/racials
    PVP_DEFENSIVE = 90,      -- PvP defensive abilities
    INTERRUPTS = 50,         -- Interrupts
}
```

### Per-Spec Middleware Requirements

#### Warriors (Arms, Fury, Protection)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Defensive Racial (all specs)
- Offensive Racial (all specs)

**Menu Settings to Add** (in `menu.lua`):
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
menu.use_offensive_racial = menu.add_checkbox("Use Offensive Racial", true)
```

**Integration Code** (in `main.lua`):
```lua
-- At top of file
local middleware = require("libraries/middleware")
local spells = require("libraries/spells")

-- In on_load() or initialization
local function setup_middleware()
    -- Healthstone
    middleware.register(middleware.healthstone(
        spells.HEALTHSTONE_ITEMS[1],  -- 22105 (Master Healthstone)
        (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30
    ))
    
    -- Healing Potion
    middleware.register(middleware.healing_potion(
        22829,  -- Super Healing Potion
        (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25
    ))
    
    -- Defensive Racial (Stoneform for Dwarf, etc.)
    local defensive_racial_id = spells.STONEFORM[1]  -- or spells.BLOOD_FURY, etc.
    if defensive_racial_id then
        middleware.register(middleware.defensive_racial(
            defensive_racial_id,
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
    
    -- Offensive Racial (Blood Fury for Orc, etc.)
    local offensive_racial_id = spells.BLOOD_FURY[1]  -- or spells.BERSERKING, etc.
    if offensive_racial_id then
        middleware.register(middleware.offensive_racial(
            offensive_racial_id
        ))
    end
end

-- In rotation update loop (before main rotation logic)
local function execute_middleware(icon, me, target)
    local settings = {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        use_defensive_racial = (menu.use_defensive_racial and menu.use_defensive_racial:get()) or true,
        use_offensive_racial = (menu.use_offensive_racial and menu.use_offensive_racial:get()) or true,
    }
    
    local context = middleware.build_context(me, target, settings)
    local result, msg = middleware.execute(icon, context)
    if result then
        return result, msg
    end
    
    -- Continue with main rotation...
end
```

---

#### Druids (Balance, Feral, Bear, Resto)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Mana Potion (Balance, Resto)
- Emergency Heal (Feral - Frenzied Regeneration)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)  -- Balance/Resto only
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)

-- Feral Only
menu.use_emergency_heal = menu.add_checkbox("Use Frenzied Regeneration", true)
menu.emergency_heal_threshold = menu.add_slider("Frenzied Regen Threshold", 35, 10, 60)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")
local spells = require("libraries/spells")

-- In on_load() or initialization
local function setup_middleware()
    -- Common recovery items
    middleware.setup_common({
        healthstone_id = spells.HEALTHSTONE_ITEMS and spells.HEALTHSTONE_ITEMS[1],
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        healing_potion_id = 22829,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
    })
    
    -- Mana potion for casters
    if menu.use_mana_potion then
        middleware.register(middleware.mana_potion(
            22832,  -- Super Mana Potion
            (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20
        ))
    end
    
    -- Feral: Frenzied Regeneration emergency heal
    if spells.FRENZIED_REGENERATION and menu.use_emergency_heal then
        middleware.register(middleware.emergency_heal(
            spells.FRENZIED_REGENERATION[1],
            (menu.emergency_heal_threshold and menu.emergency_heal_threshold:get()) or 35,
            middleware.PRIORITY.EMERGENCY_HEAL,
            false  -- Does not require combo points
        ))
    end
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Hunters (BM, MM, Survival)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Mana Potion (all specs - hunters are mana users)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for hunters (includes mana potion)
    middleware.create_class_set("hunter", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get()) or true,
        mana_potion_threshold = (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Mages (Arcane, Fire, Frost)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Mana Potion (all specs)
- Defensive Racial (all specs)
- Self Buff (Molten Armor/Ice Armor based on spec)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)

-- Buffs Section
menu.maintain_self_buff = menu.add_checkbox("Maintain Armor Buff", true)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for mages (includes mana potion)
    middleware.create_class_set("mage", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get()) or true,
        mana_potion_threshold = (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20,
    })
    
    -- Self buff (Molten Armor for Fire, Ice Armor for Frost, Mage Armor for Arcane)
    local armor_spell = nil
    local armor_buff = nil
    if menu.maintain_self_buff and menu.maintain_self_buff:get() then
        if spells.MOLTEN_ARMOR and #spells.MOLTEN_ARMOR > 0 then
            armor_spell = spells.MOLTEN_ARMOR[1]
            armor_buff = spells.MOLTEN_ARMOR[1]
        elseif spells.ICE_ARMOR and #spells.ICE_ARMOR > 0 then
            armor_spell = spells.ICE_ARMOR[1]
            armor_buff = spells.ICE_ARMOR[1]
        elseif spells.MAGE_ARMOR and #spells.MAGE_ARMOR > 0 then
            armor_spell = spells.MAGE_ARMOR[1]
            armor_buff = spells.MAGE_ARMOR[1]
        end
        
        if armor_spell then
            middleware.register(middleware.self_buff(
                armor_spell,
                armor_buff,
                middleware.PRIORITY.SELF_BUFFS,
                false  -- Can cast in combat
            ))
        end
    end
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Paladins (Holy, Protection, Retribution)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Emergency Heal (all specs - Holy Light)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_emergency_heal = menu.add_checkbox("Use Holy Light Self-Heal", true)
menu.emergency_heal_threshold = menu.add_slider("Self-Heal Threshold", 30, 10, 60)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for paladins (includes emergency heal)
    middleware.create_class_set("paladin", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_emergency_heal = (menu.use_emergency_heal and menu.use_emergency_heal:get()) or true,
        emergency_heal_id = spells.HOLY_LIGHT and spells.HOLY_LIGHT[1],
        emergency_heal_threshold = (menu.emergency_heal_threshold and menu.emergency_heal_threshold:get()) or 30,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Priests (Discipline, Holy, Shadow, Smite)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Mana Potion (all specs)
- Emergency Heal (all specs - Flash Heal/Greater Heal)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)
menu.use_emergency_heal = menu.add_checkbox("Use Self-Heal", true)
menu.emergency_heal_threshold = menu.add_slider("Self-Heal Threshold", 30, 10, 60)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for priests (includes mana potion + emergency heal)
    middleware.create_class_set("priest", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get()) or true,
        mana_potion_threshold = (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20,
        use_emergency_heal = (menu.use_emergency_heal and menu.use_emergency_heal:get()) or true,
        emergency_heal_id = spells.FLASH_HEAL and spells.FLASH_HEAL[1],
        emergency_heal_threshold = (menu.emergency_heal_threshold and menu.emergency_heal_threshold:get()) or 30,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Rogues (Assassination, Combat, Subtlety)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Common recovery items only (rogues don't use mana)
    middleware.setup_common({
        healthstone_id = spells.HEALTHSTONE_ITEMS and spells.HEALTHSTONE_ITEMS[1],
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        healing_potion_id = 22829,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Shamans (Elemental, Enhancement, Restoration)

**Required Middleware**:
- Healthstone (all specs)
- Healing Potion (all specs)
- Mana Potion (all specs)
- Emergency Heal (all specs - Healing Wave)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)
menu.use_emergency_heal = menu.add_checkbox("Use Healing Wave Self-Heal", true)
menu.emergency_heal_threshold = menu.add_slider("Self-Heal Threshold", 30, 10, 60)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for shamans (includes mana potion + emergency heal)
    middleware.create_class_set("shaman", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get()) or true,
        mana_potion_threshold = (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20,
        use_emergency_heal = (menu.use_emergency_heal and menu.use_emergency_heal:get()) or true,
        emergency_heal_id = spells.HEALING_WAVE and spells.HEALING_WAVE[1],
        emergency_heal_threshold = (menu.emergency_heal_threshold and menu.emergency_heal_threshold:get()) or 30,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

#### Warlocks (Affliction, Demonology, Destruction)

**Required Middleware**:
- Healthstone (all specs - can use their own)
- Healing Potion (all specs)
- Mana Potion (all specs)
- Defensive Racial (all specs)

**Menu Settings to Add**:
```lua
-- Recovery Section
menu.use_healthstone = menu.add_checkbox("Use Healthstone", true)
menu.healthstone_threshold = menu.add_slider("Healthstone Threshold", 30, 10, 50)
menu.use_healing_potion = menu.add_checkbox("Use Healing Potion", true)
menu.healing_potion_threshold = menu.add_slider("Potion Threshold", 25, 10, 50)
menu.use_mana_potion = menu.add_checkbox("Use Mana Potion", true)
menu.mana_potion_threshold = menu.add_slider("Mana Potion Threshold", 20, 5, 50)

-- Racial Section
menu.use_defensive_racial = menu.add_checkbox("Use Defensive Racial", true)
menu.defensive_racial_threshold = menu.add_slider("Defensive Racial Threshold", 40, 10, 60)
```

**Integration Code**:
```lua
-- At top of file
local middleware = require("libraries/middleware")

-- In on_load() or initialization
local function setup_middleware()
    -- Use class-specific setup for warlocks (includes mana potion)
    middleware.create_class_set("warlock", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        use_mana_potion = (menu.use_mana_potion and menu.use_mana_potion:get()) or true,
        mana_potion_threshold = (menu.mana_potion_threshold and menu.mana_potion_threshold:get()) or 20,
    })
    
    -- Defensive racial
    if spells.STONEFORM then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end
```

---

## 3. Dashboard Integration Guide

### Per-Class Resource Types

| Class | Resource Type | Dashboard Color |
|-------|--------------|-----------------|
| Warrior | `rage` | Red (#B43C3C) |
| Druid (Feral/Bear) | `energy` or `rage` | Yellow (#FFDC00) or Red |
| Rogue | `energy` | Yellow (#FFDC00) |
| Hunter | `mana` | Blue (#3C64B4) |
| Mage | `mana` | Blue (#3C64B4) |
| Paladin | `mana` | Blue (#3C64B4) |
| Priest | `mana` | Blue (#3C64B4) |
| Shaman | `mana` | Blue (#3C64B4) |
| Warlock | `mana` | Blue (#3C64B4) |

### Per-Spec Cooldown Lists

#### Warrior Specs (Arms, Fury, Protection)

```lua
-- Cooldowns to track
local cooldowns = {
    spells.DEATH_WISH[1],       -- 12328
    spells.RECKLESSNESS[1],     -- 1719
    spells.BLOODRAGE[1],        -- 2687
    spells.BERSERKER_RAGE[1],   -- 18499
}

-- Buffs to track
local buffs = {
    spells.BUFF_BATTLE_SHOUT[1],      -- 25289
    spells.BUFF_DEATH_WISH[1],        -- 12328
    spells.BUFF_BERSERKER_RAGE[1],    -- 18499
    spells.BUFF_FLURRY[1],            -- 16259 (Fury only)
}

-- Debuffs to track on target
local debuffs = {
    spells.DEBUFF_SUNDER_ARMOR[1],    -- 25225
    spells.DEBUFF_DEMORALIZING_SHOUT[1], -- 25202
}
```

#### Druid Specs

**Balance**:
```lua
local cooldowns = {
    spells.FORCE_OF_NATURE[1],  -- 33831 (Treants)
    spells.INNERVATE[1],        -- 29166
}

local buffs = {
    spells.BUFF_MOONKIN_FORM[1],     -- 24858
    spells.BUFF_INNERVATE[1],        -- 29166
}

local debuffs = {
    spells.DEBUFF_MOONFIRE[1],        -- 26988
    spells.DEBUFF_INSECT_SWARM[1],    -- 27013
}
```

**Feral/Bear**:
```lua
local cooldowns = {
    spells.TIGERS_FURY[1],      -- 9846
    spells.BERSERK[1],          -- 50334 (WotLK, check TBC equivalent)
    spells.FRENZIED_REGENERATION[1], -- 22842
}

local buffs = {
    spells.BUFF_CAT_FORM[1],          -- 768
    spells.BUFF_BEAR_FORM[1],         -- 5487
    spells.BUFF_TIGERS_FURY[1],       -- 9846
}

local debuffs = {
    spells.DEBUFF_RAKE[1],            -- 27003
    spells.DEBUFF_RIP[1],             -- 27008
    spells.DEBUFF_MANGLE[1],          -- 33983
}
```

**Resto**:
```lua
local cooldowns = {
    spells.INNERVATE[1],        -- 29166
    spells.TRANQUILITY[1],      -- 26983
}

local buffs = {
    spells.BUFF_TREE_OF_LIFE[1],      -- 33891
    spells.BUFF_REJUVENATION[1],      -- 26981
    spells.BUFF_REGROWTH[1],          -- 26980
}
```

#### Hunter Specs

```lua
-- All hunter specs
local cooldowns = {
    spells.RAPID_FIRE[1],       -- 3045
    spells.BESTIAL_WRATH[1],    -- 19574 (BM only)
    spells.READINESS[1],        -- 23989 (MM only)
    spells.TRAP_LAUNCHER[1],    -- 77769 (check TBC ID)
}

local buffs = {
    spells.BUFF_RAPID_FIRE[1],        -- 3045
    spells.BUFF_ASPECT_OF_THE_HAWK[1], -- 27044
    spells.BUFF_BESTIAL_WRATH[1],     -- 19574 (BM only)
}

local debuffs = {
    spells.DEBUFF_HUNTERS_MARK[1],    -- 14325
    spells.DEBUFF_SERPENT_STING[1],  -- 27016
    spells.DEBUFF_SCORPID_STING[1],  -- 3043
}
```

#### Mage Specs

```lua
-- All mage specs
local cooldowns = {
    spells.ICY_VEINS[1],        -- 12472
    spells.COMBUSTION[1],       -- 11129 (Fire)
    spells.ARCANE_POWER[1],     -- 12042 (Arcane)
    spells.COLD_SNAP[1],        -- 12472 (Frost)
    spells.EVOCATION[1],        -- 12051
}

local buffs = {
    spells.BUFF_ICY_VEINS[1],         -- 12472
    spells.BUFF_COMBUSTION[1],        -- 11129
    spells.BUFF_ARCANE_POWER[1],      -- 12042
    spells.BUFF_ICE_BLOCK[1],         -- 45438
}

local debuffs = {
    spells.DEBUFF_IMPROVED_SCORCH[1], -- 22959 (Fire Vulnerability)
}
```

#### Paladin Specs

```lua
-- All paladin specs
local cooldowns = {
    spells.AVENGING_WRATH[1],   -- 31884
    spells.DIVINE_PROTECTION[1], -- 498
    spells.DIVINE_SHIELD[1],    -- 642
    spells.BLESSING_OF_PROTECTION[1], -- 10278
}

local buffs = {
    spells.BUFF_AVENGING_WRATH[1],    -- 31884
    spells.BUFF_DIVINE_SHIELD[1],     -- 642
    spells.BUFF_SEAL_OF_COMMAND[1], -- 27170 (Ret)
    spells.BUFF_SEAL_OF_BLOOD[1],    -- 31892 (Ret)
}
```

#### Priest Specs

```lua
-- All priest specs
local cooldowns = {
    spells.POWER_INFUSION[1],   -- 10060
    spells.INNER_FOCUS[1],      -- 14751
    spells.PAIN_SUPPRESSION[1], -- 33206 (Disc)
    spells.SHADOW_FIEND[1],     -- 34433
}

local buffs = {
    spells.BUFF_POWER_WORD_SHIELD[1], -- 25218
    spells.BUFF_RENEW[1],             -- 25222
    spells.BUFF_SHADOWFORM[1],        -- 15473
    spells.BUFF_VAMPIRIC_EMBRACE[1],  -- 15286
}

local debuffs = {
    spells.DEBUFF_SHADOW_WORD_PAIN[1], -- 25368
    spells.DEBUFF_VAMPIRIC_TOUCH[1],   -- 34917 (check TBC ID)
}
```

#### Rogue Specs

```lua
-- All rogue specs
local cooldowns = {
    spells.ADRENALINE_RUSH[1],  -- 13750 (Combat)
    spells.BLADE_FLURRY[1],     -- 13877 (Combat)
    spells.COLD_BLOOD[1],       -- 14177 (Assassination)
    spells.PREPARATION[1],      -- 14185 (Subtlety)
    spells.VANISH[1],           -- 26889
}

local buffs = {
    spells.BUFF_SLICE_AND_DICE[1],    -- 6774
    spells.BUFF_BLADE_FLURRY[1],    -- 13877
    spells.BUFF_ADRENALINE_RUSH[1],  -- 13750
    spells.BUFF_STEALTH[1],         -- 1787
}

local debuffs = {
    spells.DEBUFF_RUPTURE[1],         -- 26867
    spells.DEBUFF_DEADLY_POISON[1],   -- 27282
}
```

#### Shaman Specs

```lua
-- All shaman specs
local cooldowns = {
    spells.BLOODLUST[1],        -- 2825
    spells.HEROISM[1],          -- 32182 (Alliance)
    spells.SHAMANISTIC_RAGE[1], -- 30823 (Enhancement)
    spells.EARTH_SHIELD[1],     -- 32594 (Resto)
    spells.NATURES_SWIFTNESS[1], -- 16188
}

local buffs = {
    spells.BUFF_BLOODLUST[1],         -- 2825
    spells.BUFF_LIGHTNING_SHIELD[1], -- 25472
    spells.BUFF_WATER_SHIELD[1],    -- 33736
    spells.BUFF_EARTH_SHIELD[1],    -- 32594
}

local debuffs = {
    spells.DEBUFF_FLAME_SHOCK[1],     -- 25457
    spells.DEBUFF_EARTH_SHOCK[1],   -- 25454
}
```

#### Warlock Specs

```lua
-- All warlock specs
local cooldowns = {
    spells.SOULSHATTER[1],      -- 29858
    spells.DEATH_COIL[1],       -- 27223
    spells.SUMMON_FELGUARD[1],  -- 30146 (Demonology)
}

local buffs = {
    spells.BUFF_DEMON_ARMOR[1],       -- 27260
    spells.BUFF_FEL_ARMOR[1],         -- 28189
    spells.BUFF_SOUL_LINK[1],         -- 19028
}

local debuffs = {
    spells.DEBUFF_CORRUPTION[1],      -- 27216
    spells.DEBUFF_IMMOLATE[1],        -- 27215
    spells.DEBUFF_CURSE_OF_AGONY[1], -- 27218
}
```

### Dashboard Config Templates

#### Template for All Specs

```lua
-- At top of main.lua
local dashboard = require("libraries/dashboard")

-- Dashboard configuration
local dashboard_config = {
    class_name = "Warrior Fury",  -- Change per spec
    resource_type = "rage",       -- rage/energy/mana/focus
    
    -- Cooldowns to track (spell IDs from spells.lua)
    cooldowns = {
        12328,  -- Death Wish
        1719,   -- Recklessness
        2687,   -- Bloodrage
    },
    
    -- Buffs to track on player
    buffs = {
        25289,  -- Battle Shout
        12328,  -- Death Wish
    },
    
    -- Debuffs to track on target
    debuffs = {
        25225,  -- Sunder Armor
        25202,  -- Demoralizing Shout
    },
}

-- In on_load()
local function init_dashboard()
    dashboard.init(dashboard_config)
    dashboard.set_enabled((menu.dashboard_enabled and menu.dashboard_enabled:get()) or true)
    dashboard.set_position(
        (menu.dashboard_x and menu.dashboard_x:get()) or 20,
        (menu.dashboard_y and menu.dashboard_y:get()) or 200
    )
    dashboard.set_scale((menu.dashboard_scale and menu.dashboard_scale:get()) or 1.0)
    dashboard.register_render_callback()
end

-- In menu setup
local function setup_dashboard_menu(menu, tree_node)
    menu.dashboard_enabled = menu.add_checkbox("Enable Dashboard", true)
    menu.dashboard_x = menu.add_slider("Dashboard X", 20, 0, 1000)
    menu.dashboard_y = menu.add_slider("Dashboard Y", 200, 0, 1000)
    menu.dashboard_scale = menu.add_slider("Dashboard Scale", 1.0, 0.5, 2.0, 0.1)
    
    -- Add dashboard items to tree
    dashboard.add_menu_items(menu, tree_node)
end
```

---

## 4. PvP Menu Integration Guide

### Which Specs Need PvP Mode

**All Melee Specs** (need snare/slow abilities):
- Warrior (Arms, Fury, Protection) - Hamstring
- Rogue (Assassination, Combat, Subtlety) - Crippling Poison, Gouge
- Feral Druid - Feral Charge, Bash
- Enhancement Shaman - Frost Shock
- Retribution Paladin - Judgment of Justice

**All Hunter Specs** (need kiting abilities):
- Hunter (BM, MM, Survival) - Wing Clip, Concussive Shot

**Casters with PvP modes**:
- Mage (all specs) - Polymorph, Counterspell priority
- Warlock (all specs) - Fear, Death Coil
- Shadow Priest - Silence, Psychic Scream

### Class-Specific PvP Settings

#### Warrior PvP Settings

```lua
-- In menu.lua
menu.pvp_mode = menu.add_checkbox("Enable PvP Mode", false)
menu.pvp_hamstring = menu.add_checkbox("Use Hamstring in PvP", true)
menu.pvp_hamstring_threshold = menu.add_slider("Hamstring Health Threshold", 100, 0, 100)
menu.pvp_piercing_howl = menu.add_checkbox("Use Piercing Howl", true)
menu.pvp_intercept = menu.add_checkbox("Use Intercept", true)
menu.pvp_intimidating_shout = menu.add_checkbox("Use Intimidating Shout", true)

-- In main.lua - PvP detection
local function is_pvp_target(target)
    if not target then return false end
    -- Check if target is a player
    if target.is_player and target:is_player() then
        return true
    end
    -- Check if target is a player's pet
    if target.get_owner and target:get_owner() then
        return true
    end
    return false
end

-- In rotation
local function should_use_hamstring(target)
    if not (menu.pvp_mode and menu.pvp_mode:get()) then return false end
    if not is_pvp_target(target) then return false end
    if not (menu.pvp_hamstring and menu.pvp_hamstring:get()) then return false end
    
    -- Check if target already has hamstring debuff
    if target.has_aura and target:has_aura(spells.DEBUFF_HAMSTRING[1]) then
        return false
    end
    
    -- Check health threshold
    local target_hp = target.get_health_percentage and target:get_health_percentage() or 100
    local threshold = (menu.pvp_hamstring_threshold and menu.pvp_hamstring_threshold:get()) or 100
    
    return target_hp <= threshold
end
```

#### Hunter PvP Settings

```lua
-- In menu.lua
menu.pvp_mode = menu.add_checkbox("Enable PvP Mode", false)
menu.pvp_wing_clip = menu.add_checkbox("Use Wing Clip", true)
menu.pvp_concussive_shot = menu.add_checkbox("Use Concussive Shot", true)
menu.pvp_scatter_shot = menu.add_checkbox("Use Scatter Shot", true)
menu.pvp_viper_sting = menu.add_checkbox("Use Viper Sting (vs casters)", true)
menu.pvp_traps = menu.add_checkbox("Use Traps", true)

-- In main.lua
local function is_pvp_target(target)
    if not target then return false end
    if target.is_player and target:is_player() then return true end
    if target.get_owner and target:get_owner() then return true end
    return false
end

local function should_use_wing_clip(me, target)
    if not (menu.pvp_mode and menu.pvp_mode:get()) then return false end
    if not is_pvp_target(target) then return false end
    if not (menu.pvp_wing_clip and menu.pvp_wing_clip:get()) then return false end
    
    -- Only in melee range
    local dist = me.distance_to and me:distance_to(target) or 999
    if dist > 8 then return false end
    
    -- Check if already debuffed
    if target.has_aura and target:has_aura(spells.DEBUFF_WING_CLIP[1]) then
        return false
    end
    
    return true
end
```

#### Rogue PvP Settings

```lua
-- In menu.lua
menu.pvp_mode = menu.add_checkbox("Enable PvP Mode", false)
menu.pvp_crippling_poison = menu.add_checkbox("Maintain Crippling Poison", true)
menu.pvp_gouge = menu.add_checkbox("Use Gouge", true)
menu.pvp_blind = menu.add_checkbox("Use Blind", true)
menu.pvp_kidney_shot = menu.add_checkbox("Use Kidney Shot", true)
menu.pvp_preparation = menu.add_checkbox("Use Preparation", true)

-- In main.lua
local function is_pvp_target(target)
    if not target then return false end
    if target.is_player and target:is_player() then return true end
    if target.get_owner and target:get_owner() then return true end
    return false
end
```

#### Feral Druid PvP Settings

```lua
-- In menu.lua
menu.pvp_mode = menu.add_checkbox("Enable PvP Mode", false)
menu.pvp_feral_charge = menu.add_checkbox("Use Feral Charge", true)
menu.pvp_bash = menu.add_checkbox("Use Bash", true)
menu.pvp_maim = menu.add_checkbox("Use Maim", true)
menu.pvp_cyclone = menu.add_checkbox("Use Cyclone", true)

-- In main.lua
local function is_pvp_target(target)
    if not target then return false end
    if target.is_player and target:is_player() then return true end
    if target.get_owner and target:get_owner() then return true end
    return false
end
```

### Detection Logic Setup

```lua
-- Common PvP detection module (can be added to libraries/utils.lua)

-- PvP state tracking
local pvp_state = {
    last_check = 0,
    check_interval = 1.0,  -- Check every second
    is_pvp = false,
    pvp_target_count = 0,
}

-- Detect if we're in a PvP situation
function utils.detect_pvp_mode(me, scan_radius)
    local now = core.time()
    if now - pvp_state.last_check < pvp_state.check_interval then
        return pvp_state.is_pvp, pvp_state.pvp_target_count
    end
    
    pvp_state.last_check = now
    pvp_state.pvp_target_count = 0
    
    if not me then
        pvp_state.is_pvp = false
        return false, 0
    end
    
    scan_radius = scan_radius or 40
    local me_x, me_y, me_z = me:get_position()
    
    -- Get objects in range
    local objects = core.object_manager.get_objects_in_radius(me_x, me_y, me_z, scan_radius)
    
    for _, obj in ipairs(objects) do
        if obj and obj.is_valid and obj:is_valid() then
            -- Check if it's a hostile player
            if obj.is_player and obj:is_player() then
                if obj.is_hostile and obj:is_hostile(me) then
                    pvp_state.pvp_target_count = pvp_state.pvp_target_count + 1
                end
            end
            -- Check if it's a hostile player pet
            if obj.get_owner and obj:get_owner() then
                local owner = obj:get_owner()
                if owner and owner.is_hostile and owner:is_hostile(me) then
                    pvp_state.pvp_target_count = pvp_state.pvp_target_count + 1
                end
            end
        end
    end
    
    -- Consider it PvP mode if we have any PvP targets
    pvp_state.is_pvp = pvp_state.pvp_target_count > 0
    
    return pvp_state.is_pvp, pvp_state.pvp_target_count
end

-- Check if specific target is a PvP target
function utils.is_pvp_target(target)
    if not target then return false end
    
    -- Direct player check
    if target.is_player and target:is_player() then
        return true
    end
    
    -- Pet check
    if target.get_owner and target:get_owner() then
        return true
    end
    
    return false
end

-- Get PvP mode setting with auto-detection
function utils.get_pvp_mode_setting(menu, me)
    local mode = (menu.mode and menu.mode:get()) or 1
    
    -- Mode 1 = Auto, Mode 2 = PVE Only, Mode 3 = PVP Only
    if mode == 1 then
        -- Auto - detect based on targets
        local is_pvp, count = utils.detect_pvp_mode(me)
        return is_pvp
    elseif mode == 3 then
        -- Force PvP
        return true
    else
        -- PVE only
        return false
    end
end
```

---

## 5. Migration Checklist

### Step-by-Step for Each Spec

Copy this checklist for each of the 26 remaining specs:

```markdown
## EAX<CLASS><SPEC> Migration Checklist

### Phase 1: Middleware Integration
- [ ] Add `local middleware = require("libraries/middleware")` to main.lua
- [ ] Add middleware menu settings to menu.lua
  - [ ] use_healthstone checkbox
  - [ ] healthstone_threshold slider
  - [ ] use_healing_potion checkbox
  - [ ] healing_potion_threshold slider
  - [ ] use_mana_potion checkbox (if mana user)
  - [ ] mana_potion_threshold slider (if mana user)
  - [ ] use_emergency_heal checkbox (if applicable)
  - [ ] emergency_heal_threshold slider (if applicable)
  - [ ] use_defensive_racial checkbox
  - [ ] defensive_racial_threshold slider
  - [ ] use_offensive_racial checkbox
- [ ] Create `setup_middleware()` function in main.lua
- [ ] Register healthstone middleware
- [ ] Register healing potion middleware
- [ ] Register mana potion middleware (if mana user)
- [ ] Register emergency heal middleware (if applicable)
- [ ] Register defensive racial middleware
- [ ] Register offensive racial middleware
- [ ] Call `setup_middleware()` in on_load()
- [ ] Add middleware execution to rotation update loop
- [ ] Test: Verify middleware.execute() returns before main rotation

### Phase 2: Dashboard Integration
- [ ] Add `local dashboard = require("libraries/dashboard")` to main.lua
- [ ] Define dashboard_config with:
  - [ ] class_name
  - [ ] resource_type (rage/energy/mana)
  - [ ] cooldowns array (spell IDs)
  - [ ] buffs array (spell IDs)
  - [ ] debuffs array (spell IDs)
- [ ] Add dashboard menu settings to menu.lua
  - [ ] dashboard_enabled checkbox
  - [ ] dashboard_x slider
  - [ ] dashboard_y slider
  - [ ] dashboard_scale slider
- [ ] Create `init_dashboard()` function in main.lua
- [ ] Call `dashboard.init(dashboard_config)`
- [ ] Call `dashboard.set_enabled()`
- [ ] Call `dashboard.set_position()`
- [ ] Call `dashboard.set_scale()`
- [ ] Call `dashboard.register_render_callback()`
- [ ] Call `init_dashboard()` in on_load()
- [ ] Test: Verify dashboard renders in-game

### Phase 3: PvP Menu Integration (if applicable)
- [ ] Add PvP menu settings to menu.lua
  - [ ] pvp_mode checkbox
  - [ ] Class-specific PvP abilities
- [ ] Add `is_pvp_target()` helper function
- [ ] Add PvP ability checks to rotation
- [ ] Test: Verify PvP abilities trigger on players

### Phase 4: Validation
- [ ] Run `luac -p main.lua` - must pass
- [ ] Run `luac -p libraries/menu.lua` - must pass
- [ ] Run `luac -p libraries/spells.lua` - must pass
- [ ] Run `luac -p libraries/utils.lua` - must pass
- [ ] Verify no nil reference errors in menu access
- [ ] Test in-game: Verify rotation still works
- [ ] Test in-game: Verify middleware triggers
- [ ] Test in-game: Verify dashboard displays
```

### Quick Reference: Specs by Class

| Class | Specs | Middleware | Dashboard | PvP Menu |
|-------|-------|------------|-----------|----------|
| Druid | Balance, Feral, Bear, Resto | ✅ | ✅ | Feral/Bear only |
| Hunter | BM, MM, Survival | ✅ | ✅ | ✅ All |
| Mage | Arcane, Fire, Frost | ✅ | ✅ | Optional |
| Paladin | Holy, Protection, Ret | ✅ | ✅ | Ret only |
| Priest | Disc, Holy, Shadow, Smite | ✅ | ✅ | Shadow/Smite only |
| Rogue | Assassination, Combat, Sub | ✅ | ✅ | ✅ All |
| Shaman | Elemental, Enhancement, Resto | ✅ | ✅ | Enhancement only |
| Warlock | Affliction, Demonology, Destro | ✅ | ✅ | Optional |
| Warrior | Arms, Fury, Protection | ✅ | ✅ | ✅ All |

---

## 6. Testing Instructions

### How to Verify Integration Works

#### 1. Syntax Validation

```bash
# Validate all modified files
luac -p EAX<CLASS><SPEC>/main.lua
luac -p EAX<CLASS><SPEC>/libraries/menu.lua
luac -p EAX<CLASS><SPEC>/libraries/spells.lua
luac -p EAX<CLASS><SPEC>/libraries/utils.lua

# Validate shared libraries
luac -p libraries/middleware.lua
luac -p libraries/dashboard.lua
luac -p libraries/compat.lua
```

All files must pass with no errors.

#### 2. In-Game Testing Checklist

**Middleware Testing**:
- [ ] Healthstone triggers when health < threshold
- [ ] Healing potion triggers when health < threshold
- [ ] Mana potion triggers when mana < threshold (mana users)
- [ ] Defensive racial triggers when health < threshold
- [ ] Offensive racial triggers during combat
- [ ] Emergency heal triggers (if applicable)
- [ ] Middleware respects menu toggle settings

**Dashboard Testing**:
- [ ] Dashboard appears when enabled
- [ ] Resource bar shows correct value
- [ ] Cooldown icons show remaining time
- [ ] Buff icons show active buffs
- [ ] Debuff icons show target debuffs
- [ ] Position sliders work
- [ ] Scale slider works

**PvP Testing** (if applicable):
- [ ] PvP mode detects enemy players
- [ ] PvP abilities trigger on players
- [ ] PvP abilities don't trigger on NPCs (when PvE mode)
- [ ] Snare abilities apply correctly

#### 3. Debug Commands

```lua
-- In-game console commands (if supported)
/middleware debug  -- Print middleware registry info
/dashboard toggle  -- Toggle dashboard visibility
/pvp detect        -- Force PvP detection check
```

#### 4. Common Issues and Fixes

| Issue | Cause | Fix |
|-------|-------|-----|
| `attempt to index nil` | Menu item not guarded | Use `(menu.x and menu.x:get()) or default` |
| Middleware not triggering | Priority too low | Increase priority value |
| Dashboard not showing | Render callback not registered | Call `dashboard.register_render_callback()` |
| PvP not detecting | Target check wrong | Use `utils.is_pvp_target(target)` |
| Mana potion not working | Wrong item ID | Verify TBC-era potion IDs |

#### 5. Performance Testing

```lua
-- Add to main.lua for performance monitoring
local perf = {
    last_check = 0,
    check_interval = 5.0,
}

local function check_performance()
    local now = core.time()
    if now - perf.last_check < perf.check_interval then return end
    perf.last_check = now
    
    local mw_count = middleware.count()
    print(string.format("[Perf] Middleware: %d registered", mw_count))
    
    -- Check dashboard update time
    local start = core.time()
    dashboard.update()
    local elapsed = core.time() - start
    if elapsed > 0.001 then  -- 1ms threshold
        print(string.format("[Perf] Dashboard update slow: %.3fms", elapsed * 1000))
    end
end
```

---

## Appendix A: Spell ID Reference

### Common TBC Spell IDs

| Spell | ID | Class |
|-------|-----|-------|
| Master Healthstone | 22105 | All |
| Super Healing Potion | 22829 | All |
| Super Mana Potion | 22832 | Mana users |
| Blood Fury (Orc) | 20572 | Warrior/Rogue/Shaman |
| Berserking (Troll) | 26297 | All |
| Stoneform (Dwarf) | 20594 | All |
| Will of the Forsaken | 7744 | Undead |
| Escape Artist | 20589 | Gnome |

### TBC Potion IDs

| Potion | Item ID |
|--------|---------|
| Super Healing Potion | 22829 |
| Major Healing Potion | 13446 |
| Super Mana Potion | 22832 |
| Major Mana Potion | 13444 |
| Haste Potion | 28508 |
| Destruction Potion | 28507 |

---

## Appendix B: Migration Priority

### High Priority (Do First)

1. **Warrior Fury** - Reference implementation
2. **Warrior Arms** - Similar to Fury
3. **Warrior Protection** - Tank middleware needs
4. **Rogue Combat** - Energy-based
5. **Rogue Assassination** - Poison focus
6. **Hunter BM** - Pet class complexity

### Medium Priority

7. **Druid Feral** - Form management
8. **Druid Bear** - Tank middleware
9. **Paladin Retribution** - Seal management
10. **Shaman Enhancement** - Dual-wield
11. **Mage Fire** - Clearcasting
12. **Warlock Destruction** - Shard management

### Lower Priority

13-27. All other specs - Follow patterns from above

---

## Appendix C: Code Templates

### Full main.lua Template with All Integrations

```lua
-- EAX<CLASS><SPEC>/main.lua
-- <Spec> rotation with middleware and dashboard

-- ============================================================================
-- REQUIRES
-- ============================================================================

local menu = require("libraries/menu")
local spells = require("libraries/spells")
local utils = require("libraries/utils")
local middleware = require("libraries/middleware")
local dashboard = require("libraries/dashboard")

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")
---@type auto_attack_helper
local auto_attack = require("common/utility/auto_attack_helper")
---@type interrupt_manager
local interrupt_manager = require("libraries/interrupt_manager")
---@type racial_manager
local racial_manager = require("libraries/racial_manager")

-- ============================================================================
-- API CACHING
-- ============================================================================

local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cd = core.spell_book.get_spell_cooldown

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Dashboard configuration
local dashboard_config = {
    class_name = "<CLASS> <SPEC>",
    resource_type = "<rage/energy/mana>",
    cooldowns = {
        -- Add spell IDs from spells.lua
    },
    buffs = {
        -- Add buff IDs from spells.lua
    },
    debuffs = {
        -- Add debuff IDs from spells.lua
    },
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function setup_middleware()
    -- Use class-specific setup or manual registration
    middleware.create_class_set("<class>", {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        healthstone_threshold = (menu.healthstone_threshold and menu.healthstone_threshold:get()) or 30,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        healing_potion_threshold = (menu.healing_potion_threshold and menu.healing_potion_threshold:get()) or 25,
        -- Add other options as needed
    })
    
    -- Additional middleware
    if menu.use_defensive_racial and menu.use_defensive_racial:get() then
        middleware.register(middleware.defensive_racial(
            spells.STONEFORM and spells.STONEFORM[1],
            (menu.defensive_racial_threshold and menu.defensive_racial_threshold:get()) or 40
        ))
    end
end

local function init_dashboard()
    dashboard.init(dashboard_config)
    dashboard.set_enabled((menu.dashboard_enabled and menu.dashboard_enabled:get()) or true)
    dashboard.set_position(
        (menu.dashboard_x and menu.dashboard_x:get()) or 20,
        (menu.dashboard_y and menu.dashboard_y:get()) or 200
    )
    dashboard.set_scale((menu.dashboard_scale and menu.dashboard_scale:get()) or 1.0)
    dashboard.register_render_callback()
end

-- ============================================================================
-- ROTATION
-- ============================================================================

local function rotation(icon, context)
    local me = context.me
    local target = context.target
    
    -- Execute middleware first
    local settings = {
        use_healthstone = (menu.use_healthstone and menu.use_healthstone:get()) or true,
        use_healing_potion = (menu.use_healing_potion and menu.use_healing_potion:get()) or true,
        use_defensive_racial = (menu.use_defensive_racial and menu.use_defensive_racial:get()) or true,
        use_offensive_racial = (menu.use_offensive_racial and menu.use_offensive_racial:get()) or true,
    }
    
    local mw_context = middleware.build_context(me, target, settings)
    local result, msg = middleware.execute(icon, mw_context)
    if result then
        return result, msg
    end
    
    -- Main rotation logic here...
    -- ...
end

-- ============================================================================
-- CALLBACKS
-- ============================================================================

local function on_load()
    setup_middleware()
    init_dashboard()
end

local function on_update(icon)
    local me = _get_local_player()
    if not me then return end
    
    local target = me:get_target()
    local context = { me = me, target = target }
    
    return rotation(icon, context)
end

-- ============================================================================
-- RETURN
-- ============================================================================

return {
    on_load = on_load,
    on_update = on_update,
}
```

---

**End of Integration Guide**

For questions or issues, refer to:
- `libraries/middleware.lua` - Middleware implementation
- `libraries/dashboard.lua` - Dashboard implementation
- `libraries/compat.lua` - Compatibility layer
- `AGENTS.md` - Project context and conventions
