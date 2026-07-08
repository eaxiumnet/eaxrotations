-- test_progress_tracker.lua — Unit tests for progress_tracker_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Mock helpers
-- ============================================================================

local _progress = 0
local function set_progress(val)
    _progress = val
end

local function setup_quest_log(completed_count)
    mock._quest_log = {
        { title = "Elwynn Forest", is_header = true },
        { title = "Kill Boars", quest_id = 42, level = 10, is_complete = false, is_header = false },
    }
    core.quests.get_num_quest_leader_boards = function(index)
        return 1
    end
    core.quests.get_quest_log_leader_board = function(j, i)
        local c = completed_count or 0
        return c .. "/10 Boars killed"
    end
end

-- ============================================================================
-- S1: check_progress tracks and detects progress
-- ============================================================================
local pt = require("EaxAutoQuester/progress_tracker_sylvanas")
pt.clear_all()

mock.reset()
mock.set_time(10.0)
setup_quest_log(0)

local status = pt.check_progress(42, "kill")
assert(status == "waiting", "S1a FAIL: first check should be waiting, got " .. tostring(status))

-- No progress after 10s
mock.set_time(20.0)
status = pt.check_progress(42, "kill")
assert(status == "waiting", "S1b FAIL: still waiting, got " .. tostring(status))

-- Progress after 20s
setup_quest_log(5)
mock.set_time(30.0)
status = pt.check_progress(42, "kill")
assert(status == "progress", "S1c FAIL: progress detected, got " .. tostring(status))
print("  S1 PASS: progress tracking")

-- ============================================================================
-- S2: 3 strikes → blacklist
-- ============================================================================
pt.clear_all()
mock.reset()
mock.set_time(10.0)
setup_quest_log(0)

pt.check_progress(42, "kill")  -- strike 0
mock.set_time(20.0)
pt.check_progress(42, "kill")  -- strike 1
mock.set_time(30.0)
pt.check_progress(42, "kill")  -- strike 2
mock.set_time(40.0)
status = pt.check_progress(42, "kill")  -- strike 3 → blacklist
assert(status == "blacklisted", "S2a FAIL: expected blacklisted, got " .. tostring(status))
assert(pt.is_blacklisted(42) == true, "S2b FAIL")
print("  S2 PASS: 3 strikes → blacklist")

-- ============================================================================
-- S3: non-trackable types return nil
-- ============================================================================
pt.clear_all()
status = pt.check_progress(1, "talk")
assert(status == nil, "S3 FAIL: talk should not be tracked")
status = pt.check_progress(1, "gossip")
assert(status == nil, "S3b FAIL: gossip should not be tracked")
print("  S3 PASS: non-trackable types return nil")

-- ============================================================================
-- S4: reset_tracking clears state
-- ============================================================================
pt.clear_all()
mock.reset()
mock.set_time(10.0)
setup_quest_log(0)
pt.check_progress(42, "kill")
pt.check_progress(42, "kill")
pt.check_progress(42, "kill")
pt.reset_tracking(42)
assert(pt.is_blacklisted(42) == false, "S4 FAIL: should not be blacklisted after reset")
mock.set_time(20.0)
status = pt.check_progress(42, "kill")
assert(status == "waiting", "S4b FAIL: should be fresh after reset")
print("  S4 PASS: reset_tracking works")

print("PASS test_progress_tracker")
os.exit(0)
