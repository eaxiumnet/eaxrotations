-- Mage Arcane priority list with burn/conserve phase state machine.

-- ============================================================================
-- What: TBC Mage Arcane priority with Arcane Blast stacks and burn/conserve flow.
-- When: Evaluated every tick.
-- Why: Priority-list early exit keeps combat decisions fast and predictable.
-- Safety: All settings nil-guarded; shared data is pcall-gated; conservative fallbacks.
-- ============================================================================

--
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { SPELLS = { mage = {} } } end
local TBC_MAGE = (TBC.SPELLS and TBC.SPELLS.mage) or {}

-- ============================================================================
-- Buff / Debuff IDs
-- ============================================================================
local ARCANE_BLAST_DEBUFF = { 36032, 36033, 36034 }  -- AB debuff: increases mana cost, reduces cast time
local ARCANE_POWER_BUFF = { 12042 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local MANA_SHIELD_BUFF = { 27131, 10193, 10192, 10191, 8495, 8494, 1463 }
local CLEARCASTING_BUFF = { 12536 }  -- Clearcasting proc from Arcane Concentration talent
local SLOW_DEBUFF = { 31589 }
local FROST_NOVA_ROOTS = TBC_MAGE.frost_nova or { 27088, 10230, 6131, 865, 122 }

-- ============================================================================
-- Constants
-- ============================================================================
local AB_BASE_MANA_COST = 195              -- AB rank 1 (~20% of ~975 base mana)
local AB_MANA_MULT_PER_STACK = 0.75         -- Each stack: +75% mana cost
local AB_BASE_CAST_TIME = 2.5               -- Base cast time (seconds)
local AB_CAST_REDUCTION_PER_STACK = 0.1     -- Each stack: -0.1s cast time
local AB_STACK_DURATION = 8                 -- Stacks last 8 seconds

-- MTTE constants (conservative estimates including Fire Blast / AM filler)
local MTTE_BURN_MPS_MULT = 1.4              -- Add 40% overhead for rotations with instant casts
local MTTE_CONSERVE_MPS = 100               -- ~100 mana/sec during conserve (AM filler + regen)

-- Bloodlust / Heroism buff IDs
local BLOODLUST_BUFFS = { 2825, 32182 }

-- Mana Gem spell IDs (not defined in class_sylvanas.lua, use local constant)
local MANA_GEM_SPELLS = TBC_MAGE.conjure_mana_gem or { 27101, 10054, 10053, 3552, 759 }  -- Conjure Mana Emerald -> Agate.

-- Phases
local PHASE_BURN = "burn"
local PHASE_CONSERVE = "conserve"
local PHASE_EMERGENCY = "emergency"

-- ============================================================================
-- Phase State Machine State
-- ============================================================================
local arcane_state = {
    phase = PHASE_CONSERVE,
    ab_stacks = 0,
    ab_remains = 0,
    has_arcane_power = false,
    has_presence_of_mind = false,
    has_ice_barrier = false,
    has_mana_shield = false,
    mana_pct = 100,
    hp_pct = 100,
    max_mana = 15000,
    in_combat = false,
    is_moving = false,
    target_casting = false,
    min_mtte = 12,
    mtte_burn = 999,
    mtte_conserve = 999,
    mana_gem_available = false,
    evocation_available = false,
    bloodlust_active = false,
    can_burn = false,
    should_conserve = false,
}

-- ============================================================================
-- Helper Functions
-- ============================================================================

--- Get current Arcane Blast stack count and remaining duration
local function get_ab_stacks(me)
    if not me then return 0, 0 end
    local stacks = NS.buff_stacks and NS.buff_stacks(me, ARCANE_BLAST_DEBUFF) or 0
    local remains = NS.buff_remains and NS.buff_remains(me, ARCANE_BLAST_DEBUFF) or 0
    return stacks, remains
end

--- Calculate MTTE at a given AB stack level using actual player max mana.
--- @param mana_pct number Current mana percentage (0-100)
--- @param ab_stacks number Current AB stacks (0-3)
--- @param max_mana number Player's maximum mana pool
--- @return number mtte Seconds until empty at this stack level (999 if indefinitely sustainable)
local function calc_mtte(mana_pct, ab_stacks, max_mana)
    if mana_pct <= 0 then return 0 end
    local est_mana = max_mana * (mana_pct / 100)
    if ab_stacks <= 0 then
        -- Conserve: AM filler costs ~310 mana per 5s channel, plus regen
        if MTTE_CONSERVE_MPS <= 0 then return 999 end
        return est_mana / MTTE_CONSERVE_MPS
    end
    local mana_cost = AB_BASE_MANA_COST * (1 + AB_MANA_MULT_PER_STACK * ab_stacks)
    local cast_time = math.max(1.0, AB_BASE_CAST_TIME - AB_CAST_REDUCTION_PER_STACK * ab_stacks)
    local mps = (mana_cost / cast_time) * MTTE_BURN_MPS_MULT
    if mps <= 0 then return 999 end
    return est_mana / mps
end

--- Get a numeric setting value
--- @param context table Rotation context
--- @param key string Setting key
--- @param default number Default value
--- @return number setting value
local function get_setting_num(context, key, default)
    local settings = context.settings
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return default
end

--- Get a boolean setting value
--- @param context table Rotation context
--- @param key string Setting key
--- @param default boolean Default value
--- @return boolean setting value
local function get_setting_bool(context, key, default)
    local settings = context.settings
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return default
end

-- ============================================================================
-- State Builder (called once per frame by the framework)
-- ============================================================================
local function build_state(context)
    local me = context.me or NS.GetPlayer()
    local s = arcane_state

    -- Basic state
    s.mana_pct = context.mana_pct or (me and NS.unit_mana_pct and NS.unit_mana_pct(me)) or 100
    s.hp_pct = context.hp or (me and NS.unit_health_pct and NS.unit_health_pct(me)) or 100
    s.in_combat = context.in_combat or false
    s.is_moving = context.is_moving or false
    s.target_casting = context.target and context.target.is_casting and context.target:is_casting() or false

    if me then
        -- Actual max mana for realistic MTTE
        s.max_mana = (me.get_max_mana and me:get_max_mana()) or (NS.unit_max_mana and NS.unit_max_mana(me)) or 15000
        if s.max_mana <= 0 then s.max_mana = 15000 end

        s.ab_stacks, s.ab_remains = get_ab_stacks(me)
        s.has_arcane_power = NS.buff_up and NS.buff_up(me, ARCANE_POWER_BUFF) or false
        s.has_presence_of_mind = NS.buff_up and NS.buff_up(me, PRESENCE_OF_MIND_BUFF) or false
        s.has_ice_barrier = NS.buff_up and NS.buff_up(me, ICE_BARRIER_BUFF) or false
        s.has_mana_shield = NS.buff_up and NS.buff_up(me, MANA_SHIELD_BUFF) or false
        s.bloodlust_active = false
        for _, buff_id in ipairs(BLOODLUST_BUFFS) do
            if NS.buff_up and NS.buff_up(me, { buff_id }) then
                s.bloodlust_active = true
                break
            end
        end
    end

    -- Cooldown availability
    s.evocation_available = me and NS.spell_ready and NS.spell_ready(SPELLS.Evocation, me, { skip_range = true }) or false
    s.mana_gem_available = false
    if me then
        -- Check each mana gem spell individually (SPELLS.ManaGem doesn't exist in class_sylvanas)
        for _, gem_id in ipairs(MANA_GEM_SPELLS) do
            if NS.spell_ready and NS.spell_ready(gem_id, me, { skip_range = true }) then
                s.mana_gem_available = true
                break
            end
        end
    end
    s.arcane_power_available = me and NS.spell_ready and NS.spell_ready(SPELLS.ArcanePower, me, { skip_range = true }) or false
    s.has_clearcasting = NS.buff_up and NS.buff_up(me, CLEARCASTING_BUFF) or false

    -- MTTE calculations using actual max mana
    local cur_stacks = s.ab_stacks
    s.mtte_burn = calc_mtte(s.mana_pct, math.max(cur_stacks, 2), s.max_mana)
    s.mtte_conserve = calc_mtte(s.mana_pct, 0, s.max_mana)

    -- Phase decision
    local burn_enabled = get_setting_bool(context, "arcane_use_burn", true)
    local burn_threshold = get_setting_num(context, "arcane_burn_mana_threshold", 65)
    local conserve_threshold = get_setting_num(context, "arcane_conserve_mana_threshold", 25)
    local min_mtte = get_setting_num(context, "arcane_mtte_min", 12)
    s.min_mtte = min_mtte

    -- Emergency: mana critically low
    if s.mana_pct < 10 then
        s.phase = PHASE_EMERGENCY
        s.can_burn = false
        s.should_conserve = true
        return s
    end

    -- Determine if we can sustain a burn phase
    s.can_burn = burn_enabled
        and s.mana_pct >= burn_threshold
        and s.mtte_burn >= min_mtte
        and not s.has_arcane_power  -- don't re-evaluate mid-burn CD

    -- If bloodlust is active and we have enough mana, always burn
    if s.bloodlust_active and s.mana_pct >= burn_threshold * 0.8 then
        s.can_burn = true
    end

    -- Determine if we should conserve (low mana or poor MTTE)
    s.should_conserve = s.mana_pct <= conserve_threshold
        or s.mtte_burn < 5

    -- Phase transition logic
    if s.can_burn and s.phase ~= PHASE_BURN and not s.should_conserve then
        -- Enter burn: high mana, good MTTE, not currently conserving
        if s.mana_pct >= burn_threshold then
            s.phase = PHASE_BURN
        end
    elseif s.should_conserve then
        -- Enter conserve: low mana or poor MTTE
        s.phase = PHASE_CONSERVE
    elseif s.phase == PHASE_BURN and s.mana_pct < conserve_threshold then
        -- Mana depleted during burn, switch to conserve
        s.phase = PHASE_CONSERVE
    elseif s.phase == PHASE_BURN and not s.can_burn and s.mana_pct < burn_threshold then
        -- Can't sustain burn anymore
        s.phase = PHASE_CONSERVE
    elseif s.phase ~= PHASE_BURN and s.phase ~= PHASE_CONSERVE then
        -- Default to conserve
        s.phase = PHASE_CONSERVE
    end

    return s
end

-- ============================================================================
-- Action Templates
-- ============================================================================
local ICE_BARRIER_ACTION = { name = "IceBarrier", spell = SPELLS.IceBarrier, target = "self", kind = "buff", buff = ICE_BARRIER_BUFF, requires_target = false }
local MANA_SHIELD_ACTION = { name = "ManaShield", spell = SPELLS.ManaShield, target = "self", kind = "buff", buff = MANA_SHIELD_BUFF, requires_target = false }
local COUNTERSPELL_ACTION = { name = "Counterspell", spell = SPELLS.Counterspell, cooldown = 24 }
local POLYMORPH_ACTION = { name = "Polymorph", spell = SPELLS.Polymorph, cooldown = 1.5 }
local FROST_NOVA_ACTION = { name = "FrostNova", spell = SPELLS.FrostNova, cooldown = 25 }
local SLOW_ACTION = { name = "Slow", spell = SPELLS.Slow, debuff = SLOW_DEBUFF }
local POM_ACTION = { name = "PresenceOfMind", spell = SPELLS.PresenceOfMind, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns" }
local AP_ACTION = { name = "ArcanePower", spell = SPELLS.ArcanePower, target = "self", combat = true, cooldown = 180, requires_target = false, setting = "use_cooldowns" }
local EVOCATION_ACTION = { name = "Evocation", spell = SPELLS.Evocation, target = "self", combat = true, requires_target = false, setting = "use_evocation" }
local MANA_GEM_ACTION = { name = "ManaGem", spell = MANA_GEM_SPELLS, target = "self", requires_target = false, setting = "use_mana_gem" }
local ARCANE_BLAST_ACTION = { name = "ArcaneBlast", spell = SPELLS.ArcaneBlast, not_moving = true }
local FIRE_BLAST_ACTION = { name = "FireBlast", spell = SPELLS.FireBlast, cooldown = 8 }
local ARCANE_MISSILES_ACTION = { name = "ArcaneMissiles", spell = SPELLS.ArcaneMissiles, not_moving = true }

-- ============================================================================
-- Match Functions (receive state from framework via get_state)
-- ============================================================================

--- Ice Barrier: cast when hp is low and barrier isn't up
local function ice_barrier_matches(context, s)
    if s.has_ice_barrier then return false end
    if s.hp_pct > 60 then return false end
    if not get_setting_bool(context, "use_defensives", true) then return false end
    return NS.action_matches(context, ICE_BARRIER_ACTION)
end

--- Mana Shield: cast when hp is critically low and mana is available
local function mana_shield_matches(context, s)
    if s.has_mana_shield then return false end
    if s.hp_pct > 40 then return false end
    if s.mana_pct < 30 then return false end
    if not get_setting_bool(context, "use_defensives", true) then return false end
    return NS.action_matches(context, MANA_SHIELD_ACTION)
end

--- Counterspell: interrupt casting target
local function counterspell_matches(context, s)
    if not context.target then return false end
    if not s.target_casting then return false end
    if not get_setting_bool(context, "use_interrupt", true) then return false end
    return NS.action_matches(context, COUNTERSPELL_ACTION)
end

--- Polymorph: crowd control in PvP
local function polymorph_matches(context, s)
    if not context.is_pvp then return false end
    if not context.cc_target then return false end
    if context.is_moving then return false end
    return NS.action_matches(context, POLYMORPH_ACTION)
end

--- Frost Nova: self-peel when target is in melee range
local function frost_nova_matches(context, s)
    if not (context.is_pvp or context.is_leveling or context.is_solo) then return false end
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 40
    if dist > 10 then return false end
    return NS.action_matches(context, FROST_NOVA_ACTION)
end

--- Slow: PvP snare for kiting
local function slow_matches(context, s)
    if not context.is_pvp then return false end
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 40
    if dist <= 8 then return false end
    return NS.action_matches(context, SLOW_ACTION)
end

--- Presence of Mind: use as burst opener or during movement
local function pom_matches(context, s)
    if s.has_presence_of_mind then return false end
    if not s.in_combat then return false end
    if not get_setting_bool(context, "use_cooldowns", true) then return false end
    -- Only use PoM during burn phase or bloodlust
    if s.phase ~= PHASE_BURN and not s.bloodlust_active then return false end
    -- Use PoM while moving to maintain DPS
    if s.is_moving then return true end
    return NS.action_matches(context, POM_ACTION)
end

--- Arcane Power: burn cooldown synced with AB stacks and bloodlust
local function arcane_power_matches(context, s)
    if s.has_arcane_power then return false end
    if not s.in_combat then return false end
    if not get_setting_bool(context, "use_cooldowns", true) then return false end
    if not get_setting_bool(context, "arcane_use_burn", true) then return false end
    -- Only use AP during burn phase or bloodlust
    if s.phase ~= PHASE_BURN and not s.bloodlust_active then return false end
    -- Require sufficient mana to sustain the full duration
    if s.mana_pct < 35 then return false end
    -- Prefer high AB stacks for max value
    if s.ab_stacks >= 2 then return true end
    -- Always cast AP during burn if we have the mana
    if s.phase == PHASE_BURN and s.mana_pct >= 50 then return true end
    return NS.action_matches(context, AP_ACTION)
end

--- Evocation: mana recovery during conserve/emergency
local function evocation_matches(context, s)
    if not s.in_combat then return false end
    if not get_setting_bool(context, "use_evocation", true) then return false end
    if not s.evocation_available then return false end
    local evo_mana = get_setting_num(context, "arcane_evocation_mana", 20)
    -- Emergency: very low mana
    if s.mana_pct <= evo_mana then
        return NS.action_matches(context, EVOCATION_ACTION)
    end
    -- During conserve phase: evocate if below threshold to enable next burn
    if s.phase == PHASE_CONSERVE and s.mana_pct <= 30 then
        return NS.action_matches(context, EVOCATION_ACTION)
    end
    return false
end

--- Mana Gem: use proactively during burn when mana is dropping
local function mana_gem_matches(context, s)
    if not get_setting_bool(context, "use_mana_gem", true) then return false end
    if not s.mana_gem_available then return false end
    local gem_mana = get_setting_num(context, "arcane_mana_gem_mana", 55)
    -- Use during burn when mana drops below threshold
    if s.phase == PHASE_BURN and s.mana_pct <= gem_mana then
        return NS.action_matches(context, MANA_GEM_ACTION)
    end
    -- Use during conserve to speed up recovery
    if s.phase == PHASE_CONSERVE and s.mana_pct <= 35 then
        return NS.action_matches(context, MANA_GEM_ACTION)
    end
    return false
end

--- Arcane Blast: primary nuke, stack management per phase
local function arcane_blast_matches(context, s)
    if s.is_moving then return false end
    if not context.target then return false end
    if not NS.action_matches(context, ARCANE_BLAST_ACTION) then return false end

    -- Phase-based stack limits
    local max_stacks
    if s.phase == PHASE_BURN then
        max_stacks = get_setting_num(context, "arcane_burn_max_stacks", 3)
    else
        max_stacks = get_setting_num(context, "arcane_conserve_max_stacks", 0)
        -- Emergency: always 0 stacks
        if s.phase == PHASE_EMERGENCY then max_stacks = 0 end
    end

    -- Zero-stack mode: never cast AB
    if max_stacks == 0 then return false end

    -- If we're already at max stacks for our phase, only cast AB to maintain them
    if s.ab_stacks >= max_stacks then
        if s.ab_remains > 1.5 then return false end  -- Not about to drop
    end

    -- Don't build stacks if mana is critically low
    -- Clearcasting: always consume on AB (highest mana cost) per research Angle 5
    if s.has_clearcasting then return true end

    if s.mana_pct < 15 then
        if s.ab_stacks >= max_stacks then return false end
        -- Allow building to 1 stack max when below 15% mana
        if max_stacks > 0 and s.ab_stacks >= 1 then return false end
    end

    return NS.spell_ready(SPELLS.ArcaneBlast, context.target)
end

--- Fire Blast: instant filler, use on cooldown or while moving
local function fire_blast_matches(context, s)
    if not context.target then return false end
    if not NS.action_matches(context, FIRE_BLAST_ACTION) then return false end
    -- Priority while moving (instant cast)
    if s.is_moving then return true end
    -- Priority when AB is at max stacks (weave instant between AB casts)
    local max_stacks = s.phase == PHASE_BURN
        and get_setting_num(context, "arcane_burn_max_stacks", 3)
        or get_setting_num(context, "arcane_conserve_max_stacks", 0)
    if s.ab_stacks >= max_stacks then return true end
    -- Otherwise fire blast as filler
    return true
end

--- Arcane Missiles: filler that doesn't stack AB
local function arcane_missiles_matches(context, s)
    if s.is_moving then return false end
    if not context.target then return false end
    if not NS.action_matches(context, ARCANE_MISSILES_ACTION) then return false end

    -- Clearcasting: always consume free AM casts (per research Angle 5)
    if s.has_clearcasting then return true end

    -- During burn: use AM only when mana is low
    if s.phase == PHASE_BURN then
        if s.mana_pct < 20 then
            return NS.spell_ready(SPELLS.ArcaneMissiles, context.target)
        end
        return false  -- Prefer AB in burn
    end

    -- During conserve/emergency: AM is the primary filler
    if s.phase == PHASE_CONSERVE or s.phase == PHASE_EMERGENCY then
        return NS.spell_ready(SPELLS.ArcaneMissiles, context.target)
    end

    return false
end

--- Low-level bolt (Fireball/Frostbolt for leveling before AB is learned)
local function low_level_bolt_matches(context, s)
    if not context.is_leveling then return false end
    if s.is_moving then return false end
    if NS.spell_exists(SPELLS.ArcaneBlast) then return false end
    return true
end

-- ============================================================================
-- Strategies (state passed by framework via get_state)
-- ============================================================================
local strategies = {
    -- Defensives (highest priority)
    { name = "IceBarrier",
      matches = ice_barrier_matches,
      execute = function(context) return NS.action_execute(context, ICE_BARRIER_ACTION, "[ARCANE]") end },
    { name = "ManaShield",
      matches = mana_shield_matches,
      execute = function(context) return NS.action_execute(context, MANA_SHIELD_ACTION, "[ARCANE]") end },

    -- Interrupt
    { name = "Counterspell",
      matches = counterspell_matches,
      execute = function(context) return NS.action_execute(context, COUNTERSPELL_ACTION, "[ARCANE]") end },

    -- CC / Utility
    { name = "Polymorph",
      matches = polymorph_matches,
      execute = function(context) return NS.action_execute(context, POLYMORPH_ACTION, "[ARCANE]") end },
    { name = "FrostNova",
      matches = frost_nova_matches,
      execute = function(context) return NS.action_execute(context, FROST_NOVA_ACTION, "[ARCANE]") end },
    { name = "Slow",
      matches = slow_matches,
      execute = function(context) return NS.action_execute(context, SLOW_ACTION, "[ARCANE]") end },

    -- Burst cooldowns (synced with burn phase)
    { name = "PresenceOfMind",
      matches = pom_matches,
      execute = function(context) return NS.action_execute(context, POM_ACTION, "[ARCANE]") end },
    { name = "ArcanePower",
      matches = arcane_power_matches,
      execute = function(context) return NS.action_execute(context, AP_ACTION, "[ARCANE]") end },

    -- Mana management
    { name = "Evocation",
      matches = evocation_matches,
      execute = function(context) return NS.action_execute(context, EVOCATION_ACTION, "[ARCANE]") end },
    { name = "ManaGem",
      matches = mana_gem_matches,
      execute = function(context) return NS.action_execute(context, MANA_GEM_ACTION, "[ARCANE]") end },

    -- Primary nuke: Arcane Blast (stack management)
    { name = "ArcaneBlast",
      matches = arcane_blast_matches,
      execute = function(context) return NS.action_execute(context, ARCANE_BLAST_ACTION, "[ARCANE]") end },

    -- Instant filler
    { name = "FireBlast",
      matches = fire_blast_matches,
      execute = function(context) return NS.action_execute(context, FIRE_BLAST_ACTION, "[ARCANE]") end },

    -- Filler (non-stacking)
    { name = "ArcaneMissiles",
      matches = arcane_missiles_matches,
      execute = function(context) return NS.action_execute(context, ARCANE_MISSILES_ACTION, "[ARCANE]") end },

    -- Leveling fillers (pre-AB)
    { name = "FireballLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.action_execute(context, { name = "Fireball", spell = SPELLS.Fireball, not_moving = true, max_level = 63 }, "[ARCANE]") end },
    { name = "FrostboltLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.action_execute(context, { name = "Frostbolt", spell = SPELLS.Frostbolt, not_moving = true, max_level = 63 }, "[ARCANE]") end },
}

NS.rotation_registry:register("arcane", strategies, { get_state = build_state })
NS.log("Mage arcane rotation registered (burn/conserve phase state machine + configurable AB stack limits)")
return strategies
