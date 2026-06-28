-- What: Quest item usage — scan inventory, match to active quest goals, use items
-- When: Called from do_action_state when goal type suggests item usage
-- Why: ~20% of TBC quests require using an inventory item on a target or ground.
--        Zygor never provides item IDs; we match by name.
-- Safety: All API calls pcall-guarded; 3s cooldown per item; never uses non-quest items
-- Decision: Name-matching heuristic (not perfect, but catches most cases).
--           Uses core.input.use_item / use_item_target / use_item_position.

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

-- ============================================================================
-- Inventory Scan
-- ============================================================================

--- Scan all bags for items whose name contains the given substring.
--- @param substring string Name substring to match (case-insensitive)
--- @return table[]|nil Array of { bag_id, slot_id, item_id, name } or nil
function M.find_items_by_name(substring)
    if not substring or substring == "" then return nil end
    local lower = substring:lower()
    local results = {}

    for bag = 0, 4 do
        local ok, items = pcall(_get_items_in_bag, bag)
        if ok and items then
            for _, item in ipairs(items) do
                if item and item.object then
                    local ok_name, name = pcall(function() return item.object:get_name() end)
                    local ok_id, item_id = pcall(function() return item.object:get_item_id() end)
                    if ok_name and ok_id and name and item_id then
                        if name:lower():find(lower, 1, true) then
                            results[#results + 1] = {
                                bag_id = bag,
                                slot_id = item.slot_id,
                                item_id = item_id,
                                name = name,
                            }
                        end
                    end
                end
            end
        end
    end

    if #results == 0 then return nil end
    return results
end

--- Scan all bags and return a flat list of ALL items with their IDs and names.
--- @return table[] Array of { bag_id, slot_id, item_id, name }
function M.get_all_inventory_items()
    local results = {}
    for bag = 0, 4 do
        local ok, items = pcall(_get_items_in_bag, bag)
        if ok and items then
            for _, item in ipairs(items) do
                if item and item.object then
                    local ok_name, name = pcall(function() return item.object:get_name() end)
                    local ok_id, item_id = pcall(function() return item.object:get_item_id() end)
                    if ok_name and ok_id then
                        results[#results + 1] = {
                            bag_id = bag,
                            slot_id = item.slot_id,
                            item_id = item_id,
                            name = name or "Unknown",
                        }
                    end
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
--- @return table|nil { bag_id, slot_id, item_id, name }
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

--- Use a quest item. Tries the inferred pattern, falls back through alternatives.
--- @param item table { item_id, bag_id, slot_id }
--- @param pattern string "self", "target", "position"
--- @param target game_object|nil For target-cast
--- @param position table|nil {x,y,z} For position-cast
--- @return boolean true if usage was attempted
function M.use_quest_item(item, pattern, target, position)
    if not item or not item.item_id then return false end

    -- Cooldown check
    local last = _cooldowns[item.item_id]
    if last and (_core_time() - last) < _USE_COOLDOWN then return false end
    _cooldowns[item.item_id] = _core_time()

    -- Throttle: only attempt once per item per 3s
    _core_log("[EaxAutoQuester] Using quest item: " .. tostring(item.name) .. " (" .. tostring(pattern) .. ")")

    -- Try inferred pattern first
    if pattern == "self" then
        local ok = pcall(core.input.use_item, item.item_id)
        if ok then return true end
    elseif pattern == "target" and target then
        local ok = pcall(core.input.use_item_target, item.item_id, target)
        if ok then return true end
    elseif pattern == "position" and position then
        local ok = pcall(core.input.use_item_position, item.item_id, position)
        if ok then return true end
    end

    -- Fallback 1: try self-cast (safest)
    if pattern ~= "self" then
        local ok = pcall(core.input.use_item, item.item_id)
        if ok then return true end
    end

    -- Fallback 2: try target-cast with current target
    if pattern ~= "target" then
        local me_ok, me = pcall(core.object_manager.get_local_player)
        if me_ok and me then
            local t_ok, t = pcall(function() return me:get_target() end)
            if t_ok and t then
                local ok = pcall(core.input.use_item_target, item.item_id, t)
                if ok then return true end
            end
        end
    end

    -- Fallback 3: try use_container_item (bag+slot) — some items only work this way
    local ok = pcall(core.input.use_container_item, item.bag_id, item.slot_id)
    if ok then return true end

    _core_log("[EaxAutoQuester] Failed to use quest item: " .. tostring(item.name))
    return false
end

--- Master entry point: given a goal, find the matching item and use it.
--- @param goal_text string The quest goal text (e.g. "Use Bundle of Wood on the bonfire")
--- @param target game_object|nil Optional target for target-cast
--- @param position table|nil Optional position for position-cast
--- @return boolean true if an item was found and usage was attempted
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
