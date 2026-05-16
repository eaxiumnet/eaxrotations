-- Warlock leveling priority list.
-- Designed for solo/leveling play, from level 1 to 70.
-- Handles unlearned spells gracefully via NS.spell_ready checks.
-- Uses wand/Shoot as fallback when out of mana.

local NS = _G.EaxRotations
if not NS then return nil end
local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local SPELLS = NS.WarlockSpells or {}

-- ============================================================================
-- Constants
-- ============================================================================

local FEL_ARMOR_BUFF = { 28189, 28176 }
local DEATH_COIL_IDS = { 27223, 17926, 17925, 6789 }
local FEAR_IDS = { 6215, 6213, 5782 }
local DRAIN_SOUL_IDS = { 27217, 11675, 8289, 8288, 1120 }
local CORRUPTION_IDS = { 27216, 25311, 11672, 11671, 7648, 6223, 6222, 172 }
local IMMOLATE_IDS = { 27215, 25309, 11668, 11667, 11665, 2941, 1094, 707, 348 }
local CURSE_OF_AGONY_IDS = { 27218, 11713, 11712, 11711, 6217, 1014, 980 }
local HEALTH_FUNNEL_IDS = { 27259, 11695, 11694, 11693, 755, 3699, 3700 }

local WAND_SPELL_ID = leveling.WAND_SPELL_ID or 5019

local EMPTY_SETTINGS = {}

-- ============================================================================
-- Safe API wrappers (pcall-protected against nil/throwing NS functions)
-- ============================================================================

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

-- ============================================================================
-- Context guard
-- ============================================================================

local function leveling_context_allowed(context)
    if not context then return false end
    if context.is_solo == true or context.is_leveling == true then return true end
    -- Also allow if user explicitly selected leveling playstyle
    local settings = context.settings or EMPTY_SETTINGS
    return settings.playstyle == "leveling" or settings.active_playstyle == "leveling"
end

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or EMPTY_SETTINGS
    local me = context.me
    local pet = context.pet

    leveling_state.has_fel_armor = safe_buff_up(me, FEL_ARMOR_BUFF)
    leveling_state.in_combat = context.in_combat or false
    leveling_state.mana_pct = context.mana_pct or 100
    leveling_state.hp = context.hp or 100
    leveling_state.enemies = context.enemies_count or 0
    leveling_state.target = context.target
    leveling_state.is_moving = context.is_moving or false
    leveling_state.pet = pet

    -- Settings from schema
    leveling_state.use_interrupt = settings.use_interrupt ~= false
    leveling_state.wand_threshold = settings.leveling_wand_threshold or 30
    leveling_state.life_tap_mana = settings.leveling_life_tap_mana or 30
    leveling_state.drain_soul_execute = settings.leveling_drain_soul_execute or 25
    leveling_state.use_immolate = settings.leveling_use_immolate ~= false
    leveling_state.use_corruption = settings.leveling_use_corruption ~= false
    leveling_state.use_curse_of_agony = settings.leveling_use_curse_of_agony ~= false

    -- Spell readiness (each returns false if spell not learned)
    leveling_state.shadow_bolt_ready = safe_is_spell_ready(SPELLS.ShadowBolt, context.target)
    leveling_state.corruption_ready = safe_is_spell_ready(SPELLS.Corruption, context.target)
    leveling_state.immolate_ready = safe_is_spell_ready(SPELLS.Immolate, context.target)
    leveling_state.curse_of_agony_ready = safe_is_spell_ready(SPELLS.CurseOfAgony, context.target)
    leveling_state.life_tap_ready = safe_is_spell_ready(SPELLS.LifeTap, nil, { skip_range = true })
    leveling_state.fear_ready = safe_is_spell_ready(SPELLS.Fear, context.target)
    leveling_state.drain_soul_ready = safe_is_spell_ready(SPELLS.DrainSoul, context.target)
    leveling_state.death_coil_ready = safe_is_spell_ready(SPELLS.DeathCoil, context.target)
    leveling_state.health_funnel_ready = safe_is_spell_ready(SPELLS.HealthFunnel, nil, { skip_range = true })
    leveling_state.fel_armor_ready = safe_is_spell_ready(SPELLS.FelArmor, nil, { skip_range = true })
    leveling_state.healthstone_ready = safe_is_spell_ready(SPELLS.CreateHealthstone, nil, { skip_range = true })
    leveling_state.spell_lock_ready = safe_is_spell_ready(SPELLS.SpellLock, context.target)

    -- Wand readiness
    leveling_state.wand_learned = NS.spell_exists and NS.spell_exists(WAND_SPELL_ID) or false

    -- Pet HP tracking
    if pet then
        local ok, pet_hp = pcall(function() return pet:get_health_percentage() end)
        leveling_state.pet_hp = ok and pet_hp or 100
    else
        leveling_state.pet_hp = 100
    end

    return leveling_state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function fel_armor_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if state.in_combat then return false end
    if state.has_fel_armor then return false end
    return state.fel_armor_ready
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
    if state.pet_hp > 50 then return false end
    if state.hp < 40 then return false end  -- Don't kill self healing pet
    return state.health_funnel_ready
end

local function fear_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    -- Fear when overwhelmed (multiple enemies)
    if state.enemies < 2 then return false end
    -- Don't re-fear if already feared
    local remains = safe_debuff_remains(state.target, FEAR_IDS)
    if remains > 8 then return false end
    return state.fear_ready
end

local function death_coil_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.hp > 40 then return false end
    return state.death_coil_ready
end

local function life_tap_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.in_combat then return false end
    if state.mana_pct > (state.life_tap_mana or 30) then return false end
    if state.hp < 30 then return false end  -- Don't kill self
    return state.life_tap_ready
end

local function corruption_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.use_corruption then return false end
    if not state.in_combat then return false end
    -- Refresh only if not active or about to expire
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
    -- Refresh only if not active or about to expire
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
    -- Refresh only if not active or about to expire
    local remains = safe_debuff_remains(state.target, CURSE_OF_AGONY_IDS)
    if remains > 4 then return false end
    return state.curse_of_agony_ready
end

local function drain_soul_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    -- Use Drain Soul as execute or when low mana
    local target_hp = 100
    if state.target then
        local ok, hp = pcall(function() return state.target:get_health_percentage() end)
        if ok and hp then target_hp = hp end
    end
    if target_hp > (state.drain_soul_execute or 25) and state.mana_pct > 30 then return false end
    return state.drain_soul_ready
end

local function shadow_bolt_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if state.mana_pct < 10 then return false end
    return state.shadow_bolt_ready
end

local function wand_matches(context, state)
    if not leveling_context_allowed(context) then return false end
    if not state then return false end
    if not state.target then return false end
    if not state.wand_learned then return false end
    if not state.in_combat then return false end
    if state.mana_pct >= (state.wand_threshold or 30) then return false end
    return true
end

-- ============================================================================
-- Execute functions
-- ============================================================================

local function execute_wand(context)
    return leveling.execute_wand(context)
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    -- Out-of-combat buffs
    { name = "FelArmor",
      matches = fel_armor_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.FelArmor, NS.PLAYER_UNIT, "[LEVELING] Fel Armor") or false end },

    { name = "CreateHealthstone",
      matches = healthstone_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.CreateHealthstone, NS.PLAYER_UNIT, "[LEVELING] Healthstone") or false end },

    -- Pet sustain
    -- Interrupt
    { name = "SpellLock",
      matches = spell_lock_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.SpellLock, context.target, "[LEVELING] Spell Lock") or false end },

    -- Pet sustain
    { name = "HealthFunnel",
      matches = health_funnel_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.HealthFunnel, context.pet, "[LEVELING] Health Funnel") or false end },

    -- CC / survival
    { name = "Fear",
      matches = fear_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Fear, context.target, "[LEVELING] Fear") or false end },

    { name = "DeathCoil",
      matches = death_coil_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.DeathCoil, context.target, "[LEVELING] Death Coil") or false end },

    -- Mana
    { name = "LifeTap",
      matches = life_tap_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.LifeTap, NS.PLAYER_UNIT, "[LEVELING] Life Tap") or false end },

    -- DoTs
    { name = "Corruption",
      matches = corruption_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Corruption, context.target, "[LEVELING] Corruption") or false end },

    { name = "Immolate",
      matches = immolate_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.Immolate, context.target, "[LEVELING] Immolate") or false end },

    { name = "CurseOfAgony",
      matches = curse_of_agony_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.CurseOfAgony, context.target, "[LEVELING] Curse of Agony") or false end },

    -- Execute / low mana filler
    { name = "DrainSoul",
      matches = drain_soul_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.DrainSoul, context.target, "[LEVELING] Drain Soul") or false end },

    -- Main filler
    { name = "ShadowBolt",
      matches = shadow_bolt_matches,
      execute = function(context) if not context then return false end return NS.try_cast and NS.try_cast(SPELLS.ShadowBolt, context.target, "[LEVELING] Shadow Bolt") or false end },

    -- Wand fallback (threshold controlled by schema setting)
    { name = "Wand",
      matches = wand_matches,
      execute = execute_wand },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
NS.log("Warlock leveling rotation registered")
return strategies
