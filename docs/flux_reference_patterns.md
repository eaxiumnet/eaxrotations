# Flux AIO Reference Architecture Patterns

**Document Version**: 1.0  
**Date**: April 2026  
**Source**: `flux/rotation/source/aio/`  

This document establishes the baseline patterns from the Flux AIO rotation system for comparison against the 29 EAX TBC Classic rotation plugins.

---

## Table of Contents

1. [Overview](#overview)
2. [Strategy Registry Pattern](#strategy-registry-pattern)
3. [Settings Access Pattern](#settings-access-pattern)
4. [Middleware Execution Order](#middleware-execution-order)
5. [Force Command System](#force-command-system)
6. [Context Creation and Throttling](#context-creation-and-throttling)
7. [Spell Registration Pattern](#spell-registration-pattern)
8. [Architecture Diagrams](#architecture-diagrams)

---

## Overview

Flux AIO is a modular rotation system for World of Warcraft: The Burning Crusade Classic built on the GGL Action/Textfiles framework. It uses a **Strategy Registry** pattern where:

- **Middleware** handles cross-cutting concerns (recovery, cooldowns, buffs, dispels)
- **Strategies** handle playstyle-specific rotations
- **Context** provides a unified state object passed through the execution chain

### File Structure

```
flux/rotation/source/aio/
├── main.lua              # Entry point, rotation dispatcher
├── core.lua              # Strategy registry, namespace, utilities
├── ui.lua                # ProfileUI generator for framework
├── settings.lua          # Custom tabbed settings UI
├── common.lua            # Shared schema sections
├── warrior/
│   ├── schema.lua        # Settings schema definition
│   ├── class.lua         # Class registration, spell definitions
│   ├── middleware.lua    # Cross-playstyle middleware
│   └── fury.lua          # Playstyle-specific strategies
```

---

## Strategy Registry Pattern

### Core Registry Structure

The `rotation_registry` is the central hub for all rotation logic, defined in `core.lua`:

```lua
local rotation_registry = {
    middleware = {},           -- Array of middleware handlers
    strategy_maps = {},        -- Map[playstyle] -> strategies[]
    playstyle_config = {},     -- Per-playstyle configuration
    class_config = nil,        -- Set by register_class()
}
```

### Registration Methods

#### 1. Class Registration (`register_class`)

Called from `class.lua` to register the class and its playstyles:

```lua
-- From warrior/class.lua
rotation_registry:register_class({
    name = "Warrior",
    version = "v1.8.6",
    playstyles = { "arms", "fury", "protection" },
    idle_playstyle_name = nil,

    get_active_playstyle = function(context)
        return context.settings.playstyle or "fury"
    end,

    get_idle_playstyle = nil,

    playstyle_spells = {
        fury = {
            { spell = A.Bloodthirst, name = "Bloodthirst", required = true, note = "Fury talent" },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            -- ...
        },
    },

    extend_context = function(ctx)
        -- Add class-specific fields to context
        ctx.stance = Player:GetStance()
        ctx.rage = Player:Rage()
        -- ...
    end,

    gap_handler = function(icon, context)
        -- Handle /flux gap command
        if A.Charge:IsReady(TARGET_UNIT) then
            return A.Charge:Show(icon), "[GAP] Charge"
        end
        -- ...
    end,
})
```

#### 2. Strategy Registration (`register`)

Called from playstyle files (e.g., `fury.lua`) to register rotation strategies:

```lua
-- From warrior/fury.lua
rotation_registry:register("fury", {
    named("Rampage",         Fury_Rampage),
    named("Bloodthirst",     Fury_Bloodthirst),
    named("Whirlwind",       Fury_Whirlwind),
    named("Execute",         Fury_Execute),
    -- ... more strategies
}, {
    context_builder = get_fury_state,  -- Optional state builder
})
```

**Strategy Object Structure:**

```lua
local Fury_Bloodthirst = {
    requires_combat = true,      -- Prerequisite: must be in combat
    requires_enemy = true,       -- Prerequisite: must have valid enemy target
    setting_key = "fury_use_bt", -- Prerequisite: setting must be true
    is_gcd_gated = false,        -- If false, runs even during GCD
    is_burst = true,             -- Tag for /flux burst command
    is_defensive = false,        -- Tag for /flux defensive command

    matches = function(context, state)
        -- Return true if this strategy should execute
        return A.Bloodthirst:IsReady(TARGET_UNIT)
    end,

    execute = function(icon, context, state)
        -- Return result, log_message (optional)
        return try_cast(A.Bloodthirst, icon, TARGET_UNIT, "[FURY] Bloodthirst")
    end,
}
```

#### 3. Middleware Registration (`register_middleware`)

Called from `middleware.lua` to register cross-cutting concerns:

```lua
-- From warrior/middleware.lua
rotation_registry:register_middleware({
    name = "Warrior_Interrupt",
    priority = 250,

    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_interrupt then return false end
        return true
    end,

    execute = function(icon, context)
        local castLeft = Unit(TARGET_UNIT):IsCastingRemains()
        if castLeft and castLeft > 0 then
            if A.Pummel:IsReady(TARGET_UNIT) then
                return A.Pummel:Show(icon), "[MW] Pummel"
            end
        end
        return nil
    end,
})
```

### Execution Flow

```lua
-- From main.lua A[3] function (main rotation entry)
function A[3](icon)
    refresh_settings()
    local context = create_context(icon)

    -- 1. Check force commands first
    if is_force_active("force_gap") then
        return cc.gap_handler(icon, context)
    end

    -- 2. Execute middleware (priority-ordered)
    local mw_result = rotation_registry:execute_middleware(icon, context)
    if mw_result then return mw_result end

    -- 3. Determine active playstyle
    local active = cc.get_active_playstyle(context)

    -- 4. Execute strategies for active playstyle
    local result = rotation_registry:execute_strategies(active, icon, context)
    if result then return result end
end
```

### Priority System

Higher priority numbers execute first. From `core.lua`:

```lua
local Priority = {
    MIDDLEWARE = {
        FORM_RESHIFT = 500,      -- Emergency form/stance changes
        EMERGENCY_HEAL = 400,    -- Life-saving heals
        PROACTIVE_HEAL = 390,
        DISPEL_CURSE = 350,
        DISPEL_POISON = 340,
        RECOVERY_ITEMS = 300,    -- Healthstones, potions
        INNERVATE = 290,
        MANA_RECOVERY = 280,
        SELF_BUFF_MOTW = 150,
        SELF_BUFF_THORNS = 145,
        SELF_BUFF_OOC = 140,
        OFFENSIVE_COOLDOWNS = 100,
    },
}
```

Middleware is sorted by priority in descending order:

```lua
local function priority_desc_comparator(a, b)
    return a.priority > b.priority
end

table.sort(self.middleware, priority_desc_comparator)
```

---

## Settings Access Pattern

### Schema Definition

Settings are defined in `schema.lua` using a declarative schema:

```lua
-- From warrior/schema.lua
_G.FluxAIO_SETTINGS_SCHEMA = {
    [1] = {
        name = "General",
        sections = {
            {
                header = "Spec Selection",
                settings = {
                    {
                        type = "dropdown",
                        key = "playstyle",
                        default = "fury",
                        label = "Active Spec",
                        tooltip = "Which spec rotation to use.",
                        options = {
                            { value = "arms", text = "Arms" },
                            { value = "fury", text = "Fury" },
                            { value = "protection", text = "Protection" },
                        },
                    },
                },
            },
            {
                header = "Utility",
                settings = {
                    {
                        type = "checkbox",
                        key = "use_interrupt",
                        default = true,
                        label = "Auto Interrupt",
                        tooltip = "Interrupt enemy casts.",
                    },
                    {
                        type = "slider",
                        key = "bloodrage_min_hp",
                        default = 50,
                        min = 20,
                        max = 80,
                        label = "Bloodrage Min HP (%)",
                        format = "%d%%",
                    },
                },
            },
        },
    },
}
```

### Settings Caching

Settings are cached in `core.lua` to avoid repeated `GetToggle` calls:

```lua
-- In core.lua
local cached_settings = {}
local last_settings_update = 0
local SETTINGS_CACHE_DURATION = 0.05  -- 50ms throttle

local function refresh_settings()
    local now = GetTime()
    if now - last_settings_update < SETTINGS_CACHE_DURATION then return end

    for _, tab_def in ipairs(SETTINGS_SCHEMA) do
        for _, section in ipairs(tab_def.sections) do
            for _, s in ipairs(section.settings) do
                local raw = GetToggle(2, s.key)
                local value
                if s.type == "checkbox" then
                    if s.default == true then
                        value = raw ~= false
                    else
                        value = raw == true
                    end
                else
                    value = raw or s.default
                end
                cached_settings[s.key] = value
            end
        end
    end

    last_settings_update = now
end
```

### Access Pattern

**CRITICAL RULE**: Never capture settings at load time. Always access through `context.settings`:

```lua
-- CORRECT: Access via context in matches/execute
matches = function(context)
    if context.settings.use_interrupt then
        -- ...
    end
end

-- WRONG: Capturing at module load time
local use_interrupt = context.settings.use_interrupt  -- DON'T DO THIS
```

The context gets settings from the cached table:

```lua
-- In create_context() from main.lua
ctx.settings = cached_settings
```

---

## Middleware Execution Order

### Execution Sequence

1. **Force Commands** (highest priority override)
   - `/flux burst` → sets `force_burst` flag
   - `/flux defensive` → sets `force_defensive` flag
   - `/flux gap` → triggers gap handler

2. **Middleware Chain** (priority-descending)
   - Emergency (Last Stand, Shield Wall)
   - Loss of Control breakers
   - Recovery items (Healthstones, potions)
   - Interrupts
   - Buff maintenance
   - Cooldowns

3. **Playstyle Strategies**
   - Active playstyle determined by `get_active_playstyle(context)`
   - Strategies executed in priority order

### Middleware Priority Examples (Warrior)

```lua
-- From warrior/middleware.lua
-- Priority 999: HS Queue Dequeue (highest - must run before any GCD ability)
rotation_registry:register_middleware({
    name = "Warrior_HSQueueDequeue",
    priority = 999,
    is_gcd_gated = false,
    -- ...
})

-- Priority 500: Last Stand (emergency)
rotation_registry:register_middleware({
    name = "Warrior_LastStand",
    priority = 500,
    is_defensive = true,
    -- ...
})

-- Priority 400: Spell Reflection
rotation_registry:register_middleware({
    name = "Warrior_SpellReflection",
    priority = 400,
    is_defensive = true,
    is_gcd_gated = false,
    -- ...
})

-- Priority 250: Interrupt
rotation_registry:register_middleware({
    name = "Warrior_Interrupt",
    priority = 250,
    -- ...
})

-- Priority 140: Shout Maintenance
rotation_registry:register_middleware({
    name = "Warrior_ShoutMaintain",
    priority = 140,
    -- ...
})

-- Priority 100: Death Wish (burst)
rotation_registry:register_middleware({
    name = "Warrior_DeathWish",
    priority = 100,
    is_burst = true,
    -- ...
})
```

### GCD Gating

Middleware can opt out of GCD checks:

```lua
is_gcd_gated = false  -- Will run even when on GCD
```

This is used for:
- Off-GCD abilities (Heroic Strike queue)
- Emergency reactions (Spell Reflection)
- Stance changes

---

## Force Command System

### Command Definitions

From `settings.lua`:

```lua
SLASH_FLUXAIO1 = "/flux"
SlashCmdList["FLUXAIO"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "burst" then
        NS.set_force_flag("force_burst")
        NS.show_notification("BURST", 3.0, { 1.0, 0.5, 0.1 })
        print("|cFFFFFF00Burst|r cooldowns activated!")
        return
    end

    if msg == "defensive" or msg == "def" then
        NS.set_force_flag("force_defensive")
        NS.show_notification("DEFENSIVE", 3.0, { 0.3, 0.7, 1.0 })
        print("|cFFFFFF00Defensive|r cooldowns activated!")
        return
    end

    if msg == "gap" then
        NS.set_force_flag("force_gap")
        print("|cFFFFFF00Gap closer|r activated!")
        return
    end
end
```

### Flag Implementation

From `core.lua`:

```lua
-- Force command flags (expiry timestamps)
NS.force_burst = 0
NS.force_defensive = 0
NS.force_gap = 0

local FORCE_DURATION = 3.0

local function set_force_flag(flag_name)
    NS[flag_name] = GetTime() + FORCE_DURATION
end

local function is_force_active(flag_name)
    local expiry = NS[flag_name]
    return expiry > 0 and GetTime() < expiry
end

local function clear_force_flag(flag_name)
    NS[flag_name] = 0
end
```

### Force Bypass in Execution

From `main.lua`, middleware and strategies check for force flags:

```lua
function rotation_registry:execute_middleware(icon, context)
    local force_burst = is_force_active("force_burst")
    local force_defensive = is_force_active("force_defensive")

    for _, mw in ipairs(self.middleware) do
        -- Force-bypass: skip matches() for tagged middleware when force flag active
        local forced = (force_burst and mw.is_burst) or (force_defensive and mw.is_defensive)

        -- Safety: even when forced, spell must still be ready
        if forced and mw.spell then
            local target = mw.spell_target or "player"
            if not mw.spell:IsReady(target) then forced = false end
        end

        local matches = forced or mw.matches(context)

        if matches then
            local result, log_msg = mw.execute(icon, context)
            if result then
                set_last_action(mw.name, "MW")
                return result
            end
        end
    end
end
```

### Auto-Burst System

From `core.lua`:

```lua
local function should_auto_burst(context)
    local s = context.settings
    if not s then return nil end

    -- If no burst conditions configured, return nil (CDs fire freely)
    local any_configured = s.burst_in_combat or s.burst_on_pull or s.burst_on_execute or s.burst_on_bloodlust
    if not any_configured then return nil end

    -- Must be in combat with valid target
    if not context.in_combat then return false end
    if not context.has_valid_enemy_target then return false end

    if s.burst_in_combat then return true end
    if s.burst_on_pull and context.combat_time and context.combat_time < 5 then return true end
    if s.burst_on_execute and context.target_hp and context.target_hp < 20 then return true end
    if s.burst_on_bloodlust and (Unit(PLAYER_UNIT):HasBuffs(BLOODLUST_IDS) or 0) > 0 then return true end

    return false
end
```

---

## Context Creation and Throttling

### Context Structure

From `main.lua`:

```lua
-- Reusable context table (avoid allocation every frame)
local reusable_context = {}

local function create_context(icon)
    local ctx = reusable_context
    local gcd_remaining = Player:GCDRemains()
    local on_gcd = gcd_remaining > 0.1

    -- Generic fields (all classes)
    ctx.on_gcd = on_gcd
    ctx.icon = icon
    ctx.in_combat = (combat_status == 1 or combat_status == true)
    ctx.hp = Unit(PLAYER_UNIT):HealthPercent()
    ctx.mana_pct = mana_pct
    ctx.target_exists = Unit(TARGET_UNIT):IsExists()
    ctx.target_dead = Unit(TARGET_UNIT):IsDead()
    ctx.target_enemy = Unit(TARGET_UNIT):IsEnemy()
    ctx.has_valid_enemy_target = ctx.target_exists and not ctx.target_dead and ctx.target_enemy
    ctx.target_hp = Unit(TARGET_UNIT):HealthPercent()
    ctx.ttd = get_time_to_die(TARGET_UNIT)
    ctx.target_range = max_range or 0
    ctx.in_melee_range = (min_range and min_range <= 5) or false
    ctx.settings = cached_settings
    ctx.gcd_remaining = gcd_remaining

    -- Class-specific extension
    local cc = rotation_registry.class_config
    if cc and cc.extend_context then
        cc.extend_context(ctx)
    end

    return ctx
end
```

### Context Logging (Throttled)

From `main.lua`:

```lua
local last_context_log_time = 0
local CONTEXT_LOG_INTERVAL = 2.0

-- In execute_strategies:
if context.settings.log_context and context.in_combat then
    local now = GetTime()
    if (now - last_context_log_time) >= CONTEXT_LOG_INTERVAL then
        last_context_log_time = now
        -- Dump context to debug log
        local msg = format_context_log(context, state)
        AddDebugLogLine(msg)
    end
end
```

### Settings Refresh Throttling

From `core.lua`:

```lua
local SETTINGS_CACHE_DURATION = 0.05  -- 50ms

local function refresh_settings()
    local now = GetTime()
    if now - last_settings_update < SETTINGS_CACHE_DURATION then return end
    -- ... refresh logic
    last_settings_update = now
end
```

### Debug Print Throttling

From `core.lua`:

```lua
local debug_print_cache = {}

local function debug_print(...)
    local key = table.concat({...}, "|")
    local now = GetTime()
    local last_print = debug_print_cache[key]

    if not last_print or (now - last_print) >= 1.5 then
        local message = format("[%.1fs] %s", now, ...)
        AddDebugLogLine(message)
        debug_print_cache[key] = now
    end
end
```

---

## Spell Registration Pattern

### Spell Creation

From `warrior/class.lua`:

```lua
local Create = A.Create

Action[A.PlayerClass] = {
    -- Racials
    BloodFury = Create({ Type = "Spell", ID = 20572, Click = { unit = "player", type = "spell", spell = 20572 } }),
    Berserking = Create({ Type = "Spell", ID = 26296, Click = { unit = "player", type = "spell", spell = 26296 } }),

    -- Core Damage (useMaxRank with base IDs)
    HeroicStrike = Create({ Type = "Spell", ID = 78, useMaxRank = true }),
    Bloodthirst = Create({ Type = "Spell", ID = 23881, useMaxRank = true }),
    Execute = Create({ Type = "Spell", ID = 5308, useMaxRank = true }),

    -- Cooldowns (self-cast)
    DeathWish = Create({ Type = "Spell", ID = 12292, Click = { unit = "player", type = "spell", spell = 12292 } }),
    Recklessness = Create({ Type = "Spell", ID = 1719, Click = { unit = "player", type = "spell", spell = 1719 } }),

    -- Stances
    BattleStance = Create({ Type = "Spell", ID = 2457 }),
    DefensiveStance = Create({ Type = "Spell", ID = 71 }),
    BerserkerStance = Create({ Type = "Spell", ID = 2458 }),

    -- Items
    SuperHealingPotion = Create({ Type = "Potion", ID = 22829, QueueForbidden = true }),
    HealthstoneMaster = Create({ Type = "Item", ID = 22105, QueueForbidden = true }),
}
```

### Spell Availability Checking

From `core.lua`:

```lua
local unavailable_spells = {}

local function is_spell_known(spell)
    if not spell then return false, "nil" end
    local spell_id = spell.ID
    if not spell_id then return false, "no ID" end
    local spell_name = GetSpellInfo(spell_id)
    if not spell_name then return false, "ID:" .. tostring(spell_id) end
    if IsSpellKnown and IsSpellKnown(spell_id) then
        return true, spell_name
    end
    -- Fall through to framework check
    return spell:IsExists() == true, spell_name
end

local function check_spell_availability(entries, missing_spells, optional_missing)
    for _, entry in ipairs(entries) do
        local known, name = is_spell_known(entry.spell)
        if not known then
            if entry.spell then
                unavailable_spells[entry.spell] = true
            end
            if entry.required then
                table.insert(missing_spells, entry.name)
            else
                table.insert(optional_missing, entry.name)
            end
        end
    end
end

local function is_spell_available(spell)
    if not spell then return false end
    return not unavailable_spells[spell]
end
```

### Spell Validation on Playstyle Switch

From `core.lua`:

```lua
function rotation_registry:validate_playstyle_spells(playstyle)
    if playstyle == last_validated_playstyle then return end
    last_validated_playstyle = playstyle

    -- Clear unavailable cache
    for k in pairs(unavailable_spells) do
        unavailable_spells[k] = nil
    end

    local cc = self.class_config
    if not cc or not cc.playstyle_spells then return end

    local entries = cc.playstyle_spells[playstyle]
    if not entries then return end

    local missing_spells = {}
    local optional_missing = {}

    check_spell_availability(entries, missing_spells, optional_missing)

    -- Print results
    print("|cFF00FF00[Flux AIO]|r Switched to " .. playstyle .. " playstyle")
    if #missing_spells > 0 then
        print("|cFFFF0000[Flux AIO]|r MISSING REQUIRED SPELLS:")
        for _, spell_name in ipairs(missing_spells) do
            print("|cFFFF0000[Flux AIO]|r   - " .. spell_name)
        end
    end
end
```

### Safe Casting Helpers

From `core.lua`:

```lua
local function try_cast(spell, icon, target, log_message)
    if not is_spell_available(spell) then return nil end
    if not spell:IsReady(target) then return nil end
    local result = safe_ability_cast(spell, icon, target)
    if result then return result, log_message end
    return nil
end

local function try_cast_fmt(spell, icon, target, prefix, name, info_fmt, ...)
    if not is_spell_available(spell) then return nil end
    if not spell:IsReady(target) then return nil end
    local result = safe_ability_cast(spell, icon, target)
    if result then
        if info_fmt then
            return result, format("%s %s - " .. info_fmt, prefix, name, ...)
        end
        return result, format("%s %s", prefix, name)
    end
    return nil
end
```

---

## Architecture Diagrams

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUX AIO SYSTEM                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│  │   schema    │───→│    ui.lua   │───→│ ProfileUI[2]│        │
│  │   .lua      │    │  (ProfileUI │    │  (Framework) │        │
│  │             │    │   Generator)│    │              │        │
│  └─────────────┘    └─────────────┘    └─────────────┘        │
│         │                                                        │
│         │         ┌─────────────┐    ┌─────────────┐           │
│         └────────→│ settings.lua│───→│ Custom Tabbed│           │
│                   │  (Custom UI) │    │  Settings UI │           │
│                   └─────────────┘    └─────────────┘           │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │
│  │  common.lua │───→│   core.lua  │───→│   main.lua  │           │
│  │  (Shared    │    │  (Registry, │    │  (Dispatcher)│           │
│  │   Sections) │    │  Utilities) │    │              │           │
│  └─────────────┘    └──────┬──────┘    └──────┬──────┘           │
│                            │                   │                 │
│                            ↓                   ↓                 │
│                     ┌─────────────┐    ┌─────────────┐           │
│                     │rotation_registry│  │  A[3] Entry  │         │
│                     │             │    │   Point      │           │
│                     └──────┬──────┘    └─────────────┘           │
│                            │                                     │
│         ┌──────────────────┼──────────────────┐                 │
│         ↓                  ↓                  ↓                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐           │
│  │  class.lua  │    │middleware.lua│   │  fury.lua   │           │
│  │ (Spell Defs,│    │(Cross-cutting│   │(Strategies) │           │
│  │  Register)  │    │  Concerns)   │   │             │           │
│  └─────────────┘    └─────────────┘    └─────────────┘           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                     EXECUTION FLOW                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  A[3] (Main Entry)                                               │
│     │                                                            │
│     ▼                                                            │
│  refresh_settings() ──→ Update cached_settings (50ms throttle) │
│     │                                                            │
│     ▼                                                            │
│  create_context() ──────→ Build context object                   │
│     │         │                                                │
│     │         └─→ extend_context() [class-specific fields]    │
│     │                                                            │
│     ▼                                                            │
│  Check Force Commands                                            │
│     │                                                            │
│     ├─→ force_gap active? ──→ gap_handler() ──→ Return         │
│     │                                                            │
│     ▼                                                            │
│  execute_middleware() ──→ Priority-sorted middleware chain      │
│     │                                                            │
│     ├─→ Check is_force_active() for burst/defensive             │
│     ├─→ Check is_gcd_gated                                      │
│     ├─→ Run matches(context)                                    │
│     └─→ If matches, execute(icon, context) ──→ Return result      │
│                                                                  │
│     ▼                                                            │
│  get_active_playstyle() ──→ Determine current playstyle         │
│     │                                                            │
│     ▼                                                            │
│  execute_strategies() ──→ Playstyle-specific strategies         │
│     │                                                            │
│     ├─→ Check prerequisites (combat, enemy, range, etc.)        │
│     ├─→ Check is_force_active() for burst/defensive             │
│     ├─→ Run matches(context, state)                             │
│     └─→ If matches, execute(icon, context, state) ──→ Return    │
│                                                                  │
│     ▼                                                            │
│  A[1] (Suggestion Icon) ──→ Show idle-form suggestions          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Strategy Registry Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    REGISTRY DATA FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  LOAD PHASE                                                      │
│  ═════════                                                       │
│                                                                  │
│  1. common.lua ──→ FluxAIO_SECTIONS (shared schema sections)   │
│                                                                  │
│  2. schema.lua ──→ FluxAIO_SETTINGS_SCHEMA (full schema)         │
│       │                                                          │
│       ├─→ ui.lua ──→ A.Data.ProfileUI[2] (framework UI)         │
│       └─→ settings.lua ──→ Custom Settings UI                  │
│                                                                  │
│  3. core.lua ──→ rotation_registry (empty)                       │
│       │                                                          │
│       ├─→ Priority constants                                     │
│       ├─→ Utility functions (try_cast, is_spell_available)      │
│       └─→ Force command system                                   │
│                                                                  │
│  4. class.lua ──→ Spell definitions (A.Create)                    │
│       │                                                          │
│       └─→ rotation_registry:register_class(config)               │
│             │                                                    │
│             ├─→ class_config = config                            │
│             ├─→ strategy_maps[playstyle] = {}                    │
│             └─→ extend_context() defined                         │
│                                                                  │
│  5. middleware.lua ──→ register_middleware() calls               │
│       │                                                          │
│       └─→ rotation_registry.middleware[] ──→ sort by priority   │
│                                                                  │
│  6. fury.lua (playstyle) ──→ register() calls                   │
│       │                                                          │
│       └─→ rotation_registry.strategy_maps["fury"] ──→ sort         │
│                                                                  │
│  7. main.lua ──→ A[3] function (entry point)                     │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  RUNTIME PHASE                                                   │
│  ══════════════                                                  │
│                                                                  │
│  Every Frame:                                                    │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐      │
│  │ A[3]()  │───→│refresh_ │───→│ create_ │───→│execute_ │      │
│  │         │    │settings │    │context  │    │middleware│      │
│  └─────────┘    └─────────┘    └─────────┘    └────┬────┘      │
│                                                    │            │
│                              ┌─────────────────────┘            │
│                              ▼                                  │
│                         ┌─────────┐    ┌─────────┐              │
│                         │execute_ │───→│  Show   │              │
│                         │strategies│   │  icon   │              │
│                         └─────────┘    └─────────┘              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Settings Schema Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   SETTINGS SCHEMA ARCHITECTURE                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  FluxAIO_SETTINGS_SCHEMA                                         │
│  ═══════════════════════                                         │
│                                                                  │
│  [1] General Tab                                                 │
│    ├── Spec Selection                                            │
│    │   └── playstyle (dropdown: arms/fury/protection)           │
│    ├── Shouts                                                    │
│    │   ├── shout_type (dropdown)                                 │
│    │   └── auto_shout (checkbox)                                 │
│    ├── Debuff Maintenance                                        │
│    │   ├── sunder_armor_mode (dropdown)                         │
│    │   ├── maintain_thunder_clap (checkbox)                     │
│    │   └── maintain_demo_shout (checkbox)                       │
│    ├── Utility                                                   │
│    │   ├── use_interrupt (checkbox)                             │
│    │   ├── use_bloodrage (checkbox)                             │
│    │   └── bloodrage_min_hp (slider)                            │
│    ├── External Buff Management                                  │
│    ├── AoE                                                       │
│    ├── Heroic Strike                                             │
│    ├── AoE Safety                                                │
│    ├── Cooldown Management                                       │
│    ├── Recovery Items                                            │
│    ├── Out of Combat                                             │
│    ├── Burst Conditions (from S.burst())                        │
│    ├── Dashboard (from S.dashboard())                            │
│    └── Debug (from S.debug())                                    │
│                                                                  │
│  [2] Arms Tab                                                    │
│    ├── Core Abilities                                            │
│    ├── Rotation                                                  │
│    ├── Utility                                                   │
│    ├── Execute Phase                                             │
│    ├── Rage Dump                                                 │
│    └── Cooldowns                                                 │
│                                                                  │
│  [3] Fury Tab                                                    │
│    ├── Core Abilities                                            │
│    ├── Rage Dump & Utility                                       │
│    ├── Rampage                                                   │
│    ├── Utility                                                   │
│    ├── Execute Phase                                             │
│    └── Cooldowns                                                 │
│                                                                  │
│  [4] Protection Tab                                              │
│    ├── Core Abilities                                            │
│    ├── Utility                                                   │
│    ├── Debuffs                                                   │
│    ├── Rage Dump                                                 │
│    ├── Taunts                                                    │
│    ├── Threat Tab Targeting                                      │
│    └── Threat Lead Gate                                          │
│                                                                  │
│  [5] CDs & Survival Tab                                            │
│    ├── Trinkets & Racial (from S.trinkets())                     │
│    └── Emergency Survival                                        │
│                                                                  │
│  [6] PvP Tab                                                     │
│    ├── PvP General                                                 │
│    ├── Offensive                                                 │
│    ├── CC & Control                                              │
│    ├── Interrupts (PvP)                                          │
│    └── Defensive                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Patterns Summary

| Pattern | Implementation | Location |
|---------|---------------|----------|
| **Strategy Registry** | `rotation_registry:register()`, `register_middleware()`, `register_class()` | `core.lua` |
| **Settings Access** | `context.settings.key` (never cache at load) | All files |
| **Middleware Priority** | Higher number = runs first, sorted descending | `core.lua` |
| **Force Commands** | `/flux burst`, `/flux defensive`, `/flux gap` | `settings.lua` |
| **Context Creation** | Reusable table, 50ms settings throttle | `main.lua`, `core.lua` |
| **Spell Registration** | `A.Create({ Type = "Spell", ID = n })` | `class.lua` |
| **GCD Gating** | `is_gcd_gated = false` to run during GCD | Middleware/Strategies |
| **Burst Tagging** | `is_burst = true` for `/flux burst` targeting | Middleware/Strategies |
| **Defensive Tagging** | `is_defensive = true` for `/flux defensive` | Middleware/Strategies |
| **Prerequisites** | `requires_combat`, `requires_enemy`, `setting_key` | Strategy objects |

---

## Comparison Notes for EAX Review

When comparing EAX plugins against this Flux reference:

1. **Menu Guards**: EAX uses `(menu.x and menu.x:get()) or default` pattern
2. **Settings**: Flux uses `context.settings.key` - verify EAX equivalent
3. **Registry**: Flux has explicit registry - check if EAX has similar
4. **Middleware**: Flux separates cross-cutting concerns - check EAX structure
5. **Force Commands**: Flux has `/flux` commands - check EAX equivalents
6. **Context**: Flux builds unified context - check EAX context building
7. **Throttling**: Flux throttles settings/context logging - verify EAX throttling

---

*End of Flux Reference Architecture Documentation*
