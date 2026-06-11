-- What: Questie reader — quest NPC positions from Questie addon data
-- When: Polled by quest_state.lua each tick when Questie is active
-- Why: Centralize Questie data access with nil-guards; resolve NPC IDs to in-world positions
-- Safety: All core.addons.questie.* calls nil-guarded via pcall; returns empty if Questie not loaded
-- Decision: Uses core.addons.questie.* API per core.lua docs; scans visible objects for position data

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _is_loaded        = core.addons.questie.is_loaded
local _get_quest_npc_ids = core.addons.questie.get_quest_npc_ids
local _get_visible_objs  = core.object_manager.get_visible_objects

-- Lazy-load utils for throttle (loaded at runtime, not at module init)
local _utils = nil
local function ensure_utils()
    if not _utils then
        local ok, u = pcall(require, "utils_sylvanas")
        if ok then _utils = u end
    end
    return _utils
end

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _stack = { n = 0 }

-- ============================================================================
-- Helpers
-- ============================================================================

--- Check if Questie addon is loaded (nil-guarded).
--- @return boolean true if Questie is loaded
local function questie_loaded()
    local ok, loaded = pcall(_is_loaded)
    return ok and loaded == true
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get positions of all quest-relevant NPCs from Questie.
--- Scans visible objects matching Questie's quest NPC IDs.
--- Cached with 2s throttle — returns stale data within throttle window.
--- @return table[]|nil Array of { npc_id, name, position } or nil if no data
function M_get_quest_npc_positions()
    -- Nil-guard: Questie must be loaded
    if not questie_loaded() then return nil end

    -- 2s throttle on cache refresh
    local utils = ensure_utils()
    if utils and not utils.throttle("questie_npc_positions", 2.0) then
        -- Still within throttle window — caller should use cached data
        -- Return nil to signal caller to use last known positions
        return nil
    end

    -- Nil-guard: get quest NPC IDs from Questie
    local ok, npc_ids = pcall(_get_quest_npc_ids)
    if not ok or not npc_ids or #npc_ids == 0 then return nil end

    -- Build lookup set for O(1) matching
    local id_set = {}
    for i = 1, #npc_ids do
        local id = npc_ids[i]
        if id then id_set[id] = true end
    end

    -- Scan visible objects for matching NPCs
    local ok2, objects = pcall(_get_visible_objs)
    if not ok2 or not objects or #objects == 0 then return nil end

    _stack.n = 0

    for i = 1, #objects do
        local obj = objects[i]
        if obj and obj.is_unit then
            -- Only process units (NPCs, not items or game objects)
            local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
            if unit_ok and is_unit then
                local id_ok, npc_id = pcall(function() return obj:get_npc_id() end)
                if id_ok and npc_id and id_set[npc_id] then
                    local name_ok, name = pcall(function() return obj:get_name() end)
                    local pos_ok, pos = pcall(function() return obj:get_position() end)

                    if pos_ok and pos then
                        _stack.n = _stack.n + 1
                        _stack[_stack.n] = {
                            npc_id   = npc_id,
                            name     = (name_ok and name) or "Unknown",
                            position = pos,
                        }
                    end
                end
            end
        end
    end

    if _stack.n == 0 then return nil end

    -- Copy results out of static table
    local result = {}
    for i = 1, _stack.n do
        result[i] = _stack[i]
    end
    return result
end

--- Get raw quest NPC IDs from Questie (no position scan).
--- @return integer[]|nil Array of NPC IDs or nil if Questie not loaded
function M_get_quest_npc_ids()
    if not questie_loaded() then return nil end

    local ok, ids = pcall(_get_quest_npc_ids)
    if not ok or not ids or #ids == 0 then return nil end

    local result = {}
    for i = 1, #ids do
        result[i] = ids[i]
    end
    return result
end

--- Check if Questie addon itself is loaded.
--- @return boolean
function M_is_loaded()
    return questie_loaded()
end

-- ============================================================================
-- Exports
-- ============================================================================

local M = {
    get_quest_npc_positions = M_get_quest_npc_positions,
    get_quest_npc_ids       = M_get_quest_npc_ids,
    is_loaded               = M_is_loaded,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.questie_reader = M

return M
