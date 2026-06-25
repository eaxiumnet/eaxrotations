-- What: Unit tests for zygor_reader_sylvanas.lua get_next_waypoint_world()
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify next-waypoint lookahead: coords conversion, nil guards, throttle
-- API: zygor_reader.get_next_waypoint_world() returns {x,y,z,map_id,title} or nil
-- Safety: Never uses io.popen, os.execute, ffi.C, debug.*, or math.sqrt
--
-- Scenarios:
--   S1: next_waypoint present and valid → returns world coords
--   S2: next_waypoint absent → returns nil
--   S3: invalid map_id → returns nil
--   S4: throttle — second call within 1s returns cached result
--   S5: throttle expires after 1s → fresh call

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Enable Zygor addon
mock._addon_loaded.zygor = true

-- Load module under test
local zygor_reader = require("EaxAutoQuester/zygor_reader_sylvanas")

-- Helper: compare two world-coord result tables
local function assert_result_eq(got, expected, label)
    assert(got ~= nil, label .. ": expected non-nil result")
    assert(type(got.x) == "number", label .. ": x must be number")
    assert(type(got.y) == "number", label .. ": y must be number")
    assert(type(got.z) == "number", label .. ": z must be number")
    assert(got.x == expected.x, label .. ": x mismatch " .. tostring(got.x) .. " vs " .. tostring(expected.x))
    assert(got.y == expected.y, label .. ": y mismatch " .. tostring(got.y) .. " vs " .. tostring(expected.y))
    assert(got.z == expected.z, label .. ": z mismatch " .. tostring(got.z) .. " vs " .. tostring(expected.z))
    if expected.map_id ~= nil then
        assert(got.map_id == expected.map_id, label .. ": map_id mismatch")
    end
    if expected.title ~= nil then
        assert(got.title == expected.title, label .. ": title mismatch")
    end
end

-- ============================================================
-- S1: next_waypoint present and valid → returns world coords
-- ============================================================

mock.set_time(0)
mock._zygor_next_wp = { map_id = 1, x = 0.5, y = 0.5, title = "Next Point" }

local result = zygor_reader.get_next_waypoint_world()

-- mock: get_world_pos_from_map_pos returns { x = pos.x*100, y = pos.y*100 }
-- mock: get_height_for_position returns z = 0
assert_result_eq(result, { x = 50, y = 50, z = 0, map_id = 1, title = "Next Point" }, "S1")

-- ============================================================
-- S2: next_waypoint absent → returns nil
-- ============================================================

mock._zygor_next_wp = nil
-- Clear throttle cache: advance time past 1s
mock.set_time(2.0)

result = zygor_reader.get_next_waypoint_world()
assert(result == nil, "S2: expected nil when no next waypoint")

-- ============================================================
-- S3: invalid map_id → returns nil
-- ============================================================

mock.set_time(4.0)
mock._zygor_next_wp = { map_id = nil, x = 0.5, y = 0.5, title = "Bad" }

result = zygor_reader.get_next_waypoint_world()
assert(result == nil, "S3: expected nil when map_id missing")

-- Test nil x
mock.set_time(6.0)
mock._zygor_next_wp = { map_id = 1, x = nil, y = 0.5, title = "NoX" }

result = zygor_reader.get_next_waypoint_world()
assert(result == nil, "S3: expected nil when x missing")

-- ============================================================
-- S4: throttle — second call within 1s returns cached result
-- ============================================================

mock.set_time(10.0)
mock._zygor_next_wp = { map_id = 1, x = 0.3, y = 0.7, title = "First" }

result = zygor_reader.get_next_waypoint_world()
assert_result_eq(result, { x = 30, y = 70, z = 0, title = "First" }, "S4.first")

-- Change the mock data — this should NOT be seen because we're within the 1s throttle
mock._zygor_next_wp = { map_id = 1, x = 0.9, y = 0.1, title = "Second" }

result = zygor_reader.get_next_waypoint_world()
assert_result_eq(result, { x = 30, y = 70, z = 0, title = "First" }, "S4.cached")
-- ^ title should still be "First" because throttle returned cached result

-- ============================================================
-- S5: throttle expires after 1s → fresh call
-- ============================================================

mock.set_time(11.0)  -- 1s after t=10 (10 + 1 = 11, NOT < 1.0, so throttle expires)

result = zygor_reader.get_next_waypoint_world()
assert_result_eq(result, { x = 90, y = 10, z = 0, title = "Second" }, "S5.fresh")
-- ^ Now should see "Second" because throttle expired and fresh call was made

print("PASS test_step_lookahead")
os.exit(0)
