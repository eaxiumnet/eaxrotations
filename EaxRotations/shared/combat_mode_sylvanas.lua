-- combat_mode_sylvanas.lua — Force Single Target, AoE, or Auto-detect mode.
-- WHAT:  Allows users to override rotation behavior between ST, AoE, and Auto.
-- WHEN:  All DPS and tank specs that have AoE abilities.
-- WHY:   Users want control — e.g. "force ST on boss even with adds nearby".
-- SAFETY: Setting is nil-guarded; auto mode falls back to existing enemy count
-- DECISION: Single Target / AoE / Auto override; pure setting-driven gate.
--         logic; no state mutation, pure read-only helper.
-- Decision: Shared module because 20+ specs need the same 3-state logic.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local type = type

local M = {}
NS.CombatMode = M

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
M.MODE_AUTO = 1
M.MODE_SINGLE = 2
M.MODE_AOE = 3

local MODE_NAMES = {
    [M.MODE_AUTO] = "Auto",
    [M.MODE_SINGLE] = "Single Target",
    [M.MODE_AOE] = "AoE",
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Get the effective combat mode from settings.
-- @param settings  table|nil  Context settings (combat_mode)
-- @return number  1=Auto, 2=Single Target, 3=AoE
function M.get_mode(settings)
    settings = settings or (NS.settings or {})
    local mode = settings.combat_mode
    if type(mode) ~= "number" then
        -- Fallback: string values from dropdown schemas
        if mode == "single" then return M.MODE_SINGLE end
        if mode == "aoe" then return M.MODE_AOE end
        return M.MODE_AUTO
    end
    if mode < 1 or mode > 3 then return M.MODE_AUTO end
    return mode
end

--- Determine if AoE rotation should be active.
-- @param settings     table|nil
-- @param enemy_count  number   Current enemy count from context
-- @param threshold    number   AoE threshold (default 3)
-- @return boolean     true if AoE mode is active
function M.is_aoe(settings, enemy_count, threshold)
    local mode = M.get_mode(settings)
    if mode == M.MODE_AOE then
        return true
    end
    if mode == M.MODE_SINGLE then
        return false
    end
    -- Auto mode: use existing enemy count logic
    enemy_count = type(enemy_count) == "number" and enemy_count or 0
    threshold = type(threshold) == "number" and threshold or 3
    return enemy_count >= threshold
end

--- Determine if Single Target rotation should be active.
-- @param settings     table|nil
-- @param enemy_count  number
-- @param threshold    number
-- @return boolean
function M.is_single_target(settings, enemy_count, threshold)
    return not M.is_aoe(settings, enemy_count, threshold)
end

--- Get human-readable mode name for logging.
-- @param settings  table|nil
-- @return string
function M.mode_name(settings)
    local mode = M.get_mode(settings)
    return MODE_NAMES[mode] or "Auto"
end

if NS.log then NS.log("CombatMode module loaded") end
return M
