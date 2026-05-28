-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/target_lockout_sylvanas.lua"
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
-- Shared Helper: Target Lockout
-- GUID-keyed per-spell lockout to prevent double-casting DoTs/CC to same target
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core.time

-- Lockout storage: { [guid_key] = { [spell_key] = expiry_ms, ... }, ... }
local _locks = {}

-- ============================================================================
-- Internal helpers
-- ============================================================================

--- Builds a composite key from GUID + optional sub-key
---@param guid string Target GUID
---@param key string Spell or action identifier
---@return string Composite key
local function _make_key(guid, key)
    return guid .. "|" .. key
end

--- Converts a unit to a string GUID safely
---@param unit game_object|string|nil
---@return string|nil
local function _safe_guid(unit)
    if type(unit) == "string" then return unit end
    if not unit then return nil end
    local ok, guid = pcall(function() return unit:get_guid() end)
    if ok and guid then
        -- Convert GUID object to string
        local ok2, guid_str = pcall(tostring, guid)
        if ok2 then return guid_str end
    end
    return nil
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Locks a target+spell combination for a duration
---@param unit game_object|string Target or GUID
---@param key string Spell/action identifier (e.g. "immolate", "moonfire")
---@param duration_ms number Lockout duration in milliseconds (default 1500)
---@param now_ms number|nil Current time in milliseconds (default: core.time() * 1000)
function M.lock(unit, key, duration_ms, now_ms)
    if not unit then return end
    local guid = _safe_guid(unit)
    if not guid then return end

    duration_ms = duration_ms or 1500
    now_ms = now_ms or (_core_time() * 1000)

    local composite = _make_key(guid, key)
    _locks[composite] = now_ms + duration_ms
end

--- Checks if a target+spell combination is currently locked
---@param unit game_object|string Target or GUID
---@param key string Spell/action identifier
---@param now_ms number|nil Current time in milliseconds
---@return boolean is_locked
function M.is_locked(unit, key, now_ms)
    if not unit then return false end
    local guid = _safe_guid(unit)
    if not guid then return false end

    now_ms = now_ms or (_core_time() * 1000)

    local composite = _make_key(guid, key)
    local expiry = _locks[composite]
    if not expiry then return false end

    if now_ms >= expiry then
        _locks[composite] = nil
        return false
    end

    return true
end

--- Unlocks a specific target+spell combination immediately
---@param unit game_object|string Target or GUID
---@param key string Spell/action identifier
function M.unlock(unit, key)
    if not unit then return end
    local guid = _safe_guid(unit)
    if not guid then return end

    local composite = _make_key(guid, key)
    _locks[composite] = nil
end

--- Clears all locks for a specific target (e.g. on target death)
---@param unit game_object|string Target or GUID
function M.clear_target(unit)
    if not unit then return end
    local guid = _safe_guid(unit)
    if not guid then return end

    local prefix = guid .. "|"
    for k in pairs(_locks) do
        if k:sub(1, #prefix) == prefix then
            _locks[k] = nil
        end
    end
end

--- Clears all locks (e.g. on combat end)
function M.clear_all()
    _locks = {}
end

--- Removes expired locks to prevent memory growth
---@param now_ms number|nil Current time in milliseconds
function M.prune(now_ms)
    now_ms = now_ms or (_core_time() * 1000)
    for k, expiry in pairs(_locks) do
        if now_ms >= expiry then
            _locks[k] = nil
        end
    end
end

--- Checks if a target is locked for ANY spell action
---@param unit game_object|string Target or GUID
---@return boolean has_any_lock
function M.has_any_lock(unit)
    if not unit then return false end
    local guid = _safe_guid(unit)
    if not guid then return false end

    local prefix = guid .. "|"
    for k in pairs(_locks) do
        if k:sub(1, #prefix) == prefix then
            return true
        end
    end
    return false
end

--- Convenience: lock then check in one call
---@param unit game_object|string Target or GUID
---@param key string Spell/action identifier
---@param duration_ms number Lockout duration in milliseconds
---@param now_ms number|nil Current time in milliseconds
---@return boolean was_locked True if it was already locked (caller should skip)
function M.check_and_lock(unit, key, duration_ms, now_ms)
    if M.is_locked(unit, key, now_ms) then
        return true -- was already locked
    end
    M.lock(unit, key, duration_ms, now_ms)
    return false -- was not locked, now locked
end

-- ============================================================================
-- Export
-- ============================================================================

NS.TargetLockout = M

return M
