-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/paladin/leveling_sylvanas.lua"
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
-- Paladin leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.
-- Spells: Holy Shield (lvl 40+), Consecration (lvl 20+), Holy Light (lvl 1+), Cleanse (lvl 42+), Blessing of Wisdom (lvl 4+).

-- ============================================================================
-- What: Paladin leveling priority with seal, aura, and solo fallback logic.
-- When: Evaluated every tick.
-- Why: Fast priority path keeps leveling behavior simple and reliable.
-- Safety: Unlearned spells are guarded; settings and helpers use conservative defaults.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================

local SEAL_WISDOM_BUFF = { 27166, 20357, 20356, 20166 }
local BLESSING_MIGHT_BUFF = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local BLESSING_WISDOM_BUFF = { 27142, 25290, 19854, 19853, 19852, 19850 }
local DEVOTION_AURA_BUFF = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }
local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }
local SEAL_OF_WISDOM = 20170
local SEAL_OF_RIGHTEOUSNESS = 20154
local SEAL_OF_COMMAND = 20375

local context_allowed = leveling.create_context_guard()
local leveling_state = {}

-- ============================================================================
-- Safe API wrappers
-- ============================================================================

local function spell_is_ready(action, target, opts)
    if not NS.spell_ready then return false end
    local ok, ready = pcall(NS.spell_ready, action, target, opts)
    return ok and ready
end

local function safe_buff_up(unit, buff_ids)
    if not unit or not NS.buff_up then return false end
    local ok, result = pcall(NS.buff_up, unit, buff_ids)
    return ok and result
end

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or {}
    leveling.build_common_state(context, leveling_state)

    -- Buffs
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(25780, 3.0) or false
    if not skip_aura then
        leveling_state.has_blessing_might = safe_buff_up(context.me, BLESSING_MIGHT_BUFF)
        leveling_state.has_blessing_wisdom = safe_buff_up(context.me, BLESSING_WISDOM_BUFF)
        leveling_state.has_devotion_aura = safe_buff_up(context.me, DEVOTION_AURA_BUFF)
        leveling_state.has_holy_shield = safe_buff_up(context.me, HOLY_SHIELD_BUFF)
    end

    -- Spell readiness
    leveling_state.blessing_might_ready = spell_is_ready(SPELLS.BlessingOfMight, nil, { skip_range = true })
    leveling_state.blessing_wisdom_ready = spell_is_ready(SPELLS.BlessingOfWisdom, nil, { skip_range = true })
    leveling_state.devotion_aura_ready = spell_is_ready(SPELLS.DevotionAura, nil, { skip_range = true })
    leveling_state.seal_righteousness_ready = spell_is_ready(SPELLS.SealRighteousness, nil, { skip_range = true })
    leveling_state.seal_command_ready = spell_is_ready(SPELLS.SealCommand, nil, { skip_range = true })
    leveling_state.seal_blood_ready = spell_is_ready(SPELLS.SealBlood, nil, { skip_range = true })
    leveling_state.judgement_ready = spell_is_ready(SPELLS.Judgement, context.target)
    leveling_state.consecration_ready = spell_is_ready(SPELLS.Consecration, context.target)
    leveling_state.holy_shield_ready = spell_is_ready(SPELLS.HolyShield, nil, { skip_range = true })
    leveling_state.hammer_wrath_ready = spell_is_ready(SPELLS.HammerOfWrath, context.target)
    leveling_state.crusader_strike_ready = spell_is_ready(SPELLS.CrusaderStrike, context.target)
    leveling_state.hammer_justice_ready = spell_is_ready(SPELLS.HammerOfJustice, context.target)
    leveling_state.exorcism_ready = spell_is_ready(SPELLS.Exorcism, context.target)
    leveling_state.divine_shield_ready = spell_is_ready(SPELLS.DivineShield, nil, { skip_range = true })
    leveling_state.lay_on_hands_ready = spell_is_ready(SPELLS.LayOnHands, nil, { skip_range = true })
    leveling_state.flash_light_ready = spell_is_ready(SPELLS.FlashOfLight, context.me)
    leveling_state.holy_light_ready = spell_is_ready(SPELLS.HolyLight, context.me)
    leveling_state.cleanse_ready = spell_is_ready(SPELLS.Cleanse, nil, { skip_range = true })

    return leveling_state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function holy_shield_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if state.has_holy_shield then return false end
    return state.holy_shield_ready
end

local function blessing_wisdom_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_blessing_wisdom then return false end
    if state.has_blessing_might then return false end
    return state.blessing_wisdom_ready
end

local function holy_light_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 35 then return false end
    return state.holy_light_ready
end

local function cleanse_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    -- OOC debuff cleanup between pulls
    if state.in_combat then return false end
    return state.cleanse_ready
end

-- ============================================================================

local function blessing_might_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_blessing_might then return false end
    return state.blessing_might_ready
end

local function devotion_aura_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_devotion_aura then return false end
    return state.devotion_aura_ready
end

local function seal_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    -- Prefer Seal of Command (or Blood) when available, fall back to Righteousness
    return state.seal_command_ready or state.seal_blood_ready or state.seal_righteousness_ready
end

local function judgement_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    return state.judgement_ready
end

local function hammer_wrath_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local target_hp = 100
    if state.target then
        local ok, hp = pcall(function() return state.target:get_health_percentage() end)
        if ok and hp then target_hp = hp end
    end
    if target_hp > 20 then return false end
    return state.hammer_wrath_ready
end

local function crusader_strike_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    return state.crusader_strike_ready
end

local function exorcism_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    return state.exorcism_ready
end

local function consecration_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    if state.is_moving then return false end
    return state.consecration_ready
end

local function hammer_justice_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    return state.hammer_justice_ready
end

local function divine_shield_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 20 then return false end
    return state.divine_shield_ready
end

local function lay_on_hands_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 15 then return false end
    return state.lay_on_hands_ready
end

local function flash_light_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 60 then return false end
    return state.flash_light_ready
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    -- OOC prep
    { name = "BlessingMight",
      matches = blessing_might_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.BlessingOfMight, NS.PLAYER_UNIT, "[LEVELING] Blessing of Might") or false end },

    -- OOC: Blessing of Wisdom for mana sustain (prefer Might when it's up, fallback to Wisdom)
    { name = "BlessingWisdom",
      matches = blessing_wisdom_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.BlessingOfWisdom, NS.PLAYER_UNIT, "[LEVELING] Blessing of Wisdom") or false end },

    { name = "DevotionAura",
      matches = devotion_aura_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.DevotionAura, NS.PLAYER_UNIT, "[LEVELING] Devotion Aura") or false end },

    -- Self-buffs / defensives
    { name = "HolyShield",
      matches = holy_shield_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.HolyShield, context.me, "[LEVELING] Holy Shield") or false
      end },

    -- OOC: Cleanse debuffs between pulls
    { name = "Cleanse",
      matches = cleanse_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.Cleanse, NS.PLAYER_UNIT, "[LEVELING] Cleanse") or false end },

    -- Survival
    { name = "FlashOfLight",
      matches = flash_light_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.FlashOfLight, context.me, "[LEVELING] Flash of Light") or false
      end },

    -- Big heal when critically low
    { name = "HolyLight",
      matches = holy_light_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.HolyLight, context.me, "[LEVELING] Holy Light") or false
      end },

    { name = "DivineShield",
      matches = divine_shield_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.DivineShield, NS.PLAYER_UNIT, "[LEVELING] Divine Shield") or false end },

    { name = "LayOnHands",
      matches = lay_on_hands_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.LayOnHands, context.me, "[LEVELING] Lay on Hands") or false
      end },

    -- CC
    { name = "HammerOfJustice",
      matches = hammer_justice_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.HammerOfJustice, context.target, "[LEVELING] Hammer of Justice") or false
      end },

    -- Damage
    { name = "Judgement",
      matches = judgement_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.Judgement, context.target, "[LEVELING] Judgement") or false
      end },

    { name = "HammerOfWrath",
      matches = hammer_wrath_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.HammerOfWrath, context.target, "[LEVELING] Hammer of Wrath") or false
      end },

    { name = "CrusaderStrike",
      matches = crusader_strike_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.CrusaderStrike, context.target, "[LEVELING] Crusader Strike") or false
      end },

    { name = "Exorcism",
      matches = exorcism_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.Exorcism, context.target, "[LEVELING] Exorcism") or false
      end },

    { name = "Consecration",
      matches = consecration_matches,
      execute = function(context)
        if not context then return false end
        return NS.try_cast and NS.try_cast(SPELLS.Consecration, context.target, "[LEVELING] Consecration") or false
      end },

    -- Seal (lowest priority - always keep up)
    { name = "Seal",
      matches = seal_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.SealRighteousness, NS.PLAYER_UNIT, "[LEVELING] Seal") or false end },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("Paladin leveling rotation registered")
return strategies
