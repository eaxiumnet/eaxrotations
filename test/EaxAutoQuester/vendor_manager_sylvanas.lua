-- What: Vendor, repair, and sell module for EaxAutoQuester
-- When: Called when player opens a vendor window during questing
-- Why: Automate vendor interactions — repair gear, sell junk, buy quest items
-- Safety: All vendor access nil-guarded via pcall; static table reuse for vendor item list
-- Decision: Standalone module (not EaxRotations), caches core API at load

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _get_total_repair_cost = core.inventory.get_total_repair_cost
local _get_gold = core.inventory.get_gold
local _get_items_in_bag = core.inventory.get_items_in_bag
local _get_vendor_item_count = core.game_ui.get_vendor_item_count
local _get_vendor_item_info = core.game_ui.get_vendor_item_info
local _repair_all_items = core.input.repair_all_items
local _buy_item = core.input.buy_item
local _use_container_item = core.input.use_container_item
local _get_item_info = core.quests.get_item_info
local _core_log = core.log
local _core_time = core.time

-- Static table reuse for vendor item list building (Pattern 4 from AGENTS.md)
local _t = { n = 0 }

-- Bag IDs: 0 = backpack, 1-4 = equipped bags
local BAG_IDS = { 0, 1, 2, 3, 4 }

-- Grey item quality = 0 (Poor)
local QUALITY_GREY = 0
local QUALITY_WHITE = 1
local QUALITY_GREEN = 2

-- ============================================================================
-- should_repair: Check if any equipped items need repair
-- ============================================================================

--- Check if the player has items that need repair.
--- @return boolean true if repair cost > 0, false otherwise
local function should_repair()
    local ok, cost = pcall(_get_total_repair_cost)
    if not ok then return false end
    return (cost or 0) > 0
end

-- ============================================================================
-- should_sell_junk: Check inventory for grey quality items
-- ============================================================================

--- Check if any bag contains junk items.
--- Normal mode: grey (Poor quality, quality=0) only.
--- Aggressive mode: when _force_vendor_soon is true, sells up to green (quality=2).
--- @return boolean true if junk items found, false otherwise
local function should_sell_junk()
    local ns = _G.EaxAutoQuester
    local force = ns and ns._force_vendor_soon
    local max_quality = force and QUALITY_GREEN or QUALITY_GREY

    for _, bag_id in ipairs(BAG_IDS) do
        local ok, items = pcall(_get_items_in_bag, bag_id)
        if ok and items then
            for _, item in ipairs(items) do
                if item and item.object and item.object.get_item_id then
                    local item_id = item.object:get_item_id()
                    if item_id and item_id > 0 then
                        local info_ok, info = pcall(_get_item_info, item_id)
                        if info_ok and info and (info.quality or 0) <= max_quality then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- ============================================================================
-- sell_junk: Sell all grey quality items in bags
-- ============================================================================

--- Sell junk items in inventory to the open vendor.
--- Normal mode: grey only. Aggressive mode (force flag): up to green.
--- Uses use_container_item which sells items when vendor frame is open.
--- @return number count Number of items sold
local function sell_junk()
    local ns = _G.EaxAutoQuester
    local force = ns and ns._force_vendor_soon
    local max_quality = force and QUALITY_GREEN or QUALITY_GREY

    local count = 0
    for _, bag_id in ipairs(BAG_IDS) do
        local ok, items = pcall(_get_items_in_bag, bag_id)
        if ok and items then
            -- Process in reverse order so slot shifts don't affect remaining items
            for i = #items, 1, -1 do
                local item = items[i]
                if item and item.object and item.object.get_item_id then
                    local item_id = item.object:get_item_id()
                    if item_id and item_id > 0 then
                        local info_ok, info = pcall(_get_item_info, item_id)
                        if info_ok and info and (info.quality or 0) <= max_quality then
                            local sell_ok = pcall(_use_container_item, bag_id, item.slot_id)
                            if sell_ok then
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return count
end

-- ============================================================================
-- buy_quest_items: Purchase specified items from the current vendor
-- ============================================================================

--- Buy quest items from the open vendor by item name matching.
--- @param quest_items table|nil Array of { name = string, quantity = number } items to buy
--- @return number count Number of item types successfully purchased
local function buy_quest_items(quest_items)
    if not quest_items or #quest_items == 0 then return 0 end

    local ok, vendor_count = pcall(_get_vendor_item_count)
    if not ok or not vendor_count or vendor_count <= 0 then return 0 end

    local bought = 0

    -- Build vendor item list into static reuse table (Pattern 4)
    _t.n = 0
    for i = 1, vendor_count do
        local info_ok, info = pcall(_get_vendor_item_info, i)
        if info_ok and info then
            _t.n = _t.n + 1
            _t[_t.n] = info
        end
    end

    -- Match each quest item against vendor list (case-insensitive)
    for _, quest_item in ipairs(quest_items) do
        if quest_item and quest_item.name then
            local target_name = quest_item.name:lower()
            local quantity = math.max(quest_item.quantity or 1, 1)

            for j = 1, _t.n do
                local vendor_item = _t[j]
                if vendor_item and vendor_item.item_name and vendor_item.item_name:lower() == target_name then
                    local index = vendor_item.vendor_item_index or j
                    local buy_ok = pcall(_buy_item, index, quantity)
                    if buy_ok then
                        bought = bought + 1
                        _core_log("[EaxAutoQuester] Bought " .. tostring(quantity) .. "x " .. tostring(vendor_item.item_name))
                    end
                    break
                end
            end
        end
    end

    -- Clear static table
    _t.n = 0
    return bought
end

-- ============================================================================
-- handle_vendor: Main entry point — repair, sell junk, buy quest items
-- ============================================================================

--- Handle vendor interaction: repair gear, sell junk items, buy quest items.
--- @param quest_items table|nil Optional array of { name = string, quantity = number } items to buy
--- @return boolean true if any action was taken, false otherwise
local function handle_vendor(quest_items)
    -- Verify vendor frame is open by checking vendor item count
    local ok, vendor_count = pcall(_get_vendor_item_count)
    if not ok or vendor_count == nil then return false end

    local actions_taken = false

    -- 1. Repair gear if player has enough gold
    if should_repair() then
        local gold_ok, gold = pcall(_get_gold)
        local rep_ok, cost = pcall(_get_total_repair_cost)
        if gold_ok and rep_ok and (gold or 0) >= (cost or 0) then
            local repair_ok = pcall(_repair_all_items, false)
            if repair_ok then
                _core_log("[EaxAutoQuester] Repaired all items")
                actions_taken = true
            end
        end
    end

    -- 2. Sell junk items to vendor
    if should_sell_junk() then
        local sold = sell_junk()
        if sold > 0 then
            _core_log("[EaxAutoQuester] Sold " .. tostring(sold) .. " junk items")
            actions_taken = true
        end
    end

    -- Clear force-vendor flag after handling vendor
    local ns = _G.EaxAutoQuester
    if ns and ns._force_vendor_soon then
        ns._force_vendor_soon = nil
    end

    -- 3. Buy quest items from vendor
    if quest_items and #quest_items > 0 then
        local bought = buy_quest_items(quest_items)
        if bought > 0 then
            actions_taken = true
        end
    end

    return actions_taken
end

-- ============================================================================
-- Module Table
-- ============================================================================

local M = {
    handle_vendor = handle_vendor,
    should_repair = should_repair,
    should_sell_junk = should_sell_junk,
    sell_junk = sell_junk,
    buy_quest_items = buy_quest_items,
}

-- Expose globally for cross-module access without re-require
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.vendor_manager = M

return M
