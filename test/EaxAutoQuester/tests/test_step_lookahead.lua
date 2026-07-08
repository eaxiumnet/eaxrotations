-- What: Unit tests for zygor_reader_sylvanas.lua get_next_waypoint_world()
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify next-waypoint lookahead: coords conversion, nil guards
-- API: zygor_reader.get_next_waypoint_world() returns {x,y,z,map_id,title} or nil
-- Safety: Never uses io.popen, os.execute, ffi.C, debug.*, or math.sqrt

-- Preload a working waypoint_fixer mock so zygor_reader's map→world conversion works
package.loaded["waypoint_fixer_sylvanas"] = {
    map_to_world_fixed = function(map_id, pos)
        return { x = pos.x * 100, y = pos.y * 100, z = 0 }
    end,
    fix_z = function(pos) return pos end,
}

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Enable Zygor addon
mock._addon_loaded.zygor = true

-- Clear cached module so it re-initializes with our mock setup
package.loaded["EaxAutoQuester/zygor_reader_sylvanas"] = nil

-- Load module under test
local zygor_reader = require("EaxAutoQuester/zygor_reader_sylvanas")

-- Helper: compare two world-coord result tables
local function assert_result_eq(got, expected, label)
    assert(got ~= nil, label .. ": expected non-nil result")
    assert(type(got.x) == "number", label .. ": x must be number")
    assert(type(got.y) == "number", label .. ": y must be number")
    assert(got.x == expected.x, label .. ": x mismatch " .. tostring(got.x) .. " vs " .. tostring(expected.x))
    assert(got.y == expected.y, label .. ": y mismatch " .. tostring(got.y) .. " vs " .. tostring(expected.y))
    if expected.z ~= nil then
        assert(type(got.z) == "number", label .. ": z must be number")
        assert(got.z == expected.z, label .. ": z mismatch " .. tostring(got.z) .. " vs " .. tostring(expected.z))
    end
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
assert_result_eq(result, { x = 50, y = 50 }, "S1")

-- ============================================================
-- S2: next_waypoint absent → returns nil
-- ============================================================

mock._zygor_next_wp = nil
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

print("PASS test_step_lookahead")
os.exit(0)
