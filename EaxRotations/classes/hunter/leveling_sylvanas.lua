-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/hunter/leveling_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- Hunter leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.
-- Includes Aimed Shot (lvl 20+), Concussive Shot (lvl 8+), Wing Clip (lvl 12+),
-- Rapid Fire (lvl 26+), and Scare Beast (lvl 14+) for safe leveling per TBC guides.

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
    leveling_state.aimed_shot_ready = safe_spell_ready(SPELLS.AimedShot, context.target, { expected_cooldown = 6 })
    leveling_state.mend_pet_ready = safe_spell_ready(SPELLS.MendPet, nil, { skip_range = true })
    leveling_state.call_pet_ready = safe_spell_ready(SPELLS.CallPet, nil, { skip_range = true })
    leveling_state.aspect_hawk_ready = safe_spell_ready(SPELLS.AspectOfTheHawk, nil, { skip_range = true })
    leveling_state.concussive_shot_ready = safe_spell_ready(SPELLS.ConcussiveShot, context.target)
    leveling_state.wing_clip_ready = safe_spell_ready(SPELLS.WingClip, context.target)
    leveling_state.rapid_fire_ready = safe_spell_ready(SPELLS.RapidFire, nil, { skip_range = true })
    leveling_state.scare_beast_ready = safe_spell_ready(SPELLS.ScareBeast, context.target)
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

local function concussive_shot_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 and (state.hp or 100) > 40 then return false end  -- Only when threatened
    return state.concussive_shot_ready
end

local function wing_clip_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
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
    if (state.enemies or 0) < 2 then return false end
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
    if (state.hp or 100) > 30 then return false end
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

    -- DPS cooldown
    { name = "RapidFire",
      matches = rapid_fire_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.RapidFire, NS.PLAYER_UNIT, "[LEVELING] Rapid Fire") or false end },

    -- Damage opener
    { name = "AimedShot",
      matches = aimed_shot_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.AimedShot, context.target, "[LEVELING] Aimed Shot") or false
      end },

    -- Pet sustain
    { name = "MendPet",
      matches = mend_pet_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.MendPet, context.pet, "[LEVELING] Mend Pet") or false
      end },

    -- Survival / CC
    { name = "ConcussiveShot",
      matches = concussive_shot_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.ConcussiveShot, context.target, "[LEVELING] Concussive Shot") or false
      end },

    { name = "WingClip",
      matches = wing_clip_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.WingClip, context.target, "[LEVELING] Wing Clip") or false
      end },

    { name = "ScareBeast",
      matches = scare_beast_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.ScareBeast, context.target, "[LEVELING] Scare Beast") or false
      end },

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
