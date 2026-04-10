-- ============================================================================
-- FLUX FRAMEWORK MIGRATION EXAMPLES
-- EAX Imperative API → Flux Declarative Strategy Registry
--
-- These examples show BEFORE/AFTER patterns for migrating EAX specs to Flux.
-- All examples follow exact Flux conventions from:
--   - flux/rotation/source/aio/core.lua
--   - flux/rotation/source/aio/warrior/class.lua
--   - flux/rotation/source/aio/warrior/fury.lua
--   - flux/rotation/source/aio/warrior/middleware.lua
-- ============================================================================

-- ============================================================================
-- EXAMPLE 1: COMBAT STRATEGY (Bloodthirst)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- BEFORE: Imperative EAXWarriorFury/main.lua pattern
-- ----------------------------------------------------------------------------
--[[
    EAX uses imperative function chains with manual priority ordering.
    Each ability is a function that returns boolean (success/fail).
    The main update loop calls these in hardcoded priority order.
--]]

-- EAX: Spell ID resolution at load time
local runtime = {
    bloodthirst_id = nil,
    whirlwind_id = nil,
    execute_id = nil,
}

local RUNTIME_SPELL_SPECS = {
    { field = "bloodthirst_id", ranks = spells.BLOODTHIRST },
    { field = "whirlwind_id", ranks = spells.WHIRLWIND },
    { field = "execute_id", ranks = spells.EXECUTE },
}

local function resolve_spells()
    for i = 1, #RUNTIME_SPELL_SPECS do
        local spec = RUNTIME_SPELL_SPECS[i]
        runtime[spec.field] = utils.resolve_spell_id(spec.ranks)
    end
end

-- EAX: Imperative Bloodthirst function
-- Called directly from on_update() in hardcoded sequence
local function try_bloodthirst(me, target, rage, target_hp_pct)
    -- Menu guard (nil-safe)
    if not (menu.use_bloodthirst and menu.use_bloodthirst:get_state()) then 
        return false 
    end
    
    -- Spell availability check
    if not target or not runtime.bloodthirst_id then 
        return false 
    end
    
    -- Execute phase check
    local EXECUTE_HP_THRESHOLD = 20
    if target_hp_pct <= EXECUTE_HP_THRESHOLD 
        and not (menu.execute_use_bt and menu.execute_use_bt:get_state()) then 
        return false 
    end
    
    -- Range check
    if not utils.is_melee_target(me, target) then 
        return false 
    end
    
    -- WW priority check (hardcoded logic)
    local ww_prio_count = (menu.ww_prio_count and menu.ww_prio_count:get()) or 0
    if ww_prio_count > 0 then
        local nearby = utils.enemy_count_in_radius(me, 8)
        if nearby >= ww_prio_count then
            local ww_cd = runtime.whirlwind_id 
                and core.spell_book.get_spell_cooldown(runtime.whirlwind_id) 
                or math.huge
            if ww_cd <= 0 and rage >= 25 then 
                return false 
            end
        end
    end
    
    -- Cast attempt
    if utils.cast_target(runtime.bloodthirst_id, target) then
        utils.log_debug(menu, "Bloodthirst")
        return true
    end
    
    return false
end

-- EAX: Main update loop - hardcoded priority chain
local function on_update()
    local me = _get_local_player()
    if not me then return end
    
    -- Menu guards
    if not (menu.enabled and menu.enabled:get_state()) then return end
    
    local target = me:get_target()
    local rage = utils.get_rage(me)
    local target_hp_pct = target and target:get_health_percentage() or 100
    
    -- Imperative priority chain: calls each function in sequence
    -- If any returns true, the chain stops (GCD consumed)
    if try_rampage(me) then return end
    if try_bloodthirst(me, target, rage, target_hp_pct) then return end
    if try_whirlwind(me, target, rage, target_hp_pct) then return end
    if try_execute(me, target, rage, target_hp_pct) then return end
    -- ... more abilities
end


-- ----------------------------------------------------------------------------
-- AFTER: Flux Declarative Strategy Pattern
-- ----------------------------------------------------------------------------
--[[
    Flux uses declarative strategy objects registered with rotation_registry.
    Each strategy has matches() → execute() pattern with automatic priority sorting.
    The framework calls matches() in priority order, executes the first matching strategy.
--]]

-- Flux: Module header (standard for all playstyle files)
local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "WARRIOR" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO Fury]|r Core module not loaded!")
    return
end

local A = NS.A                    -- Class Actions (from class.lua)
local Constants = NS.Constants      -- Class constants
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT
local TARGET_UNIT = NS.TARGET_UNIT
local format = string.format

-- Flux: Context builder - pre-allocated state table (no inline {} in combat)
local fury_state = {
    target_below_20 = false,
    bt_cd = 0,
    ww_cd = 0,
    enemy_count = 0,
}

-- Flux: Context builder function (called once per frame, shared by all strategies)
local function get_fury_state(context)
    -- Cache validation - avoid rebuilding state if already valid this frame
    if context._fury_valid then return fury_state end
    context._fury_valid = true
    
    -- Read from context (already populated by framework + class.lua extend_context)
    fury_state.target_below_20 = context.target_hp < 20
    fury_state.bt_cd = A.Bloodthirst:GetCooldown() or 0
    fury_state.ww_cd = A.Whirlwind:GetCooldown() or 0
    fury_state.enemy_count = context.enemy_count or 0
    
    return fury_state
end

-- Flux: Bloodthirst Strategy Object
-- Declarative pattern: matches() filters, execute() casts
local Fury_Bloodthirst = {
    -- Prerequisite flags (checked by framework before matches())
    requires_combat = true,   -- Must be in combat
    requires_enemy = true,    -- Must have valid enemy target
    
    -- matches(context, state) → boolean: Should this strategy execute?
    matches = function(context, state)
        -- During execute phase, check setting via context.settings
        if state.target_below_20 and context.settings.fury_execute_phase then
            if not context.settings.fury_bt_during_execute then return false end
        end
        
        -- Yield to WW when enough enemies nearby and WW is ready
        -- Settings read from context.settings (NOT captured at load time!)
        local ww_prio = context.settings.fury_ww_prio_count or 2
        if ww_prio > 0 
            and state.enemy_count >= ww_prio
            and context.rage >= 25
            and context.settings.fury_use_whirlwind
            and A.Whirlwind:IsReady(TARGET_UNIT, true, nil, nil, true) then
            return false
        end
        
        -- Framework spell readiness check
        return A.Bloodthirst:IsReady(TARGET_UNIT)
    end,
    
    -- execute(icon, context, state) → result, message: Perform the action
    execute = function(icon, context, state)
        -- NS.try_cast handles: availability check, IsReady(), Show(), logging
        return try_cast(A.Bloodthirst, icon, TARGET_UNIT, "[FURY] Bloodthirst")
    end,
}

-- Flux: Rampage Strategy (priority before Bloodthirst)
local Fury_Rampage = {
    requires_combat = true,
    spell = A.Rampage,              -- Framework validates spell availability
    spell_target = PLAYER_UNIT,
    
    matches = function(context, state)
        if not is_spell_available(A.Rampage) then return false end
        -- Activate if buff not present
        if not context.rampage_active then return true end
        -- Still building stacks
        if context.rampage_stacks < Constants.RAMPAGE_MAX_STACKS then return true end
        -- At max stacks, only refresh when duration low
        local threshold = context.settings.fury_rampage_threshold or 5
        return context.rampage_duration < threshold
    end,
    
    execute = function(icon, context, state)
        return try_cast(A.Rampage, icon, PLAYER_UNIT,
            format("[FURY] Rampage - Stacks: %d, Duration: %.1fs", 
                context.rampage_stacks, context.rampage_duration))
    end,
}

-- Flux: Execute Strategy (lower priority than core abilities)
local Fury_Execute = {
    requires_combat = true,
    requires_enemy = true,
    setting_key = "fury_execute_phase",  -- Auto-checked by framework
    
    matches = function(context, state)
        if not state.target_below_20 then return false end
        -- Pool extra rage for bigger Executes (+21 dmg per extra rage)
        if context.rage < 25 then return false end
        return A.Execute:IsReady(TARGET_UNIT)
    end,
    
    execute = function(icon, context, state)
        return try_cast(A.Execute, icon, TARGET_UNIT,
            format("[FURY] Execute - Rage: %d, HP: %.0f%%", context.rage, context.target_hp))
    end,
}

-- Flux: Registration with rotation_registry
-- Strategies are sorted by priority (higher = first), then executed in order
-- First strategy where matches() returns true gets execute() called
rotation_registry:register("fury", {
    named("Rampage",         Fury_Rampage),      -- Priority: 999 (first)
    named("Bloodthirst",     Fury_Bloodthirst),  -- Priority: 998
    -- named() sets strategy.name, registry auto-assigns descending priorities
    named("Execute",         Fury_Execute),
    -- ... more strategies
}, {
    -- Playstyle config: context_builder is called before strategy matching
    context_builder = get_fury_state,
})


-- ============================================================================
-- EXAMPLE 2: MIDDLEWARE (Interrupts)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- BEFORE: EAXWarriorFury/libraries/middleware_manager.lua
-- ----------------------------------------------------------------------------
--[[
    EAX middleware uses a chain-of-responsibility pattern with explicit
    registration functions. Middleware objects are created via factory functions.
--]]

local middleware = require("libraries/middleware")

-- EAX: Priority constants (local to middleware module)
local PRIORITY = {
    EMERGENCY_HEAL = 500,
    DEFENSIVE_CDS = 400,
    INTERRUPTS = 300,
    OFFENSIVE_CDS = 200,
    RECOVERY_ITEMS = 100,
}

-- EAX: Middleware factory function for interrupts
-- Creates a middleware object with explicit properties
function middleware.interrupt(spell_id, priority, setting_key)
    return {
        name = "Interrupt_" .. spell_id,
        priority = priority or PRIORITY.INTERRUPTS,
        is_gcd_gated = true,
        setting_key = setting_key,
        
        matches = function(ctx)
            -- Check setting
            if setting_key and not ctx.settings[setting_key] then return false end
            
            -- Combat state
            if not ctx.in_combat then return false end
            if not ctx.has_valid_enemy_target then return false end
            
            -- Target must be casting
            local castLeft = ctx.target_cast_remaining or 0
            if castLeft <= 0 then return false end
            
            -- Check cooldown
            local cd = core.spell_book.get_spell_cooldown(spell_id)
            if cd > 0 then return false end
            
            return true
        end,
        
        execute = function(icon, ctx)
            if icon and icon.cast then
                local ok = pcall(function() icon:cast(spell_id) end)
                if ok then
                    return true, "[MW] Interrupt"
                end
            end
            return false
        end,
    }
end

-- EAX: Initialize and register all middleware
-- Called once at load time, re-called when settings change
local _initialized = false

function middleware_manager.initialize(menu)
    if _initialized then return end
    if not menu then return end
    
    -- Clear existing to avoid duplicates
    middleware.clear()
    
    -- Register interrupt middleware
    local use_interrupt = (menu.use_interrupt and menu.use_interrupt:get_state()) or false
    if use_interrupt then
        -- Register Pummel (Berserker Stance)
        middleware.register(middleware.interrupt(
            WARRIOR_SPELLS.PUMMEL,
            PRIORITY.INTERRUPTS,
            "use_interrupt"
        ))
        
        -- Register Shield Bash (Defensive Stance)
        middleware.register(middleware.interrupt(
            WARRIOR_SPELLS.SHIELD_BASH,
            PRIORITY.INTERRUPTS - 5,
            "use_interrupt"
        ))
    end
    
    _initialized = true
end

-- EAX: Execute middleware chain
-- Called from main.lua on_update()
function middleware_manager.execute(icon, context)
    return middleware.execute(icon, context)
end


-- ----------------------------------------------------------------------------
-- AFTER: Flux Declarative Middleware Pattern
-- ----------------------------------------------------------------------------
--[[
    Flux middleware uses the same registry as strategies but with
    register_middleware(). Priority system is shared, higher = runs first.
    Middleware can be GCD-gated or off-GCD (is_gcd_gated = false).
--]]

-- Flux: Priority constants from core.lua (shared across all classes)
local Priority = NS.Priority
--[[
    NS.Priority.MIDDLEWARE = {
        FORM_RESHIFT = 500,
        EMERGENCY_HEAL = 400,
        PROACTIVE_HEAL = 390,
        DISPEL_CURSE = 350,
        DISPEL_POISON = 340,
        RECOVERY_ITEMS = 300,
        INNERVATE = 290,
        MANA_RECOVERY = 280,
        SELF_BUFF_MOTW = 150,
        OFFENSIVE_COOLDOWNS = 100,
    }
--]]

-- Flux: Interrupt middleware with stance dancing
-- Pummel: Berserker Stance only. If in Battle Stance, dance to Berserker first.
-- Shield Bash: Defensive Stance only (requires shield equipped).
-- Priority: Pummel > stance dance for Pummel > Shield Bash (no dance to Defensive).
rotation_registry:register_middleware({
    name = "Warrior_Interrupt",
    priority = 250,  -- Between RECOVERY_ITEMS (300) and MANA_RECOVERY (280)
    
    -- matches(context) → boolean
    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.use_interrupt then return false end
        if not context.has_valid_enemy_target then return false end
        return true  -- Full check in execute for cast detection
    end,
    
    -- execute(icon, context) → result, message
    execute = function(icon, context)
        local castLeft, _, _, _, notKickAble = Unit(TARGET_UNIT):IsCastingRemains()
        if not castLeft or castLeft <= 0 then return nil end
        
        local is_pvp_mode = context.is_pvp and context.settings.pvp_enabled
        
        -- PvP AntiFake: humanized random kick timing (CanInterrupt)
        local kick_allowed = true
        if is_pvp_mode then
            kick_allowed = Unit(TARGET_UNIT):CanInterrupt(true, nil, 15, 67)
        end
        
        -- PvP: Check kick immunity
        if is_pvp_mode and notKickAble then
            kick_allowed = false
        elseif kick_allowed then
            if notKickAble then return nil end
            
            -- PvP: Verify physical interrupt immunity
            if is_pvp_mode 
                and not A.Pummel:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForInterrupt) then
                return nil
            end
            
            -- Already in Berserker → Pummel directly
            if context.stance == Constants.STANCE.BERSERKER 
                and A.Pummel:IsReady(TARGET_UNIT) then
                return A.Pummel:Show(icon), 
                    format("[MW] Pummel - Cast: %.1fs", castLeft)
            end
            
            -- Already in Defensive → Shield Bash (requires shield)
            if context.stance == Constants.STANCE.DEFENSIVE 
                and A.ShieldBash:IsReady(TARGET_UNIT) then
                return A.ShieldBash:Show(icon), 
                    format("[MW] Shield Bash - Cast: %.1fs", castLeft)
            end
            
            -- In Battle Stance: dance to Berserker for Pummel
            if context.stance == Constants.STANCE.BATTLE and castLeft > 0.5 then
                local pummel_cd = A.Pummel:GetCooldown() or 0
                if pummel_cd <= 0 and A.BerserkerStance:IsReady(PLAYER_UNIT) then
                    return A.BerserkerStance:Show(icon), 
                        format("[MW] → Berserker (for Pummel) - Cast: %.1fs", castLeft)
                end
            end
        end
        
        -- PvP CC fallback chain: when kick on CD, try CC to interrupt
        if is_pvp_mode 
            and context.settings.pvp_interrupt_cc_fallback 
            and castLeft > 0.3 then
            -- Concussion Blow (stun, Prot talent)
            if context.in_melee_range
                and A.ConcussionBlow:IsReady(TARGET_UNIT)
                and A.ConcussionBlow:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForStun)
                and Unit(TARGET_UNIT):IsControlAble("stun") then
                return A.ConcussionBlow:Show(icon), 
                    format("[MW] Concussion Blow (interrupt) - Cast: %.1fs", castLeft)
            end
            
            -- Intimidating Shout (fear)
            if context.in_melee_range
                and A.IntimidatingShout:IsReady(TARGET_UNIT)
                and A.IntimidatingShout:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForFear)
                and Unit(TARGET_UNIT):IsControlAble("fear") then
                return A.IntimidatingShout:Show(icon), 
                    format("[MW] Intimidating Shout (interrupt) - Cast: %.1fs", castLeft)
            end
            
            -- War Stomp (Tauren racial, PBAoE stun)
            if context.in_melee_range
                and A.WarStomp:IsReady(PLAYER_UNIT)
                and A.WarStomp:AbsentImun(TARGET_UNIT, Constants.PVP.AuraForStun) then
                return A.WarStomp:Show(icon), 
                    format("[MW] War Stomp (interrupt) - Cast: %.1fs", castLeft)
            end
        end
        
        return nil
    end,
})

-- Flux: Another middleware example - Emergency Defensive (higher priority than interrupt)
rotation_registry:register_middleware({
    name = "Warrior_LastStand",
    priority = 500,  -- Higher than interrupt (250), runs first
    is_defensive = true,  -- Tag for dashboard/filtering
    
    matches = function(context)
        if not context.in_combat then return false end
        local threshold = context.settings.last_stand_hp or 0
        if threshold <= 0 then return false end
        if context.hp > threshold then return false end
        return true
    end,
    
    execute = function(icon, context)
        if A.LastStand:IsReady(PLAYER_UNIT) then
            return A.LastStand:Show(icon), 
                format("[MW] Last Stand - HP: %.0f%%", context.hp)
        end
        return nil
    end,
})

-- Flux: Off-GCD middleware example (HS/Cleave queue trick)
rotation_registry:register_middleware({
    name = "Warrior_HSQueueDequeue",
    priority = 999,  -- Highest priority - dequeue before MH swing
    is_gcd_gated = false,  -- Off-GCD: runs even during GCD
    
    matches = function(context)
        if not context.in_combat then return false end
        if not context.settings.hs_trick then return false end
        if not context.has_valid_enemy_target then return false end
        if not context.has_offhand then return false end
        return A.HeroicStrike:IsSpellCurrent() or A.Cleave:IsSpellCurrent()
    end,
    
    execute = function(icon, context)
        local mh_remaining = NS.get_time_until_swing()
        if mh_remaining > 0 and mh_remaining <= 0.4 then
            local oh_remaining = context.oh_remain or 999
            if oh_remaining <= 0 then oh_remaining = 999 end
            if mh_remaining <= oh_remaining and context.rage < 15 then
                return A:Show(icon, A.Const.STOPCAST), "[MW] HS Dequeue - Low rage"
            end
        end
        return nil
    end,
})


-- ============================================================================
-- EXAMPLE 3: DASHBOARD CONFIG
-- ============================================================================

-- ----------------------------------------------------------------------------
-- BEFORE: EAXWarriorFury/libraries/dashboard_config.lua
-- ----------------------------------------------------------------------------
--[[
    EAX dashboard uses a simple table return with spell IDs and labels.
    The dashboard.lua library reads this and renders the UI.
    
    local utils = require("libraries/utils")
    
    return {
        class_name = "Warrior Fury",
        class_id = 1,  -- Warrior class ID
        resource_type = "rage",
        
        -- Cooldowns to track (spell IDs)
        cooldowns = {
            12292,   -- Bloodrage
            18499,   -- Berserker Rage
            1719,    -- Recklessness
            12809,   -- Last Stand
            12328,   -- Death Wish
            29801,   -- Rampage
            6554,    -- Pummel
            20252,   -- Intercept
            1680,    -- Whirlwind
        },
        
        -- Buffs to monitor (with labels)
        buffs = {
            {id = 12964, label = "Unbridled Wrath"},
            {id = 12292, label = "Bloodrage"},
            {id = 18499, label = "Berserker Rage"},
            {id = 1719,  label = "Recklessness"},
            {id = 12809, label = "Last Stand"},
            {id = 12328, label = "Death Wish"},
            {id = 29801, label = "Rampage"},
            {id = 12970, label = "Flurry"},
            {id = 29131, label = "Bloodrage"},
        },
        
        -- Debuffs to track on target
        debuffs = {
            {id = 25225, label = "Sunder", target = true, show_stacks = true},
            {id = 25264, label = "Thunder Clap", target = true},
            {id = 25203, label = "Demoralizing Shout", target = true},
            {id = 11580, label = "Rend", target = true},
            {id = 30022, label = "Hamstring", target = true},
        },
        
        -- Custom dashboard lines (label, value function)
        custom_lines = {
            function(ctx)
                local stance = utils.get_stance_name and utils.get_stance_name() or "Unknown"
                return "Stance", stance
            end,
            function(ctx)
                local enrage = utils.get_enrage_status and utils.get_enrage_status() or false
                return "Enrage", enrage and "UP" or "DOWN"
            end,
        },
        
        -- Dashboard feature toggles
        show_timer_bars = true,
        show_action_history = true,
        show_energy_tick = false,
        show_combo_points = false,
        show_threat_bar = false,
        enable_smart_collapse = true,
    }
--]]


-- ----------------------------------------------------------------------------
-- AFTER: Flux Class Registration with Dashboard Config
-- ----------------------------------------------------------------------------
--[[
    Flux dashboard config is embedded in the class.lua register_class() call.
    Uses Action objects (A.SpellName) instead of raw spell IDs.
    Supports playstyle-specific sections (arms/fury/protection).
--]]

-- In flux/rotation/source/aio/warrior/class.lua:

rotation_registry:register_class({
    name = "Warrior",
    version = "v1.8.6",
    playstyles = { "arms", "fury", "protection" },
    
    -- Playstyle spell validation (schema.lua drives settings)
    playstyle_spells = {
        fury = {
            { spell = A.Bloodthirst, name = "Bloodthirst", required = true, note = "Fury talent" },
            { spell = A.Whirlwind, name = "Whirlwind", required = false },
            { spell = A.Execute, name = "Execute", required = false },
            { spell = A.Slam, name = "Slam", required = false },
            { spell = A.Rampage, name = "Rampage", required = false, note = "41pt Fury talent" },
            { spell = A.DeathWish, name = "Death Wish", required = false, note = "Fury talent" },
            { spell = A.Recklessness, name = "Recklessness", required = false },
        },
        -- ... arms, protection
    },
    
    -- DASHBOARD CONFIGURATION (replaces dashboard_config.lua)
    dashboard = {
        -- Resource bar type
        resource = { type = "rage", label = "Rage" },
        
        -- Cooldown tracking per playstyle (Action objects, not spell IDs)
        cooldowns = {
            arms = { 
                A.SweepingStrikes,   -- Arms-specific CD
                A.Recklessness, 
                A.DeathWish, 
                A.Trinket1,          -- Framework trinket slots
                A.Trinket2 
            },
            fury = { 
                A.DeathWish, 
                A.Recklessness, 
                A.Trinket1, 
                A.Trinket2 
            },
            protection = { 
                A.ShieldBlock, 
                A.ShieldWall, 
                A.LastStand, 
                A.Trinket1, 
                A.Trinket2 
            },
        },
        
        -- Buff tracking per playstyle (by buff ID, with labels)
        buffs = {
            fury = {
                -- Buff ID from Constants.BUFF_ID (class.lua)
                { id = Constants.BUFF_ID.DEATH_WISH, label = "DW" },
                { id = Constants.BUFF_ID.RECKLESSNESS, label = "Reck" },
                { id = Constants.BUFF_ID.RAMPAGE, label = "Ramp" },
                { id = Constants.BUFF_ID.FLURRY, label = "Flurry" },
            },
            arms = {
                { id = Constants.BUFF_ID.SWEEPING_STRIKES, label = "SS" },
                { id = Constants.BUFF_ID.RECKLESSNESS, label = "Reck" },
                { id = Constants.BUFF_ID.ENRAGE, label = "Enr" },
            },
            protection = {
                { id = Constants.BUFF_ID.SHIELD_BLOCK, label = "SB" },
                { id = Constants.BUFF_ID.LAST_STAND, label = "LS" },
                { id = Constants.BUFF_ID.SPELL_REFLECTION, label = "SR" },
            },
        },
        
        -- Debuff tracking per playstyle
        debuffs = {
            fury = {
                { 
                    id = Constants.DEBUFF_ID.SUNDER_ARMOR, 
                    label = "Sunder", 
                    target = true,      -- Check on target unit
                    show_stacks = true  -- Display stack count (5 max)
                },
            },
            arms = {
                { 
                    id = Constants.DEBUFF_ID.REND, 
                    label = "Rend", 
                    target = true 
                },
                { 
                    id = Constants.DEBUFF_ID.SUNDER_ARMOR, 
                    label = "Sunder", 
                    target = true, 
                    show_stacks = true 
                },
            },
            protection = {
                { id = Constants.DEBUFF_ID.SUNDER_ARMOR, label = "Sunder", target = true, show_stacks = true },
                -- owned = false: track even if applied by another player
                { id = Constants.DEBUFF_ID.THUNDER_CLAP, label = "TC", target = true, owned = false },
                { id = Constants.DEBUFF_ID.DEMO_SHOUT, label = "Demo", target = true, owned = false },
            },
        },
        
        -- Custom dashboard lines (label, value function)
        -- Functions receive context, return (label, value) strings
        custom_lines = {
            function(context) 
                return "Stance", STANCE_NAMES[context.stance] or "?" 
            end,
            function(context)
                -- Dual-wield diagnostic (off-hand swing remaining)
                if context.has_offhand then
                    return "OH Swing", format("%.1fs", context.oh_remain or 0)
                end
                return nil, nil  -- Skip this line if not dual-wielding
            end,
        },
    },
})


-- ============================================================================
-- KEY MIGRATION PATTERNS SUMMARY
-- ============================================================================

--[[

PATTERN                    EAX (Imperative)                    FLUX (Declarative)
------------------------   --------------------------------   --------------------------------------------------
Spell Definition           Spell ID tables (spells.lua)       Action objects via A.Create() in class.lua
Spell Resolution           Runtime resolve_spell_id()         Framework useMaxRank = true on Create()
Menu Access                menu.setting:get()                 context.settings.setting (cached, nil-safe)
Rotation Priority          Hardcoded function call order     Registry sorts by priority, auto-executes
Combat Checks              Manual in each function            Prerequisite flags: requires_combat, requires_enemy
State Management           Local tables, manual caching       context_builder() → shared state object
Casting                    utils.cast_target(id, target)      try_cast(Action, icon, target, log_msg)
Middleware Registration    middleware.register(factory())     rotation_registry:register_middleware({})
Middleware Priority        Local PRIORITY table               NS.Priority.MIDDLEWARE constants in core.lua
Interrupt Logic            Inline in main.lua                 Dedicated middleware with PvP fallbacks
Dashboard Config           dashboard_config.lua table         Embedded in register_class().dashboard
Cooldown Tracking          Spell ID arrays                    Action object references (A.SpellName)
Buff/Debuff Tracking       Raw spell IDs                      Constants.BUFF_ID / DEBUFF_ID references

--]]

-- ============================================================================
-- COMPLETE FLUX MODULE TEMPLATE (for new specs)
-- ============================================================================

--[[
    Use this template when creating a new Flux playstyle module:
    
    File: flux/rotation/source/aio/<class>/<playstyle>.lua
--]]

--[[
    Template for new Flux playstyle modules
    @class ExamplePlaystyle
--]]

local A_global = _G.Action
if not A_global or A_global.PlayerClass ~= "CLASSNAME" then return end

local NS = _G.FluxAIO
if not NS then
    print("|cFFFF0000[Flux AIO <Playstyle>]|r Core module not loaded!")
    return
end

if not NS.rotation_registry then
    print("|cFFFF0000[Flux AIO <Playstyle>]|r Registry not found!")
    return
end

-- Local references for performance
local A = NS.A
local Constants = NS.Constants
local Player = NS.Player
local Unit = NS.Unit
local rotation_registry = NS.rotation_registry
local try_cast = NS.try_cast
local named = NS.named
local is_spell_available = NS.is_spell_available
local PLAYER_UNIT = NS.PLAYER_UNIT
local TARGET_UNIT = NS.TARGET_UNIT
local format = string.format

-- ============================================================================
-- CONTEXT BUILDER (optional - if playstyle needs extra state)
-- ============================================================================
local playstyle_state = {
    -- Pre-allocated fields (no inline {} in combat)
}

local function get_playstyle_state(context)
    if context._playstyle_valid then return playstyle_state end
    context._playstyle_valid = true
    
    -- Populate from context + framework APIs
    -- Example: playstyle_state.my_cd = A.Spell:GetCooldown()
    
    return playstyle_state
end

-- ============================================================================
-- STRATEGIES
-- ============================================================================
do
    -- Strategy template:
    -- {
    --     name = "Optional_Name",           -- Auto-set by named()
    --     priority = 100,                  -- Auto-set by registry
    --     requires_combat = true,            -- Framework prerequisite check
    --     requires_enemy = true,             -- Framework prerequisite check
    --     requires_in_range = true,          -- Framework prerequisite check
    --     requires_phys_immune = false,      -- Framework prerequisite check
    --     setting_key = "use_spell",         -- Framework setting check
    --     spell = A.SpellName,               -- Framework availability check
    --     spell_target = "target",           -- Target for spell check
    --     is_gcd_gated = true,               -- Skip during GCD if true
    --     is_burst = true,                   -- Tag for burst conditions
    --     is_defensive = true,               -- Tag for defensive conditions
    --     
    --     matches = function(context, state) -- Return true to execute
    --         return true
    --     end,
    --     
    --     execute = function(icon, context, state) -- Return result, message
    --         return try_cast(A.Spell, icon, TARGET_UNIT, "[TAG] Spell Name")
    --     end,
    -- }
    
    -- Example strategies here...
    
    -- ============================================================================
    -- REGISTRATION
    -- ============================================================================
    rotation_registry:register("playstyle_name", {
        -- Strategies auto-sorted by priority (descending)
        -- named() sets strategy.name for debugging
        named("Strategy1", { }),
        named("Strategy2", { }),
    }, {
        -- Playstyle configuration
        context_builder = get_playstyle_state,  -- Optional
    })
end

print("|cFF00FF00[Flux AIO <Class>]|r <Playstyle> module loaded")


-- ============================================================================
-- END OF MIGRATION EXAMPLES
-- ============================================================================

-- Return empty table (this is an examples/documentation file)
return {}
