-- stance_manager_sylvanas.lua — Warrior stance dance management for TBC Anniversary (2.5.5).
-- WHAT:  Auto-switch stances based on rotation needs and survival state.
-- WHEN:  All Warrior specs (Arms, Fury, Protection).
-- WHY:   Battle for Rend/Overpower/Charge, Berserker for DPS/Execute/Intercept,
--         Defensive for survival.
-- SAFETY: Nil-guarded settings reads; respects lockout and rage preservation.
-- DECISION: Warrior Battle/Berserker/Defensive stance auto-switch.

local _G = _G
local NS = _G.EaxRotations
local spec_kit = require("shared/spec_kit_sylvanas")
if not NS then return end

local M = {}
NS.StanceManager = M

-- Cache warrior helpers at module load (Pattern 2: cache hot-path APIs)
local _WH
local _wh_ok, _wh_loaded = pcall(require, "classes/warrior/shared_helpers_sylvanas")
if _wh_ok and type(_wh_loaded) == "table" then _WH = _wh_loaded else _WH = {} end

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local STANCE = (NS.WarriorConstants and NS.WarriorConstants.STANCE) or { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- ---------------------------------------------------------------------------
-- Settings helper
-- ---------------------------------------------------------------------------
local function setting(context, key, fallback)
    local s = context and context.settings
    if s and s[key] ~= nil then return s[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Determine the optimal stance for the current state.
-- Returns: "battle", "defensive", "berserker", or nil (maintain current)
-- ---------------------------------------------------------------------------
function M.get_optimal_stance(context, state)
    context = context or {}
    state = state or {}

    local mode = setting(context, "stance_mode", "auto")
    -- Manual lock-in modes
    if mode == "battle" then return "battle" end
    if mode == "defensive" then return "defensive" end
    if mode == "berserker" then return "berserker" end
    if mode == "manual" then return nil end

    local hp = state.hp or context.hp or 100
    local rage = state.rage or context.rage or 0
    local stance = state.stance or context.stance or STANCE.BATTLE
    local in_combat = state.in_combat or context.in_combat or false
    local is_pvp = state.is_pvp or context.is_pvp or false

    -- Survival: drop to Defensive Stance when low HP and actively being hit
    if hp < 30 and in_combat then
        return "defensive"
    end

    -- Execute phase requires Berserker Stance in TBC
    local execute_phase = false
    if state.execute_phase ~= nil then
        execute_phase = state.execute_phase
    elseif NS.is_execute_phase then
        execute_phase = NS.is_execute_phase(context.target_hp or state.target_hp or 100, 20)
    elseif (state.target_hp or context.target_hp or 100) <= 20 then
        execute_phase = true
    end

    if execute_phase and rage >= 15 then
        return "berserker"
    end

    -- Arms-specific: Rend and Overpower require Battle Stance
    if state.rend_ready or state.overpower_ready then
        return "battle"
    end

    -- Fury-specific: Bloodthirst and Whirlwind require Berserker Stance
    if state.bt_ready or state.ww_ready then
        return "berserker"
    end

    -- PvP gap closer: Intercept requires Berserker Stance
    if is_pvp then
        local dist = state.target_distance or context.target_distance or 0
        if dist >= 8 and dist <= 25 and (state.intercept_ready or false) then
            return "berserker"
        end
    end

    -- Protection: maintain Defensive Stance as default
    if state.ss_ready or state.revenge_ready then
        if stance ~= STANCE.DEFENSIVE then
            return "defensive"
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Check if a stance switch should actually happen.
-- Respects lockout, rage preservation, and manual overrides.
-- ---------------------------------------------------------------------------
function M.should_switch(context, state, desired_stance)
    if not desired_stance then return false end
    context = context or {}
    state = state or {}

    local stance = state.stance or context.stance or STANCE.BATTLE
    local desired_id = (desired_stance == "battle" and STANCE.BATTLE)
        or (desired_stance == "defensive" and STANCE.DEFENSIVE)
        or (desired_stance == "berserker" and STANCE.BERSERKER)
        or nil

    if not desired_id then return false end
    if stance == desired_id then return false end

    -- Respect stance lockout (cached at module load)
    if _WH.stance_lockout_active and _WH.stance_lockout_active() then return false end

    -- Respect manual mode
    local mode = setting(context, "stance_mode", "auto")
    if mode == "manual" then return false end

    -- Rage preservation: Tactical Mastery cap check
    local rage = state.rage or context.rage or 0
    local cap = 25
    if NS.get_tactical_mastery_cap then
        cap = NS.get_tactical_mastery_cap()
    end
    local preserved = rage < cap and rage or cap

    -- Estimate cost of next ability in desired stance
    local next_cost = 0
    if desired_stance == "battle" then
        if state.rend_ready then next_cost = 10 end
        if state.overpower_ready then next_cost = 5 end
        if state.ms_ready then next_cost = 30 end
    elseif desired_stance == "berserker" then
        if state.execute_ready then next_cost = 15 end
        if state.bt_ready then next_cost = 30 end
        if state.ww_ready then next_cost = 25 end
    elseif desired_stance == "defensive" then
        next_cost = 0
    end

    if preserved < next_cost then
        -- Not enough preserved rage for the ability we'd swap to cast
        -- Allow swap if rage is very low (0-10) since we're not losing much
        if rage > 15 then return false end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Convenience: get stance name from ID
-- ---------------------------------------------------------------------------
function M.stance_name(id)
    if id == STANCE.BATTLE then return "battle" end
    if id == STANCE.DEFENSIVE then return "defensive" end
    if id == STANCE.BERSERKER then return "berserker" end
    return "unknown"
end

-- ---------------------------------------------------------------------------
-- Convenience: get stance ID from name
-- ---------------------------------------------------------------------------
function M.stance_id(name)
    if name == "battle" then return STANCE.BATTLE end
    if name == "defensive" then return STANCE.DEFENSIVE end
    if name == "berserker" then return STANCE.BERSERKER end
    return nil
end

-- module initialized
return M
