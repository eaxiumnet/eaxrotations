-- ts_helper_sylvanas.lua — Shared wrapper for target_selector API module.
-- WHAT:  exposes NS.get_dps_targets and NS.get_heal_targets for specs that want
--        direct target_selector queries instead of relying solely on context fields.
-- WHEN:  loaded by rotation specs during addon load.
-- WHY:   centralizes target_selector access so specs don't repeat nil-guard boilerplate.
-- SAFETY: all functions nil-guard NS.target_selector; return empty table when unavailable.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}

-- Cache the module reference at load time (nil if unavailable in unit tests)
local _ts = NS.target_selector

--- Get DPS targets via target_selector:get_targets(limit).
--- Returns empty table if target_selector is unavailable.
---@param limit number|nil Maximum number of targets (default 10)
---@return table enemies
function M.get_dps_targets(limit)
    if not _ts then return {} end
    if type(_ts.get_targets) ~= "function" then return {} end
    local ok, result = pcall(_ts.get_targets, _ts, limit or 10)
    if not ok or type(result) ~= "table" then return {} end
    return result
end

--- Get heal targets via target_selector:get_targets_heal(limit).
--- Returns empty table if target_selector is unavailable.
---@param limit number|nil Maximum number of targets (default 10)
---@return table allies
function M.get_heal_targets(limit)
    if not _ts then return {} end
    if type(_ts.get_targets_heal) ~= "function" then return {} end
    local ok, result = pcall(_ts.get_targets_heal, _ts, limit or 10)
    if not ok or type(result) ~= "table" then return {} end
    return result
end

NS.TSHelper = M
return M
