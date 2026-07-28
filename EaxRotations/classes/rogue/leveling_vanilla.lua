-- leveling_vanilla.lua — Rogue Leveling rotation for Vanilla/Classic Anniversary (1.15.x).
-- WHAT:  adaptive leveling (sinister strike, eviscerate, gouge, stealth).
-- WHEN:  any combat while leveling, when NS.is_vanilla() is true.
-- WHY:   handles sub-60 content and combo-point management.
-- SAFETY: nil-guards on NS, SPELLS, and state fields per Pattern 14.

local NS = _G.EaxRotations
if not NS then return nil end

local spec_kit = require("shared/spec_kit_sylvanas")

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

-- ============================================================================
-- Module table
-- ============================================================================
local rogue_leveling = {}

-- ============================================================================
-- Context guard
-- ============================================================================
local is_leveling_context = leveling.create_context_guard()

-- ============================================================================
-- Constants
-- ============================================================================
local SPELLS = NS.RogueSpells or NS.SPELLS or {}
local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }
local HAS_KICK = NS.spell_exists and NS.spell_exists(SPELLS.Kick and SPELLS.Kick[1] or 1766)

-- ============================================================================
-- Strategy helpers
-- ============================================================================

local function spell_ready(spell_action)
    if not spell_action then return false end
    return NS.spell_ready and NS.spell_ready(spell_action) or false
end

local function try_cast(spell_action, target, label, opts)
    if not spell_action then return false end
    local ok, result = pcall(NS.try_cast, spell_action, target, label or "", opts)
    return ok and result == true
end

local function has_buff(buff_ids)
    if not buff_ids then return false end
    local me = (NS.GetPlayer and NS.GetPlayer()) or (NS.get_local_player and NS.get_local_player()) or nil
    if not me then return false end
    local ids = type(buff_ids) == "table" and buff_ids or { buff_ids }
    if NS.buff_up then return NS.buff_up(me, ids) end
    return false
end

-- ============================================================================
-- State builder
-- ============================================================================

-- Schema for safe_state: Pattern 14 nil-guard defaults for rogue leveling.
local LEVELING_VANILLA_SCHEMA = {
    hp = 100,  energy = 100,  combo_points = 0,  max_combo_points = 5,
    enemies = 0,  in_combat = false,  is_pvp = false,  in_melee_range = false,
    is_moving = false,  target = nil,
    use_cooldowns = true,  use_blade_flurry = true,
    blade_flurry_min_enemies = 3,  vanish_hp = 15,
    use_interrupt = true,  use_expose_armor = false,
    has_slice_and_dice = false,  stealthed = false,
    sinister_strike_ready = false,  eviscerate_ready = false,
    slice_and_dice_ready = false,  rupture_ready = false,
    garrote_ready = false,  ambush_ready = false,
    kick_ready = false,  gouge_ready = false,
    evasion_ready = false,  sprint_ready = false,
    blade_flurry_ready = false,  adrenaline_rush_ready = false,
    cold_blood_ready = false,  vanish_ready = false,
    stealth_ready = false,  kidney_shot_ready = false,
    expose_armor_ready = false,  shiv_ready = false,
    thistle_tea_ready = false,  sap_ready = false,  blind_ready = false,
}

function rogue_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    leveling.build_common_state(context, state)

    state.sinister_strike_ready = spell_ready(SPELLS.SinisterStrike)
    state.eviscerate_ready = spell_ready(SPELLS.Eviscerate)
    state.slice_and_dice_ready = spell_ready(SPELLS.SliceAndDice)
    state.rupture_ready = spell_ready(SPELLS.Rupture)
    state.garrote_ready = spell_ready(SPELLS.Garrote)
    state.ambush_ready = spell_ready(SPELLS.Ambush)
    state.kick_ready = HAS_KICK and spell_ready(SPELLS.Kick)
    state.gouge_ready = spell_ready(SPELLS.Gouge)
    state.evasion_ready = spell_ready(SPELLS.Evasion)
    state.sprint_ready = spell_ready(SPELLS.Sprint)
    state.blade_flurry_ready = spell_ready(SPELLS.BladeFlurry)
    state.adrenaline_rush_ready = spell_ready(SPELLS.AdrenalineRush)
    state.cold_blood_ready = spell_ready(SPELLS.ColdBlood)
    state.vanish_ready = spell_ready(SPELLS.Vanish)
    state.stealth_ready = spell_ready(SPELLS.Stealth)
    state.kidney_shot_ready = spell_ready(SPELLS.KidneyShot)
    state.expose_armor_ready = spell_ready(SPELLS.ExposeArmor)
    state.shiv_ready = spell_ready(SPELLS.Shiv)
    state.thistle_tea_ready = SPELLS.ThistleTea and spell_ready(SPELLS.ThistleTea) or false
    state.sap_ready = spell_ready(SPELLS.Sap)
    state.blind_ready = spell_ready(SPELLS.Blind)


    state.is_pvp = context.is_pvp or false
    state.in_melee_range = context.in_melee_range or false

    state.combo_points = NS.combo_points or 0
    state.max_combo_points = 5
    state.energy = NS.energy or 100

    state.has_slice_and_dice = has_buff(SLICE_AND_DICE_BUFF)
    state.stealthed = has_buff(STEALTH_BUFF)

    state.use_cooldowns = spec_kit.setting_bool(context, "use_cooldowns", true)
    state.use_blade_flurry = spec_kit.setting_bool(context, "leveling_use_blade_flurry", true)
    state.blade_flurry_min_enemies = spec_kit.setting_number(context, "leveling_blade_flurry_enemies", 3)
    state.vanish_hp = spec_kit.setting_number(context, "leveling_vanish_hp", 15)

    return spec_kit.safe_state(state, LEVELING_VANILLA_SCHEMA)
end

-- ============================================================================
-- Match functions
-- ============================================================================

local stealth_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.stealthed then return false end
    if not state.stealth_ready then return false end
    if not context.target then return false end
    local dist = NS.get_distance and NS.get_distance(context.target)
    if dist and dist > 30 then return false end
    return true
end

local ambush_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.ambush_ready then return false end
    if not context.target then return false end
    return true
end

local garrote_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.garrote_ready then return false end
    if not context.target then return false end
    return true
end

--- Sap — CC humanoid target while stealthed (OOC only, requires stealth)
local sap_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.sap_ready then return false end
    if not context.target then return false end
    -- Only sap humanoids (creature_type 7)
    local ctype = context.target_creature_type
    if not ctype and context.target and context.target.get_creature_type then
        local ok, val = pcall(function() return context.target:get_creature_type() end)
        if ok then ctype = val end
    end
    if ctype and ctype ~= 7 then return false end
    return true
end

local gouge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.gouge_ready then return false end
    if not state.target then return false end
    if (state.hp or 100) > 40 then return false end
    return true
end

local kick_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.kick_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

local evasion_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.evasion_ready then return false end
    if (state.hp or 100) > 50 then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

local blind_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.blind_ready then return false end
    if not state.target then return false end
    if (state.hp or 100) > 30 then return false end
    return true
end

local sprint_escape_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sprint_ready then return false end
    if (state.hp or 100) > 30 then return false end
    return true
end

local slice_and_dice_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.slice_and_dice_ready then return false end
    if state.has_slice_and_dice then return false end
    if (state.combo_points or 0) < 1 then return false end
    return true
end

local rupture_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rupture_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < 3 then return false end
    if (state.combo_points or 0) >= state.max_combo_points then return false end
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Rupture) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

local expose_armor_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.expose_armor_ready then return false end
    if not state.target then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if (state.combo_points or 0) < 3 then return false end
    local ok, stacks = pcall(function() return NS.debuff_stacks and NS.debuff_stacks(state.target, SPELLS.ExposeArmor) or 0 end)
    if ok and stacks and stacks > 0 then return false end
    if (state.combo_points or 0) >= state.max_combo_points then return false end
    return true
end

local kidney_shot_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.kidney_shot_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < 3 then return false end
    if (state.hp or 100) > 40 then return false end
    return true
end

local eviscerate_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.eviscerate_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < state.max_combo_points then return false end
    return true
end

local cold_blood_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.cold_blood_ready then return false end
    if not state.target then return false end
    if not state.use_cooldowns then return false end
    if (state.combo_points or 0) < state.max_combo_points then return false end
    return true
end

local adrenaline_rush_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.adrenaline_rush_ready then return false end
    if not state.use_cooldowns then return false end
    if (state.energy or 0) > 60 then return false end
    return true
end

local blade_flurry_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.blade_flurry_ready then return false end
    if not state.use_blade_flurry then return false end
    if (state.enemies or 0) < state.blade_flurry_min_enemies then return false end
    return true
end

local sinister_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sinister_strike_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) >= state.max_combo_points then return false end
    return true
end

local thistle_tea_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.thistle_tea_ready then return false end
    if (state.energy or 100) > 40 then return false end
    return true
end

local vanish_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.vanish_ready then return false end
    if (state.hp or 100) > state.vanish_hp then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    { name = "Stealth",
      matches = stealth_matches,
      execute = function(context) return try_cast(SPELLS.Stealth, nil, "[LEVELING] Stealth") end },

    { name = "Ambush",
      matches = ambush_matches,
      execute = function(context) return try_cast(SPELLS.Ambush, context and context.target, "[LEVELING] Ambush") end },

    { name = "Garrote",
      matches = garrote_matches,
      execute = function(context) return try_cast(SPELLS.Garrote, context and context.target, "[LEVELING] Garrote") end },

    { name = "Kick",
      matches = kick_matches,
      execute = function(context) return try_cast(SPELLS.Kick, context and context.target, "[LEVELING] Kick") end },

    { name = "Gouge",
      matches = gouge_matches,
      execute = function(context) return try_cast(SPELLS.Gouge, context and context.target, "[LEVELING] Gouge") end },

    { name = "Vanish",
      matches = vanish_matches,
      execute = function(context) return try_cast(SPELLS.Vanish, nil, "[LEVELING] Vanish") end },

    { name = "Evasion",
      matches = evasion_matches,
      execute = function(context) return try_cast(SPELLS.Evasion, nil, "[LEVELING] Evasion") end },

    { name = "Sprint",
      matches = sprint_escape_matches,
      execute = function(context) return try_cast(SPELLS.Sprint, nil, "[LEVELING] Sprint") end },

    { name = "Blind",
      matches = blind_matches,
      execute = function(context) return try_cast(SPELLS.Blind, context and context.target, "[LEVELING] Blind") end },

    { name = "ThistleTea",
      matches = thistle_tea_matches,
      execute = function(context) return try_cast(SPELLS.ThistleTea, nil, "[LEVELING] Thistle Tea") end },

    { name = "ColdBlood",
      matches = cold_blood_matches,
      execute = function(context) return try_cast(SPELLS.ColdBlood, nil, "[LEVELING] Cold Blood") end },

    { name = "AdrenalineRush",
      matches = adrenaline_rush_matches,
      execute = function(context) return try_cast(SPELLS.AdrenalineRush, nil, "[LEVELING] Adrenaline Rush") end },

    { name = "BladeFlurry",
      matches = blade_flurry_matches,
      execute = function(context) return try_cast(SPELLS.BladeFlurry, nil, "[LEVELING] Blade Flurry") end },

    { name = "SliceAndDice",
      matches = slice_and_dice_matches,
      execute = function(context) return try_cast(SPELLS.SliceAndDice, nil, "[LEVELING] Slice and Dice") end },

    { name = "Rupture",
      matches = rupture_matches,
      execute = function(context) return try_cast(SPELLS.Rupture, context and context.target, "[LEVELING] Rupture") end },
    -- Sap: CC humanoid while stealthed (before entering combat)
    { name = "Sap",
      matches = sap_matches,
      execute = function(context) return try_cast(SPELLS.Sap, context and context.target, "[LEVELING] Sap") end },

    { name = "Eviscerate",
      matches = eviscerate_matches,
      execute = function(context) return try_cast(SPELLS.Eviscerate, context and context.target, "[LEVELING] Eviscerate") end },

    { name = "ExposeArmor",
      matches = expose_armor_matches,
      execute = function(context) return try_cast(SPELLS.ExposeArmor, context and context.target, "[LEVELING] Expose Armor") end },

    { name = "KidneyShot",
      matches = kidney_shot_matches,
      execute = function(context) return try_cast(SPELLS.KidneyShot, context and context.target, "[LEVELING] Kidney Shot") end },

    { name = "SinisterStrike",
      matches = sinister_strike_matches,
      execute = function(context) return try_cast(SPELLS.SinisterStrike, context and context.target, "[LEVELING] Sinister Strike") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = rogue_leveling.build_state })
end

function rogue_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = rogue_leveling.build_state(context)
    if not state then return false end

    for i = 1, #strategies do
        local strategy = strategies[i]
        local ok, should_execute = pcall(strategy.matches, context, state)
        if ok and should_execute then
            local ok2, result = pcall(strategy.execute, context)
            if ok2 and result then
                return true
            end
        end
    end

    return false
end

-- [Rogue] Leveling rotation loaded (Classic)
rogue_leveling.strategies = strategies

return rogue_leveling
