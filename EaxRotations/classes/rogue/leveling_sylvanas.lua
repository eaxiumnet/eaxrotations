-- Rogue leveling rotation.
-- Auto-activates in solo/leveling context or when playstyle = "leveling".
-- Uses shared leveling module for context guard, wand, and common helpers.

local NS = _G.EaxRotations
if not NS then return nil end

local leveling = require("shared/leveling_sylvanas")
if not leveling then return nil end

local _format = string.format

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
local CCGateDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local HAS_STEALTH = NS.spell_exists and NS.spell_exists(SPELLS.Stealth and SPELLS.Stealth[1] or 1784)
local HAS_SAP = NS.spell_exists and NS.spell_exists(SPELLS.Sap and SPELLS.Sap[1] or 6770)
local HAS_KICK = NS.spell_exists and NS.spell_exists(SPELLS.Kick and SPELLS.Kick[1] or 1766)
local SLICE_AND_DICE_BUFF = { 6774, 5171 }
local STEALTH_BUFF = { 1787, 1786, 1785, 1784 }

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
    if NS.buff_up then
        local ok, result = pcall(NS.buff_up, me, ids)
        return ok and result
    end
    return false
end

local function read_numeric_helper(source)
    if type(source) == "number" then return source end
    if type(source) ~= "function" then return nil end
    local ok, value = pcall(source)
    if ok and type(value) == "number" then return value end
    return nil
end

-- ============================================================================
-- State builder
-- ============================================================================

function rogue_leveling.build_state(context)
    if not context then return nil end

    local state = {}

    -- Common state
    leveling.build_common_state(context, state)

    -- Rogue-specific spell readiness
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
    state.sap_ready = HAS_SAP and spell_ready(SPELLS.Sap)
    state.blind_ready = spell_ready(SPELLS.Blind)
    state.kidney_shot_ready = spell_ready(SPELLS.KidneyShot)
    state.expose_armor_ready = spell_ready(SPELLS.ExposeArmor)
    state.shiv_ready = spell_ready(SPELLS.Shiv)

    -- PvP state
    state.is_pvp = context.is_pvp or false
    state.in_melee_range = context.in_melee_range or false

    -- Shiv purge detection via offensive dispel priority DB
    state.shiv_purge_name = nil
    if state.target and state.is_pvp and state.shiv_ready and state.in_melee_range then
        local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(state.target, NS)
        if best_id then
            state.shiv_purge_name = best_name
        end
    end

    -- Combo points
    state.combo_points = context.combo_points or context.combo or read_numeric_helper(NS.combo_points) or 0
    state.max_combo_points = 5
    state.energy = context.energy or read_numeric_helper(NS.energy) or 100

    -- Buff checks
    state.has_slice_and_dice = has_buff(SLICE_AND_DICE_BUFF)
    state.stealthed = has_buff(STEALTH_BUFF)

    -- Settings from context (fallback to shared wand threshold)
    local settings = context.settings or {}
    state.use_cooldowns = settings.use_cooldowns ~= false
    state.use_blade_flurry = settings.leveling_use_blade_flurry ~= false
    state.blade_flurry_min_enemies = settings.leveling_blade_flurry_enemies or 3
    state.vanish_hp = settings.leveling_vanish_hp or 15
    state.use_expose_armor = settings.leveling_use_expose_armor == true

    return state
end

-- ============================================================================
-- Match functions
-- ============================================================================

--- Stealth OOC for opener
local stealth_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if state.stealthed then return false end
    if not state.stealth_ready then return false end
    if not context.target then return false end
    -- Only stealth when we have a target nearby
    local dist = NS.get_distance and NS.get_distance(context.target)
    if dist and dist > 30 then return false end
    return true
end

--- Ambush - stealth opener (high burst, requires behind target)
-- NOTE: NS.spell_ready is expected to validate the behind-target positional requirement.
local ambush_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.ambush_ready then return false end
    if not context.target then return false end
    return true
end

--- Garrote - stealth opener (DoT + silence, good vs casters)
local garrote_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.garrote_ready then return false end
    if not context.target then return false end
    return true
end

--- Sap OOC CC
local sap_matches = function(context, state)
    if not state then return false end
    if state.in_combat then return false end
    if not state.stealthed then return false end
    if not state.sap_ready then return false end
    if not context.target then return false end
    -- Don't sap the current kill target
    return false  -- Disabled by default — manual Sap is better
end

--- Gouge - CC to bandage/eat or interrupt
local gouge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.gouge_ready then return false end
    if not state.target then return false end
    -- Only Gouge when HP is low (setup for bandage/eat reset)
    if (state.hp or 100) > 40 then return false end
    return true
end

--- Kick interrupt
local kick_matches = function(context, state)
    if not state then return false end
    if not state.use_interrupt then return false end
    if not state.kick_ready then return false end
    if not state.target then return false end
    if not state.in_combat then return false end
    local ok, casting = pcall(function() return state.target:is_casting() end)
    return ok and casting
end

--- Shiv Purge - dispel 1 magic buff via Wound Poison (PvP, no stance required)
-- Shared warrior ShieldSlamPurge leveling pattern.
local shiv_purge_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    local settings = context.settings or {}
    if settings.use_shiv_purge == false then return false end
    -- Skip entirely if Shiv not learned (level < 28)
    if not (NS.is_spell_learned and NS.is_spell_learned(5938)) then return false end
    if not state.in_melee_range then return false end
    if not state.shiv_ready then return false end
    -- PvP only gating: only purge enemy players
    if settings.shiv_purge_pvp_only ~= false then
        local ok, is_player = pcall(function() return state.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    -- Check if target has a priority dispellable buff
    if not state.shiv_purge_name then return false end
    context._shiv_purge_name = state.shiv_purge_name
    return true
end

--- Evasion - defensive when overwhelmed
local evasion_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.evasion_ready then return false end
    if (state.hp or 100) > 50 then return false end
    if (state.enemies or 0) < 2 then return false end
    return true
end

--- Blind - OOC CC escape or setup (breaks on damage)
local blind_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.blind_ready then return false end
    if not state.target then return false end
    if (state.hp or 100) > 30 then return false end
    return true
end

--- Sprint - use when low HP vs single target
local sprint_escape_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sprint_ready then return false end
    if (state.hp or 100) > 30 then return false end
    return true  -- Sprint to kite/escape
end

--- Slice and Dice - maintain
local slice_and_dice_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.slice_and_dice_ready then return false end
    if state.has_slice_and_dice then return false end
    if (state.combo_points or 0) < 1 then return false end
    return true
end

--- Rupture - maintain on target
local rupture_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rupture_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < 3 then return false end
    if (state.combo_points or 0) >= (state.max_combo_points or 5) then return false end  -- prefer Eviscerate at 5 CP
    -- Check if rupture is already up
    local ok, remains = pcall(function() return NS.debuff_remains and NS.debuff_remains(state.target, SPELLS.Rupture) or 0 end)
    if ok and remains and remains > 4 then return false end
    return true
end

--- Expose Armor - when enough CP
local expose_armor_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.expose_armor_ready then return false end
    if not state.target then return false end
    if not state.use_expose_armor then return false end
    -- Skip if target has no armor (API unavailable or already fully reduced)
    if (context.target_armor or 0) <= 0 then return false end
    if (state.combo_points or 0) < 3 then return false end
    -- Check if already applied
    local ok, stacks = pcall(function() return NS.debuff_stacks and NS.debuff_stacks(state.target, SPELLS.ExposeArmor) or 0 end)
    if ok and stacks and stacks > 0 then return false end
    if (state.combo_points or 0) >= (state.max_combo_points or 5) then return false end  -- prefer Eviscerate at 5
    if not state.target_is_elite and not state.target_is_boss and (state.target_ttd or 999) < 20 then return false end
    return true
end

--- Kidney Shot - finisher stun (CC + damage)
local kidney_shot_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.kidney_shot_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < 3 then return false end
    -- Use when HP is low for CC safety
    if (state.hp or 100) > 40 then return false end
    return true
end

--- Eviscerate - primary finisher
local eviscerate_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.eviscerate_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) < (state.max_combo_points or 5) then return false end
    return true
end

--- Cold Blood before Eviscerate
local cold_blood_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.cold_blood_ready then return false end
    if not state.target then return false end
    if not state.use_cooldowns then return false end
    if (state.combo_points or 0) < (state.max_combo_points or 5) then return false end
    return true
end

--- Adrenaline Rush - burst
local adrenaline_rush_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.adrenaline_rush_ready then return false end
    if not state.use_cooldowns then return false end
    if (state.energy or 0) > 60 then return false end  -- Use when low energy for regen
    return true
end

--- Blade Flurry - AoE
local blade_flurry_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.blade_flurry_ready then return false end
    if not state.use_blade_flurry then return false end
    if (state.enemies or 0) < (state.blade_flurry_min_enemies or 3) then return false end
    return true
end

--- Sinister Strike - primary CP builder
local sinister_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sinister_strike_ready then return false end
    if not state.target then return false end
    if (state.combo_points or 0) >= (state.max_combo_points or 5) then return false end
    return true
end

--- Vanish - emergency escape
local vanish_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.vanish_ready then return false end
    if (state.hp or 100) > (state.vanish_hp or 15) then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Stealth
    { name = "Stealth",
      matches = stealth_matches,
      execute = function(context) return try_cast(SPELLS.Stealth, nil, "[LEVELING] Stealth", { skip_range = true }) end },

    -- OOC: Stealth openers
    { name = "Ambush",
      matches = ambush_matches,
      execute = function(context) return try_cast(SPELLS.Ambush, context and context.target, "[LEVELING] Ambush") end },

    { name = "Garrote",
      matches = garrote_matches,
      execute = function(context) return try_cast(SPELLS.Garrote, context and context.target, "[LEVELING] Garrote") end },

    -- Interrupt
    { name = "Kick",
      matches = kick_matches,
      execute = function(context) return try_cast(SPELLS.Kick, context and context.target, "[LEVELING] Kick") end },

    -- CC: Gouge (low HP - setup for bandage/eat reset)
    { name = "Gouge",
      matches = gouge_matches,
      execute = function(context) return try_cast(SPELLS.Gouge, context and context.target, "[LEVELING] Gouge") end },

    -- PvP: Shiv Purge (after interrupt, before defensives — ShieldSlamPurge parity)
    { name = "ShivPurge",
      matches = shiv_purge_matches,
      execute = function(context)
          if not context then return false end
          local name = context._shiv_purge_name or "buff"
          return try_cast(SPELLS.Shiv, context.target, "[LEVELING] Shiv purge → " .. name, { expected_cooldown = 10 })
      end },

    -- Survival: Vanish
    { name = "Vanish",
      matches = vanish_matches,
      execute = function(context) return try_cast(SPELLS.Vanish, nil, "[LEVELING] Vanish", { skip_range = true }) end },

    -- Survival: Evasion when overwhelmed
    { name = "Evasion",
      matches = evasion_matches,
      execute = function(context) return try_cast(SPELLS.Evasion, nil, "[LEVELING] Evasion", { skip_range = true }) end },

    -- Emergency: Health Potion
    { name = "HealthPotion",
      matches = function(context, state) return leveling.health_potion_matches(context, state, 30) end,
      execute = function(context) return leveling.health_potion_execute(context) end },

    -- Escape: Sprint when low HP
    { name = "Sprint",
      matches = sprint_escape_matches,
      execute = function(context) return try_cast(SPELLS.Sprint, nil, "[LEVELING] Sprint", { skip_range = true }) end },

    -- CC: Blind (low HP emergency escape, breaks on damage)
    { name = "Blind",
      matches = blind_matches,
      execute = function(context) return try_cast(SPELLS.Blind, context and context.target, "[LEVELING] Blind") end },

    -- Burst: Cold Blood before finisher
    { name = "ColdBlood",
      matches = cold_blood_matches,
      execute = function(context) return try_cast(SPELLS.ColdBlood, nil, "[LEVELING] Cold Blood", { skip_range = true }) end },

    -- Burst: Adrenaline Rush
    { name = "AdrenalineRush",
      matches = adrenaline_rush_matches,
      execute = function(context) return try_cast(SPELLS.AdrenalineRush, nil, "[LEVELING] Adrenaline Rush", { skip_range = true }) end },

    -- Burst: Blade Flurry (AoE)
    { name = "BladeFlurry",
      matches = blade_flurry_matches,
      execute = function(context) return try_cast(SPELLS.BladeFlurry, nil, "[LEVELING] Blade Flurry", { skip_range = true }) end },

    -- Finisher: Slice and Dice
    { name = "SliceAndDice",
      matches = slice_and_dice_matches,
      execute = function(context) return try_cast(SPELLS.SliceAndDice, nil, "[LEVELING] Slice and Dice", { skip_range = true }) end },

    -- Finisher: Rupture (when 3-4 CP)
    { name = "Rupture",
      matches = rupture_matches,
      execute = function(context) return try_cast(SPELLS.Rupture, context and context.target, "[LEVELING] Rupture") end },

    -- Finisher: Expose Armor (when 3-4 CP, not applied)
    { name = "ExposeArmor",
      matches = expose_armor_matches,
      execute = function(context) return try_cast(SPELLS.ExposeArmor, context and context.target, "[LEVELING] Expose Armor") end },

    -- Finisher: Kidney Shot (stun CC, low HP safety)
    { name = "KidneyShot",
      matches = kidney_shot_matches,
      execute = function(context) return try_cast(SPELLS.KidneyShot, context and context.target, "[LEVELING] Kidney Shot") end },

    -- Finisher: Eviscerate (5 CP)
    { name = "Eviscerate",
      matches = eviscerate_matches,
      execute = function(context) return try_cast(SPELLS.Eviscerate, context and context.target, "[LEVELING] Eviscerate") end },

    -- Builder: Sinister Strike
    { name = "SinisterStrike",
      matches = sinister_strike_matches,
      execute = function(context) return try_cast(SPELLS.SinisterStrike, context and context.target, "[LEVELING] Sinister Strike") end },
}

if NS.rotation_registry and NS.rotation_registry.register then
    NS.rotation_registry:register("leveling", strategies, { get_state = rogue_leveling.build_state })
end

-- ============================================================================
-- Rotation entry point
-- ============================================================================

function rogue_leveling.on_update(context)
    if not context then return false end
    if not is_leveling_context(context) then return false end

    local state = rogue_leveling.build_state(context)
    if not state then return false end

    -- Evaluate strategies in priority order
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

NS.log("[Rogue] Leveling rotation loaded")
return rogue_leveling
