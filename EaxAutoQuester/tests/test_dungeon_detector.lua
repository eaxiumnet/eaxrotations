-- test_dungeon_detector.lua — Unit tests for dungeon_detector_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local dd = require("EaxAutoQuester/dungeon_detector_sylvanas")

-- ============================================================================
-- S1: is_dungeon_goal via step text
-- ============================================================================
assert(dd.is_dungeon_goal({}, "Enter the dungeon and kill the boss") == true, "S1a FAIL")
assert(dd.is_dungeon_goal({}, "Go inside the instance") == true, "S1b FAIL")
assert(dd.is_dungeon_goal({}, "Kill 10 boars outside") == false, "S1c FAIL")
assert(dd.is_dungeon_goal({}, nil) == false, "S1d FAIL")
print("  S1 PASS: step text detection")

-- ============================================================================
-- S2: is_dungeon_goal via goal text
-- ============================================================================
assert(dd.is_dungeon_goal({ text = "Enter the dungeon" }, nil) == true, "S2a FAIL")
assert(dd.is_dungeon_goal({ name = "Heroic dungeon run" }, nil) == true, "S2b FAIL")
assert(dd.is_dungeon_goal({ text = "Collect apples" }, nil) == false, "S2c FAIL")
print("  S2 PASS: goal text detection")

-- ============================================================================
-- S3: should_skip — outside instance + dungeon goal = skip
-- ============================================================================
mock.reset()
mock.set_time(10.0)
-- mock core.get_instance_type to return "none"
core.get_instance_type = function() return "none" end
assert(dd.should_skip({ text = "Enter dungeon" }, nil) == true, "S3a FAIL")
assert(dd.should_skip({ text = "Kill boars" }, nil) == false, "S3b FAIL")
print("  S3 PASS: should_skip outside instance")

-- ============================================================================
-- S4: should_skip — inside instance = never skip
-- ============================================================================
core.get_instance_type = function() return "party" end
assert(dd.should_skip({ text = "Enter dungeon" }, nil) == false, "S4 FAIL: inside instance should not skip")
print("  S4 PASS: inside instance allows all")

-- ============================================================================
-- S5: quest log scan for dungeon text
-- ============================================================================
mock.reset()
mock.set_time(10.0)
core.get_instance_type = function() return "none" end
mock._quest_log = {
    { title = "Elwynn Forest", is_header = true },
    { title = "Dungeon Quest", quest_id = 99, level = 10, is_complete = false, is_header = false },
}
core.quests.get_num_quest_leader_boards = function() return 1 end
core.quests.get_quest_log_leader_board = function() return "This quest must be completed in Heroic dungeon difficulty" end
assert(dd.is_dungeon_goal({ quest_id = 99 }, nil) == true, "S5a FAIL")
print("  S5 PASS: quest log objective scan")

-- ============================================================================
-- S6: goal_filter integration
-- ============================================================================
local gf = require("EaxAutoQuester/goal_filter_sylvanas")
mock.reset()
mock.set_time(10.0)
local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
mock._player = me
core.get_instance_type = function() return "none" end
local passes, reason = gf.passes({ text = "Enter the dungeon", quest_id = 1 }, me)
assert(passes == false, "S6a FAIL: dungeon goal should be filtered out")
assert(reason == "dungeon", "S6b FAIL: reason should be 'dungeon', got " .. tostring(reason))
print("  S6 PASS: goal_filter integration")

print("PASS test_dungeon_detector")
os.exit(0)
