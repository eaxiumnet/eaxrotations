-- What: Questie reader — full Questie addon API surface for EaxAutoQuester
-- When: Polled by quest_state, goal_resolver, and npc_manager each tick
-- Why: Centralize ALL Questie data access; fix Z coords via waypoint_fixer;
--      add is_quest_unit scanning for quest-related NPC detection
-- Safety: All core.addons.questie.* calls pcall-guarded; nil-safe returns;
--         positions fixed via waypoint_fixer before returning
-- Decision: Replaces old minimal reader; backward-compatible exports kept

-- Dynamic resolution — not cached, resolves each call (Questie may load after this module)

local _core_time = core.time
local _is_loaded = core.addons.questie.is_loaded
local _get_quest_npc_ids = core.addons.questie.get_quest_npc_ids
local _get_quest_objectives = core.addons.questie.get_quest_objectives
local _get_quest_locations = core.addons.questie.get_quest_locations
local _get_visible_objs = core.object_manager.get_visible_objects

-- ============================================================================
-- Lazy-load waypoint_fixer and utils
-- ============================================================================

local _waypoint_fixer = nil
local function ensure_waypoint_fixer()
    if _waypoint_fixer then return true end
    local ok, w = pcall(require, "waypoint_fixer_sylvanas")
    if ok and w then _waypoint_fixer = w end
    return _waypoint_fixer ~= nil
end

local _utils = nil
local function ensure_utils()
    if _utils then return true end
    local ok, u = pcall(require, "utils_sylvanas")
    if ok then _utils = u end
    return _utils ~= nil
end

-- ============================================================================
-- Static Table Reuse (Pattern 4 from AGENTS.md)
-- ============================================================================

local _stack = { n = 0 }

-- ============================================================================
-- Helpers
-- ============================================================================

local function questie_loaded()
    local ok, loaded = pcall(function() return core.addons.questie.is_loaded() end)
    return ok and loaded == true
end

--- Fix Z coordinate on a position if waypoint_fixer is available.
--- @param pos table|nil { x, y, z }
--- @return table|nil
local function fix_pos(pos)
    if not pos then return nil end
    if ensure_waypoint_fixer() and _waypoint_fixer.fix_z then
        return _waypoint_fixer.fix_z(pos)
    end
    return pos
end

--- Fix Z on all positions in an array.
--- @param positions table[]|nil
--- @return table[]|nil
local function fix_positions(positions)
    if not positions or #positions == 0 then return positions end
    if ensure_waypoint_fixer() and _waypoint_fixer.fix_positions then
        return _waypoint_fixer.fix_positions(positions)
    end
    return positions
end

-- ============================================================================
-- Public API — Backward-compatible + new functions
-- ============================================================================

--- Get raw quest NPC IDs from Questie (no position scan).
--- @return integer[]|nil Array of NPC IDs or nil if Questie not loaded
function M_get_quest_npc_ids()
    if not questie_loaded() then return nil end
    local ok, ids = pcall(_get_quest_npc_ids)
    if not ok or not ids or #ids == 0 then return nil end
    local result = {}
    for i = 1, #ids do result[i] = ids[i] end
    return result
end

--- Get positions of visible quest-relevant NPCs from Questie.
--- Cached with 2s throttle.
--- @return table[]|nil Array of { npc_id, name, position } or nil
function M_get_quest_npc_positions()
    if not questie_loaded() then return nil end

    local utils = ensure_utils()
    if utils and not utils.throttle("questie_npc_positions", 2.0) then
        return nil
    end

    local ok, npc_ids = pcall(_get_quest_npc_ids)
    if not ok or not npc_ids or #npc_ids == 0 then return nil end

    local id_set = {}
    for i = 1, #npc_ids do
        local id = npc_ids[i]
        if id then id_set[id] = true end
    end

    local ok2, objects = pcall(_get_visible_objs)
    if not ok2 or not objects or #objects == 0 then return nil end

    _stack.n = 0
    for i = 1, #objects do
        local obj = objects[i]
        if obj then
            local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
            if unit_ok and is_unit then
                local id_ok, npc_id = pcall(function() return obj:get_npc_id() end)
                if id_ok and npc_id and id_set[npc_id] then
                    local name_ok, name = pcall(function() return obj:get_name() end)
                    local pos_ok, pos = pcall(function() return obj:get_position() end)
                    if pos_ok and pos then
                        _stack.n = _stack.n + 1
                        _stack[_stack.n] = {
                            npc_id = npc_id,
                            name = (name_ok and name) or "Unknown",
                            position = fix_pos(pos),
                        }
                    end
                end
            end
        end
    end

    if _stack.n == 0 then return nil end
    local result = {}
    for i = 1, _stack.n do result[i] = _stack[i] end
    return result
end

--- NEW: Get quest objectives from Questie for a specific quest ID.
--- Returns objective data with world positions (Z fixed via waypoint_fixer).
--- @param quest_id number
--- @return table[]|nil Array of objective info tables or nil
function M_get_quest_objectives(quest_id)
    if not questie_loaded() then return nil end
    if not quest_id then return nil end

    local ok, objectives = pcall(_get_quest_objectives, quest_id)
    if not ok or not objectives or #objectives == 0 then return nil end

    local result = {}
    for i = 1, #objectives do
        local o = objectives[i]
        if o then
            result[i] = {
                text = o.text,
                type = o.type,
                finished = o.finished,
                num_required = o.num_required,
                num_fulfilled = o.num_fulfilled,
                position = fix_pos(o.position),
            }
        end
    end
    return result
end

--- NEW: Get quest locations from Questie for a specific quest ID.
--- Returns NPC/object spawn locations with world positions (Z fixed).
--- @param quest_id number
--- @return table[]|nil Array of { x, y, z, map_id, name, npc_id } or nil
function M_get_quest_locations(quest_id)
    if not questie_loaded() then return nil end
    if not quest_id then return nil end

    local ok, locations = pcall(_get_quest_locations, quest_id)
    if not ok or not locations or #locations == 0 then return nil end

    local result = {}
    for i = 1, #locations do
        local loc = locations[i]
        if loc then
            result[i] = {
                x = loc.x or 0,
                y = loc.y or 0,
                z = (loc.z and loc.z ~= 0 and loc.z) or (fix_pos(loc) and fix_pos(loc).z) or 0,
                map_id = loc.map_id,
                name = loc.name,
                npc_id = loc.npc_id,
            }
        end
    end
    return result
end

--- NEW: Find the nearest visible unit that is flagged as a quest unit.
--- Uses game_object:is_quest_unit() — much more reliable than name matching.
--- @param range number|nil Max search yards (default 50)
--- @return game_object|nil Nearest quest unit, or nil
function M_find_nearest_quest_unit(range)
    range = range or 50
    local range_sq = range * range

    local ok_me, me = pcall(core.object_manager.get_local_player)
    if not ok_me or not me then return nil end

    local ok_objs, objects = pcall(_get_visible_objs)
    if not ok_objs or not objects or #objects == 0 then return nil end

    local utils = ensure_utils()
    local best = nil
    local best_dist_sq = range_sq

    local limit = #objects > 50 and 50 or #objects
    for i = 1, limit do
        local obj = objects[i]
        if obj then
            local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
            if unit_ok and is_unit then
                local quest_ok, is_quest = pcall(function() return obj:is_quest_unit() end)
                if quest_ok and is_quest then
                    local pos_ok, pos = pcall(function() return obj:get_position() end)
                    if pos_ok and pos and utils then
                        local dist_sq = utils.squared_distance(me, pos)
                        if dist_sq < best_dist_sq then
                            best_dist_sq = dist_sq
                            best = obj
                        end
                    end
                end
            end
        end
    end

    return best
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
    get_quest_objectives    = M_get_quest_objectives,
    get_quest_locations     = M_get_quest_locations,
    find_nearest_quest_unit = M_find_nearest_quest_unit,
    is_loaded               = M_is_loaded,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.questie_reader = M

return M
