-- What: Auto-loot module for EaxAutoQuester — loot window management
-- When: Called from quest_state or main loop after kills / object interaction
-- Why: Centralize loot logic with gold priority, throttle, and nil-guards
-- Safety: All game_ui/input calls pcall-wrapped; static table reuse; 0.5s throttle via utils
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _core_time = core.time
local _core_log = core.log
local _get_loot_item_count = core.game_ui.get_loot_item_count
local _get_loot_item_id = core.game_ui.get_loot_item_id
local _get_loot_item_name = core.game_ui.get_loot_item_name
local _get_loot_is_gold = core.game_ui.get_loot_is_gold
local _loot_item = core.input.loot_item
local _close_loot = core.input.close_loot
local _loot_object = core.input.loot_object
local _get_visible_objects = core.object_manager.get_visible_objects
local _get_local_player = core.object_manager.get_local_player

-- Static table reuse (Pattern 4 from AGENTS.md) — avoids per-frame GC churn
local _t = { n = 0 }
local _gold_indices = { n = 0 }
local _item_indices = { n = 0 }

-- ============================================================================
-- Module Table
-- ============================================================================
local M = {}

-- ============================================================================
-- Internal: utils reference (lazy-loaded)
-- ============================================================================

local _utils = nil

local function ensure_utils()
    if _utils then return true end
    local ok, mod = pcall(require, "utils_sylvanas")
    if ok and mod then
        _utils = mod
        return true
    end
    return false
end

-- ============================================================================
-- try_loot — process currently open loot window
-- ============================================================================

--- Iterate all items in the open loot window.
--- Gold slots are looted first (priority), then item slots.
--- Closes the window when done.
--- @return boolean true if loot window was processed successfully
function M.try_loot()
    local count_ok, count = pcall(_get_loot_item_count)
    if not count_ok or not count or count < 1 then
        return false
    end

    -- Separate gold indices from item indices in a single pass
    _gold_indices.n = 0
    _item_indices.n = 0

    for i = 0, count - 1 do
        local is_gold_ok, is_gold = pcall(_get_loot_is_gold, i)
        if is_gold_ok and is_gold then
            _gold_indices.n = _gold_indices.n + 1
            _gold_indices[_gold_indices.n] = i
        else
            _item_indices.n = _item_indices.n + 1
            _item_indices[_item_indices.n] = i
        end
    end

    -- Loot gold first (priority)
    for j = 1, _gold_indices.n do
        pcall(_loot_item, _gold_indices[j])
    end

    -- Loot items second
    for j = 1, _item_indices.n do
        pcall(_loot_item, _item_indices[j])
    end

    -- Close loot window after processing
    pcall(_close_loot)

    return true
end

-- ============================================================================
-- auto_loot_all — find and loot all nearby lootable objects
-- ============================================================================

--- Scan visible objects in range, open loot window for each, and loot contents.
--- Throttled to 0.5s between cycles via utils.throttle.
--- @param range number|nil Max distance in yards (default: 5). Uses squared distance internally.
--- @return boolean true if at least one lootable object was processed
function M.auto_loot_all(range)
    -- Throttle: 0.5s between full loot cycles
    if not ensure_utils() then return false end
    if not _utils.throttle("loot_cycle", 0.5) then return false end

    local max_range = range or 5
    local max_range_sq = max_range * max_range

    local player_ok, player = pcall(_get_local_player)
    if not player_ok or not player then return false end

    local objects_ok, objects = pcall(_get_visible_objects)
    if not objects_ok or not objects then return false end

    -- Collect lootable objects into static table
    _t.n = 0

    for idx = 1, #objects do
        local obj = objects[idx]
        if obj then
            -- Check if object can be looted
            local can_loot_ok, can_loot = pcall(function() return obj:can_be_looted() end)
            if can_loot_ok and can_loot then
                -- Check distance (squared, no math.sqrt — Pattern 3)
                local pos_ok, pos = pcall(function() return obj:get_position() end)
                if pos_ok and pos then
                    local dx = (pos.x or 0) - (player.x or 0)
                    local dy = (pos.y or 0) - (player.y or 0)
                    local dz = (pos.z or 0) - (player.z or 0)
                    local dist_sq = dx * dx + dy * dy + dz * dz

                    if dist_sq <= max_range_sq then
                        _t.n = _t.n + 1
                        _t[_t.n] = obj
                    end
                end
            end
        end
    end

    if _t.n < 1 then return false end

    -- Process each lootable object
    for j = 1, _t.n do
        local obj = _t[j]
        -- Open loot window via loot_object
        local loot_ok = pcall(_loot_object, obj)
        if loot_ok then
            -- Process the loot window contents
            M.try_loot()
        end
    end

    return _t.n > 0
end

-- ============================================================================
-- close — close loot window if open
-- ============================================================================

--- Close the currently open loot window.
--- Nil-guarded via pcall.
function M.close()
    pcall(_close_loot)
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.loot_manager = M

return M
