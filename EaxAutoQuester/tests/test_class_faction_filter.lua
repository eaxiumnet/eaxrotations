-- What: Unit tests for EaxAutoQuester/goal_filter_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify goal filtering by quest completion, level, class, and faction
-- API: core.quests.is_quest_flagged_completed, me:get_level(), me:get_class(), me:get_faction_id()
-- Safety: All goals nil-guarded; mock player extended for level/faction in test setup only

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- ============================================================================
-- Mock extensions (test setup only — not modifying mock_core.lua)
-- ============================================================================

-- Add is_quest_flagged_completed to mock quests
mock.quests.is_quest_flagged_completed = function(id)
    return mock._quest_completed and mock._quest_completed[id] or false
end

-- Helper: create player with level and faction support
local function make_player(opts)
    opts = opts or {}
    opts.level = opts.level or 60
    opts.faction_id = opts.faction_id or 0
    local player = mock.create_player(opts)
    player._level = opts.level
    player.get_level = function() return player._level end
    player._faction_id = opts.faction_id
    player.get_faction_id = function() return player._faction_id end
    return player
end

-- ============================================================================
-- The module under test does not exist yet → will fail at require (RED)
-- ============================================================================

local filter = require("EaxAutoQuester/goal_filter_sylvanas")

-- ============================================================================
-- S1 — Quest already completed → (false, "completed")
-- ============================================================================
do
    mock._quest_completed = { [9526] = true }
    local me = make_player({ class = 1, level = 60, faction_id = 0 })
    local passes, reason = filter.passes({ quest_id = 9526 }, me)
    assert(passes == false, "S1 FAIL: completed quest should be filtered. Got passes=" .. tostring(passes))
    assert(reason == "completed", "S1 FAIL: reason should be 'completed'. Got " .. tostring(reason))
    print("  S1 PASS: completed quest → (false, 'completed')")
end

-- ============================================================================
-- S2 — Level too low → (false, "level_too_low")
-- ============================================================================
do
    mock._quest_completed = {}
    local me = make_player({ class = 1, level = 10, faction_id = 0 })
    local passes, reason = filter.passes({ quest_id = 100, min_level = 60 }, me)
    assert(passes == false, "S2 FAIL: level too low should be filtered. Got passes=" .. tostring(passes))
    assert(reason == "level_too_low", "S2 FAIL: reason should be 'level_too_low'. Got " .. tostring(reason))
    print("  S2 PASS: level too low → (false, 'level_too_low')")
end

-- ============================================================================
-- S3 — Class mismatch (goal.class=1 Warrior, me class=5 Priest) → (false, "class_mismatch")
-- ============================================================================
do
    mock._quest_completed = {}
    local me = make_player({ class = 5, level = 60, faction_id = 0 })  -- Priest
    local passes, reason = filter.passes({ quest_id = 100, min_level = nil, class = 1 }, me)  -- Warrior goal
    assert(passes == false, "S3 FAIL: class mismatch should be filtered. Got passes=" .. tostring(passes))
    assert(reason == "class_mismatch", "S3 FAIL: reason should be 'class_mismatch'. Got " .. tostring(reason))
    print("  S3 PASS: class mismatch → (false, 'class_mismatch')")
end

-- ============================================================================
-- S4 — Faction mismatch (goal.faction=1 Horde, me faction_id=0 Alliance) → (false, "faction_mismatch")
-- ============================================================================
do
    mock._quest_completed = {}
    local me = make_player({ class = 1, level = 60, faction_id = 0 })  -- Alliance
    local passes, reason = filter.passes({ quest_id = 100, faction = 1 }, me)  -- Horde goal
    assert(passes == false, "S4 FAIL: faction mismatch should be filtered. Got passes=" .. tostring(passes))
    assert(reason == "faction_mismatch", "S4 FAIL: reason should be 'faction_mismatch'. Got " .. tostring(reason))
    print("  S4 PASS: faction mismatch → (false, 'faction_mismatch')")
end

-- ============================================================================
-- S5 — All conditions pass → (true, nil)
-- ============================================================================
do
    mock._quest_completed = {}
    local me = make_player({ class = 1, level = 60, faction_id = 0 })
    local passes, reason = filter.passes({ quest_id = 100, faction = 0 }, me)
    assert(passes == true, "S5 FAIL: all conditions pass should be true. Got passes=" .. tostring(passes))
    assert(reason == nil, "S5 FAIL: reason should be nil. Got " .. tostring(reason))
    print("  S5 PASS: all conditions pass → (true, nil)")
end

print("PASS test_class_faction_filter")
os.exit(0)
