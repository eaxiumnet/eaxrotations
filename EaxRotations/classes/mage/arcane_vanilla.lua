-- arcane_vanilla.lua — Mage Arcane for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  Arcane Power Frost hybrid (Frostbolt primary, AP/PoM cooldowns).
-- WHEN:  combat, in caster form, when NS.is_vanilla() is true.
-- WHY:   Vanilla has no Arcane Blast; this spec is AP-boosted Frostbolt.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.


--
local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.MageSpells or {}

-- ============================================================================
-- Buff / Debuff IDs
-- ============================================================================
local ARCANE_BLAST_DEBUFF = { }  -- AB debuff: increases mana cost, reduces cast time
local ARCANE_POWER_BUFF = { 12042 }
local PRESENCE_OF_MIND_BUFF = { 12043 }
local ICE_BARRIER_BUFF = { 13032, 13031, 13033 }
local MANA_SHIELD_BUFF = { 10193, 10192, 10191, 8495, 8494, 1463 }
local CLEARCASTING_BUFF = { 12536 }  -- Clearcasting proc from Arcane Concentration talent
-- Slow (31589) is TBC-only; not available in Classic Vanilla
local FROST_NOVA_ROOTS = { 10230, 6131, 865, 122 }

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

local MANA_GEM_CONJURE = { 10054, 10053, 3552, 759 }
local MANA_GEM_ITEM_IDS = { 8008, 8007, 5513, 5514 }

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
    local stacks = NS.debuff_stacks and NS.debuff_stacks(me, ARCANE_BLAST_DEBUFF) or 0
    local remains = NS.debuff_remains and NS.debuff_remains(me, ARCANE_BLAST_DEBUFF) or 0
    return stacks, remains
end

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function use_mana_gem()
    local item_id = first_ready_mana_gem()
    if not item_id or not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used == true
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
local get_setting_num = NS.setting or function(context, key, default)
    local settings = context and context.settings
    if settings and settings[key] ~= nil then return settings[key] end
    if NS.get_setting then return NS.get_setting(key, default) end
    return default
end
local get_setting_bool = get_setting_num

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
    end

    -- Cooldown availability
    s.evocation_available = me and NS.spell_ready and NS.spell_ready(SPELLS.Evocation, me, { skip_range = true }) or false
    s.mana_gem_available = false
    if me then s.mana_gem_available = first_ready_mana_gem() ~= nil end
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
-- Match Functions (receive state from framework via get_state)
-- ============================================================================

--- Ice Barrier: cast when hp is low and barrier isn't up
local function ice_barrier_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.IceBarrier, 3.0) then return false end
    if s.has_ice_barrier then return false end
    if (s.hp_pct or 100) > 60 then return false end
    if not get_setting_bool(context, "use_defensives", true) then return false end
    if not get_setting_bool(context, "use_ice_barrier", true) then return false end
    return true
end

--- Mana Shield: cast when hp is critically low and mana is available
local function mana_shield_matches(context, s)
    if NS.broken_api_throttled and NS.broken_api_throttled(SPELLS.ManaShield, 3.0) then return false end
    if s.has_mana_shield then return false end
    if (s.hp_pct or 100) > 40 then return false end
    if (s.mana_pct or 0) < 30 then return false end
    if not get_setting_bool(context, "use_defensives", true) then return false end
    if not get_setting_bool(context, "use_mana_shield", true) then return false end
    return true
end

--- Counterspell: interrupt casting target
local function counterspell_matches(context, s)
    if not context.target then return false end
    if not s.target_casting then return false end
    if not get_setting_bool(context, "use_interrupt", true) then return false end
    return true
end

--- Polymorph: crowd control in PvP
local function polymorph_matches(context, s)
    if not context.is_pvp then return false end
    if not context.cc_target then return false end
    if context.is_moving then return false end
    return true
end

--- Frost Nova: self-peel when target is in melee range
local function frost_nova_matches(context, s)
    if not (context.is_pvp or context.is_leveling or context.is_solo) then return false end
    if not context.target then return false end
    local me = context.me
    if not me then return false end
    local dist = me.get_distance and me:get_distance(context.target) or 40
    if dist > 10 then return false end
    return true
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
    return true
end

--- Arcane Power: burn cooldown synced with AB stacks and bloodlust
local function arcane_power_matches(context, s)
    if s.has_arcane_power then return false end
    if not s.in_combat then return false end
    if not get_setting_bool(context, "use_cooldowns", true) then return false end
    if not NS.gate_cooldown_boss_only(context) then return false end
    if not get_setting_bool(context, "arcane_use_burn", true) then return false end
    -- Only use AP during burn phase or bloodlust
    if s.phase ~= PHASE_BURN and not s.bloodlust_active then return false end
    -- Require sufficient mana to sustain the full duration
    if (s.mana_pct or 0) < 35 then return false end
    -- Prefer high AB stacks for max value
    if (s.ab_stacks or 0) >= 2 then return true end
    -- Always cast AP during burn if we have the mana
    if s.phase == PHASE_BURN and (s.mana_pct or 0) >= 50 then return true end
    return true
end

--- Evocation: mana recovery during conserve/emergency
local function evocation_matches(context, s)
    if not s.in_combat then return false end
    if not get_setting_bool(context, "use_evocation", true) then return false end
    if not s.evocation_available then return false end
    local evo_mana = get_setting_num(context, "arcane_evocation_mana", 20)
    -- Emergency: very low mana
    if (s.mana_pct or 100) <= evo_mana then
        return true
    end
    -- During conserve phase: evocate if below threshold to enable next burn
    if s.phase == PHASE_CONSERVE and (s.mana_pct or 100) <= 30 then
        return true
    end
    return false
end

--- Mana Gem: use proactively during burn when mana is dropping
local function mana_gem_matches(context, s)
    if not get_setting_bool(context, "use_mana_gem", true) then return false end
    if not s.mana_gem_available then return false end
    local gem_mana = get_setting_num(context, "arcane_mana_gem_mana", 55)
    -- Use during burn when mana drops below threshold
    if s.phase == PHASE_BURN and (s.mana_pct or 100) <= gem_mana then
        return true
    end
    -- Use during conserve to speed up recovery
    if s.phase == PHASE_CONSERVE and (s.mana_pct or 100) <= 35 then
        return true
    end
    return false
end

--- Fire Blast: instant filler, use only while moving in Vanilla
local function fire_blast_matches(context, s)
    if not context.target then return false end
    -- In Vanilla Arcane (AP Frost), Fire Blast is only used while moving
    -- Frostbolt is the primary nuke; never spam Fire Blast as filler
    if s.is_moving then return true end
    return false
end

--- Frostbolt: primary nuke for Vanilla Arcane (AP Frost hybrid)
local function frostbolt_matches(context, s)
    if s.is_moving then return false end
    if not context.target then return false end
    return NS.spell_ready(SPELLS.Frostbolt, context.target)
end

--- Arcane Missiles: filler that doesn't stack AB
local function arcane_missiles_matches(context, s)
    if context.is_channeling then return false end
    if s.is_moving then return false end
    if not context.target then return false end

    -- Clearcasting: always consume free AM casts (per research Angle 5)
    if s.has_clearcasting then return true end

    -- During burn: use AM only when mana is low
    if s.phase == PHASE_BURN then
        if (s.mana_pct or 100) < 20 then
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
    if NS.spell_exists(SPELLS.UnavailableClassicMageArcane) then return false end
    return true
end

-- ============================================================================
-- Strategies (state passed by framework via get_state)
-- ============================================================================
local strategies = {
    -- Defensives (highest priority)
    { name = "IceBarrier",
      matches = ice_barrier_matches,
      execute = function(context) return NS.try_cast(SPELLS.IceBarrier, context.me, "[ARCANE] IceBarrier") end },
    { name = "ManaShield",
      matches = mana_shield_matches,
      execute = function(context) return NS.try_cast(SPELLS.ManaShield, context.me, "[ARCANE] ManaShield") end },

    -- Interrupt
    { name = "Counterspell",
      matches = counterspell_matches,
      execute = function(context) return NS.try_cast(SPELLS.Counterspell, context.target, "[ARCANE] Counterspell") end },

    -- CC / Utility
    { name = "Polymorph",
      matches = polymorph_matches,
      execute = function(context) return NS.try_cast(SPELLS.Polymorph, context.cc_target or context.target, "[ARCANE] Polymorph") end },
    { name = "FrostNova",
      matches = frost_nova_matches,
      execute = function(context) return NS.try_cast(SPELLS.FrostNova, context.target, "[ARCANE] FrostNova") end },
    -- Slow is TBC-only, removed from Vanilla strategy table

    -- Burst cooldowns (synced with burn phase)
    { name = "PresenceOfMind",
      matches = pom_matches,
      execute = function(context) return NS.try_cast(SPELLS.PresenceOfMind, context.me, "[ARCANE] PresenceOfMind") end },
    { name = "ArcanePower",
      matches = arcane_power_matches,
      execute = function(context) return NS.try_cast(SPELLS.ArcanePower, context.me, "[ARCANE] ArcanePower") end },

    -- Mana management
    { name = "Evocation",
      matches = evocation_matches,
      execute = function(context) return NS.try_cast(SPELLS.Evocation, context.me, "[ARCANE] Evocation") end },
    { name = "ManaGem",
      matches = mana_gem_matches,
      execute = function() return use_mana_gem() end },

    -- Instant filler (moving only in Vanilla)
    { name = "FireBlast",
      matches = fire_blast_matches,
      execute = function(context) return NS.try_cast(SPELLS.FireBlast, context.target, "[ARCANE] FireBlast") end },

    -- Primary nuke: Frostbolt (Vanilla Arcane = AP-boosted Frostbolt)
    { name = "Frostbolt",
      matches = frostbolt_matches,
      execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[ARCANE] Frostbolt") end },

    -- Filler (non-stacking)
    { name = "ArcaneMissiles",
      matches = arcane_missiles_matches,
      execute = function(context) return NS.try_cast(SPELLS.ArcaneMissiles, context.target, "[ARCANE] ArcaneMissiles") end },

    -- Leveling fillers (pre-AB)
    { name = "FireballLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.try_cast(SPELLS.Fireball, context.target, "[ARCANE] Fireball") end },
    { name = "FrostboltLeveling",
      matches = function(context, s) return low_level_bolt_matches(context, s) end,
      execute = function(context) return NS.try_cast(SPELLS.Frostbolt, context.target, "[ARCANE] Frostbolt") end },
}

NS.rotation_registry:register("arcane", strategies, { get_state = build_state })
NS.log("Mage arcane rotation registered (burn/conserve phase state machine + configurable AB stack limits)")
return strategies

