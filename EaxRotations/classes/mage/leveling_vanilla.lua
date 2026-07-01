-- leveling_vanilla.lua — Mage Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling rotation (frostbolt, fireball, polymorph, food/water).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and mana conservation.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end
local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end
local SPELLS = NS.MageSpells or {}

-- ============================================================================
-- Constants
-- ============================================================================

local ARCANE_INTELLECT_BUFF = { 10157, 10156, 1461, 1460, 1459 }
local FROST_ARMOR_BUFF = { 12544, 12543, 10174, 10173, 7301, 7300, 168 }
local ICE_BARRIER_BUFF = { 13033, 13032, 13031, 11426 }
local MANA_SHIELD_BUFF = { 13008, 13007, 13006, 13005, 13003, 8495, 8494, 8492, 1463 }
local POLYMORPH_IDS = { 12826, 12825, 12824, 118 }

local CONJURE_MANA_GEM_SPELLS = { 10054, 10053, 3552, 759 }
local MANA_GEM_ITEM_IDS = { 8008, 8007, 5513, 5514 }

local WAND_SPELL_ID = leveling.WAND_SPELL_ID or 5019

local EMPTY_SETTINGS = {}

-- ============================================================================
-- Safe API wrappers
-- ============================================================================

local function spell_is_ready(action, target, opts)
    if not NS.spell_ready then return false end
    local ok, ready = pcall(NS.spell_ready, action, target, opts)
    return ok and ready
end

local function safe_buff_up(unit, ids)
    if not unit or not NS.buff_up then return false end
    local ok, has_buff = pcall(NS.buff_up, unit, ids)
    return ok and has_buff
end

local function safe_debuff_remains(unit, ids)
    if not unit or not NS.debuff_remains then return 0 end
    local ok, remains = pcall(NS.debuff_remains, unit, ids)
    if ok and type(remains) == "number" then return remains end
    return 0
end

local function safe_is_item_ready(item_id)
    if not NS.is_item_ready then return false end
    local ok, ready = pcall(NS.is_item_ready, item_id)
    return ok and ready
end

local function safe_use_item(item_id)
    if not NS.use_item_by_id then return false end
    local ok, used = pcall(NS.use_item_by_id, item_id)
    return ok and used
end

-- ============================================================================
-- State builder
-- ============================================================================

local function build_state(context)
    if not context then return nil end
    local settings = context.settings or EMPTY_SETTINGS
    local me = context.me
    local state = {}

    state.has_ai = safe_buff_up(me, ARCANE_INTELLECT_BUFF)
    state.has_frost_armor = safe_buff_up(me, FROST_ARMOR_BUFF)
    state.has_ice_barrier = safe_buff_up(me, ICE_BARRIER_BUFF)
    state.has_mana_shield = safe_buff_up(me, MANA_SHIELD_BUFF)

    state.in_combat = context.in_combat or false
    state.mana_pct = context.mana_pct or 100
    state.hp = context.hp or 100
    state.enemies = context.enemies_count or 0
    state.target = context.target
    state.is_moving = context.is_moving or false

    state.wand_threshold = settings.leveling_wand_threshold or 30
    state.polymorph_hp = settings.leveling_polymorph_hp or 40
    state.use_arcane_missiles = settings.leveling_arcane_missiles_use ~= false
    state.use_scorch = settings.leveling_scorch_use ~= false
    state.use_interrupt = settings.use_interrupt ~= false
    state.use_fire_blast = settings.leveling_fire_blast_use ~= false

    state.use_mana_gem = settings.use_mana_gem ~= false
    state.mana_gem_threshold = settings.mana_gem_mana_pct or 70

    state.conjure_gem_ready = false
    for _, spell_id in ipairs(CONJURE_MANA_GEM_SPELLS) do
        local ok_e, exists = pcall(NS.spell_exists, spell_id)
        if ok_e and exists then
            state.conjure_gem_ready = true
            break
        end
    end

    state.mana_gem_available = false
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        if safe_is_item_ready(item_id) then
            state.mana_gem_available = true
            break
        end
    end

    state.frostbolt_ready = spell_is_ready(SPELLS.Frostbolt, context.target)
    state.fire_blast_ready = spell_is_ready(SPELLS.FireBlast, context.target)
    state.scorch_ready = spell_is_ready(SPELLS.Scorch, context.target)
    state.fireball_ready = spell_is_ready(SPELLS.Fireball, context.target)
    state.scorch_ready = spell_is_ready(SPELLS.Scorch, context.target)
    state.arcane_missiles_ready = spell_is_ready(SPELLS.ArcaneMissiles, context.target)
    state.frost_nova_ready = spell_is_ready(SPELLS.FrostNova, context.target)
    state.blizzard_ready = spell_is_ready(SPELLS.Blizzard, context.target)
    state.polymorph_ready = spell_is_ready(SPELLS.Polymorph, context.target)
    state.counterspell_ready = spell_is_ready(SPELLS.Counterspell, context.target)
    state.evocation_ready = spell_is_ready(SPELLS.Evocation, nil, { skip_range = true })
    state.ice_barrier_ready = spell_is_ready(SPELLS.IceBarrier, nil, { skip_range = true })
    state.mana_shield_ready = spell_is_ready(SPELLS.ManaShield, nil, { skip_range = true })
    state.ai_ready = spell_is_ready(SPELLS.ArcaneIntellect, nil, { skip_range = true })
    state.remove_curse_ready = spell_is_ready(SPELLS.RemoveCurse, nil, { skip_range = true })
    state.frost_armor_ready = spell_is_ready(SPELLS.FrostArmor, nil, { skip_range = true })
    state.fire_ward_ready = spell_is_ready(SPELLS.FireWard, nil, { skip_range = true })
    state.has_fire_ward = safe_buff_up(me, { 543 })
    state.cone_of_cold_ready = spell_is_ready(SPELLS.ConeOfCold, context.target)
    state.blink_ready = spell_is_ready(SPELLS.Blink, nil, { skip_range = true })

    local ok_wand, exists = pcall(NS.spell_exists, WAND_SPELL_ID)
    state.wand_learned = ok_wand and exists or false

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

local function arcane_intellect_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_ai then return false end
    return state.ai_ready
end

local function evocation_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if (state.mana_pct or 100) > 25 then return false end
    return state.evocation_ready
end

local function ice_barrier_matches(context, state)
    if not state then return false end
    if state.has_ice_barrier then return false end
    if not state.in_combat then return false end
    return state.ice_barrier_ready
end

local function mana_shield_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if state.has_mana_shield then return false end
    if (state.hp or 100) > 40 then return false end
    return state.mana_shield_ready
end

local function counterspell_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.use_interrupt then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    if not ok or not casting then return false end
    return state.counterspell_ready
end

local function polymorph_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if state.in_combat then return false end
    local ok, hp = pcall(function() return state.target:get_health_percentage() end)
    if ok and hp and hp >= (state.polymorph_hp or 40) then return false end
    local remains = safe_debuff_remains(state.target, POLYMORPH_IDS)
    if remains >= 10 then return false end
    return state.polymorph_ready
end

local function frost_nova_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not context.me then return false end
    local ok, dist = pcall(function() return state.target:get_distance(context.me) end)
    if not ok or not dist or dist > 10 then return false end
    return state.frost_nova_ready
end

local function blizzard_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 3 then return false end
    if state.is_moving then return false end
    return state.blizzard_ready
end

local function fire_blast_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.use_fire_blast then return false end
    return state.fire_blast_ready
end

local function arcane_missiles_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if not state.use_arcane_missiles then return false end
    if (state.mana_pct or 100) < 20 then return false end
    return state.arcane_missiles_ready
end

local function frostbolt_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return state.frostbolt_ready
end

local function scorch_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.use_scorch then return false end
    if state.is_moving then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return state.scorch_ready
end
local function scorch_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if not state.use_scorch then return false end
    if state.is_moving then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return state.scorch_ready
end

--- Fireball — primary fire nuke, used when fire is preferred or as fallback nuke
local function fireball_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if state.is_moving then return false end
    if (state.mana_pct or 100) < 10 then return false end
    return state.fireball_ready
end


local function frost_armor_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_frost_armor then return false end
    return state.frost_armor_ready
end

local function fire_ward_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.has_fire_ward then return false end
    return state.fire_ward_ready
end

local function cone_of_cold_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    if (state.enemies or 0) < 2 then return false end
    if not context.me then return false end
    local ok, dist = pcall(function() return state.target:get_distance(context.me) end)
    if not ok or not dist or dist > 10 then return false end
    return state.cone_of_cold_ready
end

local function blink_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if (state.hp or 100) > 50 then return false end
    return state.blink_ready
end

local function remove_curse_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    return state.remove_curse_ready
end

local function wand_matches(context, state)
    if not state then return false end
    if not state.target then return false end
    if not state.wand_learned then return false end
    if (state.mana_pct or 100) >= (state.wand_threshold or 30) then return false end
    return true
end

local function conjure_gem_matches(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.conjure_gem_ready then return false end
    if state.mana_gem_available then return false end
    return true
end

local function use_mana_gem_matches(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.use_mana_gem then return false end
    if not state.mana_gem_available then return false end
    if (state.mana_pct or 100) >= (state.mana_gem_threshold or 70) then return false end
    return true
end

-- ============================================================================
-- Execute functions
-- ============================================================================

local function execute_wand(context)
    return leveling.execute_wand(context)
end

local function frost_nova_execute()
    return NS.try_cast and NS.try_cast(SPELLS.FrostNova, nil, "[LEVELING] Frost Nova") or false
end

local function conjure_gem_execute()
    for _, spell_id in ipairs(CONJURE_MANA_GEM_SPELLS) do
        if NS.spell_exists and NS.spell_exists(spell_id) then
            return NS.try_cast and NS.try_cast(spell_id, NS.PLAYER_UNIT, "[LEVELING] Conjure Mana Gem") or false
        end
    end
    return false
end

local function use_mana_gem_execute()
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        if safe_is_item_ready(item_id) then
            return safe_use_item(item_id)
        end
    end
    return false
end

-- ============================================================================
-- Strategies
-- ============================================================================

local strategies = {
    { name = "ArcaneIntellect",
      matches = arcane_intellect_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.ArcaneIntellect, NS.PLAYER_UNIT, "[LEVELING] Arcane Intellect") or false end },

    { name = "FrostArmor",
      matches = frost_armor_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.FrostArmor, NS.PLAYER_UNIT, "[LEVELING] Frost Armor") or false end },

    { name = "FireWard",
      matches = fire_ward_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.FireWard, NS.PLAYER_UNIT, "[LEVELING] Fire Ward") or false end },

    { name = "RemoveCurse",
      matches = remove_curse_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.RemoveCurse, NS.PLAYER_UNIT, "[LEVELING] Remove Curse") or false end },

    { name = "ConjureManaGem",
      matches = conjure_gem_matches,
      execute = conjure_gem_execute },

    { name = "Polymorph",
      matches = polymorph_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Polymorph, context.target, "[LEVELING] Polymorph") or false end },

    { name = "Counterspell",
      matches = counterspell_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Counterspell, context.target, "[LEVELING] Counterspell") or false end },

    { name = "ManaShield",
      matches = mana_shield_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.ManaShield, NS.PLAYER_UNIT, "[LEVELING] Mana Shield") or false end },

    { name = "IceBarrier",
      matches = ice_barrier_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.IceBarrier, NS.PLAYER_UNIT, "[LEVELING] Ice Barrier") or false end },

    { name = "FrostNova",
      matches = frost_nova_matches,
      execute = frost_nova_execute },

    { name = "ConeOfCold",
      matches = cone_of_cold_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.ConeOfCold, context.target, "[LEVELING] Cone of Cold") or false end },

    { name = "Blink",
      matches = blink_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.Blink, NS.PLAYER_UNIT, "[LEVELING] Blink") or false end },

    { name = "Blizzard",
      matches = blizzard_matches,
      execute = function(context) local t = context.target; local pos = t and context and NS.get_aoe_cast_position and NS.get_aoe_cast_position(NS.get_spell_id(SPELLS.Blizzard), t, 8, 35); if pos and NS.try_cast_position then return NS.try_cast_position(SPELLS.Blizzard, pos, t, "[LEVELING] Blizzard") end; return context and NS.try_cast and NS.try_cast(SPELLS.Blizzard, t, "[LEVELING] Blizzard") or false end },

    { name = "Evocation",
      matches = evocation_matches,
      execute = function() return NS.try_cast and NS.try_cast(SPELLS.Evocation, NS.PLAYER_UNIT, "[LEVELING] Evocation") or false end },

    { name = "FireBlast",
      matches = fire_blast_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.FireBlast, context.target, "[LEVELING] Fire Blast") or false end },
    { name = "Fireball",
      matches = fireball_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Fireball, context.target, "[LEVELING] Fireball") or false end },

    { name = "Frostbolt",
      matches = frostbolt_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Frostbolt, context.target, "[LEVELING] Frostbolt") or false end },


    { name = "Scorch",
      matches = scorch_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Scorch, context.target, "[LEVELING] Scorch") or false end },

    { name = "ArcaneMissiles",
      matches = arcane_missiles_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.ArcaneMissiles, context.target, "[LEVELING] Arcane Missiles") or false end },

    { name = "Frostbolt",
      matches = frostbolt_matches,
      execute = function(context) return context and NS.try_cast and NS.try_cast(SPELLS.Frostbolt, context.target, "[LEVELING] Frostbolt") or false end },

    { name = "UseManaGem",
      matches = use_mana_gem_matches,
      execute = use_mana_gem_execute },

    { name = "Wand",
      matches = wand_matches,
      execute = execute_wand },
}

NS.rotation_registry:register("leveling", strategies, { get_state = build_state })
-- [Mage] Leveling rotation loaded (Classic)
return strategies
