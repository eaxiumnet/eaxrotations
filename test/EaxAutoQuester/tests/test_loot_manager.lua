-- What: Unit tests for EaxAutoQuester/loot_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify loot window processing and auto-loot scanning

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })

-- Test try_loot with no loot window
local loot_manager = require("EaxAutoQuester/loot_manager_sylvanas")
local result = loot_manager.try_loot()
assert(result == false, "try_loot should return false when no loot window")

-- Test try_loot with loot window
mock._loot_items = {
    { id = 1, name = "Sword", is_gold = false },
    { id = 2, name = "Gold", is_gold = true },
    { id = 3, name = "Shield", is_gold = false },
}
result = loot_manager.try_loot()
assert(result == true, "try_loot should return true when loot window open")

-- Test auto_loot_all with no lootable objects
mock._objects = {}
local auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == false, "auto_loot_all should return false with no lootable objects")

-- Test auto_loot_all with lootable object
local lootable = mock.create_object({ pos = {x=2, y=0, z=0}, name = "Corpse", lootable = true, valid = true, unit = true })
mock._objects = { lootable }
mock.set_time(1.0)  -- advance time to bypass throttle
auto_loot = loot_manager.auto_loot_all(5)
assert(auto_loot == true, "auto_loot_all should return true with lootable object")

-- Test close
loot_manager.close()

print("PASS test_loot_manager")
os.exit(0)
