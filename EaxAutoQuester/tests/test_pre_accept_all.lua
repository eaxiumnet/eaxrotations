-- What: Tests for pre-accept-all gossip settle behavior
-- When: Run via run_quester_tests.lua
-- Why: Verify accept_all_available() returns structured accept data, sets settle
--      timer, and can_close_gossip() respects the 1.1s settle period
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
-- S1: 1 available quest → accepted_n=1, settle timer set
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = { make_quest(101, "Quest A") }
    mock.set_time(0)

    local result = qi.accept_all_available()

    assert(result ~= nil, "S1: accept_all_available should return table with 1 quest")
    assert(type(result) == "table", "S1: return should be a table, got " .. type(result))
    assert(result.accepted_n == 1,
        "S1: expected accepted_n=1, got " .. tostring(result.accepted_n))
    assert(#result.titles == 1,
        "S1: expected 1 title, got " .. tostring(#result.titles))
    assert(result.titles[1] == "Quest A",
        "S1: expected title 'Quest A', got " .. tostring(result.titles[1]))
    print("PASS S1: Single quest accepted_n=1, correct title")
end

-- ============================================================================
-- S2: 3 available quests → all 3 accepted, settle timer set
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

    assert(result ~= nil, "S2: should return table with 3 quests")
    assert(result.accepted_n == 3,
        "S2: expected accepted_n=3, got " .. tostring(result.accepted_n))
    assert(#result.titles == 3,
        "S2: expected 3 titles, got " .. tostring(#result.titles))
    assert(result.titles[1] == "Quest A", "S2: title[1] mismatch")
    assert(result.titles[2] == "Quest B", "S2: title[2] mismatch")
    assert(result.titles[3] == "Quest C", "S2: title[3] mismatch")
    print("PASS S2: All 3 quests accepted_n=3, correct titles")
end

-- ============================================================================
-- S3: Settle timer prevents close_gossip immediately after accept
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = { make_quest(101, "Quest A") }
    mock.set_time(0)

    qi.accept_all_available()  -- sets settle_until = 0 + 1.1 = 1.1

    -- Immediately check — time is still 0, should NOT be closable
    local can_close = qi.can_close_gossip()
    assert(can_close == false,
        "S3: expected can_close_gossip=false at t=0 right after accept, got " .. tostring(can_close))
    print("PASS S3: Settle blocks close at t=0 after accept")
end

-- ============================================================================
-- S4: After 1.2s, close is allowed (past the 1.1s settle)
-- ============================================================================
do
    mock.set_time(1.2)  -- past settle_until = 1.1

    local can_close = qi.can_close_gossip()
    assert(can_close == true,
        "S4: expected can_close_gossip=true at t=1.2, got " .. tostring(can_close))
    print("PASS S4: After 1.2s, close is allowed")
end

-- ============================================================================
-- S5: Idempotent re-call returns same accepted_n
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = { make_quest(101, "Quest A") }
    mock.set_time(0)

    local r1 = qi.accept_all_available()
    local r2 = qi.accept_all_available()

    assert(r1 ~= nil, "S5: first call should return table")
    assert(r2 ~= nil, "S5: second call should return table")
    assert(r1.accepted_n == r2.accepted_n,
        "S5: accepted_n changed from " .. tostring(r1.accepted_n) ..
        " to " .. tostring(r2.accepted_n))
    print("PASS S5: Re-call idempotent — accepted_n unchanged")
end

-- ============================================================================
-- S6: 0 available quests → returns nil (no crash)
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = {}
    mock.set_time(0)

    local result = qi.accept_all_available()
    assert(result == nil,
        "S6: expected nil for 0 available quests, got " .. tostring(result))
    print("PASS S6: Empty quest list returns nil (no crash)")
end

print("PASS test_pre_accept_all")
os.exit(0)
