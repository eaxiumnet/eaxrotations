-- mount_manager_sylvanas.lua — Auto-mount/dismount for EaxAutoQuester
-- WHAT:  Mounts the player when traveling long distances (>50yd), dismounts
--        when arriving (<15yd). Only mounts when not in combat.
-- WHEN:  NAV state and idle state (before starting nav).
-- WHY:   Eliminates slow ground walking between distant quest objectives.
-- SAFETY: pcall on all API calls; nil-guard on mount_info; distance checks
--         use squared yards (no math.sqrt in hot path).

local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local MOUNT_DISTANCE_SQ = 2500    -- 50 yards squared
local DISMOUNT_DISTANCE_SQ = 225  -- 15 yards squared
local MOUNT_COOLDOWN = 3.0        -- seconds between mount attempts

-- ============================================================================
-- State
-- ============================================================================

local _last_mount_attempt = 0
local _cached_mount_index = nil   -- cache first usable mount

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check if player is currently mounted.
-- @param me game_object|nil
-- @return boolean
local function is_mounted(me)
    if not me then return false end
    local ok, mounted = pcall(function() return me:is_mounted() end)
    return ok and mounted == true
end

--- Check if player is in combat.
-- @param me game_object|nil
-- @return boolean
local function is_in_combat(me)
    if not me then return false end
    local ok, combat = pcall(function() return me:is_in_combat() end)
    return ok and combat == true
end

--- Find the first usable mount index.
-- @return number|nil
local function find_usable_mount()
    if _cached_mount_index then return _cached_mount_index end

    local ok, count = pcall(core.spell_book.get_mount_count)
    if not ok or not count or count < 1 then return nil end

    for i = 1, count do
        local ok2, info = pcall(core.spell_book.get_mount_info, i)
        if ok2 and info and info.is_usable then
            _cached_mount_index = i
            return i
        end
    end
    return nil
end

--- Get squared distance between player and destination.
-- @param me game_object
-- @param dest table {x,y,z}
-- @return number|nil
local function dist_sq_to_dest(me, dest)
    if not me or not dest then return nil end
    local ok, pos = pcall(function() return me:get_position() end)
    if not ok or not pos then return nil end
    local dx = (pos.x or 0) - (dest.x or 0)
    local dy = (pos.y or 0) - (dest.y or 0)
    local dz = (pos.z or 0) - (dest.z or 0)
    return dx*dx + dy*dy + dz*dz
end

-- ============================================================================
-- Core Logic
-- ============================================================================

--- Attempt to mount if conditions are met.
-- @param me game_object
-- @param dest table|nil {x,y,z} destination position
-- @return boolean True if mount was attempted.
function M.try_mount(me, dest)
    if not me then return false end
    if is_mounted(me) then return false end
    if is_in_combat(me) then return false end

    -- Distance check
    if dest then
        local d_sq = dist_sq_to_dest(me, dest)
        if not d_sq or d_sq < MOUNT_DISTANCE_SQ then return false end
    end

    -- Throttle
    local now = core.time()
    if now - _last_mount_attempt < MOUNT_COOLDOWN then return false end
    _last_mount_attempt = now

    local mount_idx = find_usable_mount()
    if not mount_idx then return false end

    local ok = pcall(function() core.input.mount(mount_idx) end)
    if ok and core.log then
        core.log("[EaxAutoQuester] Mounting up")
    end
    return ok
end

--- Dismount if close to destination or explicitly requested.
-- @param me game_object
-- @param dest table|nil {x,y,z}
-- @param force boolean|nil Always dismount if true.
-- @return boolean True if dismount was attempted.
function M.try_dismount(me, dest, force)
    if not me then return false end
    if not is_mounted(me) then return false end

    if force then
        pcall(function() core.input.dismount() end)
        return true
    end

    if dest then
        local d_sq = dist_sq_to_dest(me, dest)
        if d_sq and d_sq <= DISMOUNT_DISTANCE_SQ then
            pcall(function() core.input.dismount() end)
            if core.log then
                core.log("[EaxAutoQuester] Dismounting — close to destination")
            end
            return true
        end
    end

    return false
end

--- Full update: mount if far, dismount if close.
-- Call every tick while navigating.
-- @param me game_object
-- @param dest table|nil {x,y,z}
-- @return string|nil "mounted", "dismounted", or nil.
function M.update(me, dest)
    if not me then return nil end

    if M.try_dismount(me, dest) then
        return "dismounted"
    end

    if M.try_mount(me, dest) then
        return "mounted"
    end

    return nil
end

--- Reset cached mount index (call on spec/class change).
function M.invalidate_cache()
    _cached_mount_index = nil
end

--- Reset all internal state (for testing).
function M.reset()
    _cached_mount_index = nil
    _last_mount_attempt = 0
end

return M
