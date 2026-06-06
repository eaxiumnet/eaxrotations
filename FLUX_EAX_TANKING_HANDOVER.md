# Flux vs EAX Tanking Analysis - Comprehensive Handover Document

**Generated**: 2026-04-08  
**Scope**: Protection Warrior, Bear Druid, Protection Paladin tanking specs  
**Platforms**: Flux AIO (GGL/TellMeWhen) vs EAX (Project Sylvanas)

---

## Executive Summary

Flux AIO implements several **advanced tanking features** that EAX currently lacks. This document provides a detailed feature comparison, identifies missing capabilities, and provides implementation guidance for porting Flux innovations to the Project Sylvanas platform.

### Key Findings:
- **Threat-aware tab targeting**: Flux has sophisticated multi-mob threat management; EAX has basic targeting
- **Middleware architecture**: Flux uses priority-ordered middleware for shared logic; EAX uses sequential function calls
- **Smart defensive cooldowns**: Flux has predictive/mitigation-aware defense; EAX uses simple HP thresholds
- **IZI SDK integration**: Project Sylvanas has powerful APIs (IZI, buff_manager, combat_forecast) that could dramatically enhance EAX tanking

---

## 1. Feature Comparison Matrix

### 1.1 Core Rotation Features

| Feature | Flux | EAX | Notes |
|---------|------|-----|-------|
| **Threat Rotation** | | | |
| Shield Slam priority | ✅ Yes | ✅ Yes | Both prioritize correctly |
| Revenge proc handling | ✅ Yes | ✅ Yes | Both handle revenge procs |
| Devastate/Sunder maintenance | ✅ Yes | ✅ Yes | Both stack maintenance |
| Thunder Clap stance dancing | ✅ Yes | ✅ Yes | Both dance to Battle for TC |
| **Threat Tab Targeting** | | | |
| Multi-mob threat scanning | ✅ Yes | ❌ No | **MAJOR GAP** - Flux scans all nameplates |
| Threat level categorization | ✅ Yes (0-3 tiers) | ❌ No | Flux: 0=loose, 1=have threat, 2=insecure, 3=secure |
| Priority-based target selection | ✅ Yes | ❌ No | Flux: boss > elite > trash |
| Threat equalization | ✅ Yes | ❌ No | Flux rotates to lowest-threat mob when all secure |
| Manual target respect | ✅ Yes (3s grace) | ❌ No | Flux detects manual target changes |
| **Taunt System** | | | |
| Smart single-target taunt | ✅ Yes | ✅ Basic | Flux: classification filtering, CC checks, TTD gates |
| AoE taunt (Challenging) | ✅ Yes | ✅ Yes | Both have, Flux has better thresholds |
| Mocking Blow fallback | ✅ Yes | ✅ Yes | Both have stance-dance fallback |
| Healer-targeted taunt priority | ✅ Yes | ❌ No | **GAP** - Flux always taunts if healer targeted |
| **Defensive Cooldowns** | | | |
| Last Stand | ✅ Yes | ✅ Yes | Both have emergency HP-based trigger |
| Shield Wall | ✅ Yes | ✅ Yes | Both have stance-restricted use |
| Shield Block | ✅ Yes | ✅ Yes | Both have crush prevention |
| Spell Reflection | ✅ Advanced | ✅ Basic | **GAP** - Flux has PvP whitelist + PvE detection |
| Predictive mitigation | ✅ Yes | ❌ No | **MAJOR GAP** |

### 1.2 Advanced Flux Features (Missing in EAX)

| Feature | Description | Impact |
|---------|-------------|--------|
| **HS/Cleave Queue Trick** | Dual-wield optimization: queue HS for yellow OH hit, dequeue before MH if low rage | **+5-10% DPS** for Fury/Prot hybrid |
| **Threat Lead Gating** | Utility abilities (Demo Shout, Thunder Clap) gated behind configurable threat % lead | Prevents threat loss from utility |
| **Rage Reservation** | Maul/Mangle rage reservation system prevents starving important abilities | Better resource management |
| **Swing Timer Integration** | Next-swing prediction for Maul/Heroic Strike optimization | Better rage efficiency |
| **PvP AntiFake Timing** | Randomized kick timing (15-67% of cast) to prevent prediction | **PvP advantage** |
| **CC Break Prevention** | Detects breakable CC near target (Polymorph, Sap, etc.) and skips AoE | **Critical for PvE/PvP** |

---

## 2. Architecture Comparison

### 2.1 Flux Architecture (Superior)

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FLUX AIO ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     ROTATION REGISTRY                             │ │
│  │   (Priority-sorted middleware + strategies per playstyle)        │ │
│  └────────────────────────────────────────────────────────────────┘ │
│         │                      │                      │              │
│    ┌────┴────┐           ┌─────┴─────┐         ┌────┴────┐        │
│    │MIDDLEWARE│           │ STRATEGY  │         │ CONTEXT  │        │
│    │(Priority)│           │  ARRAYS   │         │ BUILDER  │        │
│    └────┬────┘           └─────┬─────┘         └────┬────┘        │
│         │                      │                      │              │
│    ┌────┴────┐           ┌─────┴─────┐         ┌────┴────┐        │
│    │Last Stand│           │ShieldSlam │         │Debuff   │        │
│    │ShieldWall│           │Revenge   │         │States   │        │
│    │Healthstone│          │Devastate │         │Threat   │        │
│    │Interrupt │           │Taunt     │         │Data     │        │
│    │Racial   │            │TabTarget │         │         │        │
│    └─────────┘            └──────────┘         └─────────┘        │
└─────────────────────────────────────────────────────────────────────┘

Key Innovation: Middleware runs BEFORE rotation, handles emergencies/recovery first
```

**Flux Strategy Pattern:**
```lua
local Prot_ShieldSlam = {
    requires_combat = true,
    requires_enemy = true,
    spell = A.ShieldSlam,
    
    matches = function(context, state)
        -- Pre-conditions checked here
        return true
    end,
    
    execute = function(icon, context, state)
        return try_cast(A.ShieldSlam, icon, TARGET_UNIT, "[PROT] Shield Slam")
    end,
}
```

### 2.2 EAX Architecture (Current)

```
┌─────────────────────────────────────────────────────────────────────┐
│                      EAX CURRENT ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    SEQUENTIAL ON_UPDATE                       │   │
│   │                                                              │   │
│   │   1. Resolve spell IDs                                      │   │
│   │   2. Get player/target state                                │   │
│   │   3. PvP context detection                                  │   │
│   │   4. Execute middleware (if implemented)                    │   │
│   │   5. Try abilities in priority order:                       │   │
│   │      - try_last_stand()                                     │   │
│   │      - try_shield_wall()                                    │   │
│   │      - try_taunt()                                          │   │
│   │      - ...etc                                               │   │
│   │   6. Return (only one ability per frame)                    │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                      │
│   Problems:                                                          │
│   - Hardcoded priority order                                         │
│   - No shared context/state between functions                        │
│   - Each function re-queries buffs/debuffs                           │
│   - No sophisticated targeting system                                │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.3 Architecture Recommendations

**RECOMMENDATION**: EAX should adopt a **context-builder + priority-ordered execution** pattern:

```lua
-- New architecture pattern for EAX
local function on_update()
    -- 1. Build shared context (once per frame)
    local ctx = build_context()
    
    -- 2. Execute priority-ordered abilities
    for _, ability in ipairs(ABILITY_PRIORITY) do
        if ability.matches(ctx) then
            if ability.execute(ctx) then return end
        end
    end
end
```

---

## 3. Missing Features - Detailed Specifications

### 3.1 CRITICAL: Threat-Aware Tab Targeting

**Current EAX Gap**: EAX has no intelligent multi-target threat management.

**Flux Implementation** (`flux/rotation/source/aio/warrior/protection.lua` lines 216-394):

```lua
-- THREAT TIER DEFINITIONS:
-- 0 = not on threat table (loose mob)
-- 1 = have threat but not tanking (target is someone else)
-- 2 = insecurely tanking (high threat but not highest)
-- 3 = securely tanking (highest threat)

local function get_target_threat(unitID)
    local threat = _G.UnitThreatSituation("player", unitID) or 0
    if threat < 2 then
        local tt = unitID .. "target"
        if UnitExists(tt) and UnitIsUnit(tt, PLAYER_UNIT) then
            return 2  -- Fallback: if targeting us, treat as insecure
        end
    end
    return threat
end

-- TARGET SELECTION LOGIC:
local function should_prot_tab(ctx, state)
    -- Respect manual target selection
    if (GetTime() - prot_state.manual_target_time) < MANUAL_TARGET_GRACE then 
        return false 
    end
    
    -- Current target assessment
    local currentThreat = get_target_threat()
    if currentThreat == 0 then return false end  -- Stay on loose mob
    
    -- Scan all nameplates
    local plates = MultiUnits:GetActiveUnitPlates()
    for unitID in pairs(plates) do
        local unitThreat = get_target_threat(unitID)
        local unitPriority = get_unit_priority(unitID)  -- boss=3, elite=2, trash=1
        
        -- Categorize by threat tier
        if unitThreat == 0 and unitPriority >= minPriority then
            bestT0Unit = unitID  -- Loose mob found!
        elseif unitThreat == 1 and unitPriority >= minPriority then
            bestT1Unit = unitID  -- Have threat but not tanking
        end
    end
    
    -- SWITCH LOGIC: Only switch to MORE urgent threats
    if currentThreat == 1 then
        if bestT0Unit then return true end  -- Switch to loose mob
    elseif currentThreat == 2 then
        if bestT0Unit then return true      -- Loose mob first
        elseif bestT1Unit then return true end  -- Then other non-tanking
    elseif currentThreat >= 3 then
        -- Securely tanking: can leave for any lower threat tier
        if bestT0Unit or bestT1Unit then return true end
    end
end
```

**Implementation for EAX:**

```lua
-- File: EAXWarriorProtection/libraries/threat_tab_manager.lua

---@class threat_tab_manager
local threat_tab_manager = {}

-- Unit priority constants
local PRIO_BOSS = 3
local PRIO_ELITE = 2
local PRIO_TRASH = 1

-- Configuration
local MANUAL_TARGET_GRACE = 3  -- seconds
local TAB_MAX_ATTEMPTS = 10

-- State
local state = {
    tab_target_desired = nil,
    tab_target_attempts = 0,
    last_target_guid = nil,
    manual_target_time = 0,
}

---Get threat level for a unit
---@param target game_object
---@return number threat_level (0-3)
function threat_tab_manager.get_threat_level(target)
    if not target or not target:is_valid() then return 0 end
    
    -- Use game_object threat API
    local threat_data = target:get_threat_situation(me)
    local threat_status = threat_data and threat_data.status or 0
    if threat_status > 0 then return threat_status end
    
    -- Fallback: check target's target
    local target_target = target:get_target()
    if target_target and target_target:is_valid() then
        local me = core.object_manager.get_local_player()
        if target_target == me then return 2 end  -- Insecurely tanking
    end
    
    return 0
end

---Get unit priority for targeting
---@param target game_object
---@return number priority (PRIO_BOSS, PRIO_ELITE, or PRIO_TRASH)
function threat_tab_manager.get_unit_priority(target)
    if not target then return PRIO_TRASH end
    
    local classification = target:get_classification()
    if classification == "worldboss" then return PRIO_BOSS end
    if classification == "elite" or classification == "rareelite" then 
        return PRIO_ELITE 
    end
    return PRIO_TRASH
end

---Should we tab target?
---@param me game_object
---@param current_target game_object
---@param settings table
---@return boolean should_tab
---@return string|nil reason
function threat_tab_manager.should_tab(me, current_target, settings)
    -- Manual target grace period
    local now = core.time()
    if (now - state.manual_target_time) < MANUAL_TARGET_GRACE then
        return false, "manual_target_grace"
    end
    
    -- Single target - no need to tab
    local enemy_count = utils.count_nearby_enemies(me, 30)
    if enemy_count < 2 then
        return false, "single_target"
    end
    
    -- Get current threat level
    local current_threat = threat_tab_manager.get_threat_level(current_target)
    
    -- If we have no threat, stay and build it
    if current_threat == 0 then
        return false, "building_threat"
    end
    
    -- Scan for better targets
    local objects = core.object_manager.get_all_objects()
    local best_loose = nil
    local best_loose_prio = 0
    
    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and me:can_attack(obj) then
            if obj ~= current_target and not obj:is_dead() then
                local threat = threat_tab_manager.get_threat_level(obj)
                local priority = threat_tab_manager.get_unit_priority(obj)
                local min_priority = settings.tab_min_priority or PRIO_TRASH
                
                -- Only consider units with lower threat than current
                if threat < current_threat and priority >= min_priority then
                    if priority > best_loose_prio then
                        best_loose = obj
                        best_loose_prio = priority
                    end
                end
            end
        end
    end
    
    if best_loose then
        state.tab_target_desired = best_loose
        return true, "loose_mob_detected"
    end
    
    return false, "no_better_target"
end

return threat_tab_manager
```

---

### 3.2 HIGH PRIORITY: Smart Defensive Cooldowns

**Current EAX**: Simple HP thresholds
```lua
if hp_pct < menu.last_stand_hp_pct:get() then
    try_last_stand(me)
end
```

**Flux Implementation**: Context-aware with predictive elements

```lua
-- From flux/rotation/source/aio/warrior/middleware.lua

-- Last Stand middleware (priority 500)
matches = function(context)
    if not context.in_combat then return false end
    local threshold = context.settings.last_stand_hp or 0
    if threshold <= 0 then return false end
    if context.hp > threshold then return false end
    return true
end

-- Shield Wall middleware (priority 490)  
matches = function(context)
    if not context.in_combat then return false end
    local threshold = context.settings.shield_wall_hp or 0
    if threshold <= 0 then return false end
    if context.hp > threshold then return false end
    -- Shield Wall requires Defensive Stance
    if context.stance ~= Constants.STANCE.DEFENSIVE then return false end
    return true
end

-- PvP: Defensive Stance at range (priority 192)
-- When kiting/kited, switch to Defensive for 10% DR
matches = function(context)
    if not context.in_combat then return false end
    if not context.is_pvp or not context.settings.pvp_enabled then return false end
    if context.in_melee_range then return false end
    if context.stance == Constants.STANCE.DEFENSIVE then return false end
    -- Only when Intercept is on CD
    local intercept_cd = A.Intercept:GetCooldown() or 0
    if intercept_cd <= 0 then return false end
    return true
end
```

**Enhanced EAX Implementation using IZI SDK:**

```lua
-- Enhanced defensive manager using IZI SDK + combat_forecast

---@type combat_forecast
local combat_forecast = require("common/modules/combat_forecast")

local smart_defensive = {}

---Predict if we're about to take burst damage
---@param me game_object
---@return boolean is_burst_incoming
---@return number predicted_damage
function smart_defensive.predict_burst(me)
    -- Get combat forecast
    local forecast = combat_forecast:get_forecast_single(me, true)
    if not forecast then return false, 0 end
    
    -- Check incoming DPS vs our mitigation
    local incoming_dps = forecast.incoming_dps or 0
    local mitigation = utils.get_current_mitigation(me)
    
    -- Predict damage in next 3 seconds
    local predicted_damage = incoming_dps * 3 * (1 - mitigation)
    local hp_pct = me:get_health_percentage()
    
    -- If predicted damage would drop us below critical threshold
    if hp_pct - (predicted_damage / me:get_max_health() * 100) < 20 then
        return true, predicted_damage
    end
    
    return false, 0
end

---Should use defensive cooldown?
---@param me game_object
---@param defensive_type string ("last_stand", "shield_wall", etc.)
---@param settings table
---@return boolean
function smart_defensive.should_use(me, defensive_type, settings)
    local hp_pct = me:get_health_percentage()
    
    -- Basic HP threshold
    local threshold = settings[defensive_type .. "_hp"] or 25
    if hp_pct > threshold then return false end
    
    -- Predictive: check if burst is incoming
    local burst_incoming, predicted_dmg = smart_defensive.predict_burst(me)
    if burst_incoming then
        return true  -- Use defensively BEFORE the damage
    end
    
    -- Check if tanking multiple enemies
    local enemy_count = utils.count_nearby_enemies(me, 10)
    if enemy_count >= 3 and hp_pct < threshold + 10 then
        return true  -- More lenient with multiple targets
    end
    
    return hp_pct <= threshold
end

return smart_defensive
```

---

### 3.3 MEDIUM PRIORITY: CC Break Prevention

**Flux Feature**: Detects breakable CC near target and skips AoE abilities

```lua
-- From flux/rotation/source/aio/druid/bear.lua

-- Name-based checks (not "BreakAble" category) so we detect ANY caster's debuffs
local SWIPE_CC_CHECK_RANGE = 10  -- yards; slightly wider than melee for safety
local BREAKABLE_CC_NAMES = {
    "Polymorph",            -- Mage
    "Freezing Trap Effect", -- Hunter
    "Repentance",           -- Paladin
    "Blind",                -- Rogue
    "Sap",                  -- Rogue
    "Gouge",                -- Rogue
    "Hibernate",            -- Druid
    "Wyvern Sting",         -- Hunter
    "Scatter Shot",         -- Hunter
    "Shackle Undead",       -- Priest
    "Seduction"            -- Warlock (Succubus)
}

local function has_breakable_cc_nearby()
    local plates = A.MultiUnits:GetActiveUnitPlates()
    for unitID in pairs(plates) do
        if Unit(unitID):GetRange() <= SWIPE_CC_CHECK_RANGE then
            for i = 1, NUM_BREAKABLE_CC do
                if (Unit(unitID):HasDeBuffs(BREAKABLE_CC_NAMES[i]) or 0) > 0 then
                    return true
                end
            end
        end
    end
    return false
end
```

**EAX Implementation:**

```lua
-- libraries/cc_break_prevention.lua

local cc_break_prevention = {
    -- Breakable CC spell IDs (TBC)
    BREAKABLE_CC_IDS = {
        [118] = "Polymorph",           -- Mage
        [3355] = "Freezing Trap",      -- Hunter
        [20066] = "Repentance",        -- Paladin
        [2094] = "Blind",              -- Rogue
        [6770] = "Sap",                -- Rogue
        [1776] = "Gouge",              -- Rogue
        [2637] = "Hibernate",            -- Druid
        [19386] = "Wyvern Sting",      -- Hunter
        [19503] = "Scatter Shot",      -- Hunter
        [9484] = "Shackle Undead",     -- Priest
        [6358] = "Seduction",          -- Warlock
    },
    CHECK_RANGE = 10,  -- yards
}

---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

function cc_break_prevention.has_cc_nearby(me)
    local check_range_sq = cc_break_prevention.CHECK_RANGE * cc_break_prevention.CHECK_RANGE
    local my_pos = me:get_position()
    
    local objects = core.object_manager.get_all_objects()
    for _, obj in ipairs(objects) do
        if obj and obj:is_valid() and obj:is_unit() and not obj:is_dead() then
            local obj_pos = obj:get_position()
            if obj_pos and my_pos then
                local dx = obj_pos.x - my_pos.x
                local dy = obj_pos.y - my_pos.y
                local dz = obj_pos.z - my_pos.z
                local dist_sq = dx*dx + dy*dy + dz*dz
                
                if dist_sq <= check_range_sq then
                    -- Check if this unit has breakable CC
                    local debuffs = buff_manager:get_debuff_cache(obj)
                    for _, debuff in ipairs(debuffs) do
                        if cc_break_prevention.BREAKABLE_CC_IDS[debuff.buff_id] then
                            return true, cc_break_prevention.BREAKABLE_CC_IDS[debuff.buff_id]
                        end
                    end
                end
            end
        end
    end
    
    return false, nil
end

return cc_break_prevention
```

---

### 3.4 LOW PRIORITY: HS/Cleave Queue Trick (Optimization)

**Flux Implementation** (`flux/rotation/source/aio/warrior/middleware.lua` lines 58-126):

```lua
-- HS/CLEAVE QUEUE TRICK (highest priority — dequeue before MH swing lands)
-- In TBC, queuing HS/Cleave converts both MH and OH swings to "yellow" hits
-- (no glancing blows, better hit table). The trick: queue HS to get yellow
-- OH hit, then dequeue before MH lands if rage is insufficient.

rotation_registry:register_middleware({
    name = "Warrior_HSQueueDequeue",
    priority = 999,
    is_gcd_gated = false,

    matches = function(context)
        if not context.settings.hs_trick then return false end
        if not context.has_offhand then return false end
        -- Check if HS or Cleave is currently queued
        return A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent()
    end,

    execute = function(icon, context)
        local mh_remaining = NS.get_time_until_swing()
        local should_dequeue = false
        
        -- 1. MH swing landing soon and not enough rage for HS cost
        --    But keep queued if OH lands first (we want the yellow OH hit)
        if mh_remaining > 0 and mh_remaining <= 0.4 then
            local hs_cost = 15  -- HS base cost in TBC
            if context.rage < hs_cost then
                local oh_remaining = context.oh_remain or 999
                if oh_remaining <= 0 then oh_remaining = 999 end
                -- Only dequeue if MH lands before OH (preserve yellow OH hit)
                if mh_remaining <= oh_remaining then
                    should_dequeue = true
                end
            end
        end

        -- 2. Target casting — hold rage for Pummel
        if not should_dequeue and context.has_valid_enemy_target then
            local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
            if castLeft and castLeft > 0 and not notKickAble then
                local hs_cost = 15
                local pummel_cost = 10
                if context.rage < (hs_cost + pummel_cost) then
                    should_dequeue = true
                end
            end
        end

        if should_dequeue then
            return A:Show(icon, CONST.STOPCAST), "[MW] HS Dequeue"
        end
        return nil
    end,
})
```

---

## 4. Available APIs for Enhancement

### 4.1 IZI SDK (Project Sylvanas Native)

**Location**: `api/common/izi_sdk.lua`, documented in `apidocs/pages/dev/libraries/izi/`

**Key Features for Tanking:**

```lua
-- Event-driven callbacks (replace polling)
local izi = require("common/izi_sdk")

-- Buff/debuff tracking
izi.on_buff_gain(function(event)
    if event.buff_id == 642 then  -- Divine Shield
        -- Target bubbled, switch targets!
    end
end)

izi.on_debuff_lose(function(event)
    if event.debuff_id == 1161 then  -- Demo Shout
        -- Need to reapply Demo Shout
    end
end)

-- Smart targeting
local target = izi.pick_enemy(function(unit)
    local threat = get_threat_level(unit)
    local priority = get_unit_priority(unit)
    -- Score: lower threat = higher priority, higher unit priority = higher score
    return (100 - threat * 25) + priority * 10
end)

-- Unit queries
local enemies = izi.enemies(30)  -- All enemies within 30 yards
local friends = izi.friends(40)  -- All friendlies within 40 yards

-- OO spell objects
local shield_slam = izi.spell(23922)
if shield_slam:is_castable(target) then
    shield_slam:cast_safe(target)
end
```

### 4.2 Buff Manager Module

**Location**: `api/common/modules/buff_manager.lua`

```lua
---@type buff_manager
local buff_manager = require("common/modules/buff_manager")

-- Cached buff lookup (performance optimized)
local buff_data = buff_manager:get_buff_data(me, {17, 606})  -- PW:S, PW:F
if buff_data.is_active then
    print("PW:S has " .. buff_data.remaining .. "ms remaining")
end

-- Debuff tracking
local sunder_data = buff_manager:get_debuff_data(target, 11597)
if sunder_data.stacks < 5 then
    -- Apply more Sunder Armor
end
```

### 4.3 Combat Forecast Module

**Location**: `api/common/modules/combat_forecast.lua`

```lua
---@type combat_forecast
local combat_forecast = require("common/modules/combat_forecast")

-- Predict incoming damage
local forecast = combat_forecast:get_forecast_single(me, true)
if forecast then
    local incoming_dps = forecast.incoming_dps
    local time_to_die = forecast.time_to_die
    
    -- Use defensive if TTD is short
    if time_to_die < 5 then
        try_last_stand(me)
    end
end
```

### 4.4 Target Selector Module

**Location**: `api/common/modules/target_selector.lua`

```lua
---@type target_selector
local target_selector = require("common/modules/target_selector")

-- Get targets from the system target selector
local targets = target_selector:get_targets(5)  -- Up to 5 targets
for _, target in ipairs(targets) do
    -- Process each target
end
```

---

## 5. Implementation Roadmap

### Phase 1: Foundation (Week 1)
1. **Create shared context builder**
   - File: `EAXWarriorProtection/libraries/context_builder.lua`
   - Pre-computes threat, debuffs, enemy counts once per frame
   - Reduces API calls and ensures consistency

2. **Adopt priority-ordered execution**
   - Convert sequential `try_*` functions to priority array
   - Enable middleware-style emergency handling

### Phase 2: Core Features (Week 2-3)
1. **Implement threat-aware tab targeting**
   - Port Flux logic to EAX
   - Use IZI SDK `izi.pick_enemy()` for smart selection
   - Test with multi-mob scenarios

2. **Enhance defensive cooldowns**
   - Add predictive mitigation using `combat_forecast`
   - Implement stance-aware defensive triggers
   - Add PvP defensive stance at range

### Phase 3: Polish (Week 4)
1. **Add CC break prevention**
   - Port breakable CC detection
   - Gate AoE abilities behind CC safety check

2. **Implement HS/Cleave queue trick**
   - Add swing timer tracking
   - Implement dequeue logic

3. **IZI SDK integration**
   - Add event-driven buff/debuff tracking
   - Use OO spell objects where beneficial

---

## 6. Code Templates

### 6.1 Context Builder Template

```lua
-- libraries/context_builder.lua

local context_builder = {}

---Build rotation context (call once per frame)
---@param me game_object
---@param target game_object|nil
---@param menu table
---@return table context
function context_builder.build(me, target, menu)
    local ctx = {}
    
    -- Player state
    ctx.me = me
    ctx.hp = me:get_health_percentage()
    ctx.rage = utils.get_rage(me)
    ctx.in_combat = me:is_in_combat()
    ctx.stance = utils.get_current_stance(me)
    
    -- Target state
    ctx.target = target
    ctx.has_target = target and target:is_valid()
    ctx.in_melee_range = target and utils.is_melee_target(me, target)
    ctx.target_hp = target and target:get_health_percentage()
    
    -- Threat data
    if target then
        ctx.threat_status = utils.get_threat_status(me, target)
        ctx.threat_pct = utils.get_threat_percentage(me, target)
    end
    
    -- Enemy count
    ctx.enemy_count = utils.count_nearby_enemies(me, 30)
    
    -- Debuff states (cached)
    ctx.sunder_stacks = target and utils.get_debuff_stacks(target, spells.DEBUFF_SUNDER) or 0
    ctx.thunder_clap_duration = target and utils.get_debuff_remaining(target, spells.DEBUFF_THUNDER_CLAP) or 0
    ctx.demo_shout_duration = target and utils.get_debuff_remaining(target, spells.DEBUFF_DEMO_SHOUT) or 0
    
    -- Settings references
    ctx.settings = menu
    
    return ctx
end

return context_builder
```

### 6.2 Priority Array Template

```lua
-- main.lua - New priority-based rotation

local ABILITY_PRIORITY = {
    -- Tier 1: Off-GCD Emergencies (highest priority)
    { name = "LastStand", fn = try_last_stand, off_gcd = true },
    { name = "ShieldWall", fn = try_shield_wall, off_gcd = true },
    { name = "ChallengingShout", fn = try_challenging_shout, off_gcd = true },
    { name = "Taunt", fn = try_taunt, off_gcd = true },
    
    -- Tier 2: GCD Abilities
    { name = "ShieldBlock", fn = try_shield_block },
    { name = "ThunderClap", fn = try_thunder_clap },
    { name = "DemoShout", fn = try_demo_shout },
    { name = "ShieldSlam", fn = try_shield_slam },
    { name = "Revenge", fn = try_revenge },
    { name = "Execute", fn = try_execute },
    { name = "Devastate", fn = try_devastate },
    { name = "SunderArmor", fn = try_sunder_armor },
    
    -- Tier 3: Off-GCD Rage Dump (lowest priority, fills GCD gaps)
    { name = "HeroicStrike", fn = try_heroic_strike, off_gcd = true },
}

local function on_update()
    -- Build context once per frame
    local me = core.object_manager.get_local_player()
    if not me or not me:is_valid() then return end
    
    local target = utils.find_best_target(me)
    local ctx = context_builder.build(me, target, menu)
    
    -- Execute in priority order
    for _, ability in ipairs(ABILITY_PRIORITY) do
        -- Check GCD state
        if not ability.off_gcd and not utils.is_gcd_ready(me) then
            goto continue
        end
        
        -- Try the ability
        if ability.fn(ctx) then
            return  -- Ability executed successfully
        end
        
        ::continue::
    end
end
```

### 6.3 Enhanced Taunt with Healer Priority

```lua
-- From flux/rotation/source/aio/warrior/protection.lua lines 565-596

local Prot_Taunt = {
    requires_combat = true,
    requires_enemy = true,
    is_gcd_gated = false,
    
    matches = function(context, state)
        if context.settings.prot_no_taunt then return false end
        -- Only taunt NPCs, not players
        if UnitIsPlayer(TARGET_UNIT) then return false end
        -- Skip if target is CC'd (taunting wastes 10s CD)
        if is_target_cc_locked(Constants.TAUNT.CC_THRESHOLD) then return false end
        -- Skip if we already have aggro
        if has_target_aggro() then return false end
        -- Only taunt elites and bosses — don't waste 10s CD on trash
        local classification = UnitClassification(TARGET_UNIT)
        if classification ~= "elite" and classification ~= "worldboss" and classification ~= "rareelite" then return false end
        -- TTD check: skip dying elites to save taunt CD
        -- Exception: ALWAYS taunt if elite is hitting a healer
        local targeting_healer = is_targettarget_healer()
        if not targeting_healer and (context.ttd or 999) < Constants.TAUNT.MIN_TTD then return false end
        return true
    end,
    
    execute = function(icon, context, state)
        local targeting_healer = is_targettarget_healer()
        local reason = targeting_healer and "HEALER TARGETED" or "taunting"
        return try_cast(A.Taunt, icon, TARGET_UNIT,
            format("[PROT] Taunt - Lost aggro - %s (TTD: %.0fs)", reason, context.ttd or 0))
    end,
}
```

---

## 7. Testing Checklist

### Functional Testing
- [ ] Tab targeting switches to loose mobs correctly
- [ ] Tab targeting respects manual target selection
- [ ] Defensive cooldowns trigger at correct HP thresholds
- [ ] Predictive defensive triggers before burst damage
- [ ] CC break prevention skips AoE near CC'd targets
- [ ] Healer-targeted taunt bypasses all other checks
- [ ] Thunder Clap stance dancing works correctly
- [ ] HS/Cleave queue trick preserves yellow OH hits

### Performance Testing
- [ ] Context builder caches data correctly (no redundant API calls)
- [ ] Tab targeting doesn't cause lag with many enemies
- [ ] Buff/debuff lookups use caching
- [ ] Memory allocation is stable (no growing tables per frame)

### Edge Cases
- [ ] Tab targeting with 0 loose mobs (stay on current)
- [ ] Tab targeting when already tanking all mobs (equalization mode)
- [ ] Defensive cooldowns when already buffed (don't overwrite)
- [ ] CC break prevention with multiple CC types
- [ ] Rage starvation scenarios

---

## 8. References

### Key Files

**Flux Tanking Implementations:**
- `flux/rotation/source/aio/warrior/protection.lua` - Protection Warrior (769 lines)
- `flux/rotation/source/aio/warrior/middleware.lua` - Shared warrior logic (1185+ lines)
- `flux/rotation/source/aio/druid/bear.lua` - Bear Druid (1061 lines)
- `flux/rotation/source/aio/paladin/protection.lua` - Protection Paladin (708 lines)
- `flux/rotation/source/aio/core.lua` - Framework infrastructure (1116 lines)

**EAX Current Implementations:**
- `EAXWarriorProtection/main.lua` - Current Protection Warrior (696 lines)
- `EAXWarriorProtection/libraries/menu.lua` - Menu configuration (369 lines)
- `EAXDruidBear/main.lua` - Current Bear Druid (353 lines)

**Project Sylvanas APIs:**
- `api/common/izi_sdk.lua` - IZI SDK main module
- `api/common/modules/buff_manager.lua` - Cached buff/debuff tracking
- `api/common/modules/combat_forecast.lua` - Combat prediction
- `api/common/modules/target_selector.lua` - Target selection integration
- `apidocs/pages/dev/libraries/izi/` - IZI SDK documentation

---

## 9. Summary for Implementation AI

### Top 3 Priorities (Start Here):

1. **Threat-Aware Tab Targeting** (HIGH IMPACT)
   - Port from Flux protection.lua lines 216-394
   - Use IZI SDK `izi.pick_enemy()` if available
   - Implement threat tier categorization (0-3)
   - Add manual target detection with grace period

2. **Smart Defensive Cooldowns** (HIGH IMPACT)
   - Enhance current HP-threshold system
   - Add `combat_forecast` integration for predictive triggers
   - Implement stance-aware defensive logic
   - Add PvP defensive stance at range feature

3. **Middleware Architecture** (MEDIUM IMPACT, HIGH MAINTAINABILITY)
   - Create context builder to share state between abilities
   - Convert sequential `try_*` functions to priority array
   - Separate off-GCD emergencies from GCD rotation
   - This enables all other enhancements

### Code Style Notes:
- EAX uses `snake_case` for functions, `SCREAMING_SNAKE_CASE` for constants
- Always nil-guard menu access: `(menu.item and menu.item:get()) or default`
- Cache hot-path APIs at module level (e.g., `local _get_local_player = core.object_manager.get_local_player`)
- Use squared distances for range checks (avoid `sqrt()`)
- Validate with `luac -p` before committing

### Testing Strategy:
- Test tab targeting in Stratholme/BRD with multiple mobs
- Verify defensive cooldowns with `/combatlog` or damage meter
- Test CC break prevention in dungeons with CC-capable classes

---

**Document End** | **Next Action**: Implement Phase 1 (Context Builder + Priority Array)
