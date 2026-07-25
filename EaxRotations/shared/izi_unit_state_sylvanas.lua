-- izi_unit_state_sylvanas.lua — IZI SDK unit state helpers (CC, immunity, combat time, totem info).
-- WHAT:  thin wrappers around IZI SDK game_object methods with feature-detection + pcall safety.
-- WHEN:  called by spec files that need CC awareness, immunity checks, or combat timing.
-- WHY:   centralizes IZI SDK feature-detection pattern so specs don't each re-implement it.
-- SAFETY: every method type-checks + pcalls; returns safe defaults when SDK unavailable.

local M = {}

--- Check if a unit is currently crowd-controlled (stunned, feared, incapped, etc.)
--- Uses IZI SDK is_cc() when available.
---@param unit game_object
---@return boolean
function M.is_cc(unit)
    if not unit then return false end
    if type(unit.is_cc) == "function" then
        local ok, result = pcall(unit.is_cc, unit)
        if ok and result then return true end
    end
    return false
end

--- Check if a unit is stunned.
---@param unit game_object
---@return boolean
function M.is_stunned(unit)
    if not unit then return false end
    if type(unit.is_stunned) == "function" then
        local ok, result = pcall(unit.is_stunned, unit)
        if ok and result then return true end
    end
    return false
end

--- Check if a unit is feared.
---@param unit game_object
---@return boolean
function M.is_feared(unit)
    if not unit then return false end
    if type(unit.is_feared) == "function" then
        local ok, result = pcall(unit.is_feared, unit)
        if ok and result then return true end
    end
    return false
end

--- Check if a unit is silenced.
---@param unit game_object
---@return boolean
function M.is_silenced(unit)
    if not unit then return false end
    if type(unit.is_silenced) == "function" then
        local ok, result = pcall(unit.is_silenced, unit)
        if ok and result then return true end
    end
    return false
end

--- Check if a unit is damage-immune (Divine Shield, Ice Block, etc.)
--- Uses IZI SDK is_damage_immune() when available.
---@param unit game_object
---@return boolean
function M.is_damage_immune(unit)
    if not unit then return false end
    if type(unit.is_damage_immune) == "function" then
        local ok, result = pcall(unit.is_damage_immune, unit)
        if ok and result then return true end
    end
    return false
end

--- Get global time-to-die (entire pull, not per-unit).
--- Uses IZI SDK get_time_to_die_global() when available.
---@return number|nil ttd_seconds, or nil if unavailable
function M.get_time_to_die_global()
    local izi = nil
    local ok_izi, mod = pcall(require, "common/izi_sdk")
    if ok_izi and type(mod) == "table" then izi = mod end
    if izi and type(izi.get_time_to_die_global) == "function" then
        local ok, ttd = pcall(izi.get_time_to_die_global)
        if ok and type(ttd) == "number" then return ttd end
    end
    return nil
end

--- Get time in combat for a unit (seconds since combat started).
--- Uses IZI SDK time_in_combat() when available.
---@param unit game_object
---@return number seconds (0 if unavailable)
function M.time_in_combat(unit)
    if not unit then return 0 end
    if type(unit.time_in_combat) == "function" then
        local ok, t = pcall(unit.time_in_combat, unit)
        if ok and type(t) == "number" then return t end
    end
    return 0
end

--- Get combo points via IZI SDK (unit:combo_points_current()).
--- Falls back to nil if unavailable (caller should use context.combo_points).
---@param unit game_object
---@return number|nil
function M.combo_points_current(unit)
    if not unit then return nil end
    if type(unit.combo_points_current) == "function" then
        local ok, cp = pcall(unit.combo_points_current, unit)
        if ok and type(cp) == "number" then return cp end
    end
    return nil
end

--- Get totem info for a slot (1=fire, 2=earth, 3=water, 4=air) via IZI SDK.
--- Returns (active, name, start_time, duration) or (false, nil, 0, 0).
---@param unit game_object
---@param slot number 1-4
---@return boolean active
---@return string|nil name
---@return number start_time
---@return number duration
function M.get_totem_info(unit, slot)
    if not unit then return false, nil, 0, 0 end
    if type(unit.get_totem_info) == "function" then
        local ok, active, name, start, dur = pcall(unit.get_totem_info, unit, slot)
        if ok then
            return active or false, name, start or 0, dur or 0
        end
    end
    return false, nil, 0, 0
end

--- Calculate totem remaining time from IZI SDK get_totem_info on a unit.
--- Returns seconds remaining, or 0 if no totem / unavailable.
---@param unit game_object
---@param slot number 1-4
---@return number remaining_seconds
function M.totem_remaining(unit, slot)
    local active, _, start, dur = M.get_totem_info(unit, slot)
    if not active or dur <= 0 then return 0 end
    local now = 0
    local NS = _G.EaxRotations
    if NS and NS.game_time then
        now = NS.game_time() or 0
    elseif NS and NS.game_time_ms then
        now = (NS.game_time_ms() or 0) / 1000
    end
    local elapsed = now - start
    local remaining = dur - elapsed
    return remaining > 0 and remaining or 0
end

return M
