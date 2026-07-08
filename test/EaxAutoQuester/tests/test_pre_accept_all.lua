-- What: Tests for accept_all_available behavior
-- When: Run via run_quester_tests.lua
-- Why: Verify accept_all_available() returns action string and handles edge cases
-- Safety: No io.popen, os.execute, ffi.C, math.sqrt, debug.*

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Helper: create a gossip available quest entry
local function make_quest(id, title)
    return { quest_id = id, title = title, is_complete = false }
end

-- Load module under test once (test runner isolates per-file via snapshot/restore)
local qi = require("EaxAutoQuester/quest_interaction_sylvanas")

-- ============================================================================
-- S1: 1 available quest → action string returned
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = { make_quest(101, "Quest A") }
    mock.set_time(0)

    local result = qi.accept_all_available()

    assert(result ~= nil, "S1: accept_all_available should return non-nil")
    assert(type(result) == "string", "S1: return should be a string, got " .. type(result))
    assert(result:find("Quest A"), "S1: action string should contain 'Quest A'")
    print("PASS S1: Single quest accepted, action string returned")
end

-- ============================================================================
-- S2: 3 available quests → all 3 accepted
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = {
        make_quest(101, "Quest A"),
        make_quest(102, "Quest B"),
        make_quest(103, "Quest C"),
    }
    mock.set_time(0)

    local result = qi.accept_all_available()

    assert(result ~= nil, "S2: should return action string with 3 quests")
    assert(result:find("Quest A"), "S2: should contain 'Quest A'")
    assert(result:find("Quest B"), "S2: should contain 'Quest B'")
    assert(result:find("Quest C"), "S2: should contain 'Quest C'")
    print("PASS S2: All 3 quests accepted in action string")
end

-- ============================================================================
-- S3: 0 available quests → returns nil (no crash)
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = {}
    mock.set_time(0)

    local result = qi.accept_all_available()
    assert(result == nil,
        "S3: expected nil for 0 available quests, got " .. tostring(result))
    print("PASS S3: Empty quest list returns nil (no crash)")
end

print("PASS test_pre_accept_all")
os.exit(0)
