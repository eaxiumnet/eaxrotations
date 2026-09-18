-- What: Goal resolver — converts Zygor quest goals into concrete NPC/item/location targets
-- When: Called by quest_state to resolve goal text to actionable data for NAV/DO_ACTION
-- Why: Centralize 6-stage resolution with 60s cache; fix broken Questie stage;
--      add is_quest_unit fast-path; fix Z via waypoint_fixer
-- Safety: All core.* calls wrapped in pcall; nil-guarded goal fields; cache auto-expires on step change
-- Decision: Reads npc_db from _G.EaxAutoQuester.npc_db; Questie via questie_reader module;
--           quest log via core.quests; positions fixed by waypoint_fixer

-- ============================================================================
-- Hot-path API Caching at Module Load (Pattern 2 from AGENTS.md)
-- ============================================================================

local _core_time = core.time
local _inventory_get_items = core.inventory.get_items_in_bag
local _get_quest_log_title = core.quests.get_quest_log_title
local _get_num_quest_log_entries = core.quests.get_num_quest_log_entries

-- ============================================================================
-- Lazy-load submodules
-- ============================================================================

local _questie_reader = nil
local function ensure_questie_reader()
    if _questie_reader then return true end
    local ok, q = pcall(require, "questie_reader_sylvanas")
    if ok and q then _questie_reader = q end
    return _questie_reader ~= nil
end

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
-- Cache State
-- ============================================================================

local _cache = {}
local _last_step_num_cache = nil

-- ============================================================================
-- NPC DB Access — reads from global (set by npc_db_sylvanas.lua at load)
-- ============================================================================

local _npc_db = nil
local function ensure_npc_db()
    if not _npc_db then
        _npc_db = (_G.EaxAutoQuester and _G.EaxAutoQuester.npc_db) or nil
    end
    return _npc_db
end

-- ============================================================================
-- Helpers
-- ============================================================================

--- Fix Z coordinate via waypoint_fixer if available.
local function fix_pos(pos)
    if not pos then return nil end
    if ensure_waypoint_fixer() and _waypoint_fixer.fix_z then
        return _waypoint_fixer.fix_z(pos)
    end
    return pos
end

--- Search inventory by item name substring.
--- @param me table|nil Player unit
--- @param substring string Search term
--- @return table|nil { name, id } or nil if not found
local function search_inventory_by_name(me, substring)
    if not substring or substring == "" then return nil end
    local lower = substring:lower()
    for bag = 0, 4 do
        local ok, items = pcall(_inventory_get_items, bag)
        if ok and items and #items > 0 then
            for i = 1, #items do
                local item = items[i]
                if item and item.name then
                    local item_name_lower = item.name:lower()
                    if item_name_lower:find(lower, 1, true) or lower:find(item_name_lower, 1, true) then
                        return item
                    end
                end
            end
        end
    end
    return nil
end

--- Scan the quest log for a quest whose title contains goal_text.
--- Uses core.quests.get_quest_log_title() which returns {title, level, quest_id, is_header, is_complete}.
--- @param goal_text string
--- @return number|nil quest_id, string|nil title
local function find_quest_id_by_title(goal_text)
    if not goal_text or goal_text == "" then return nil, nil end
    local lower = goal_text:lower()

    local ok_count, count = pcall(_get_num_quest_log_entries)
    if not ok_count or not count or count <= 0 then return nil, nil end

    for idx = 1, count do
        local ok, info = pcall(_get_quest_log_title, idx)
        if ok and info and not info.is_header and info.title then
            if info.title:lower():find(lower, 1, true) then
                return info.quest_id, info.title
            end
        elseif not ok then
            break
        end
    end
    return nil, nil
end

--- Scan visible objects for the nearest quest unit (is_quest_unit == true).
--- @param range number|nil
--- @return table|nil { position, name, npc_id, source="is_quest_unit" }
local function find_nearest_quest_unit_visible(range)
    range = range or 50
    local range_sq = range * range

    local ok_me, me = pcall(core.object_manager.get_local_player)
    if not ok_me or not me then return nil end

    local ok_objs, objects = pcall(core.object_manager.get_visible_objects)
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
                    local dead_ok, is_dead = pcall(function() return obj:is_dead() end)
                    if not (dead_ok and is_dead) then
                        local pos_ok, pos = pcall(function() return obj:get_position() end)
                        if pos_ok and pos and utils then
                            local dist_sq = utils.squared_distance(me, pos)
                            if dist_sq < best_dist_sq then
                                best_dist_sq = dist_sq
                                local name_ok, name = pcall(function() return obj:get_name() end)
                                local id_ok, npc_id = pcall(function() return obj:get_npc_id() end)
                                best = {
                                    position = fix_pos(pos),
                                    name = (name_ok and name) or "Quest Unit",
                                    npc_id = (id_ok and npc_id) or nil,
                                    source = "is_quest_unit",
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================================
-- resolve_goal — 6-stage resolution
-- ============================================================================

--- Resolve a single goal into actionable data.
--- Resolution order (short-circuit on first match):
---   1. Zygor passthrough (goal.npc_id or goal.target_id is positive int)
---   2. NPC DB name lookup
---   3. Inventory item search
---   4a. is_quest_unit visible scan (fast path — no addon needed)
---   4b. Questie quest log location lookup (addon-based, Z-fixed)
---   5. Unresolved (source='unresolved')
---
--- Results are cached by {step_num, text} with 60s TTL.
---
--- @param goal table Zygor goal: fields { npc_id, target_id, text, name }
--- @param current_step_num number|nil Current Zygor step number
--- @param me table|nil Local player unit
--- @return table { npc_id, position, name, item_id, source }
function M_resolve_goal(goal, current_step_num, me)
    if not goal then return { source = "unresolved" } end

    local goal_text = goal.text or goal.name or ""
    local step_num = current_step_num or 0
    local cache_key = tostring(step_num) .. "|" .. tostring(goal_text)

    -- Cache expiry on step_num change
    if _last_step_num_cache ~= nil and _last_step_num_cache ~= step_num then
        _cache = {}
    end
    _last_step_num_cache = step_num

    -- Cache lookup
    local cached = _cache[cache_key]
    if cached then
        local elapsed = _core_time() - cached.time
        if elapsed >= 0 and elapsed < 60 then
            return cached.result
        end
    end

    local result = nil

    -- ============================================================
    -- Stage 1: Zygor passthrough
    -- ============================================================
    local npc_id = goal.npc_id or goal.target_id
    if type(npc_id) == "number" and npc_id > 0 and npc_id == math.floor(npc_id) then
        result = {
            npc_id   = npc_id,
            position = nil,
            name     = goal_text,
            source   = "zyg",
        }
    end

    -- ============================================================
    -- Stage 2: NPC DB name lookup
    -- ============================================================
    if not result then
        local db = ensure_npc_db()
        if db and db.search_npc_by_name and goal_text ~= "" then
            local ok, matches = pcall(db.search_npc_by_name, db, goal_text)
            if ok and matches and #matches > 0 then
                local match = matches[1]
                result = {
                    npc_id   = match.npc_id,
                    position = fix_pos({ x = match.x, y = match.y, z = match.z or 0 }),
                    name     = match.name or goal_text,
                    source   = "npc_db",
                }
            end
        end
    end

    -- ============================================================
    -- Stage 3: Inventory item search
    -- ============================================================
    if not result then
        local item = search_inventory_by_name(me, goal_text)
        if item then
            result = {
                npc_id   = nil,
                position = nil,
                name     = item.name,
                item_id  = item.id,
                source   = "inventory",
            }
        end
    end

    -- ============================================================
    -- Stage 4a: is_quest_unit fast path (no addon needed)
    -- ============================================================
    if not result and goal_text ~= "" then
        local quest_unit = find_nearest_quest_unit_visible(80)
        if quest_unit then
            result = {
                npc_id   = quest_unit.npc_id,
                position = quest_unit.position,
                name     = quest_unit.name,
                source   = "is_quest_unit",
            }
        end
    end

    -- ============================================================
    -- Stage 4b: Questie quest log + location lookup
    -- ============================================================
    if not result and ensure_questie_reader() and goal_text ~= "" then
        local quest_id, title = find_quest_id_by_title(goal_text)
        if quest_id then
            -- Try Questie get_quest_locations first (most reliable)
            local locations = _questie_reader.get_quest_locations(quest_id)
            if locations and #locations > 0 then
                local loc = locations[1]
                result = {
                    npc_id   = loc.npc_id,
                    position = fix_pos({ x = loc.x, y = loc.y, z = loc.z or 0 }),
                    name     = loc.name or title or goal_text,
                    source   = "questie_locations",
                }
            end

            -- Fallback: Questie get_quest_objectives
            if not result then
                local objectives = _questie_reader.get_quest_objectives(quest_id)
                if objectives and #objectives > 0 then
                    local obj = objectives[1]
                    if obj.position then
                        result = {
                            npc_id   = nil,
                            position = fix_pos(obj.position),
                            name     = title or goal_text,
                            source   = "questie_objectives",
                        }
                    end
                end
            end
        end
    end

    -- ============================================================
    -- Stage 5: Unresolved
    -- ============================================================
    if not result then
        result = { source = "unresolved" }
    end

    -- Cache and return
    _cache[cache_key] = { result = result, time = _core_time() }
    return result
end

-- ============================================================================
-- Exports
-- ============================================================================

local M = {
    resolve_goal = M_resolve_goal,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.goal_resolver = M

return M
