-- Hunter leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.

-- ============================================================================
-- What: Hunter leveling priority list for solo questing and pet-supported play
-- When: Evaluated by the leveling dispatcher in solo or leveling context
-- Why: Centralizes low-level shot, pet, and aspect decisions for predictable leveling
-- Safety: Context guard and spell checks are nil-safe; conservative fallback behavior
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.HunterSpells or {}
local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================

local ASPECT_HAWK_BUFF = { 27044, 25296, 14322, 14321, 14320, 14319, 14318, 13165 }
local SERPENT_STING_IDS = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 }
local HUNTERS_MARK_IDS = { 14325, 14324, 14323, 14322, 1130 }

local context_allowed = leveling.create_context_guard()
local leveling_state = {}

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

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or {}
    leveling.build_common_state(context, leveling_state)

    -- Buffs
    leveling_state.has_aspect_hawk = safe_buff_up(context.me, ASPECT_HAWK_BUFF)

    -- Settings
    leveling_state.serpent_sting_use = settings.leveling_serpent_sting_use ~= false
    leveling_state.hunters_mark_use = settings.leveling_hunters_mark_use ~= false

    -- Spell readiness
    leveling_state.serpent_sting_ready = safe_spell_ready(SPELLS.SerpentSting, context.target)
    leveling_state.hunters_mark_ready = safe_spell_ready(SPELLS.HuntersMark, context.target)
    leveling_state.arcane_shot_ready = safe_spell_ready(SPELLS.ArcaneShot, context.target)
    leveling_state.steady_shot_ready = safe_spell_ready(SPELLS.SteadyShot, context.target)
    leveling_state.multi_shot_ready = safe_spell_ready(SPELLS.MultiShot, context.target)
    leveling_state.mend_pet_ready = safe_spell_ready(SPELLS.MendPet, nil, { skip_range = true })
    leveling_state.call_pet_ready = safe_spell_ready(SPELLS.CallPet, nil, { skip_range = true })
    leveling_state.aspect_hawk_ready = safe_spell_ready(SPELLS.AspectOfTheHawk, nil, { skip_range = true })
    leveling_state.feign_death_ready = safe_spell_ready(SPELLS.FeignDeath, nil, { skip_range = true })
    leveling_state.freezing_trap_ready = safe_spell_ready(SPELLS.FreezingTrap, context.target)

    -- Pet HP
    if context.pet then
        local ok, pet_hp = pcall(function() return context.pet:get_health_percentage() end)
        leveling_state.pet_hp = ok and pet_hp or 100
    else
        leveling_state.pet_hp = 100
    end

    return leveling_state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function aspect_hawk_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_aspect_hawk then return false end
    return state.aspect_hawk_ready
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
    if state.pet_hp > 60 then return false end
    return state.mend_pet_ready
end

local function freezing_trap_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.enemies < 2 then return false end
    return state.freezing_trap_ready
end

local function serpent_sting_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.serpent_sting_use then return false end
    if not state.in_combat then return false end
    local remains = safe_debuff_remains(state.target, SERPENT_STING_IDS)
    if remains >= 4 then return false end
    return state.serpent_sting_ready
end

local function arcane_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    return state.arcane_shot_ready
end

local function multi_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.enemies < 2 then return false end
    return state.multi_shot_ready
end

local function steady_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    return state.steady_shot_ready
end

local function feign_death_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if state.hp > 30 then return false end
    return state.feign_death_ready
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    -- OOC prep
    { name = "AspectHawk",
      matches = aspect_hawk_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.AspectOfTheHawk, NS.PLAYER_UNIT, "[LEVELING] Aspect of the Hawk") or false end },

    { name = "CallPet",
      matches = call_pet_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.CallPet, NS.PLAYER_UNIT, "[LEVELING] Call Pet") or false end },

    { name = "HuntersMark",
      matches = hunters_mark_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.HuntersMark, context.target, "[LEVELING] Hunter's Mark") or false
      end },

    -- Pet sustain
    { name = "MendPet",
      matches = mend_pet_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.MendPet, context.pet, "[LEVELING] Mend Pet") or false
      end },

    -- Survival
    { name = "FreezingTrap",
      matches = freezing_trap_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.FreezingTrap, context.target, "[LEVELING] Freezing Trap") or false
      end },

    { name = "FeignDeath",
      matches = feign_death_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.FeignDeath, NS.PLAYER_UNIT, "[LEVELING] Feign Death") or false end },

    -- Damage
    { name = "SerpentSting",
      matches = serpent_sting_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.SerpentSting, context.target, "[LEVELING] Serpent Sting") or false
      end },

    { name = "ArcaneShot",
      matches = arcane_shot_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.ArcaneShot, context.target, "[LEVELING] Arcane Shot") or false
      end },

    { name = "MultiShot",
      matches = multi_shot_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.MultiShot, context.target, "[LEVELING] Multi-Shot") or false
      end },

    { name = "SteadyShot",
      matches = steady_shot_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.SteadyShot, context.target, "[LEVELING] Steady Shot") or false
      end },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("Hunter leveling rotation registered")
return strategies
