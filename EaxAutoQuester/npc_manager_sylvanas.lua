-- What: NPC/object manager — find nearest NPCs, interactable objects, enemies
-- When: Used by quest_state to locate quest givers, turn-in NPCs, kill targets, loot objects
-- Why: Centralize all visible-object scanning with capping, nil-guards, squared distance
-- Safety: All core.object_manager.get_visible_objects() calls nil-guarded via pcall
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _get_visible_objs = core.object_manager.get_visible_objects
local _get_local_player  = core.object_manager.get_local_player
local _core_log          = core.log

-- Static table reuse (Pattern 4 from AGENTS.md)
local _stack = { n = 0 }

-- Lazy-load utils and reader modules at runtime (not module init)
local _utils = nil
local function ensure_utils()
    if not _utils then
        local ok, u = pcall(require, "utils_sylvanas")
        if ok then _utils = u end
    end
    return _utils
end

local _questie_reader = nil
local function ensure_questie()
    if not _questie_reader then
        local ok, q = pcall(require, "questie_reader_sylvanas")
        if ok then _questie_reader = q end
    end
    return _questie_reader
end

local _zygor_reader = nil
local function ensure_zygor()
    if not _zygor_reader then
        local ok, z = pcall(require, "zygor_reader_sylvanas")
        if ok then _zygor_reader = z end
    end
    return _zygor_reader
end

-- Max visible objects to scan per call (performance cap)
local MAX_SCAN = 50

-- ============================================================================
-- Public API
-- ============================================================================

--- Find nearest NPC matching any ID in list, within range.
--- Uses squared distance — no math.sqrt() (Pattern 3 from AGENTS.md).
--- @param ids integer[]|nil NPC ID list to match
--- @param range number|nil Max search yards (default: 50)
--- @return game_object|nil Closest match, or nil
local function find_nearest_npc(ids, range)
    if not ids or #ids == 0 then return nil end
    range = range or 50
    local range_sq = range * range

    local ok, objects = pcall(_get_visible_objs)
    if not ok or not objects or #objects == 0 then return nil end

    local utils = ensure_utils()
    local me = _get_local_player()
    if not me then return nil end
    local _, me_pos = pcall(function() return me:get_position() end)

    -- Cache player name for extra self-exclusion guard
    local _, me_name = pcall(function() return me:get_name() end)
    me_name = me_name and me_name:lower() or nil

    -- Build ID lookup set for O(1) matching
    local id_set = {}
    for i = 1, #ids do
        local id = ids[i]
        if id then id_set[id] = true end
    end

    local best = nil
    local best_dist_sq = range_sq

    local limit = #objects
    if limit > MAX_SCAN then limit = MAX_SCAN end

    for i = 1, limit do
        local obj = objects[i]
        if not obj then break end

        local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
        if unit_ok and is_unit then
            -- Exclude the local player — targeting self causes infinite loops
            local player_ok, is_player = pcall(function() return obj:is_player() end)
            if player_ok and is_player then
                -- skip player (confirmed)
            elseif player_ok and not is_player then
                -- Extra guard: skip if name matches local player
                local name_ok, obj_name = pcall(function() return obj:get_name() end)
                if name_ok and me_name and obj_name and obj_name:lower() == me_name then
                    -- skip self by name
                else
                    -- confirmed NOT player, safe to process
                    local id_ok, npc_id = pcall(function() return obj:get_npc_id() end)
                    if id_ok and npc_id and id_set[npc_id] then
                        local pos_ok, pos = pcall(function() return obj:get_position() end)
                        if pos_ok and pos then
                            local dist_sq = (me_pos and utils) and utils.squared_distance(me_pos, pos) or 0
                            if dist_sq < best_dist_sq then
                                best_dist_sq = dist_sq
                                best = obj
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

--- Find visible objects whose name contains given substring (case-insensitive).
--- @param name_filter string|nil Substring to match
--- @return game_object[]|nil Matching objects, or nil
local function find_interactable_objects(name_filter)
    if not name_filter or name_filter == "" then return nil end

    local ok, objects = pcall(_get_visible_objs)
    if not ok or not objects or #objects == 0 then return nil end

    _stack.n = 0

    local limit = #objects
    if limit > MAX_SCAN then limit = MAX_SCAN end

    local filter_lower = name_filter:lower()

    for i = 1, limit do
        local obj = objects[i]
        if obj then
            local name_ok, name = pcall(function() return obj:get_name() end)
            if name_ok and name then
                local lower_ok, lower_name = pcall(function() return name:lower() end)
                if lower_ok and lower_name then
                    if lower_name:find(filter_lower, 1, true) then
                        _stack.n = _stack.n + 1
                        _stack[_stack.n] = obj
                    end
                end
            end
        end
    end

    if _stack.n == 0 then return nil end

    local result = {}
    for i = 1, _stack.n do
        result[i] = _stack[i]
    end
    return result
end

--- Return unique NPC IDs from both Questie quest NPCs and Zygor current step goals.
--- @return integer[]|nil Array of unique NPC IDs, or nil
local function find_quest_npcs()
    local combined = {}
    local seen = {}

    -- Collect from Questie
    local questie = ensure_questie()
    if questie then
        local ok, ids = pcall(questie.get_quest_npc_ids)
        if ok and ids then
            for i = 1, #ids do
                local id = ids[i]
                if id and not seen[id] then
                    seen[id] = true
                    combined[#combined + 1] = id
                end
            end
        end
    end

    -- Collect from Zygor current step goals
    local zygor = ensure_zygor()
    if zygor then
        local ok, step = pcall(zygor.get_current_step_info)
        if ok and step and step.goals then
            for i = 1, #step.goals do
                local goal = step.goals[i]
                if goal then
                    -- Try npc_id, id, or raw numeric value; skip strings
                    local npc_id = nil
                    if type(goal) == "table" then
                        npc_id = goal.npc_id or goal.id or nil
                    elseif type(goal) == "number" then
                        npc_id = goal
                    end
                    if npc_id and not seen[npc_id] then
                        seen[npc_id] = true
                        combined[#combined + 1] = npc_id
                    end
                end
            end
        end
    end

    if #combined == 0 then return nil end
    return combined
end

--- Find nearest attackable enemy within range.
--- @param range number|nil Max search yards (default: 50)
--- @return game_object|nil Closest enemy, or nil
local function get_nearest_enemy(range)
    range = range or 50
    local range_sq = range * range

    local ok, objects = pcall(_get_visible_objs)
    if not ok or not objects or #objects == 0 then return nil end

    local utils = ensure_utils()
    local me = _get_local_player()
    if not me then return nil end
    local _, me_pos = pcall(function() return me:get_position() end)

    local best = nil
    local best_dist_sq = range_sq

    local limit = #objects
    if limit > MAX_SCAN then limit = MAX_SCAN end

    for i = 1, limit do
        local obj = objects[i]
        if obj then
            local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
            if unit_ok and is_unit then
                -- Exclude player
                local player_ok, is_player = pcall(function() return obj:is_player() end)
                if player_ok and is_player then
                    -- skip player (confirmed)
                elseif player_ok and not is_player then
                    -- confirmed NOT player, safe to process
                    local dead_ok, is_dead = pcall(function() return obj:is_dead() end)
                    if dead_ok and not is_dead then
                        local attack_ok, can_attack = pcall(function() return obj:can_attack(me) end)
                        local enemy_ok, is_enemy   = pcall(function() return obj:is_enemy_with(me) end)
                        if attack_ok and can_attack and enemy_ok and is_enemy then
                        local pos_ok, pos = pcall(function() return obj:get_position() end)
                        if pos_ok and pos then
                            local dist_sq = utils and utils.squared_distance(me, pos) or 0
                            if dist_sq < best_dist_sq then
                                best_dist_sq = dist_sq
                                best = obj
                            end
                        end
                    end
                end
            end
        end
    end
end

    return best
end

--- Find nearest visible unit flagged as a quest unit (is_quest_unit == true).
--- This is the most reliable way to find quest NPCs without relying on
--- Questie/Zygor data or name matching. Uses the game engine's own quest flag.
--- @param range number|nil Max search yards (default 50)
--- @param exclude_dead boolean|nil If true, skip dead units (default true)
--- @return game_object|nil Closest quest unit, or nil
local function find_nearest_quest_unit(range, exclude_dead)
    range = range or 50
    exclude_dead = (exclude_dead ~= false)  -- default true
    local range_sq = range * range

    local ok, objects = pcall(_get_visible_objs)
    if not ok or not objects or #objects == 0 then return nil end

    local utils = ensure_utils()
    local me = _get_local_player()
    if not me then return nil end

    local best = nil
    local best_dist_sq = range_sq

    local limit = #objects
    if limit > MAX_SCAN then limit = MAX_SCAN end

    for i = 1, limit do
        local obj = objects[i]
        if obj then
            local unit_ok, is_unit = pcall(function() return obj:is_unit() end)
            if unit_ok and is_unit then
                -- Exclude player
                local player_ok, is_player = pcall(function() return obj:is_player() end)
                if player_ok and is_player then
                    -- skip player (confirmed)
                elseif player_ok and not is_player then
                    -- confirmed NOT player, safe to process
                    local quest_ok, is_quest = pcall(function() return obj:is_quest_unit() end)
                    if quest_ok and is_quest then
                        if exclude_dead then
                            local dead_ok, is_dead = pcall(function() return obj:is_dead() end)
                            if dead_ok and is_dead then
                                -- skip dead quest unit
                            else
                                local pos_ok, pos = pcall(function() return obj:get_position() end)
                                if pos_ok and pos then
                                    local dist_sq = utils and utils.squared_distance(me, pos) or 0
                                    if dist_sq < best_dist_sq then
                                        best_dist_sq = dist_sq
                                        best = obj
                                    end
                                end
                            end
                        else
                            local pos_ok, pos = pcall(function() return obj:get_position() end)
                            if pos_ok and pos then
                                local dist_sq = utils and utils.squared_distance(me, pos) or 0
                                if dist_sq < best_dist_sq then
                                    best_dist_sq = dist_sq
                                    best = obj
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return best
end

--- Real distance in yards from player to object (uses math.sqrt for final readout).
--- @param obj game_object|nil Target object
--- @return number Yards (0 if obj nil or position unavailable)
local function get_interact_distance(obj)
    if not obj then return 0 end

    local utils = ensure_utils()
    local me = _get_local_player()
    if not me or not utils then return 0 end

    local _, me_pos = pcall(function() return me:get_position() end)
    if not me_pos then return 0 end

    local pos_ok, pos = pcall(function() return obj:get_position() end)
    if not pos_ok or not pos then return 0 end

    return math.sqrt(utils.squared_distance(me_pos, pos))
end

-- ============================================================================
-- Exports
-- ============================================================================

local M = {
    find_nearest_npc          = find_nearest_npc,
    find_interactable_objects = find_interactable_objects,
    find_quest_npcs           = find_quest_npcs,
    find_nearest_quest_unit   = find_nearest_quest_unit,
    get_nearest_enemy         = get_nearest_enemy,
    get_interact_distance     = get_interact_distance,
}

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.npc_manager = M

return M
