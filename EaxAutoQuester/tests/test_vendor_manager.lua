-- What: Unit tests for EaxAutoQuester/vendor_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify repair detection, junk selling, and quest item buying
-- Safety (item 14): selling names an item through the documented (bag_id, bag_slot) pair and
--         never a raw core.inventory slot_id ("Passing a raw slot_id straight from
--         get_items_in_bag targets the item NEXT to the one you meant", .api/core.lua:1749);
--         without the mini-lib that owns that pair nothing is sold. Buying passes the 1-based
--         index the vendor entry was READ with, which is the documented base of
--         core.input.buy_item, not the entry's position in a compacted snapshot.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })

local vendor_manager = require("vendor_manager_sylvanas")

-- ============================================================================
-- V0: without the documented slot pair, nothing is sold
-- ============================================================================
-- The (bag_id, bag_slot) pair belongs to common/utility/inventory_helper (.api/core.lua:1747).
-- With it absent there is no safe way to name a bag slot, and guessing with a raw slot_id
-- sells an item nobody chose — so the module must sell nothing.
mock.uninstall_inventory_helper()
mock._bag_items = { [0] = { { object = { get_item_id = function() return 100 end } } } }
mock.quests.get_item_info = function() return { quality = 0, sell_price = 1 } end
assert(vendor_manager.should_sell_junk() == false,
    "V0a FAIL: no inventory_helper -> no slot can be named -> no junk may be reported")
assert(vendor_manager.sell_junk() == 0,
    "V0b FAIL: no inventory_helper -> nothing may be sold")
mock.install_inventory_helper()
print("  V0 PASS: no inventory_helper -> no sale (never a raw slot_id)")

-- ============================================================================
-- V1: repair detection and empty state (unchanged behavior)
-- ============================================================================
-- Test should_repair with no repair needed
assert(vendor_manager.should_repair() == false, "should_repair should be false when no cost")

-- Test should_sell_junk with no grey items
mock._bag_items = {}
assert(vendor_manager.should_sell_junk() == false, "should_sell_junk should be false with no junk")

-- Test handle_vendor with no vendor frame
local actions = vendor_manager.handle_vendor()
assert(actions == false, "handle_vendor should return false when no vendor frame")

-- Test buy_quest_items with no vendor
local bought = vendor_manager.buy_quest_items({ { name = "Test Item", quantity = 1 } })
assert(bought == 0, "buy_quest_items should return 0 with no vendor")

-- ============================================================================
-- V2: buying names the index the entry was READ with
-- ============================================================================
-- The vendor list is 1-based (.api/core.lua:1272 - "vendor_item_id is 1-indexed (internally
-- adjusted to 0-indexed)") and core.input.buy_item's index is 1-based too (docs "Vendor
-- Interaction"). The struct field vendor_item_index has no documented base, and the snapshot
-- POSITION shifts whenever a read fails.
mock.reset()
local real_get_vendor_item_info = mock.game_ui.get_vendor_item_info
mock._vendor_items = {
    [1] = { item_name = "Sold Out Thing", vendor_item_index = 0, quantity = 1 },
    [2] = { item_name = "Quest Reagent", vendor_item_index = 0, quantity = 1 },
    [3] = { item_name = "Third Thing", vendor_item_index = 0, quantity = 1 },
}
-- Read 1 fails: the vendor list refreshed mid-scan, so the snapshot compacts.
mock.game_ui.get_vendor_item_info = function(index)
    if index == 1 then return nil end
    return real_get_vendor_item_info(index)
end
mock._input_calls = {}
local bought_matched = vendor_manager.buy_quest_items({ { name = "quest reagent", quantity = 2 } })
assert(bought_matched == 1,
    "V2a FAIL: the matching entry should be bought once, got " .. tostring(bought_matched))
local buy_index, buy_quantity = nil, nil
for _, call in ipairs(mock._input_calls) do
    if call[1] == "buy_item" then buy_index, buy_quantity = call[2], call[3] end
end
assert(buy_index == 2,
    "V2b FAIL: the entry read at index 2 is the one buy_item documents (1-based); got " ..
    tostring(buy_index) .. " (0 is the undocumented field, 1 is the compacted position)")
assert(buy_quantity == 2, "V2c FAIL: quantity should be 2, got " .. tostring(buy_quantity))
mock.game_ui.get_vendor_item_info = real_get_vendor_item_info
print("  V2 PASS: buy_item gets the read-time vendor index, not the field or the position")

print("PASS test_vendor_manager")
os.exit(0)
