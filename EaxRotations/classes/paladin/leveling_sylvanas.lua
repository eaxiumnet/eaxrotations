-- leveling_sylvanas -- paladin leveling_sylvanas rotation for TBC Anniversary (2.5.5).
-- WHAT:  priority-list strategies for leveling_sylvanas gameplay.
-- WHEN:  combat with valid enemy target (or healing context for healers).
-- WHY:   mirrors SimulationCraft / wowsims APL with TBC-era mechanics.
-- SAFETY: every state field read is nil-guarded via build_state() defaults; no on_update() allocs.

-- Paladin leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.
-- Spells: Holy Shield (lvl 40+), Consecration (lvl 20+), Holy Light (lvl 1+), Cleanse (lvl 42+), Blessing of Wisdom (lvl 4+).


local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local leveling = require("shared/leveling_sylvanas")

-- ============================================================================
-- Constants
-- ============================================================================

local SEAL_WISDOM_BUFF = { 27166, 20357, 20356, 20166 }
local SEAL_RIGHTEOUSNESS_BUFF = { 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154 }
local SEAL_COMMAND_BUFF = { 27170, 20920, 20919, 20918, 20915, 20375 }
local SEAL_BLOOD_BUFF = { 31892 }
local SEAL_MARTYR_BUFF = { 348700 }
local ANY_SEAL_BUFF = { 27166, 20357, 20356, 20166, 27155, 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154, 27170, 20920, 20919, 20918, 20915, 20375, 31892, 348700 }
local BLESSING_MIGHT_BUFF = { 27140, 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local BLESSING_WISDOM_BUFF = { 27142, 25290, 19854, 19853, 19852, 19850 }
local DEVOTION_AURA_BUFF = { 27149, 10293, 10292, 1032, 643, 10291, 10290, 465 }
local RETRIBUTION_AURA_BUFF = { 27150, 10299, 10298, 7294, 10301, 10300, 466 }
local HOLY_SHIELD_BUFF = { 27179, 20928, 20927, 20925 }
local SEAL_OF_WISDOM = 20170
local SEAL_OF_RIGHTEOUSNESS = 20154
local SEAL_OF_COMMAND = 20375
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

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

local function needs_cleanse(unit)
    if not unit or type(NS.has_dispel_type_debuff) ~= "function" then return false end
    return NS.has_dispel_type_debuff(unit, "Poison")
        or NS.has_dispel_type_debuff(unit, "Disease")
        or NS.has_dispel_type_debuff(unit, "Magic")
end

local function creature_type(unit)
    if not unit or not unit.get_creature_type then return nil end
    local ok, value = pcall(unit.get_creature_type, unit)
    return ok and value or nil
end

local function try_cast(spell_action, target, label, opts)
    if not spell_action then return false end
    if not NS.try_cast then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "", opts)
    return ok and result == true
end

local function choose_seal_action(state)
    if state.seal_command_ready then return SPELLS.SealCommand end
    if state.seal_blood_ready then return SPELLS.SealBlood end
    if state.seal_martyr_ready then return SPELLS.SealOfTheMartyr end
    if state.seal_righteousness_ready then return SPELLS.SealRighteousness end
    return nil
end

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or {}
    leveling.build_common_state(context, leveling_state)
    leveling_state.has_any_seal = false
    leveling_state.needs_cleanse = needs_cleanse(context.me)

    -- Buffs
    -- Broken-API guard: skip aura checks if API is unhealthy (prevents crash loops on private servers)
    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(25780, 3.0) or false
    if not skip_aura then
        leveling_state.has_blessing_might = safe_buff_up(context.me, BLESSING_MIGHT_BUFF)
        leveling_state.has_blessing_wisdom = safe_buff_up(context.me, BLESSING_WISDOM_BUFF)
        leveling_state.has_devotion_aura = safe_buff_up(context.me, DEVOTION_AURA_BUFF)
        leveling_state.has_retribution_aura = safe_buff_up(context.me, RETRIBUTION_AURA_BUFF)
        leveling_state.has_holy_shield = safe_buff_up(context.me, HOLY_SHIELD_BUFF)
        leveling_state.has_any_seal = safe_buff_up(context.me, ANY_SEAL_BUFF)
    end

    -- Player level for death-zone-aware thresholds
    local me = context.me
    if me and me.get_level then
        local ok, lvl = pcall(me.get_level, me)
        if ok then leveling_state.level = lvl end
    end

    -- Spell readiness
    leveling_state.blessing_might_ready = spell_is_ready(SPELLS.BlessingOfMight, nil, { skip_range = true })
    leveling_state.blessing_wisdom_ready = spell_is_ready(SPELLS.BlessingOfWisdom, nil, { skip_range = true })
    leveling_state.devotion_aura_ready = spell_is_ready(SPELLS.DevotionAura, nil, { skip_range = true })
    leveling_state.retribution_aura_ready = SPELLS.RetributionAura and spell_is_ready(SPELLS.RetributionAura, nil, { skip_range = true }) or false
    leveling_state.seal_righteousness_ready = spell_is_ready(SPELLS.SealRighteousness, nil, { skip_range = true })
    leveling_state.seal_command_ready = spell_is_ready(SPELLS.SealCommand, nil, { skip_range = true })
    leveling_state.seal_blood_ready = spell_is_ready(SPELLS.SealBlood, nil, { skip_range = true })
    leveling_state.seal_martyr_ready = spell_is_ready(SPELLS.SealOfTheMartyr, nil, { skip_range = true })
    leveling_state.judgement_ready = spell_is_ready(SPELLS.Judgement, context.target)
    leveling_state.consecration_ready = spell_is_ready(SPELLS.Consecration, context.me, { skip_range = true, expected_cooldown = 8 })
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
    leveling_state.selected_seal = choose_seal_action(leveling_state)

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
    -- Death zone fix: more aggressive healing at low levels (level 1-20: threshold 50, 21+: 35)
    local level = state.level or 1
    local threshold = level <= 20 and 50 or 35
    if (state.hp or 100) > threshold then return false end
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
    if state.has_retribution_aura then return false end  -- Prefer Retribution Aura for leveling DPS
    return state.devotion_aura_ready
end

--- Retribution Aura - DPS aura for leveling (reflects melee damage)
local function retribution_aura_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_retribution_aura then return false end
    return state.retribution_aura_ready
end

local function seal_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if state.has_any_seal then return false end
    -- Prefer Seal of Command (or Blood) when available, fall back to Righteousness
    return state.seal_command_ready or state.seal_blood_ready or state.seal_martyr_ready or state.seal_righteousness_ready
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
    local type = creature_type(state.target)
    if not DEMON_OR_UNDEAD[type] then return false end
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
    -- Death zone fix: more aggressive healing at low levels (level 1-20: threshold 75, 21+: 60)
    local level = state.level or 1
    local threshold = level <= 20 and 75 or 60
    if (state.hp or 100) > threshold then return false end
    return state.flash_light_ready
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    -- OOC prep
    { name = "BlessingMight",
      matches = blessing_might_matches,
      execute = function() return try_cast(SPELLS.BlessingOfMight, NS.PLAYER_UNIT, "[LEVELING] Blessing of Might") end },

    -- OOC: Blessing of Wisdom for mana sustain (prefer Might when it's up, fallback to Wisdom)
    { name = "BlessingWisdom",
      matches = blessing_wisdom_matches,
      execute = function() return try_cast(SPELLS.BlessingOfWisdom, NS.PLAYER_UNIT, "[LEVELING] Blessing of Wisdom") end },

    -- DPS aura for leveling (reflects melee damage from mobs)
    { name = "RetributionAura",
      matches = retribution_aura_matches,
      execute = function() return try_cast(SPELLS.RetributionAura, NS.PLAYER_UNIT, "[LEVELING] Retribution Aura") end },

    { name = "DevotionAura",
      matches = devotion_aura_matches,
      execute = function() return try_cast(SPELLS.DevotionAura, NS.PLAYER_UNIT, "[LEVELING] Devotion Aura") end },

    -- Self-buffs / defensives
    { name = "HolyShield",
      matches = holy_shield_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.HolyShield, context.me, "[LEVELING] Holy Shield")
      end },

    -- OOC: Cleanse debuffs between pulls
    { name = "Cleanse",
      matches = cleanse_matches,
      execute = function() return try_cast(SPELLS.Cleanse, NS.PLAYER_UNIT, "[LEVELING] Cleanse") end },

    -- Survival
    { name = "FlashOfLight",
      matches = flash_light_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.FlashOfLight, context.me, "[LEVELING] Flash of Light")
      end },

    -- Big heal when critically low
    { name = "HolyLight",
      matches = holy_light_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.HolyLight, context.me, "[LEVELING] Holy Light")
      end },

    { name = "DivineShield",
      matches = divine_shield_matches,
      execute = function() return try_cast(SPELLS.DivineShield, NS.PLAYER_UNIT, "[LEVELING] Divine Shield") end },

    { name = "LayOnHands",
      matches = lay_on_hands_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.LayOnHands, context.me, "[LEVELING] Lay on Hands")
      end },

    -- CC
    { name = "HammerOfJustice",
      matches = hammer_justice_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.HammerOfJustice, context.target, "[LEVELING] Hammer of Justice")
      end },

    -- Seal (apply BEFORE Judgement — Seal needs to be active for Judgement to consume it)
    { name = "Seal",
       matches = seal_matches,
      execute = function(_, state) return try_cast(state and state.selected_seal or SPELLS.SealRighteousness, NS.PLAYER_UNIT, "[LEVELING] Seal") end },

    -- Damage
    { name = "Judgement",
      matches = judgement_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.Judgement, context.target, "[LEVELING] Judgement")
      end },

    { name = "HammerOfWrath",
      matches = hammer_wrath_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.HammerOfWrath, context.target, "[LEVELING] Hammer of Wrath")
      end },

    { name = "CrusaderStrike",
      matches = crusader_strike_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.CrusaderStrike, context.target, "[LEVELING] Crusader Strike")
      end },

    { name = "Exorcism",
      matches = exorcism_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.Exorcism, context.target, "[LEVELING] Exorcism")
      end },

    { name = "Consecration",
      matches = consecration_matches,
      execute = function(context)
        if not context then return false end
        return try_cast(SPELLS.Consecration, context.me, "[LEVELING] Consecration", { skip_range = true, expected_cooldown = 8 })
      end },

}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("Paladin leveling rotation registered")
return strategies
