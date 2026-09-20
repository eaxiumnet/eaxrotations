-- test_quest_log_manager.lua — Unit tests for quest_log_manager_sylvanas

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- ============================================================================
-- Mock helpers
-- ============================================================================

local function set_quest_log(entries)
    mock._quest_log = entries or {}
    core.quests.get_num_quest_log_entries = function() return #mock._quest_log end
    core.quests.get_quest_log_title = function(index)
        return mock._quest_log[index] or nil
    end
end

-- ============================================================================
-- S1: scan_quest_log filters headers, returns correct metadata
-- ============================================================================
package.loaded["quest_log_manager_sylvanas"] = nil
local qm = require("quest_log_manager_sylvanas")

mock.reset()
mock.set_time(10.0)
local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, get_level = 30 })
mock._player = me

-- Build a log with 20+ entries to trigger the abandon threshold
local big_log = { { title = "Elwynn Forest", is_header = true } }
for i = 1, 22 do
    big_log[#big_log + 1] = { title = "Quest " .. i, quest_id = i, level = 25, is_complete = false, is_header = false }
end
-- Add one grey quest
big_log[#big_log + 1] = { title = "Collect Apples", quest_id = 99, level = 10, is_complete = false, is_header = false }
set_quest_log(big_log)

local quests = qm.scan_quest_log()
assert(#quests == 23, "S1a FAIL: should skip header, got " .. tostring(#quests) .. " quests")
assert(quests[1].quest_id == 1, "S1b FAIL")
assert(quests[23].is_grey == true, "S1c FAIL: level 10 vs player 30 should be grey")
assert(quests[1].is_grey == false, "S1d FAIL: level 25 vs player 30 should not be grey")
assert(quests[23].is_complete == false, "S1e FAIL")
print("  S1 PASS: scan_quest_log filters headers, computes grey")

-- ============================================================================
-- S2: find_grey_quests returns only incomplete grey
-- ============================================================================
local grey = qm.find_grey_quests()
assert(#grey == 1, "S2a FAIL: expected 1 grey, got " .. tostring(#grey))
assert(grey[1].quest_id == 99, "S2b FAIL")
print("  S2 PASS: find_grey_quests")

-- ============================================================================
-- S3: maintenance_check abandons when threshold exceeded
-- ============================================================================
mock._input_calls = {}
mock.set_time(40.0)  -- past the 30s throttle interval
local abandoned = qm.maintenance_check()
assert(abandoned == 1, "S3a FAIL: expected 1 abandoned, got " .. tostring(abandoned))
local found = false
for _, call in ipairs(mock._input_calls) do
    if call[1] == "set_abandon_quest" then found = true end
end
assert(found, "S3b FAIL: set_abandon_quest should be called")
print("  S3 PASS: maintenance_check abandons grey quest")

-- ============================================================================
-- S4: blacklist prevents re-abandon
-- ============================================================================
mock._input_calls = {}
abandoned = qm.maintenance_check()
assert(abandoned == 0, "S4 FAIL: should not abandon same quest again")
print("  S4 PASS: blacklist prevents re-abandon")

-- ============================================================================
-- S5: no abandonment when log below threshold
-- ============================================================================
package.loaded["quest_log_manager_sylvanas"] = nil
qm = require("quest_log_manager_sylvanas")
mock._input_calls = {}
set_quest_log({
    { title = "Collect Apples", quest_id = 2, level = 10, is_complete = false, is_header = false },
})
abandoned = qm.maintenance_check()
assert(abandoned == 0, "S5 FAIL: below threshold, should not abandon")
print("  S5 PASS: below threshold → no action")

-- ============================================================================
-- S6: abandoning while the log compacts must act on fresh indexes
-- The quest log is index addressed, 1 based (game-ui.md:1455). Each abandonment
-- REMOVES an entry and renumbers the rest, so indexes captured in one scan are
-- stale for the next abandon — a snapshot walk then abandons a quest that was
-- never grey. The greys here sit at positions 2, 5 and 9 of 24 entries.
-- ============================================================================
package.loaded["quest_log_manager_sylvanas"] = nil
qm = require("quest_log_manager_sylvanas")
mock.reset()
mock._player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, get_level = 30 })

local GREY_IDS = { [2] = 902, [5] = 905, [9] = 909 }
local compact_log = {}
for pos = 1, 24 do
    local grey_id = GREY_IDS[pos]
    compact_log[pos] = {
        title = grey_id and ("Grey " .. grey_id) or ("Keep " .. tostring(1000 + pos)),
        quest_id = grey_id or (1000 + pos),
        level = grey_id and 10 or 25,
        is_complete = false,
        is_header = false,
    }
end
set_quest_log(compact_log)
mock._quest_log_compacts = true
mock._input_calls = {}
mock.set_time(80.0)  -- fresh module, so any time clears the 30s throttle

-- set_quest_log hands the mock the same table, and the mock mutates it when an
-- abandonment lands, so snapshot the ids before the run.
local before_ids = {}
for pos = 1, 24 do before_ids[pos] = compact_log[pos].quest_id end

local remaining = {}
abandoned = qm.maintenance_check()
for _, entry in ipairs(mock._quest_log) do remaining[entry.quest_id] = true end

local removed = {}
for _, id in ipairs(before_ids) do
    if not remaining[id] then removed[#removed + 1] = id end
end
table.sort(removed)

assert(abandoned == 3, "S6a FAIL: expected 3 abandons, got " .. tostring(abandoned))
assert(#removed == 3 and removed[1] == 902 and removed[2] == 905 and removed[3] == 909,
    "S6b FAIL: only the grey quests may be removed, removed: " .. table.concat(removed, ","))
print("  S6 PASS: each abandon uses a freshly read log index")

print("PASS test_quest_log_manager")
os.exit(0)
