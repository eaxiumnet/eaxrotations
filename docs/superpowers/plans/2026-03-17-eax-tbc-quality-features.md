# EAX TBC #1 Quality Features Implementation Plan

> **For agentic workers:** Use subagent-driven-development or executing-plans to implement this plan.

**Goal:** Add set bonus detection, talent stat bonuses, and aura tracking to match tbc/sim reference quality

**Architecture:** Create shared modules in common/ that provide:
- set_bonus.lua: Detects equipped set pieces, returns active bonuses
- talent_bonus.lua: Parses talents and applies stat multipliers
- aura_tracker.lua: Tracks active auras for rotation decisions

**Tech Stack:** Lua (Sylvanas plugin API)

---

## Overview of Features

### 1. Set Bonus Detection
Check equipped gear slots (19 slots), count set pieces, apply damage multipliers:
- T4 2p/4p: 5%/10% damage
- T5 2p/4p: 5%/10% damage  
- T6 2p/4p: 5%/10% damage
- Tier-specific (Tier 3-6)

### 2. Talent Stat Bonuses
Parse talent trees, apply stat effects:
- Elemental: Lightning Overload, Elemental Mastery
- Enhancement: Dual Wield, Shamanistic Rage
- All specs: Stat conversions from talents

### 3. Aura Tracking
Track active buffs for rotation decisions:
- Clearcasting (free spell)
- Elemental Mastery (burst window)
- Nature's Swiftness (instant cast)
- Berserking/Blood Fury (burst)

---

## Chunk 1: Set Bonus Detection Module

**Files:**
- Create: `common/eax_shared/set_bonus.lua`
- Test: Manual testing with equipped gear

- [ ] **Step 1: Create set bonus detection module**

```lua
-- common/eax_shared/set_bonus.lua
-- Set bonus detection for TBC raid gear

local set_bonus = {}

-- Equipment slot IDs (standard WoW inventory)
local INVENTORY_SLOT_HEAD = 0
local INVENTORY_SLOT_NECK = 1
local INVENTORY_SLOT_SHOULDER = 2
local INVENTORY_SLOT_SHIRT = 3
local INVENTORY_SLOT_CHEST = 4
local INVENTORY_SLOT_WAIST = 5
local INVENTORY_SLOT_LEGS = 6
local INVENTORY_SLOT_FEET = 7
local INVENTORY_SLOT_WRIST = 8
local INVENTORY_SLOT_HAND = 9
local INVENTORY_SLOT_FINGER = 10
local INVENTORY_SLOT_TRINKET = 12
local INVENTORY_SLOT_BACK = 14
local INVENTORY_SLOT_MAINHAND = 15
local INVENTORY_SLOT_OFFHAND = 16
local INVENTORY_SLOT_RANGED = 18

-- All equipment slots to check
local ALL_EQUIP_SLOTS = {
    INVENTORY_SLOT_HEAD, INVENTORY_SLOT_NECK, INVENTORY_SLOT_SHOULDER,
    INVENTORY_SLOT_CHEST, INVENTORY_SLOT_WAIST, INVENTORY_SLOT_LEGS,
    INVENTORY_SLOT_FEET, INVENTORY_SLOT_WRIST, INVENTORY_SLOT_HAND,
    INVENTORY_SLOT_FINGER, INVENTORY_SLOT_TRINKET, INVENTORY_SLOT_BACK,
    INVENTORY_SLOT_MAINHAND, INVENTORY_SLOT_OFFHAND, INVENTORY_SLOT_RANGED
}

-- Set definitions: set_name -> { item_ids = {}, bonuses = {2 = multiplier, 4 = multiplier} }
local TBC_SETS = {
    -- Tier 4
    ["Elemental"] = {
        items = { 29080, 29081, 29082, 29083, 29084 }, -- Cyclone
        bonuses = { 2 = 1.05, 4 = 1.10 }
    },
    ["Glorious"] = {
        items = { 29061, 29062, 29063, 29064, 29065 }, -- Warrior
        bonuses = { 2 = 1.05, 4 = 1.10 }
    },
    [" Battlegear of"] = {
        items = { 29036, 29037, 29038, 29039, 29040 }, -- Rogue
        bonuses = { 2 = 1.05, 4 = 1.10 }
    },
    -- Add more sets as needed
}

-- Get item ID from slot
local function get_item_id_in_slot(me, slot_id)
    if not me then return nil end
    local ok, slot_info = pcall(function() return me:get_item_at_inventory_slot(slot_id) end)
    if not ok or not slot_info or not slot_info.object then return nil end
    local item = slot_info.object
    if not item or not item.is_valid or not item:is_valid() then return nil end
    local item_id = item.get_item_id and item:get_item_id()
    return item_id
end

-- Get all equipped item IDs
local function get_equipped_items(me)
    local items = {}
    for _, slot in ipairs(ALL_EQUIP_SLOTS) do
        local item_id = get_item_id_in_slot(me, slot)
        if item_id and item_id > 0 then
            table.insert(items, item_id)
        end
    end
    return items
end

-- Check if player has set bonus active
-- Returns: multiplier (1.0 if no bonus) or nil if not found
function set_bonus.get_multiplier(me, set_name)
    if not me then return 1.0 end
    
    local set_def = TBC_SETS[set_name]
    if not set_def or not set_def.items or not set_def.bonuses then
        return 1.0
    end
    
    local items = get_equipped_items(me)
    local count = 0
    
    -- Count matching set pieces
    for _, item_id in ipairs(items) do
        for _, set_item_id in ipairs(set_def.items) do
            if item_id == set_item_id then
                count = count + 1
                break
            end
        end
    end
    
    -- Return multiplier if threshold met
    if count >= 4 and set_def.bonuses[4] then
        return set_def.bonuses[4]
    elseif count >= 2 and set_def.bonuses[2] then
        return set_def.bonuses[2]
    end
    
    return 1.0
end

-- Get all active set bonuses as table
function set_bonus.get_active_sets(me)
    if not me then return {} end
    
    local active = {}
    local items = get_equipped_items(me)
    
    for set_name, set_def in pairs(TBC_SETS) do
        local count = 0
        for _, item_id in ipairs(items) do
            for _, set_item_id in ipairs(set_def.items) do
                if item_id == set_item_id then
                    count = count + 1
                    break
                end
            end
        end
        
        if count >= 2 then
            table.insert(active, {
                name = set_name,
                count = count,
                multiplier = (count >= 4 and set_def.bonuses[4]) or (count >= 2 and set_def.bonuses[2]) or 1.0
            })
        end
    end
    
    return active
end

return set_bonus
```

- [ ] **Step 2: Add set bonus check to one spec (EAXShamanEnhancement)**

Modify: `EAXShamanEnhancement/main.lua`

Add after require section:
```lua
local set_bonus = require("common/eax_shared/set_bonus")
```

Add to runtime:
```lua
set_multiplier = 1.0,  -- Damage multiplier from set bonuses
```

In resolve_spells():
```lua
-- Check set bonuses
local multiplier = set_bonus.get_multiplier(me, "Elemental")
if multiplier then
    runtime.set_multiplier = multiplier
end
```

In spell cast, apply multiplier:
```lua
-- Apply set bonus multiplier to damage
if runtime.set_multiplier and runtime.set_multiplier > 1.0 then
    -- Log for debugging
    utils.log_debug(menu, "Set bonus active: " .. tostring(runtime.set_multiplier))
end
```

- [ ] **Step 3: Test set bonus detection**

Load EAXShamanEnhancement with T4 gear, verify multiplier detected

- [ ] **Step 4: Commit**

```bash
git add common/eax_shared/set_bonus.lua EAXShamanEnhancement/
git commit -m "feat: add set bonus detection module"
```

---

## Chunk 2: Talent Stat Bonuses

**Files:**
- Create: `common/eax_shared/talent_bonus.lua`
- Modify: Add to spec main.lua files

- [ ] **Step 1: Create talent bonus module**

```lua
-- common/eax_shared/talent_bonus.lua
-- Talent-based stat bonuses and multipliers

local talent_bonus = {}

-- Talent spell IDs that indicate talent points spent
-- Format: talent_name -> { spell_ids = {}, effect = function() end }

local TALENT_EFFECTS = {
    -- Shaman Enhancement
    ["shamanistic_rage"] = {
        spells = { 30823 },  -- Shamanistic Rage
        effect = "mana_regen"
    },
    ["dual_wield"] = {
        spells = { 674 },   -- Dual Wield
        effect = "hit_boost"
    },
    -- Add more as needed
}

-- Check if talent is active (spell learned)
function talent_bonus.has_talent(spell_id)
    if not spell_id then return false end
    local ok, learned = pcall(function() return core.spell_book.is_spell_learned(spell_id) end)
    return ok and learned
end

-- Get talent effect multiplier
function talent_bonus.get_effect(talent_name)
    local def = TALENT_EFFECTS[talent_name]
    if not def then return nil end
    
    for _, spell_id in ipairs(def.spells) do
        if talent_bonus.has_talent(spell_id) then
            return def.effect
        end
    end
    return nil
end

-- Generic damage multiplier from talents
function talent_bonus.get_damage_multiplier(me, class, spec)
    if not me then return 1.0 end
    
    local multiplier = 1.0
    
    -- Class-specific talent effects
    if class == "shaman" then
        if spec == "enhancement" then
            -- Stormstrike bonus from talents (simplified)
            if talent_bonus.has_talent(17364) then  -- Stormstrike
                multiplier = multiplier * 1.10  -- 10% bonus
            end
        end
    end
    
    return multiplier
end

return talent_bonus
```

- [ ] **Step 2: Integrate with EAXShamanEnhancement**

Modify: `EAXShamanEnhancement/main.lua`

Add after set_bonus require:
```lua
local talent_bonus = require("common/eax_shared/talent_bonus")
```

In rotation, apply:
```lua
local function get_damage_multiplier()
    local mult = runtime.set_multiplier or 1.0
    local talent_mult = talent_bonus.get_damage_multiplier(me, "shaman", "enhancement")
    return mult * talent_mult
end
```

- [ ] **Step 3: Commit**

```bash
git add common/eax_shared/talent_bonus.lua EAXShamanEnhancement/
git commit -m "feat: add talent bonus module"
```

---

## Chunk 3: Aura Tracking

**Files:**
- Create: `common/eax_shared/aura_tracker.lua`
- Modify: Add to spec main.lua files

- [ ] **Step 1: Create aura tracker module**

```lua
-- common/eax_shared/aura_tracker.lua
-- Track active auras/buffs for rotation decisions

local aura_tracker = {}

-- Cache for aura checks (avoid spam)
local aura_cache = {}
local CACHE_DURATION = 0.1  -- seconds

-- Common TBC auras to track
local AURAS = {
    -- Clearcasting (Shaman)
    clearcasting = {
        spells = { 16271, 16267, 16266, 16265, 16264, 16263, 16262 },
        buff_name = "Clearcasting"
    },
    -- Elemental Mastery (Shaman)
    elemental_mastery = {
        spells = { 16166, 16188, 16187, 16186, 16185, 16184, 16183 },
        buff_name = "Elemental Mastery"
    },
    -- Nature's Swiftness (Druid/Shaman)
    natures_swiftness = {
        spells = { 17116, 17115, 17114, 17113, 17112, 17111, 17110 },
        buff_name = "Natures Swiftness"
    },
    -- Berserking (Troll)
    berserking = {
        spells = { 26297 },
        buff_name = "Berserking"
    },
    -- Blood Fury (Orc)
    blood_fury = {
        spells = { 33697, 20572 },
        buff_name = "Blood Fury"
    },
}

-- Check if aura is active
function aura_tracker.is_active(aura_name)
    if not aura_name then return false end
    
    local def = AURAS[aura_name]
    if not def then return false end
    
    -- Check cache
    local now = core.time()
    if aura_cache[aura_name] and (now - aura_cache[aura_name].time) < CACHE_DURATION then
        return aura_cache[aura_name].active
    end
    
    -- Check if any spell ID is active on player
    local me = core.object_manager.get_local_player()
    if not me then return false end
    
    local is_active = false
    for _, spell_id in ipairs(def.spells) do
        local ok, has_buff = pcall(function()
            return me:has_aura(spell_id)
        end)
        if ok and has_buff then
            is_active = true
            break
        end
    end
    
    -- Update cache
    aura_cache[aura_name] = {
        active = is_active,
        time = now
    }
    
    return is_active
end

-- Check multiple auras at once
function aura_tracker.check_any(...)
    local aura_names = {...}
    for _, name in ipairs(aura_names) do
        if aura_tracker.is_active(name) then
            return true
        end
    end
    return false
end

-- Get all active tracked auras
function aura_tracker.get_active()
    local active = {}
    for name, _ in pairs(AURAS) do
        if aura_tracker.is_active(name) then
            table.insert(active, name)
        end
    end
    return active
end

return aura_tracker
```

- [ ] **Step 2: Integrate with EAXShamanEnhancement**

Modify: `EAXShamanEnhancement/main.lua`

Add after talent_bonus require:
```lua
local aura_tracker = require("common/eax_shared/aura_tracker")
```

In rotation, use for decisions:
```lua
-- Check for Clearcasting (free spell)
local has_clearcasting = aura_tracker.is_active("clearcasting")
if has_clearcasting then
    -- Use free spell window
end

-- Check for Elemental Mastery (burst)
local has_elemental_mastery = aura_tracker.is_active("elemental_mastery")
if has_elemental_mastery then
    -- Burst window
end
```

- [ ] **Step 3: Commit**

```bash
git add common/eax_shared/aura_tracker.lua EAXShamanEnhancement/
git commit -m "feat: add aura tracking module"
```

---

## Chunk 4: Roll Out to All Specs

**Files:**
- Modify: All 27 spec main.lua files

For each spec (17 remaining without integration):
- Add requires for set_bonus, talent_bonus, aura_tracker
- Add runtime fields
- Integrate into rotation

This chunk is repetitive - use subagent-driven-development with workers.

---

## Estimated Timeline

- Chunk 1 (Set Bonus): 30 minutes
- Chunk 2 (Talents): 30 minutes  
- Chunk 3 (Auras): 30 minutes
- Chunk 4 (Rollout): 2-3 hours (parallel agents)

**Total: ~4 hours**
