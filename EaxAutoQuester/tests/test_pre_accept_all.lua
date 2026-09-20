-- What: Tests for accept_all_available / turn_in_completable framed quest selection
-- When: Run via run_quester_tests.lua
-- Why: A gossip frame's quest_id is a 1-BASED ROW INDEX on the private-server builds
--      (.api/core.lua, "GOSSIP ACROSS GAME VERSIONS"), so it addresses only the frame
--      it was read from: selecting an entry rebuilds that list and the rows renumber.
--      These tests pin two separate guarantees:
--        (1) the id passed to the selector is each entry's OWN quest_id, never its
--            position (S2, non-sequential ids);
--        (2) each selection re-resolves from a FRESH read, so a snapshot taken before
--            an earlier selection cannot address the wrong row or miss one (S4/S5).
--      S4 and S5 fail against a snapshot walk; S2 fails against an index-based select.
-- Safety: No io.popen, os.execute, ffi.C, math.sqrt, debug.*

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Load module under test once (test runner isolates per-file via snapshot/restore)
local qi = require("quest_interaction_sylvanas")

-- The mock's selectors are replaced by recorders per scenario; they are fields of the
-- same table the module cached at load, so restore them explicitly afterwards.
local REAL_SELECT_AVAILABLE = mock.quests.select_gossip_available_quest
local REAL_SELECT_ACTIVE = mock.quests.select_gossip_active_quest

-- Helper: create a gossip quest entry
local function make_quest(id, title, complete)
    return { quest_id = id, title = title, is_complete = complete or false }
end

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
-- S2: non-sequential ids → each selection carries the entry's own quest_id
--     (an index-based selection passes 1,2,3 here and fails)
-- ============================================================================
do
    mock.reset()
    mock._gossip_available = {
        make_quest(101, "Quest A"),
        make_quest(205, "Quest B"),
        make_quest(309, "Quest C"),
    }

    local seen = {}
    mock.quests.select_gossip_available_quest = function(id)
        seen[#seen + 1] = id
    end
    mock.set_time(0)

    local result = qi.accept_all_available()
    mock.quests.select_gossip_available_quest = REAL_SELECT_AVAILABLE

    assert(result ~= nil, "S2: should return an action string with 3 quests")
    assert(result:find("Quest A") and result:find("Quest B") and result:find("Quest C"),
        "S2: action string should name all three quests, got " .. tostring(result))
    assert(#seen == 3,
        "S2: expected 3 selections, got " .. tostring(#seen) .. " (" .. tostring(seen[1]) ..
        "," .. tostring(seen[2]) .. "," .. tostring(seen[3]) .. ")")
    assert(seen[1] == 101 and seen[2] == 205 and seen[3] == 309,
        "S2: selections must pass each entry's own quest_id (101,205,309), not its row " ..
        "position (1,2,3); got " .. tostring(seen[1]) .. "," .. tostring(seen[2]) ..
        "," .. tostring(seen[3]))
    print("PASS S2: non-sequential ids passed through, never the row position")
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

-- ============================================================================
-- S4: the frame is rebuilt by every selection — private-server semantics, where
--     quest_id IS the row index and consuming a row renumbers the rest.
--     Walking a snapshot captured before the first selection picks the WRONG row
--     for the second quest and then misses entirely; re-reading per step picks
--     each offered quest exactly once.
-- ============================================================================
do
    mock.reset()
    local frame = {
        make_quest(1, "Quest A"),
        make_quest(2, "Quest B"),
        make_quest(3, "Quest C"),
    }
    mock._gossip_available = frame

    local selected_titles, misses = {}, 0
    mock.quests.select_gossip_available_quest = function(id)
        for i = 1, #frame do
            if frame[i].quest_id == id then
                selected_titles[#selected_titles + 1] = frame[i].title
                table.remove(frame, i)
                -- Row indexes renumber after a selection on these builds.
                for j = 1, #frame do frame[j].quest_id = j end
                return
            end
        end
        misses = misses + 1   -- addressed a row the rebuilt frame no longer has
    end
    mock.set_time(0)

    local result = qi.accept_all_available()
    mock.quests.select_gossip_available_quest = REAL_SELECT_AVAILABLE

    local joined = table.concat(selected_titles, ",")
    assert(joined == "Quest A,Quest B,Quest C",
        "S4: every offered quest must be selected exactly once, in order — got '" ..
        joined .. "' (a stale snapshot skips a quest or takes the wrong one)")
    assert(misses == 0,
        "S4: no selection may address a row the rebuilt frame does not have; misses=" ..
        tostring(misses))
    assert(result ~= nil, "S4: expected an action string")
    print("PASS S4: re-reads the frame per selection (stale row indexes fail here)")
end

-- ============================================================================
-- S5: same guarantee for the turn-in list, which shares the selection helper and
--     additionally filters on is_complete.
-- ============================================================================
do
    mock.reset()
    local frame = {
        make_quest(1, "Done A", true),
        make_quest(2, "Not done", false),
        make_quest(3, "Done B", true),
    }
    mock._gossip_active = frame

    local selected_titles, misses, skipped_incomplete = {}, 0, 0
    mock.quests.select_gossip_active_quest = function(id)
        for i = 1, #frame do
            if frame[i].quest_id == id then
                if not frame[i].is_complete then skipped_incomplete = skipped_incomplete + 1 end
                selected_titles[#selected_titles + 1] = frame[i].title
                table.remove(frame, i)
                for j = 1, #frame do frame[j].quest_id = j end
                return
            end
        end
        misses = misses + 1
    end
    mock.set_time(0)

    local result = qi.turn_in_completable()
    mock.quests.select_gossip_active_quest = REAL_SELECT_ACTIVE

    local joined = table.concat(selected_titles, ",")
    assert(joined == "Done A,Done B",
        "S5: turn-in must select each complete quest exactly once, in order — got '" ..
        joined .. "'")
    assert(misses == 0,
        "S5: no turn-in selection may address a missing row; misses=" .. tostring(misses))
    assert(skipped_incomplete == 0,
        "S5: an incomplete active quest must never be selected; got " ..
        tostring(skipped_incomplete))
    assert(result ~= nil, "S5: expected an action string")
    print("PASS S5: turn-in re-reads the frame per selection")
end

print("PASS test_pre_accept_all")
os.exit(0)
