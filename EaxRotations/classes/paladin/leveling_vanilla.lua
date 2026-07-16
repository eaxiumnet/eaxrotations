-- leveling_vanilla.lua — Paladin Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling rotation (seal, judgement, healing, buffs).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and mana efficiency.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local SPELLS = NS.PaladinSpells or {}
local leveling = require("shared/leveling_sylvanas")

local BLESSING_MIGHT_BUFF = { 25291, 19838, 19837, 19836, 19835, 19834, 19740 }
local BLESSING_WISDOM_BUFF = { 25290, 19854, 19853, 19852, 19850 }
local DEVOTION_AURA_BUFF = { 10293, 10292, 1032, 643, 10291, 10290, 465 }
local ANY_SEAL_BUFF = { 20293, 20292, 20291, 20290, 20289, 20288, 20287, 21084, 20154, 20920, 20919, 20918, 20915, 20375, 20308, 20307, 20306, 20305, 21082, 20162, 20164, 20349, 20348, 20347, 20165, 20357, 20356, 20166 }
local DEMON_OR_UNDEAD = { [3] = true, [6] = true }

local context_allowed = leveling.create_context_guard()
local leveling_state = {}

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

local function choose_seal_action(state)
    if state.seal_command_ready then return SPELLS.SealCommand end
    if state.seal_righteousness_ready then return SPELLS.SealRighteousness end
    return nil
end

local function build_state(context)
    if not context then return nil end
    leveling.build_common_state(context, leveling_state)
    leveling_state.has_any_seal = false
    leveling_state.needs_cleanse = needs_cleanse(context.me)

    local skip_aura = NS.broken_api_throttled and NS.broken_api_throttled(25780, 3.0) or false
    if not skip_aura then
        leveling_state.has_blessing_might = safe_buff_up(context.me, BLESSING_MIGHT_BUFF)
        leveling_state.has_blessing_wisdom = safe_buff_up(context.me, BLESSING_WISDOM_BUFF)
        leveling_state.has_devotion_aura = safe_buff_up(context.me, DEVOTION_AURA_BUFF)
        leveling_state.has_any_seal = safe_buff_up(context.me, ANY_SEAL_BUFF)
    end

    leveling_state.blessing_might_ready = spell_is_ready(SPELLS.BlessingOfMight, nil, { skip_range = true })
    leveling_state.blessing_wisdom_ready = spell_is_ready(SPELLS.BlessingOfWisdom, nil, { skip_range = true })
    leveling_state.devotion_aura_ready = spell_is_ready(SPELLS.DevotionAura, nil, { skip_range = true })
    leveling_state.seal_righteousness_ready = spell_is_ready(SPELLS.SealRighteousness, nil, { skip_range = true })
    leveling_state.seal_command_ready = spell_is_ready(SPELLS.SealCommand, nil, { skip_range = true })
    leveling_state.seal_blood_ready = false
    leveling_state.judgement_ready = spell_is_ready(SPELLS.Judgement, context.target)
    leveling_state.consecration_ready = spell_is_ready(SPELLS.Consecration, context.me, { skip_range = true, expected_cooldown = 8 })
    leveling_state.hammer_wrath_ready = spell_is_ready(SPELLS.HammerOfWrath, context.target)
    leveling_state.crusader_strike_ready = false
    leveling_state.hammer_justice_ready = spell_is_ready(SPELLS.HammerOfJustice, context.target)
    leveling_state.exorcism_ready = spell_is_ready(SPELLS.Exorcism, context.target)
    leveling_state.divine_shield_ready = spell_is_ready(SPELLS.DivineShield, nil, { skip_range = true })
    leveling_state.lay_on_hands_ready = spell_is_ready(SPELLS.LayOnHands, nil, { skip_range = true })
    leveling_state.flash_light_ready = spell_is_ready(SPELLS.FlashOfLight, context.me)
    leveling_state.holy_light_ready = spell_is_ready(SPELLS.HolyLight, context.me)
    leveling_state.cleanse_ready = spell_is_ready(SPELLS.Cleanse, nil, { skip_range = true })
    leveling_state.holy_shield_ready = spell_is_ready(SPELLS.HolyShield, nil, { skip_range = true })
    leveling_state.retribution_aura_ready = spell_is_ready(SPELLS.RetributionAura, nil, { skip_range = true })
    leveling_state.selected_seal = choose_seal_action(leveling_state)
    return leveling_state
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
    if state.in_combat then return false end
    if not state.needs_cleanse then return false end
    return state.cleanse_ready
end

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
    -- Check if seal is already active (refresh when missing)
    if state.has_any_seal then return false end
    return (state.selected_seal ~= nil)
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
    if (state.hp or 100) > 60 then return false end
    return state.flash_light_ready
end

--- Holy Shield — defensive block-chance buff for protection leveling
local function holy_shield_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.holy_shield_ready then return false end
    if (state.hp or 100) > 70 then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Retribution Aura — damage aura for solo/leveling (alternative to Devotion)
local function retribution_aura_matches(context, state)
    if not context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if not state.retribution_aura_ready then return false end
    if state.has_devotion_aura then return false end  -- dont override devotion
    local RETRIBUTION_AURA_BUFF = { 27150, 10301, 10300, 10299, 10298, 7294 }
    if safe_buff_up(context.me, RETRIBUTION_AURA_BUFF) then return false end
    return true
end

local strategies = {
    { name = "BlessingMight", matches = blessing_might_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.BlessingOfMight, NS.PLAYER_UNIT, "[LEVELING] Blessing of Might") or false end },
    { name = "BlessingWisdom", matches = blessing_wisdom_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.BlessingOfWisdom, NS.PLAYER_UNIT, "[LEVELING] Blessing of Wisdom") or false end },
    { name = "DevotionAura", matches = devotion_aura_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.DevotionAura, NS.PLAYER_UNIT, "[LEVELING] Devotion Aura") or false end },
    { name = "RetributionAura", matches = retribution_aura_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.RetributionAura, NS.PLAYER_UNIT, "[LEVELING] Retribution Aura") or false end },
    { name = "HolyShield", matches = holy_shield_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.HolyShield, NS.PLAYER_UNIT, "[LEVELING] Holy Shield") or false end },
    { name = "DivineShield", matches = divine_shield_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.DivineShield, NS.PLAYER_UNIT, "[LEVELING] Divine Shield") or false end },
    { name = "Cleanse", matches = cleanse_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.Cleanse, NS.PLAYER_UNIT, "[LEVELING] Cleanse") or false end },
    { name = "FlashOfLight", matches = flash_light_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.FlashOfLight, context.me, "[LEVELING] Flash of Light") or false end },
    { name = "HolyLight", matches = holy_light_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HolyLight, context.me, "[LEVELING] Holy Light") or false end },
    { name = "LayOnHands", matches = lay_on_hands_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.LayOnHands, context.me, "[LEVELING] Lay on Hands") or false end },
    { name = "HammerOfJustice", matches = hammer_justice_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HammerOfJustice, context.target, "[LEVELING] Hammer of Justice") or false end },
    { name = "Judgement", matches = judgement_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Judgement, context.target, "[LEVELING] Judgement") or false end },
    { name = "HammerOfWrath", matches = hammer_wrath_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HammerOfWrath, context.target, "[LEVELING] Hammer of Wrath") or false end },
    { name = "Exorcism", matches = exorcism_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Exorcism, context.target, "[LEVELING] Exorcism") or false end },
    { name = "Consecration", matches = consecration_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Consecration, context.me, "[LEVELING] Consecration", { skip_range = true, expected_cooldown = 8 }) or false end },
    { name = "Seal", matches = seal_matches,
      execute = function(_, state) return NS.try_cast and NS.try_cast(state and state.selected_seal or SPELLS.SealRighteousness, NS.PLAYER_UNIT, "[LEVELING] Seal") or false end },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
-- [Paladin] Leveling rotation loaded (Classic)
return { strategies = strategies, build_state = build_state }