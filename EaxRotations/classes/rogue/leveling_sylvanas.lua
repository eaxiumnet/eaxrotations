-- Rogue leveling rotation.
-- ============================================================================
-- What: Rogue leveling rotation for solo questing and stealth openers
-- When: Per tick
-- Why: Uses shared leveling state so solo combat stays simple and predictable
-- Safety: pcall around spell and buff helpers, disabled Sap by default, nil-guarded target checks
-- ============================================================================
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

-- Disarm target classes: melee classes that lose weapon-based damage when disarmed
local DISARM_CLASS_IDS = { [1] = true, [2] = true, [4] = true, [7] = true }  -- Warrior, Paladin, Rogue, Shaman

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
    for _, id in ipairs(ids) do
        local ok, result = pcall(function() return me:has_buff(id) end)
        if ok and result then return true end
    end
    return false
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
    state.expose_armor_ready = spell_ready(SPELLS.ExposeArmor)
    state.disarm_ready = spell_ready(SPELLS.Dismantle)
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

    -- Disarm burst detection via offensive dispel priority DB
    state.disarm_class_ok = false
    state.disarm_buff_name = nil
    if state.target and state.is_pvp and state.disarm_ready then
        local ok, class_id = pcall(function() return state.target:get_class() end)
        if ok and type(class_id) == "number" and DISARM_CLASS_IDS[class_id] then
            state.disarm_class_ok = true
            local best_id, best_priority, best_name = CCGateDB.find_best_dispel_target(state.target, NS)
            if best_id and (best_priority or 0) >= 3 then
                state.disarm_buff_name = best_name
            end
        end
    end

    -- Combo points
    state.combo_points = NS.combo_points or 0
    state.max_combo_points = 5
    state.energy = NS.energy or 100

    -- Buff checks
    state.has_slice_and_dice = has_buff(SLICE_AND_DICE_BUFF)
    state.stealthed = has_buff(STEALTH_BUFF)

    -- Settings from context (fallback to shared wand threshold)
    local settings = context.settings or {}
    state.use_cooldowns = settings.use_cooldowns ~= false
    state.use_blade_flurry = settings.leveling_use_blade_flurry ~= false
    state.blade_flurry_min_enemies = settings.leveling_blade_flurry_enemies or 3
    state.vanish_hp = settings.leveling_vanish_hp or 15

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
-- Ported from Flux Warrior ShieldSlamPurge via warrior leveling pattern.
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

--- Dismantle - remove enemy melee weapon (PvP, no stance required)
-- Ported from Flux Warrior middleware via warrior leveling pattern.
local disarm_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.target then return false end
    if not state.is_pvp then return false end
    local settings = context.settings or {}
    if settings.use_disarm == false then return false end
    -- Skip entirely if Dismantle not learned (level < 40)
    if not (NS.is_spell_learned and NS.is_spell_learned(51722)) then return false end
    if not state.in_melee_range then return false end
    if not state.disarm_ready then return false end
    if not state.disarm_class_ok then return false end
    -- Player-only gate
    if settings.disarm_pvp_only ~= false then
        local ok, is_player = pcall(function() return state.target:is_player() end)
        if not (ok and is_player) then return false end
    end
    -- Trigger mode
    local trigger = settings.disarm_trigger or "on_burst"
    if trigger == "on_burst" then
        if not state.disarm_buff_name then return false end
        context._disarm_buff_name = state.disarm_buff_name
    end
    return true
end

--- Evasion - defensive when overwhelmed
local evasion_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.evasion_ready then return false end
    if state.hp > 50 then return false end
    if state.enemies < 2 then return false end
    return true
end

--- Sprint - use when low HP vs single target
local sprint_escape_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sprint_ready then return false end
    if state.hp > 30 then return false end
    return true  -- Sprint to kite/escape
end

--- Slice and Dice - maintain
local slice_and_dice_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.slice_and_dice_ready then return false end
    if state.has_slice_and_dice then return false end
    if state.combo_points < 1 then return false end
    return true
end

--- Rupture - maintain on target
local rupture_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.rupture_ready then return false end
    if not state.target then return false end
    if state.combo_points < 3 then return false end
    if state.combo_points >= state.max_combo_points then return false end  -- prefer Eviscerate at 5 CP
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
    if state.combo_points < 3 then return false end
    -- Check if already applied
    local ok, stacks = pcall(function() return NS.debuff_stacks and NS.debuff_stacks(state.target, SPELLS.ExposeArmor) or 0 end)
    if ok and stacks and stacks > 0 then return false end
    if state.combo_points >= state.max_combo_points then return false end  -- prefer Eviscerate at 5
    return true
end

--- Eviscerate - primary finisher
local eviscerate_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.eviscerate_ready then return false end
    if not state.target then return false end
    if state.combo_points < state.max_combo_points then return false end
    return true
end

--- Cold Blood before Eviscerate
local cold_blood_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.cold_blood_ready then return false end
    if not state.target then return false end
    if not state.use_cooldowns then return false end
    if state.combo_points < state.max_combo_points then return false end
    return true
end

--- Adrenaline Rush - burst
local adrenaline_rush_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.adrenaline_rush_ready then return false end
    if not state.use_cooldowns then return false end
    if state.energy > 60 then return false end  -- Use when low energy for regen
    return true
end

--- Blade Flurry - AoE
local blade_flurry_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.blade_flurry_ready then return false end
    if not state.use_blade_flurry then return false end
    if state.enemies < state.blade_flurry_min_enemies then return false end
    return true
end

--- Sinister Strike - primary CP builder
local sinister_strike_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.sinister_strike_ready then return false end
    if not state.target then return false end
    if state.combo_points >= state.max_combo_points then return false end
    return true
end

--- Vanish - emergency escape
local vanish_matches = function(context, state)
    if not state then return false end
    if not state.in_combat then return false end
    if not state.vanish_ready then return false end
    if state.hp > state.vanish_hp then return false end
    return true
end

-- ============================================================================
-- Strategies table
-- ============================================================================

local strategies = {
    -- OOC: Stealth
    { name = "Stealth",
      matches = stealth_matches,
      execute = function(context) return try_cast(SPELLS.Stealth, nil, "[LEVELING] Stealth") end },

    -- Interrupt
    { name = "Kick",
      matches = kick_matches,
      execute = function(context) return try_cast(SPELLS.Kick, context and context.target, "[LEVELING] Kick") end },

    -- PvP: Shiv Purge (after interrupt, before defensives — ShieldSlamPurge parity)
    { name = "ShivPurge",
      matches = shiv_purge_matches,
      execute = function(context)
          local name = context._shiv_purge_name or "buff"
          return try_cast(SPELLS.Shiv, context.target, "[LEVELING] Shiv purge → " .. name, { expected_cooldown = 10 })
      end },

    -- Survival: Vanish
    { name = "Vanish",
      matches = vanish_matches,
      execute = function(context) return try_cast(SPELLS.Vanish, nil, "[LEVELING] Vanish") end },

    -- Survival: Evasion when overwhelmed
    { name = "Evasion",
      matches = evasion_matches,
      execute = function(context) return try_cast(SPELLS.Evasion, nil, "[LEVELING] Evasion") end },

    -- Escape: Sprint when low HP
    { name = "Sprint",
      matches = sprint_escape_matches,
      execute = function(context) return try_cast(SPELLS.Sprint, nil, "[LEVELING] Sprint") end },

    -- PvP: Dismantle (after defensives, before burst — survival wins over utility)
    { name = "Disarm",
      matches = disarm_matches,
      execute = function(context)
          local label = context._disarm_buff_name
              and ("[LEVELING] Dismantle → " .. context._disarm_buff_name)
              or "[LEVELING] Dismantle"
          return try_cast(SPELLS.Dismantle, context.target, label, { expected_cooldown = 60 })
      end },

    -- Burst: Cold Blood before finisher
    { name = "ColdBlood",
      matches = cold_blood_matches,
      execute = function(context) return try_cast(SPELLS.ColdBlood, nil, "[LEVELING] Cold Blood") end },

    -- Burst: Adrenaline Rush
    { name = "AdrenalineRush",
      matches = adrenaline_rush_matches,
      execute = function(context) return try_cast(SPELLS.AdrenalineRush, nil, "[LEVELING] Adrenaline Rush") end },

    -- Burst: Blade Flurry (AoE)
    { name = "BladeFlurry",
      matches = blade_flurry_matches,
      execute = function(context) return try_cast(SPELLS.BladeFlurry, nil, "[LEVELING] Blade Flurry") end },

    -- Finisher: Slice and Dice
    { name = "SliceAndDice",
      matches = slice_and_dice_matches,
      execute = function(context) return try_cast(SPELLS.SliceAndDice, nil, "[LEVELING] Slice and Dice") end },

    -- Finisher: Rupture (when 3-4 CP)
    { name = "Rupture",
      matches = rupture_matches,
      execute = function(context) return try_cast(SPELLS.Rupture, context and context.target, "[LEVELING] Rupture") end },

    -- Finisher: Expose Armor (when 3-4 CP, not applied)
    { name = "ExposeArmor",
      matches = expose_armor_matches,
      execute = function(context) return try_cast(SPELLS.ExposeArmor, context and context.target, "[LEVELING] Expose Armor") end },

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
