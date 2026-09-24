-- What: Quest item usage — scan inventory, match active goals, and use concrete item IDs.
-- When: Called from do_action_state when the existing goal text selects an item.
-- Why: The goal has no documented item ID, so the existing text fallback stays ordered;
--        the selected inventory object's get_item_id() is the only use identity.
-- Safety: Invalid inventory identities are skipped; calls are pcall-guarded; 3s cooldown.
-- Decision: Only a documented true return from use_item* counts as successful use.

-- ============================================================================
-- API Caching at Module Load (Pattern 2)
-- ============================================================================

local _core_time = core.time
local _core_log = core.log
local _get_items_in_bag = core.inventory.get_items_in_bag

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {}

-- ============================================================================
-- Usage cooldowns: item_id -> last_use_time
-- ============================================================================

local _cooldowns = {}
local _USE_COOLDOWN = 3.0

-- Bag rows do not carry an item ID. Read the name and concrete identity from the
-- object the client placed in the row, and reject a missing/non-positive client ID.
local function read_inventory_item(row)
    if not row or not row.object then return nil end

    local name_ok, name = pcall(function() return row.object:get_name() end)
    local id_ok, item_id = pcall(function() return row.object:get_item_id() end)
    if not name_ok or not id_ok or type(name) ~= "string" or name == "" then return nil end
    if type(item_id) ~= "number" or item_id <= 0 then return nil end

    return name, item_id
end

-- ============================================================================
-- Inventory Scan
-- ============================================================================

--- Scan all bags for items whose name contains the given substring.
--- @param substring string Name substring to match (case-insensitive)
--- @return table[]|nil Array of { bag_id, slot_id, item_id, name, object } or nil
function M.find_items_by_name(substring)
    if not substring or substring == "" then return nil end
    local lower = substring:lower()
    local results = {}

    for bag = 0, 4 do
        local ok, items = pcall(_get_items_in_bag, bag)
        if ok and items then
            for _, row in ipairs(items) do
                local name, item_id = read_inventory_item(row)
                if name and name:lower():find(lower, 1, true) then
                    results[#results + 1] = {
                        bag_id = bag,
                        slot_id = row.slot_id,
                        item_id = item_id,
                        name = name,
                        object = row.object,
                    }
                end
            end
        end
    end

    if #results == 0 then return nil end
    return results
end

--- Scan all bags and return a flat list of ALL items with their IDs and names.
--- @return table[] Array of { bag_id, slot_id, item_id, name, object }
function M.get_all_inventory_items()
    local results = {}
    for bag = 0, 4 do
        local ok, items = pcall(_get_items_in_bag, bag)
        if ok and items then
            for _, row in ipairs(items) do
                local name, item_id = read_inventory_item(row)
                if name and item_id then
                    results[#results + 1] = {
                        bag_id = bag,
                        slot_id = row.slot_id,
                        item_id = item_id,
                        name = name,
                        object = row.object,
                    }
                end
            end
        end
    end
    return results
end

-- ============================================================================
-- Goal → Item Matching
-- ============================================================================

--- Extract likely item name from a quest goal text.
--- Patterns: "Use X on Y" → "X"; "Use the X" → "X"; "Equip X" → "X"
--- @param goal_text string
--- @return string|nil
function M.extract_item_name_from_goal(goal_text)
    if not goal_text or goal_text == "" then return nil end
    local lower = goal_text:lower()

    -- Pattern: "Use [the] X on Y" → return X
    local use_on = lower:match("use%s+the?%s+(.-)%s+on%s+")
    if use_on then return use_on end

    -- Pattern: "Use [the] X" → return X
    local use_plain = lower:match("use%s+the?%s+(.-)$")
    if use_plain then return use_plain end

    -- Pattern: "Equip X" → return X
    local equip = lower:match("equip%s+(.-)$")
    if equip then return equip end

    -- Fallback: if goal text is short (< 30 chars), treat whole thing as item name
    if #goal_text < 30 then return goal_text end

    return nil
end

--- Match a quest goal to an inventory item.
--- @param goal_text string
--- @return table|nil { bag_id, slot_id, item_id, name, object }
function M.find_item_for_goal(goal_text)
    local item_name = M.extract_item_name_from_goal(goal_text)
    if not item_name then return nil end

    -- Try exact-ish match first
    local items = M.find_items_by_name(item_name)
    if items then return items[1] end

    -- Try stripping "a/an/the" and re-match
    local stripped = item_name:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
    if stripped ~= item_name then
        items = M.find_items_by_name(stripped)
        if items then return items[1] end
    end

    -- Try first word only (e.g. "Bundle of Wood" → "Bundle")
    local first_word = item_name:match("^(%S+)")
    if first_word and #first_word > 3 then
        items = M.find_items_by_name(first_word)
        if items then
            -- Make sure the full name contains the rest of the query
            for _, item in ipairs(items) do
                if item.name:lower():find(item_name, 1, true) then
                    return item
                end
            end
        end
    end

    return nil
end

-- ============================================================================
-- Item Usage
-- ============================================================================

--- Determine usage pattern from goal text.
--- @param goal_text string
--- @return string One of: "self", "target", "position", "unknown"
function M.infer_usage_pattern(goal_text)
    if not goal_text then return "unknown" end
    local lower = goal_text:lower()

    -- Contains "on [target]" → target-cast
    if lower:find(" on ", 1, true) then return "target" end
    -- Contains "at [position]" → position-cast
    if lower:find(" at ", 1, true) then return "position" end
    -- Contains "near" or "around" → position-cast
    if lower:find("near ", 1, true) or lower:find("around ", 1, true) then return "position" end

    -- Default: self-cast (safest)
    return "self"
end

-- Every use_item* API reports the same boolean contract. pcall only proves that
-- the call did not raise; both facts are required before claiming success.
local function use_succeeded(fn, ...)
    local ok, result = pcall(fn, ...)
    return ok and result == true
end

--- Use a quest item. Tries the inferred pattern, falls back through alternatives.
--- @param item table { object, item_id, bag_id, slot_id }
--- @param pattern string "self", "target", "position"
--- @param target game_object|nil For target-cast
--- @param position table|nil {x,y,z} For position-cast
--- @return boolean true only when a use_item* call reports true
function M.use_quest_item(item, pattern, target, position)
    if not item or not item.object then return false end

    -- Re-read the concrete client identity immediately before use. The bag row
    -- itself has no ID, and accepting a caller-supplied name-only record would
    -- make fuzzy selection look like authoritative item identity.
    local id_ok, item_id = pcall(function() return item.object:get_item_id() end)
    if not id_ok or type(item_id) ~= "number" or item_id <= 0 then return false end

    -- Cooldown check
    local last = _cooldowns[item_id]
    if last and (_core_time() - last) < _USE_COOLDOWN then return false end
    _cooldowns[item_id] = _core_time()

    -- Throttle: only attempt once per item per 3s
    _core_log("[EaxAutoQuester] Using quest item: " .. tostring(item.name) .. " (" .. tostring(pattern) .. ")")

    -- Try inferred pattern first
    if pattern == "self" then
        if use_succeeded(core.input.use_item, item_id) then return true end
    elseif pattern == "target" and target then
        if use_succeeded(core.input.use_item_target, item_id, target) then return true end
    elseif pattern == "position" and position then
        if use_succeeded(core.input.use_item_position, item_id, position) then return true end
    end

    -- Fallback 1: try self-cast (safest)
    if pattern ~= "self" then
        if use_succeeded(core.input.use_item, item_id) then return true end
    end

    -- Fallback 2: try target-cast with current target
    if pattern ~= "target" then
        local me_ok, me = pcall(core.object_manager.get_local_player)
        if me_ok and me then
            local t_ok, t = pcall(function() return me:get_target() end)
            if t_ok and t then
                if use_succeeded(core.input.use_item_target, item_id, t) then return true end
            end
        end
    end

    -- Item use is addressed by item ID here. Raw core.inventory slot_id values are not
    -- interchangeable with the container-slot API's inventory-helper slot pair.
    if use_succeeded(core.input.use_item, item_id) then return true end

    _core_log("[EaxAutoQuester] Failed to use quest item: " .. tostring(item.name))
    return false
end

--- Master entry point: given a goal, find the matching item and use it.
--- @param goal_text string The quest goal text (e.g. "Use Bundle of Wood on the bonfire")
--- @param target game_object|nil Optional target for target-cast
--- @param position table|nil Optional position for position-cast
--- @return boolean true only when a matched item was successfully used
function M.handle_goal_item(goal_text, target, position)
    local item = M.find_item_for_goal(goal_text)
    if not item then return false end

    local pattern = M.infer_usage_pattern(goal_text)
    return M.use_quest_item(item, pattern, target, position)
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.quest_item_manager = M

return M
