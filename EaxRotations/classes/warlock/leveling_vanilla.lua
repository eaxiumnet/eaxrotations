-- Warlock leveling rotation (Classic/Vanilla 1.12).
-- Stripped of TBC-only abilities: Fel Armor.

local NS = _G.EaxRotations
if not NS then return nil end
local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local SPELLS = NS.WarlockSpells or {}

local DEMON_ARMOR_BUFF = { 11735, 11734, 11733, 1086, 706, 696, 687 }
local DEATH_COIL_IDS = { 17926, 17925, 6789 }
local FEAR_IDS = { 6215, 6213, 5782 }
local CORRUPTION_IDS = { 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_IDS = { 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CURSE_OF_AGONY_IDS = { 11713, 11712, 11711, 6217, 1014, 980 }
local DRAIN_LIFE_IDS = { 11700, 11699, 7651, 709, 699, 689 }

local WAND_SPELL_ID = leveling.WAND_SPELL_ID or 5019
local EMPTY_SETTINGS = {}

local function safe_buff_up(unit, buff_ids)
    if not unit or not NS.buff_up then return false end
    local ok, result = pcall(NS.buff_up, unit, buff_ids)
    return ok and result
end

local function safe_is_spell_ready(spell_ids, target, opts)
    if not NS.spell_ready then return false end
    local ok, ready = pcall(NS.spell_ready, spell_ids, target, opts)
    return ok and ready
end

local function safe_debuff_remains(unit, debuff_ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, remains = pcall(NS.debuff_remains, unit, debuff_ids)
    if not ok or not remains then return 0 end
    return remains
end

local leveling_state = {}

local function leveling_context_allowed(context)
    if not context then return false end
    if context.is_solo == true or context.is_leveling == true then return true end
    local settings = context.settings or EMPTY_SETTINGS
    return settings.playstyle == "leveling" or settings.active_playstyle == "leveling"
end

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or EMPTY_SETTINGS
    local me = context.me
    local pet = context.pet

    leveling_state.in_combat = context.in_combat or false
    leveling_state.mana_pct = context.mana_pct or 100
    leveling_state.hp = context.hp or 100
    leveling_state.enemies = context.enemies_count or 0
    leveling_state.target = context.target
    leveling_state.is_moving = context.is_moving or false
    leveling_state.pet = pet

    leveling_state.use_interrupt = settings.use_interrupt ~= false
    leveling_state.wand_threshold = settings.leveling_wand_threshold or 30
    leveling_state.life_tap_mana = settings.leveling_life_tap_mana or 30
    leveling_state.drain_soul_execute = settings.leveling_drain_soul_execute or 25
    leveling_state.use_immolate = settings.leveling_use_immolate ~= false
    leveling_state.use_corruption = settings.leveling_use_corruption ~= false
    leveling_state.use_curse_of_agony = settings.leveling_use_curse_of_agony ~= false
    leveling_state.drain_life_hp = settings.leveling_drain_life_hp or 60

    leveling_state.shadow_bolt_ready = safe_is_spell_ready(SPELLS.ShadowBolt, context.target)
    leveling_state.searing_pain_ready = safe_is_spell_ready(SPELLS.SearingPain, context.target)
    leveling_state.corruption_ready = safe_is_spell_ready(SPELLS.Corruption, context.target)
    leveling_state.immolate_ready = safe_is_spell_ready(SPELLS.Immolate, context.target)
    leveling_state.curse_of_agony_ready = safe_is_spell_ready(SPELLS.CurseOfAgony, context.target)
    leveling_state.life_tap_ready = safe_is_spell_ready(SPELLS.LifeTap, nil, { skip_range = true })
    leveling_state.fear_ready = safe_is_spell_ready(SPELLS.Fear, context.target)
    leveling_state.drain_soul_ready = safe_is_spell_ready(SPELLS.DrainSoul, context.target)
    leveling_state.death_coil_ready = safe_is_spell_ready(SPELLS.DeathCoil, context.target)
    leveling_state.health_funnel_ready = safe_is_spell_ready(SPELLS.HealthFunnel, nil, { skip_range = true })
    leveling_state.healthstone_ready = safe_is_spell_ready(SPELLS.CreateHealthstone, nil, { skip_range = true })
    leveling_state.soulstone_ready = safe_is_spell_ready(SPELLS.CreateSoulstone, nil, { skip_range = true })
    leveling_state.spell_lock_ready = safe_is_spell_ready(SPELLS.SpellLock, context.target)
    leveling_state.howl_of_terror_ready = safe_is_spell_ready(SPELLS.HowlofTerror, nil, { skip_range = true })
    leveling_state.siphon_life_ready = safe_is_spell_ready(SPELLS.SiphonLife, context.target)
    leveling_state.drain_life_ready = safe_is_spell_ready(SPELLS.DrainLife, context.target)
    leveling_state.demon_armor_ready = safe_is_spell_ready(SPELLS.DemonArmor, nil, { skip_range = true })
    leveling_state.has_demon_armor = safe_buff_up(me, DEMON_ARMOR_BUFF)

    leveling_state.wand_learned = NS.spell_exists and NS.spell_exists(WAND_SPELL_ID) or false

    if pet then
        local ok, pet_hp = pcall(function() return pet:get_health_percentage() end)
        leveling_state.pet_hp = ok and pet_hp or 100
    else
        leveling_state.pet_hp = 100
    end

    return leveling_state
end

local function demon_armor_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_demon_armor then return false end
    return state.demon_armor_ready
end

local function healthstone_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    return state.healthstone_ready
end

local function spell_lock_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.use_interrupt then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    if not ok or not casting then return false end
    return state.spell_lock_ready
end

local function health_funnel_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.pet then return false end
    if (state.pet_hp or 100) > 50 then return false end
    if (state.hp or 100) < 40 then return false end
    return state.health_funnel_ready
end

local function fear_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    local remains = safe_debuff_remains(state.target, FEAR_IDS)
    if remains > 8 then return false end
    return state.fear_ready
end

local function death_coil_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 40 then return false end
    return state.death_coil_ready
end

local function life_tap_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if (state.mana_pct or 100) > (state.life_tap_mana or 30) then return false end
    if (state.hp or 100) < 30 then return false end
    return state.life_tap_ready
end

local function corruption_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.use_corruption then return false end
    if not state.in_combat then return false end
    local remains = safe_debuff_remains(state.target, CORRUPTION_IDS)
    if remains > 4 then return false end
    return state.corruption_ready
end

local function immolate_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.use_immolate then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    local remains = safe_debuff_remains(state.target, IMMOLATE_IDS)
    if remains > 4 then return false end
    return state.immolate_ready
end

local function curse_of_agony_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.use_curse_of_agony then return false end
    if not state.in_combat then return false end
    local remains = safe_debuff_remains(state.target, CURSE_OF_AGONY_IDS)
    if remains > 4 then return false end
    return state.curse_of_agony_ready
end

local function soulstone_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    return state.soulstone_ready
end

local function howl_of_terror_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if not state.howl_of_terror_ready then return false end
    if (state.enemies or 0) < 3 then return false end
    if (state.hp or 100) > 40 then return false end
    return true
end

local function siphon_life_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.siphon_life_ready then return false end
    local remains = safe_debuff_remains(state.target, SPELLS.SiphonLife)
    if remains > 4 then return false end
    return true
end

local function drain_life_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.drain_life_ready then return false end
    if state.is_moving then return false end
    if (state.hp or 100) > (state.drain_life_hp or 60) then return false end
    local target_hp = 100
    if state.target then
        local ok, hp = pcall(function() return state.target:get_health_percentage() end)
        if ok and hp then target_hp = hp end
    end
    if target_hp <= (state.drain_soul_execute or 25) then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return true
end

local function drain_soul_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local target_hp = 100
    if state.target then
        local ok, hp = pcall(function() return state.target:get_health_percentage() end)
        if ok and hp then target_hp = hp end
    end
    if target_hp > (state.drain_soul_execute or 25) and (state.mana_pct or 100) > 30 then return false end
    return state.drain_soul_ready
end

local function searing_pain_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.searing_pain_ready then return false end
    if state.is_moving then return false end
    -- Use Searing Pain when Shadow Bolt is on cooldown or mana is low (faster cast, less mana)
    return true
end

local function shadow_bolt_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return state.shadow_bolt_ready
end

local function wand_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.wand_learned then return false end
    if not state.in_combat then return false end
    if (state.mana_pct or 100) >= (state.wand_threshold or 30) then return false end
    return true
end

local function execute_wand(context)
    return leveling.execute_wand(context)
end

local strategies = {
    { name = "DemonArmor", matches = demon_armor_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.DemonArmor, NS.PLAYER_UNIT, "[LEVELING] Demon Armor") or false end },

    { name = "CreateHealthstone", matches = healthstone_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.CreateHealthstone, NS.PLAYER_UNIT, "[LEVELING] Healthstone") or false end },
    { name = "CreateSoulstone", matches = soulstone_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.CreateSoulstone, NS.PLAYER_UNIT, "[LEVELING] Soulstone") or false end },
    { name = "SpellLock", matches = spell_lock_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.SpellLock, context.target, "[LEVELING] Spell Lock") or false end },
    { name = "HealthFunnel", matches = health_funnel_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HealthFunnel, context.pet, "[LEVELING] Health Funnel") or false end },
    { name = "Fear", matches = fear_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Fear, context.target, "[LEVELING] Fear") or false end },
    { name = "HowlOfTerror", matches = howl_of_terror_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.HowlofTerror, nil, "[LEVELING] Howl of Terror") or false end },
    { name = "DeathCoil", matches = death_coil_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.DeathCoil, context.target, "[LEVELING] Death Coil") or false end },
    { name = "LifeTap", matches = life_tap_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.LifeTap, NS.PLAYER_UNIT, "[LEVELING] Life Tap") or false end },
    { name = "Corruption", matches = corruption_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Corruption, context.target, "[LEVELING] Corruption") or false end },
    { name = "Immolate", matches = immolate_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Immolate, context.target, "[LEVELING] Immolate") or false end },
    { name = "CurseOfAgony", matches = curse_of_agony_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.CurseOfAgony, context.target, "[LEVELING] Curse of Agony") or false end },
    { name = "SiphonLife", matches = siphon_life_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.SiphonLife, context.target, "[LEVELING] Siphon Life") or false end },
    { name = "DrainLife", matches = drain_life_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.DrainLife, context.target, "[LEVELING] Drain Life") or false end },
    { name = "DrainSoul", matches = drain_soul_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.DrainSoul, context.target, "[LEVELING] Drain Soul") or false end },
    { name = "SearingPain", matches = searing_pain_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.SearingPain, context.target, "[LEVELING] Searing Pain") or false end },

    { name = "ShadowBolt", matches = shadow_bolt_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.ShadowBolt, context.target, "[LEVELING] Shadow Bolt") or false end },
    { name = "Wand", matches = wand_matches, execute = execute_wand },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("[Warlock] Leveling rotation loaded (Classic)")
return strategies
