-- What: Unit tests for EaxAutoQuester/vendor_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify repair detection, junk selling, and quest item buying

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })

local vendor_manager = require("EaxAutoQuester/vendor_manager_sylvanas")

-- Test should_repair with no repair needed
assert(vendor_manager.should_repair() == false, "should_repair should be false when no cost")

-- Test should_sell_junk with no grey items
assert(vendor_manager.should_sell_junk() == false, "should_sell_junk should be false with no junk")

-- Test handle_vendor with no vendor frame
local actions = vendor_manager.handle_vendor()
assert(actions == false, "handle_vendor should return false when no vendor frame")

-- Test buy_quest_items with no vendor
local bought = vendor_manager.buy_quest_items({ { name = "Test Item", quantity = 1 } })
assert(bought == 0, "buy_quest_items should return 0 with no vendor")

print("PASS test_vendor_manager")
os.exit(0)
