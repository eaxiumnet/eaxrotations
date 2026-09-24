-- test_dungeon_detector.lua — Unit tests for dungeon_detector_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local dd = require("dungeon_detector_sylvanas")

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
local gf = require("goal_filter_sylvanas")
mock.reset()
mock.set_time(10.0)
local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
mock._player = me
core.get_instance_type = function() return "none" end
local passes, reason = gf.passes({ text = "Enter the dungeon", quest_id = 1 }, me)
assert(passes == false, "S6a FAIL: dungeon goal should be filtered out")
assert(reason == "dungeon", "S6b FAIL: reason should be 'dungeon', got " .. tostring(reason))
print("  S6 PASS: goal_filter integration")

-- ===========================================================================
-- S7: documented Zygor goal labels and the real reader -> IDLE seam
-- ===========================================================================
-- core.addons.zygor documents target/npc on a goal, but no text/name field.
-- The detector keeps text/name for explicit callers; this matrix proves the
-- production reader/IDLE path uses the documented labels and the existing
-- instance short-circuit without pretending that a step.text exists.
local idle_state = require("quest_state/idle_state")
local utils = require("utils_sylvanas")
local zygor_reader = require("zygor_reader_sylvanas")

local function make_goal(target, npc)
    return {
        action = "talk",
        quest_id = nil,
        npc_id = 0,
        target_id = 0,
        target = target,
        npc = npc,
        is_complete = false,
    }
end

local function fresh_shared(step_num)
    return {
        _interact_cooldown = 0,
        _loot_cooldown = 0,
        _last_cooldown_log = 0,
        _nav_destination = nil,
        _area_wait_timer = 0,
        _post_interact_timer = 0,
        _at_quest_object_timer = 0,
        _action_pause_timer = 0,
        _respawn_wait_until = 0,
        _last_step_num = step_num,
    }
end

local function set_real_step(goals, step_num)
    mock.reset()
    mock._addon_loaded.zygor = true
    mock._zygor_step = { num = step_num, is_complete = false, goals = goals }
    mock.set_time(100.0)
    core.get_instance_type = function() return "none" end
    return mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
end

local function make_idle_ctx(objects)
    return {
        zygor = zygor_reader,
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = utils,
        me = mock._player,
        now = 100.0,
        debug_log = function() end,
        log = function() end,
        safe = function(value, fallback)
            if value == nil then return fallback end
            return value
        end,
        detect_open_frame = function() return false end,
        npc_manager = {
            find_interactable_objects = function(name)
                for _, object in ipairs(objects) do
                    if object:get_name() == name then return { object } end
                end
                return {}
            end,
        },
        object_scanner = { get_visible_objects = function() return objects end },
    }
end

-- S7a: the documented step shape has no step text. This is the measured
-- runtime boundary: the reader forwards num/is_complete/goals, nothing else.
local benign = make_goal("Northshire Combe Boar", nil)
local dungeon = make_goal("Deadmines Instance", nil)
local dungeon_npc = make_goal(nil, "Heroic Dungeon Entrance")
set_real_step({ benign }, 71)
local observed_step = zygor_reader.get_current_step_info()
assert(observed_step.step_num == 71, "S7a FAIL: reader did not preserve step number")
assert(observed_step.text == nil, "S7a FAIL: undocumented step.text was invented")
print("  S7a PASS: real Zygor reader exposes its documented step shape")

-- S7b: a documented goal target containing dungeon evidence is skipped, and
-- the next benign goal is the one IDLE acts on. The dungeon object is absent
-- on purpose, so this cannot pass by accidentally selecting the wrong goal.
local benign_object = mock.create_object({
    pos = { x = 0, y = 0, z = 0 }, name = "Northshire Combe Boar",
    unit = false, valid = true, guid = "dungeon_matrix_benign",
})
set_real_step({ dungeon, benign }, 72)
mock._objects = { benign_object }
local state = idle_state.run(fresh_shared(72), make_idle_ctx({ benign_object }))
assert(state == "DO_ACTION", "S7b FAIL: documented target label was not filtered (got " .. tostring(state) .. ")")

-- S7c: npc is the other documented label field and follows the same decision.
local dungeon_target_object = mock.create_object({
    pos = { x = 0, y = 0, z = 0 }, name = "Deadmines Instance",
    unit = false, valid = true, guid = "dungeon_matrix_target",
})
set_real_step({ dungeon_npc, benign }, 73)
mock._objects = { benign_object }
state = idle_state.run(fresh_shared(73), make_idle_ctx({ benign_object }))
assert(state == "DO_ACTION", "S7c FAIL: documented npc label was not filtered (got " .. tostring(state) .. ")")

-- S7d: a benign documented goal remains eligible outside an instance.
set_real_step({ benign }, 74)
mock._objects = { benign_object }
state = idle_state.run(fresh_shared(74), make_idle_ctx({ benign_object }))
assert(state == "DO_ACTION", "S7d FAIL: benign goal was unexpectedly filtered (got " .. tostring(state) .. ")")

-- S7e: the same dungeon evidence is allowed when the client says the player
-- is already inside an instance. This is the existing short-circuit, not a
-- new routing or combat policy.
set_real_step({ dungeon }, 75)
core.get_instance_type = function() return "party" end
mock._objects = { dungeon_target_object }
state = idle_state.run(fresh_shared(75), make_idle_ctx({ dungeon_target_object }))
assert(state == "DO_ACTION", "S7e FAIL: in-instance dungeon goal was filtered (got " .. tostring(state) .. ")")

print("  S7 PASS: real reader -> goal_filter -> IDLE dungeon decision matrix")
print("PASS test_dungeon_detector")
os.exit(0)
