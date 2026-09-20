-- What: Unit tests for EaxAutoQuester/loot_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify loot window processing and auto-loot scanning
-- Safety: pins the 0 BASED loot index range (.api/core.lua:1025 — "Every loot index
--         below is 0 based, running 0 to this count minus 1"), gold priority, and that
--         a window which compacts as slots are taken still loses nothing. Addressing
--         these slots 1-based skips the first slot and reads one past the end.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })

--- Every loot_item index passed to the mock, in call order.
local function loot_calls()
    local out = {}
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "loot_item" then out[#out + 1] = call[2] end
    end
    return out
end

-- ============================================================================
-- S1: try_loot with no loot window
-- ============================================================================
local loot_manager = require("loot_manager_sylvanas")
local result = loot_manager.try_loot()
assert(result == false, "S1 FAIL: try_loot should return false when no loot window")
print("  S1 PASS: no loot window -> false")

-- ============================================================================
-- S2: every 0-based slot is looted exactly once, and gold goes first
-- ============================================================================
mock._loot_items = {
    { id = 1, name = "Sword", is_gold = false },   -- slot 0
    { id = 2, name = "Gold",  is_gold = true  },   -- slot 1
    { id = 3, name = "Shield", is_gold = false },  -- slot 2
}
mock._input_calls = {}

result = loot_manager.try_loot()
assert(result == true, "S2a FAIL: try_loot should return true when loot window open")

local calls = loot_calls()
local seen, dup = {}, nil
for _, idx in ipairs(calls) do
    if seen[idx] then dup = idx end
    seen[idx] = true
end
assert(not dup, "S2b FAIL: slot " .. tostring(dup) .. " was looted twice")
assert(seen[0] and seen[1] and seen[2],
    "S2c FAIL: every slot 0..2 must be looted, got " .. table.concat(calls, ","))
assert(not seen[3], "S2d FAIL: index 3 is out of range for a 3 slot window (slots 0..2)")
assert(calls[1] == 1, "S2e FAIL: the gold slot (1) must be looted first, got " .. tostring(calls[1]))
assert(mock._input_calls[#mock._input_calls][1] == "close_loot",
    "S2f FAIL: the loot window must be closed after processing")
print("  S2 PASS: 0-based slots, gold priority, no out-of-range index")

-- ============================================================================
-- S3: a window that compacts as slots are looted loses nothing
-- ============================================================================
-- Real windows compact: taking a slot removes it and the ones above renumber.
-- Capturing the window once and then walking it by ascending index therefore
-- skips slots (and reads past the end). Same fixtures, compaction on.
mock.reset()
mock._loot_items = {
    { id = 1, name = "Sword", is_gold = false },
    { id = 2, name = "Gold",  is_gold = true  },
    { id = 3, name = "Shield", is_gold = false },
}
mock._loot_compacts = true
mock._input_calls = {}

result = loot_manager.try_loot()
assert(result == true, "S3a FAIL: try_loot should return true")

local expected = { "Gold", "Shield", "Sword" }
assert(#mock._looted_names == 3,
    "S3b FAIL: all 3 items must be looted when the window compacts, looted " ..
    tostring(#mock._looted_names) .. " (" .. table.concat(mock._looted_names, ",") .. ")")
for n = 1, 3 do
    assert(mock._looted_names[n] == expected[n],
        "S3c FAIL: looted order should be " .. table.concat(expected, ",") ..
        ", got " .. table.concat(mock._looted_names, ","))
end
print("  S3 PASS: compacting window still loots every item, gold first")

-- ============================================================================
-- S4: auto_loot_all with no lootable objects
-- ============================================================================
mock.reset()
mock._player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock._objects = {}
local auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == false, "S4 FAIL: auto_loot_all should return false with no lootable objects")
print("  S4 PASS: no lootable objects -> false")

-- ============================================================================
-- S5: auto_loot_all with lootable object
-- ============================================================================
local lootable = mock.create_object({ pos = {x=2, y=0, z=0}, name = "Corpse", lootable = true, valid = true, unit = true })
mock._objects = { lootable }
mock.set_time(mock.get_time() + 1.0)  -- advance time past the 0.5s loot throttle
auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == true, "S5 FAIL: auto_loot_all should return true with lootable object")
print("  S5 PASS: lootable object -> true")

-- ============================================================================
-- S6: close() actually closes the loot window
-- ============================================================================
mock.reset()
mock._input_calls = {}
loot_manager.close()
local closed = false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "close_loot" then closed = true end
end
assert(closed, "S6 FAIL: close() must call close_loot, calls: " ..
    tostring(#mock._input_calls))
print("  S6 PASS: close() closes the loot window")

print("PASS test_loot_manager")
os.exit(0)
