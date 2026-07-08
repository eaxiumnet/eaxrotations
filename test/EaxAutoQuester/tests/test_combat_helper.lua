-- What: Unit tests for EaxAutoQuester/combat_helper_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify target acquisition and combat helpers

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })
local enemy = mock.create_object({ pos = {x=5, y=0, z=0}, name = "Enemy", unit = true, valid = true, dead = false, enemy = true, attackable = true })
local dead_enemy = mock.create_object({ pos = {x=3, y=0, z=0}, name = "DeadEnemy", unit = true, valid = true, dead = true, enemy = true, attackable = true })
local player_obj = mock.create_object({ pos = {x=0, y=0, z=0}, name = "Player", unit = true, player = true, valid = true })

mock._objects = { enemy, dead_enemy, player_obj }

local combat_helper = require("EaxAutoQuester/combat_helper_sylvanas")

-- Test target_and_tag_nearest
local tagged = combat_helper.target_and_tag_nearest(50)
assert(tagged == true, "target_and_tag_nearest should tag enemy")
assert(player:get_target() == enemy, "target_and_tag_nearest should set target to enemy")

-- Test is_current_target_valid
assert(combat_helper.is_current_target_valid(30) == true, "is_current_target_valid should be true for enemy in range")
assert(combat_helper.is_current_target_valid(3) == false, "is_current_target_valid should be false for enemy out of range (5yd > 3yd)")

-- Test use_quest_item_on_target
local used = combat_helper.use_quest_item_on_target(12345)
assert(used == true or used == false, "use_quest_item_on_target should return boolean")

-- Reset target and test with no valid enemies
player._target = nil
mock._objects = {}  -- clear all enemies
local not_tagged = combat_helper.target_and_tag_nearest(50)
assert(not_tagged == false, "target_and_tag_nearest should fail with no valid enemies")

print("PASS test_combat_helper")
os.exit(0)
