-- leveling_sylvanas -- hunter leveling_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for leveling_sylvanas gameplay.
-- WHEN:  combat with valid enemy target.
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: Pattern 14 eliminated via spec_kit.safe_state(); no manual nil-guards; no on_update() allocs.

-- Hunter leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.
-- Includes Aimed Shot (lvl 20+), Concussive Shot (lvl 8+), Wing Clip (lvl 12+),
-- Rapid Fire (lvl 26+), and Scare Beast (lvl 14+) for safe leveling per TBC guides.


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}
local spec_kit = require("shared/spec_kit_sylvanas")
local define = spec_kit.define_action_for_class(SPELLS)
local leveling_helpers = require("shared/leveling_helpers_sylvanas")

local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================

local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local SERPENT_STING_IDS = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_IDS = { 14325, 14324, 14323, 1130 }

local context_allowed = leveling.create_context_guard()
local leveling_state = {}
local _last_aspect_hawk_cast = 0  -- Throttle: prevent thrashing (WoW API buff detection delay)

-- Safe wrappers for API resilience (pcall protection for tests)
local function safe_buff_up(unit, ids)
    if not unit or not NS.buff_up then return false end
    local ok, result = pcall(NS.buff_up, unit, ids)
    return ok and result or false
end

local function safe_spell_ready(spell, target, opts)
    if not NS.spell_ready then return false end
    local ok, result = pcall(NS.spell_ready, spell, target, opts)
    return ok and result or false
end

local function safe_debuff_remains(unit, ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, result = pcall(NS.debuff_remains, unit, ids)
    if ok and type(result) == "number" then return result end
    return 0
end

local function try_cast(spell_action, target, label, opts)
    if not NS.try_cast then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label, opts)
    return ok and result == true
end

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    leveling.build_common_state(context, leveling_state)

    -- Buffs
    leveling_state.has_aspect_hawk = safe_buff_up(context.me, ASPECT_HAWK_BUFF)

    -- Settings
    leveling_state.serpent_sting_use = spec_kit.setting_bool(context, "leveling_serpent_sting_use", true)
    leveling_state.hunters_mark_use = spec_kit.setting_bool(context, "leveling_hunters_mark_use", true)
    leveling_state.hunter_auto_aspect = spec_kit.setting_bool(context, "hunter_auto_aspect", true)

    -- Spell readiness
    leveling_state.serpent_sting_ready = safe_spell_ready(SPELLS.SerpentSting, context.target)
    leveling_state.hunters_mark_ready = safe_spell_ready(SPELLS.HuntersMark, context.target)
    leveling_state.arcane_shot_ready = safe_spell_ready(SPELLS.ArcaneShot, context.target)
    leveling_state.steady_shot_ready = safe_spell_ready(SPELLS.SteadyShot, context.target)
    leveling_state.multi_shot_ready = safe_spell_ready(SPELLS.MultiShot, context.target)
    leveling_state.aimed_shot_ready = safe_spell_ready(SPELLS.AimedShot, context.target, { expected_cooldown = 6 })
    leveling_state.mend_pet_ready = safe_spell_ready(SPELLS.MendPet, nil, { skip_range = true })
    leveling_state.call_pet_ready = safe_spell_ready(SPELLS.CallPet, nil, { skip_range = true })
    leveling_state.aspect_hawk_ready = safe_spell_ready(SPELLS.AspectOfTheHawk, nil, { skip_range = true })
    leveling_state.concussive_shot_ready = safe_spell_ready(SPELLS.ConcussiveShot, context.target)
    leveling_state.wing_clip_ready = safe_spell_ready(SPELLS.WingClip, context.target)
    leveling_state.rapid_fire_ready = safe_spell_ready(SPELLS.RapidFire, nil, { skip_range = true })
    leveling_state.scare_beast_ready = safe_spell_ready(SPELLS.ScareBeast, context.target)
    leveling_state.freezing_trap_ready = safe_spell_ready(SPELLS.FreezingTrap, context.me, { skip_range = true, expected_cooldown = 30 })
    leveling_state.feign_death_ready = safe_spell_ready(SPELLS.FeignDeath, nil, { skip_range = true })
    leveling_state.raptor_strike_ready = safe_spell_ready(SPELLS.RaptorStrike, context.target)
    leveling_state.in_melee = context.in_melee_range == true

    -- Pet HP
    if context.pet then
        local ok, pet_hp = pcall(function() return context.pet:get_health_percentage() end)
        leveling_state.pet_hp = ok and pet_hp or 100
    else
        leveling_state.pet_hp = 100
    end

    -- Low mana gate: conserve mana below wand threshold for emergency spells.
    -- Death zone fix: at low levels (1-20), hunters have a very limited mana pool.
    local level = leveling_helpers.level_from_context(context, 0)
    if level <= 0 then
        level = 1
        if context.me and context.me.get_level then
            local ok, lvl = pcall(context.me.get_level, context.me)
            if ok and type(lvl) == "number" and lvl > 0 then level = lvl end
        end
    end
    leveling_state.level = level
    local base_threshold = level <= 20 and 15 or (leveling_state.wand_threshold or 30)
    leveling_state.low_mana = (leveling_state.mana_pct or 100) < base_threshold

    return spec_kit.safe_state(leveling_state)
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function aspect_hawk_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.hunter_auto_aspect then return false end
    if state.in_combat then return false end
    if state.has_aspect_hawk then return false end
    if not state.aspect_hawk_ready then return false end
    -- Throttle: WoW API buff detection can lag 1-2 frames; prevent thrashing
    if NS.time_now ~= nil and (NS.time_now() - _last_aspect_hawk_cast) < 3 then return false end
    return true
end

local function hunters_mark_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.hunters_mark_use then return false end
    if state.in_combat then return false end
    -- Don't reapply if already marked
    local remains = safe_debuff_remains(state.target, HUNTERS_MARK_IDS)
    if remains > 30 then return false end
    return state.hunters_mark_ready
end

local function call_pet_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if context.pet then return false end
    return state.call_pet_ready
end

local function mend_pet_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not context.pet then return false end
    if (state.pet_hp or 100) > 60 then return false end
    if state.low_mana then return false end  -- Preserve mana for emergency
    return state.mend_pet_ready
end

local function concussive_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    if (state.enemies or 0) < 2 and (state.hp or 100) > 40 then return false end  -- Only when threatened
    return state.concussive_shot_ready
end

local function wing_clip_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    if not state.in_melee then return false end  -- Melee range only
    if (state.hp or 100) > 50 then return false end  -- Only when threatened
    return state.wing_clip_ready
end

local function scare_beast_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end  -- Only when overwhelmed
    return state.scare_beast_ready
end

local function freezing_trap_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    return state.freezing_trap_ready
end

local function rapid_fire_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    return state.rapid_fire_ready
end

local function aimed_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if state.low_mana then return false end  -- Preserve mana
    if state.is_moving then return false end
    if not state.aimed_shot_ready then return false end
    return true
end

local function serpent_sting_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.serpent_sting_use then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    local remains = safe_debuff_remains(state.target, SERPENT_STING_IDS)
    if remains >= 4 then return false end
    return state.serpent_sting_ready
end

local function arcane_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    return state.arcane_shot_ready
end

local function multi_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    if (state.enemies or 0) < 2 then return false end
    return state.multi_shot_ready
end

local function steady_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    if state.is_moving then return false end
    return state.steady_shot_ready
end

local function feign_death_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 30 then return false end
    return state.feign_death_ready  -- Emergency: no mana gate
end

local function raptor_strike_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.low_mana then return false end  -- Preserve mana
    if not state.in_melee then return false end
    return state.raptor_strike_ready
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    -- OOC prep
    { name = "AspectHawk",
      matches = aspect_hawk_matches,
      execute = function()
          local result = try_cast(SPELLS.AspectOfTheHawk, NS.PLAYER_UNIT, "[LEVELING] Aspect of the Hawk")
          if result and NS.time_now then _last_aspect_hawk_cast = NS.time_now() end
          return result
      end },

    { name = "CallPet",
      matches = call_pet_matches,
      execute = function() return try_cast(SPELLS.CallPet, NS.PLAYER_UNIT, "[LEVELING] Call Pet") end },

    { name = "HuntersMark",
      matches = hunters_mark_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.HuntersMark, context.target, "[LEVELING] Hunter's Mark")
      end },

    -- DPS cooldown
    { name = "RapidFire",
      matches = rapid_fire_matches,
      execute = function() return try_cast(SPELLS.RapidFire, NS.PLAYER_UNIT, "[LEVELING] Rapid Fire") end },

    -- Damage opener
    { name = "AimedShot",
      matches = aimed_shot_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.AimedShot, context.target, "[LEVELING] Aimed Shot")
      end },

    -- Pet sustain
    { name = "MendPet",
      matches = mend_pet_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.MendPet, context.pet, "[LEVELING] Mend Pet")
      end },

    -- Survival / CC
    { name = "ConcussiveShot",
      matches = concussive_shot_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.ConcussiveShot, context.target, "[LEVELING] Concussive Shot")
      end },

    { name = "WingClip",
      matches = wing_clip_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.WingClip, context.target, "[LEVELING] Wing Clip")
      end },

    { name = "ScareBeast",
      matches = scare_beast_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.ScareBeast, context.target, "[LEVELING] Scare Beast")
      end },

    { name = "FreezingTrap",
      matches = freezing_trap_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.FreezingTrap, context and context.me or NS.PLAYER_UNIT, "[LEVELING] Freezing Trap", { skip_range = true, expected_cooldown = 30 })
      end },

    { name = "FeignDeath",
      matches = feign_death_matches,
      execute = function() return try_cast(SPELLS.FeignDeath, NS.PLAYER_UNIT, "[LEVELING] Feign Death") end },

    -- Damage
    { name = "SerpentSting",
      matches = serpent_sting_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.SerpentSting, context.target, "[LEVELING] Serpent Sting")
      end },

    { name = "ArcaneShot",
      matches = arcane_shot_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.ArcaneShot, context.target, "[LEVELING] Arcane Shot")
      end },

    { name = "MultiShot",
      matches = multi_shot_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.MultiShot, context.target, "[LEVELING] Multi-Shot")
      end },

    -- Melee weave: Raptor Strike when mob is in melee range
    { name = "RaptorStrike",
      matches = raptor_strike_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.RaptorStrike, context.target, "[LEVELING] Raptor Strike")
      end },

    { name = "SteadyShot",
      matches = steady_shot_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.SteadyShot, context.target, "[LEVELING] Steady Shot")
      end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
end
-- Hunter leveling rotation registered
return { strategies = strategies, build_state = build_state }