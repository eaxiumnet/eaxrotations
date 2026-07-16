-- health_pred_helper_sylvanas.lua — Shared wrapper for health_prediction API module.
-- WHAT:  exposes NS.incoming_damage / NS.predicted_hp_pct / NS.is_tank_role for healer specs.
-- WHEN:  loaded by healer spec files (holy, discipline, restoration) during addon load.
-- WHY:   centralizes health_prediction access so specs don't repeat nil-guard boilerplate.
-- SAFETY: all functions nil-guard NS.health_prediction; return safe defaults when unavailable.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- Lazy resolve: main_sylvanas may assign NS.health_prediction after other modules
-- load in tests; always prefer the live NS reference.
local function hp_mod()
    return NS.health_prediction
end

--- Get incoming damage for a unit within a deadline (seconds).
--- Returns 0 if health_prediction is unavailable or unit is nil.
---@param unit game_object|nil Target unit
---@param deadline number|nil Seconds to look ahead (default 3.0)
---@return number incoming_damage
function M.incoming_damage(unit, deadline)
    local _hp = hp_mod()
    if not unit or not _hp then return 0 end
    if type(_hp.get_incoming_damage) ~= "function" then return 0 end
    local ok, dmg = pcall(_hp.get_incoming_damage, _hp, unit, deadline or 3.0)
    if not ok or type(dmg) ~= "number" then return 0 end
    return dmg
end

--- Predict the future HP percentage of a unit after incoming damage.
--- Returns current HP percentage if health_prediction is unavailable.
---@param unit game_object|nil Target unit
---@param deadline number|nil Seconds to look ahead (default 3.0)
---@return number predicted_hp_pct (0-100)
function M.predicted_hp_pct(unit, deadline)
    if not unit then return 100 end
    local hp_pct = 100
    if type(unit.get_health_percentage) == "function" then
        local ok, pct = pcall(unit.get_health_percentage, unit)
        if ok and type(pct) == "number" then hp_pct = pct end
    elseif type(unit.get_health) == "function" and type(unit.get_max_health) == "function" then
        local ok_h, h = pcall(unit.get_health, unit)
        local ok_mh, mh = pcall(unit.get_max_health, unit)
        if ok_h and ok_mh and mh and mh > 0 then hp_pct = (h / mh) * 100 end
    end
    if not hp_mod() then return hp_pct end
    local dmg = M.incoming_damage(unit, deadline)
    if dmg <= 0 then return hp_pct end
    local max_hp = 100
    if type(unit.get_max_health) == "function" then
        local ok, mh = pcall(unit.get_max_health, unit)
        if ok and mh and mh > 0 then max_hp = mh end
    end
    local future_hp = hp_pct - (dmg / max_hp * 100)
    if future_hp < 0 then future_hp = 0 end
    return future_hp
end

--- Check if a unit is a tank via health_prediction role detection.
--- Falls back to NS.unit_is_tank if health_prediction is unavailable.
---@param unit game_object|nil Target unit
---@return boolean is_tank
function M.is_tank_role(unit)
    if not unit then return false end
    local _hp = hp_mod()
    if _hp and type(_hp.is_tank) == "function" then
        local ok, result = pcall(_hp.is_tank, _hp, unit)
        if ok then return result == true end
    end
    if NS.unit_is_tank then return NS.unit_is_tank(unit) == true end
    return false
end

--- Get damage types (physical/magical) incoming on a unit.
--- Returns empty table if unavailable.
---@param unit game_object|nil Target unit
---@param deadline number|nil Seconds to look ahead (default 3.0)
---@return table { physical_damage = number[], magical_damage = number[] }
function M.get_damage_types(unit, deadline)
    local _hp = hp_mod()
    if not unit or not _hp then return { physical_damage = {}, magical_damage = {} } end
    if type(_hp.get_damage_types) ~= "function" then return { physical_damage = {}, magical_damage = {} } end
    local ok, result = pcall(_hp.get_damage_types, _hp, unit, deadline or 3.0)
    if not ok or type(result) ~= "table" then return { physical_damage = {}, magical_damage = {} } end
    return result
end

-- Canonical table + flat NS aliases (per integrate-advanced-modules plan Phase 2).
NS.HealthPredHelper = M
NS.incoming_damage = M.incoming_damage
NS.predicted_hp_pct = M.predicted_hp_pct
NS.is_tank_role = M.is_tank_role

return M
