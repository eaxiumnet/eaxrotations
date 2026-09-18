-- What: Unit tests for bag fullness → force vendor trigger (D.build deliverable)
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify loot triggers flag at 80% fullness, coordinator NAV transitions,
--      vendor_manager aggressive sell, and flag cleared after vendor interaction
-- Exercises: loot_manager.auto_loot_all(), vendor_manager.should_sell_junk/sell_junk/handle_vendor,
--            coordinator.update() with _force_vendor_soon flag
-- API reference: mock_core inventory (get_num_bag_slots, get_items_in_bag), core.time

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Ensure _G.EaxAutoQuester exists (modules create it, but guard for standalone runs)
_G.EaxAutoQuester = _G.EaxAutoQuester or {}

-- Helper: create a mock bag item with a given item_id
local function make_item(item_id)
    return {
        object = { get_item_id = function() return item_id end },
        slot_id = item_id,  -- unique per item_id for test determinism
    }
end

-- Helper: fill all bags to a given item count per bag
local function fill_bags(item_count, override_mock)
    local m = override_mock or mock
    m._bag_items = {}
    local item_counter = 1
    for bag_id = 0, 4 do
        m._bag_items[bag_id] = {}
        for i = 1, item_count do
            m._bag_items[bag_id][i] = make_item(1000 + item_counter)
            item_counter = item_counter + 1
        end
    end
end

-- ============================================================================
-- S1: bag ≥80% full after loot → _force_vendor_soon flag set
-- ============================================================================
do
    mock.reset()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- 5 bags × 16 slots = 80 total. 13 items/bag = 65/80 = 81.25%
    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(13)

    -- Lootable object within range
    local obj = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, lootable = true, valid = true, unit = true })
    mock._objects = { obj }

    -- Bypass 0.5s throttle
    mock.set_time(1.0)

    local loot_manager = require("EaxAutoQuester/loot_manager_sylvanas")
    local result = loot_manager.auto_loot_all(5)
    assert(result == true, "S1: auto_loot_all should return true with lootable object")

    local flag = _G.EaxAutoQuester and _G.EaxAutoQuester._force_vendor_soon
    assert(flag == true, "S1 FAIL: _force_vendor_soon should be true when bag ≥80% full after loot. Got " .. tostring(flag))
    print("  S1 PASS: bag 80% full after loot → _force_vendor_soon = true")
end

-- ============================================================================
-- S2: bag 50% full → no flag
-- ============================================================================
do
    mock.reset()
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- 5 bags × 16 slots = 80 total. 8 items/bag = 40/80 = 50%
    mock._bag_slots = { [0] = 16, [1] = 16, [2] = 16, [3] = 16, [4] = 16 }
    fill_bags(8)

    local obj = mock.create_object({ pos = { x = 2, y = 0, z = 0 }, lootable = true, valid = true, unit = true })
    mock._objects = { obj }

    mock.set_time(2.0)  -- different time to avoid throttle collision with S1

    local loot_manager = require("EaxAutoQuester/loot_manager_sylvanas")
    loot_manager.auto_loot_all(5)

    local flag = _G.EaxAutoQuester and _G.EaxAutoQuester._force_vendor_soon
    assert(flag == nil, "S2 FAIL: _force_vendor_soon should be nil when bag 50% full. Got " .. tostring(flag))
    print("  S2 PASS: bag 50% full → no flag")
end

-- ============================================================================
-- S3: coordinator sees flag → transitions to NAV toward vendor
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Pre-load mock state handlers (all return current state to not interfere)
    local noop_handler = { run = function() return nil end }
    package.loaded["quest_state/idle_state"] = { run = function(shared, ctx) return "IDLE" end }
    package.loaded["quest_state/nav_state"] = noop_handler
    package.loaded["quest_state/interact_state"] = noop_handler
    package.loaded["quest_state/do_action_state"] = noop_handler
    package.loaded["quest_state/waiting_state"] = noop_handler
    package.loaded["quest_state/dead_state"] = noop_handler

    -- Pre-load mock npc_db with find_transport_npc
    package.loaded["EaxAutoQuester.npc_db_sylvanas"] = {
        find_transport_npc = function(kind)
            if kind == "vendor" then
                return { x = 100, y = 200, z = 0 }
            end
            return nil
        end,
    }

    -- Set the force vendor flag
    _G.EaxAutoQuester._force_vendor_soon = true

    -- Load coordinator and run update
    local coordinator = require("EaxAutoQuester/quest_state/coordinator")
    coordinator.update()

    -- Verify state transition via test accessor
    local state, dest = coordinator._test_inspect()
    assert(state == "NAV", "S3 FAIL: coordinator should transition to NAV when flag set. Got state=" .. tostring(state))
    assert(dest ~= nil, "S3 FAIL: nav destination should be set. Got " .. tostring(dest))
    assert(dest.x == 100, "S3 FAIL: nav dest x should be vendor x=100. Got " .. tostring(dest and dest.x))
    print("  S3 PASS: coordinator sees flag → transitions to NAV toward vendor")
end

-- ============================================================================
-- S4: vendor_manager sells aggressively when flag is set
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Setup menu: vendor_threshold = 1 (Grey only → quality ≤ 1 = grey + white)
    _G.EaxAutoQuester.menu = {
        get = function(key)
            if key == "vendor_threshold" then return 1 end
            return nil
        end,
    }

    -- Custom get_item_info: quality 2 = green (should NOT sell normally, SHOULD sell with flag)
    mock.quests.get_item_info = function(id)
        if id == 300 then
            return { quality = 2, sell_price = 10 }  -- green item
        end
        if id == 100 then
            return { quality = 0, sell_price = 1 }   -- grey item
        end
        return { quality = 0, sell_price = 1 }
    end

    local vendor_manager = require("EaxAutoQuester/vendor_manager_sylvanas")

    -- Without flag: green item (quality=2) should NOT be detected with threshold=1
    _G.EaxAutoQuester._force_vendor_soon = nil
    mock._bag_items = { [0] = { make_item(300) } }  -- green item
    local result_no_flag = vendor_manager.should_sell_junk()
    assert(result_no_flag == false,
        "S4a FAIL: without flag, green item should not trigger sell. Got " .. tostring(result_no_flag))
    print("  S4a PASS: without flag, green item NOT sold (quality 2 > threshold 1)")

    -- With flag: green item SHOULD be detected (effective threshold ≥ 3)
    _G.EaxAutoQuester._force_vendor_soon = true
    mock._bag_items = { [0] = { make_item(300) } }
    local result_with_flag = vendor_manager.should_sell_junk()
    assert(result_with_flag == true,
        "S4b FAIL: with flag, green item should trigger sell. Got " .. tostring(result_with_flag))
    print("  S4b PASS: with flag, green item detected (aggressive threshold)")

    -- Verify sell_junk actually sells the item
    mock._input_calls = {}
    local sold = vendor_manager.sell_junk()
    assert(sold >= 1, "S4c FAIL: sell_junk should sell at least 1 item with flag. Got sold=" .. tostring(sold))
    -- Verify a use_container_item call was recorded for bag 0
    local sell_calls = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "use_container_item" then sell_calls = sell_calls + 1 end
    end
    assert(sell_calls >= 1,
        "S4c FAIL: sell_junk should make use_container_item calls. Got " .. tostring(sell_calls))
    print("  S4c PASS: sell_junk sells green item aggressively when flag set")
end

-- ============================================================================
-- S5: flag cleared after vendor interaction completes
-- ============================================================================
do
    mock.reset()
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })

    -- Setup vendor frame open
    mock._vendor_items = { { item_name = "Test Item", vendor_item_index = 1 } }
    mock._repair_cost = 0
    mock._gold = 1000
    mock._bag_items = {}

    _G.EaxAutoQuester._force_vendor_soon = true

    local vendor_manager = require("EaxAutoQuester/vendor_manager_sylvanas")
    vendor_manager.handle_vendor()

    local flag_after = _G.EaxAutoQuester._force_vendor_soon
    assert(flag_after == nil,
        "S5 FAIL: _force_vendor_soon should be cleared after vendor interaction. Got " .. tostring(flag_after))
    print("  S5 PASS: flag cleared after vendor interaction completes")
end

print("PASS test_vendor_bag_trigger")
os.exit(0)
