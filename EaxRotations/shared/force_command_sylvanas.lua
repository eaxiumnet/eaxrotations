-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/force_command_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- Shared Helper: Force Command System
-- ============================================================================
-- Pattern: Control-panel keybinds (not slash commands) that set timed flags.
-- When active, middleware checks bypass normal `matches()` checks.
--
-- Usage:
--   local force = require("shared/force_command_sylvanas")
--   force.activate("burst") -- Force burst for 3 seconds
--   force.activate("defensive") -- Force defensive for 5 seconds
--   force.activate("gap") -- Force gap-closer for 3 seconds
--
-- In middleware:
--   if force.is_active("burst") then
--     -- bypass normal checks and cast burst
--   end
-- ============================================================================

local M = {}

-- Command windows (seconds)
local COMMAND_WINDOWS = {
    burst = 3,
    defensive = 5,
    gap = 3,
}

-- Active command state: { command_name = expiration_time }
local active_commands = {}

--- Activate a force command for its configured duration.
-- @param command string - "burst", "defensive", or "gap"
-- @return boolean - true if activated, false if invalid command
function M.activate(command)
    if not COMMAND_WINDOWS[command] then
        return false
    end
    -- Use core.time() via NS when available, fallback to os.time for standalone
    local now = (_G.EaxRotations and _G.EaxRotations.time_now and _G.EaxRotations.time_now()) or os.time()
    active_commands[command] = now + COMMAND_WINDOWS[command]
    return true
end

--- Check if a force command is currently active.
-- @param command string - "burst", "defensive", or "gap"
-- @return boolean - true if active and not expired
function M.is_active(command)
    local expiration = active_commands[command]
    if not expiration then
        return false
    end
    local now = (_G.EaxRotations and _G.EaxRotations.time_now and _G.EaxRotations.time_now()) or os.time()
    if now > expiration then
        -- Clear expired command
        active_commands[command] = nil
        return false
    end
    return true
end

--- Get remaining time for an active command.
-- @param command string - "burst", "defensive", or "gap"
-- @return number|nil - seconds remaining, or nil if not active
function M.get_remaining(command)
    local expiration = active_commands[command]
    if not expiration then
        return nil
    end
    local now = (_G.EaxRotations and _G.EaxRotations.time_now and _G.EaxRotations.time_now()) or os.time()
    local remaining = expiration - now
    if remaining <= 0 then
        active_commands[command] = nil
        return nil
    end
    return remaining
end

--- Clear all active commands (e.g., on combat end).
function M.clear_all()
    active_commands = {}
end

--- Get list of currently active commands.
-- @return table - array of active command names
function M.get_active_commands()
    local result = {}
    local now = (_G.EaxRotations and _G.EaxRotations.time_now and _G.EaxRotations.time_now()) or os.time()
    for command, expiration in pairs(active_commands) do
        if now <= expiration then
            table.insert(result, command)
        else
            active_commands[command] = nil
        end
    end
    return result
end

-- Register with EaxRotations namespace if available
if _G.EaxRotations then
    _G.EaxRotations.ForceCommand = M
    _G.EaxRotations.force_burst_active = function()
        return M.is_active("burst")
    end
    _G.EaxRotations.force_defensive_active = function()
        return M.is_active("defensive")
    end
    _G.EaxRotations.force_gap_active = function()
        return M.is_active("gap")
    end
end

return M
