-- What: Vendor, repair, and sell module for EaxAutoQuester
-- When: Called when player opens a vendor window during questing
-- Why: Automate vendor interactions — repair gear, sell junk, buy quest items
-- Safety: All vendor access nil-guarded via pcall; static table reuse for vendor item list
-- Decision: Standalone module (not EaxRotations), caches core API at load
-- API shapes (item 14): selling reads its (bag_id, bag_slot) pair from the documented owner
--     (common/utility/inventory_helper) because a raw core.inventory slot_id names the item
--     NEXT to the one meant; buying passes the 1-based index the vendor list was READ with
--     (the documented base for core.input.buy_item) instead of the undocumented
--     vendor_item_index field or the position of a compacted snapshot.

-- Hot-path API caching at module load (Pattern 2 from AGENTS.md)
local _get_total_repair_cost = core.inventory.get_total_repair_cost
local _get_gold = core.inventory.get_gold
local _get_vendor_item_count = core.game_ui.get_vendor_item_count
local _get_vendor_item_info = core.game_ui.get_vendor_item_info
local _repair_all_items = core.input.repair_all_items
local _buy_item = core.input.buy_item
local _use_container_item = core.input.use_container_item
local _get_item_info = core.quests.get_item_info
local _core_log = core.log

-- Static table reuse for vendor item list building (Pattern 4 from AGENTS.md)
local _t = { n = 0 }
-- Lockstep companion to _t: the 1-based vendor index each snapshot entry was READ with.
local _t_index = { n = 0 }

-- The documented owner of the (bag_id, bag_slot) pair. Cached on success only, so a build
-- that loads the mini-lib late still picks it up.
local _inv_helper = nil
local function get_inventory_helper()
    if _inv_helper then return _inv_helper end
    local ok, mod = pcall(require, "common/utility/inventory_helper")
    if ok and type(mod) == "table" then _inv_helper = mod end
    return _inv_helper
end

--- Character-bag slots, as the documented owner reports them.
---
--- core.input.use_container_item's arguments "are the bag_id and bag_slot that
--- common/utility/inventory_helper.lua hands you; that module owns the shift from the raw
--- core.inventory.get_items_in_bag slot_id and is the supported way to get this pair. Passing a
--- raw slot_id straight from get_items_in_bag targets the item NEXT to the one you meant"
--- (.api/core.lua:1747-1750). In a sale that means selling an item nobody chose, and
--- get_items_in_bag(0) is not even the backpack — it is the whole player container, worn gear
--- and the bag objects included (:859-876) — so the raw scan also offered equipped gear up as
--- junk. When the mini-lib is absent the honest answer is "no slots", not a raw slot_id.
--- @return table[]|nil
local function get_bag_slots()
    local helper = get_inventory_helper()
    if not helper or type(helper.get_character_bag_slots) ~= "function" then return nil end
    local ok, slots = pcall(helper.get_character_bag_slots, helper)
    if not ok or type(slots) ~= "table" then return nil end
    return slots
end

--- Item id of one slot_data entry; nil when the entry carries nothing readable.
--- @param slot table|nil
--- @return integer|nil
local function slot_item_id(slot)
    local item = slot and slot.item
    if not item then return nil end
    local ok_id, item_id = pcall(function() return item:get_item_id() end)
    if not ok_id or type(item_id) ~= "number" then return nil end
    return item_id
end

--- Whether a slot is one of the containers the pair convention covers (0 = backpack, 1-4 =
--- the equipped bags). Anything else is not something this module may sell out of.
--- @param slot table|nil
--- @return boolean
local function is_character_bag(slot)
    local bag_id = slot and slot.bag_id
    return type(bag_id) == "number" and bag_id >= 0 and bag_id <= 4
end

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

    local slots = get_bag_slots()
    if not slots then return false end

    for _, slot in ipairs(slots) do
        if is_character_bag(slot) then
            local item_id = slot_item_id(slot)
            if item_id and item_id > 0 then
                local info_ok, info = pcall(_get_item_info, item_id)
                if info_ok and info and (info.quality or 0) <= max_quality then
                    return true
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
--- Identity comes from the documented (bag_id, bag_slot) pair, never from a raw
--- core.inventory slot_id (see get_bag_slots). The count is the number of sell attempts the
--- client was asked to make — use_container_item has no documented result to confirm a sale
--- with, so it stays what it always was.
--- @return number count Number of items sold
local function sell_junk()
    local ns = _G.EaxAutoQuester
    local force = ns and ns._force_vendor_soon
    local max_quality = force and QUALITY_GREEN or QUALITY_GREY

    local slots = get_bag_slots()
    if not slots then
        if _core_log then
            _core_log("[EaxAutoQuester] inventory_helper unavailable - not selling (a raw slot_id names the wrong item)")
        end
        return 0
    end

    local count = 0
    for _, slot in ipairs(slots) do
        if is_character_bag(slot) then
            local item_id = slot_item_id(slot)
            if item_id and item_id > 0 then
                local info_ok, info = pcall(_get_item_info, item_id)
                if info_ok and info and (info.quality or 0) <= max_quality then
                    local sell_ok = pcall(_use_container_item, slot.bag_id, slot.bag_slot)
                    if sell_ok then
                        count = count + 1
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

    -- Build vendor item list into static reuse table (Pattern 4), each entry carrying the
    -- 1-based index it was READ with. Both readers and the buyer share one base: the vendor
    -- list is 1-based (.api/core.lua:1272 - "vendor_item_id is 1-indexed (internally adjusted
    -- to 0-indexed)") and core.input.buy_item's index is 1-based too (docs "Vendor
    -- Interaction": "The vendor item index (1-based)"). The struct field vendor_item_index has
    -- no documented base, and the snapshot POSITION was wrong the moment a read failed: the
    -- list compacts and every later position then names an earlier vendor slot.
    _t.n = 0
    for i = 1, vendor_count do
        local info_ok, info = pcall(_get_vendor_item_info, i)
        if info_ok and info then
            _t.n = _t.n + 1
            _t[_t.n] = info
            _t_index[_t.n] = i
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
                    local index = _t_index[j]
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

    -- Clear static tables
    _t.n = 0
    _t_index.n = 0
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
    -- The reason belongs to the flag. Clearing one without the other would leave this visit's
    -- cause behind and make the NEXT request report it.
    if ns then
        ns._force_vendor_reason = nil
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
