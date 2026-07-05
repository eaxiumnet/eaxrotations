-- test_quest_tracker.lua — Unit tests for the quest tracker module.

local QuestTracker = require("fishing/quest_tracker")

local assertions = 0
local failures = 0

local function CHECK(cond, msg)
    assertions = assertions + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. msg)
    end
end

-- TQ1: module exposes expected API
CHECK(type(QuestTracker) == "table", "QuestTracker is a table")
CHECK(type(QuestTracker.detect_quest_fish) == "function", "detect_quest_fish is a function")
CHECK(type(QuestTracker.get_quest_pools) == "function", "get_quest_pools is a function")
CHECK(type(QuestTracker.is_quest_pool) == "function", "is_quest_pool is a function")
CHECK(type(QuestTracker.update) == "function", "update is a function")
CHECK(type(QuestTracker.reset) == "function", "reset is a function")

-- TQ2: is_quest_pool matches correct pool names
CHECK(QuestTracker.is_quest_pool("Bloodtooth Frenzy School", 27437) == true, "Bloodtooth Frenzy School matches quest 27437")
CHECK(QuestTracker.is_quest_pool("Feltail School", 27438) == true, "Feltail School matches quest 27438")
CHECK(QuestTracker.is_quest_pool("Sporefish School", 27439) == true, "Sporefish School matches quest 27439")

-- TQ3: is_quest_pool returns false for non-matching pools
CHECK(QuestTracker.is_quest_pool("Furious Crawdad School", 27437) == false, "Crawdad School does NOT match quest 27437")
CHECK(QuestTracker.is_quest_pool(nil, 27437) == false, "nil pool name returns false")
CHECK(QuestTracker.is_quest_pool("Test Pool", nil) == false, "nil quest_fish_id returns false")

-- TQ4: get_quest_pools returns table for known quest fish
local pools = QuestTracker.get_quest_pools(27437)
CHECK(type(pools) == "table", "get_quest_pools returns table for known quest fish")
CHECK(pools ~= nil and #pools > 0, "quest pools list is non-empty")

-- TQ5: get_quest_pools returns nil for unknown quest fish
CHECK(QuestTracker.get_quest_pools(99999) == nil, "get_quest_pools returns nil for unknown quest fish")

-- TQ6: detect_quest_fish returns nil under unit test (no API)
local ctx = { state = { quest = { last_check_time = 0 } }, deps = { config = { menu = {} } } }
local quest_id = QuestTracker.detect_quest_fish(ctx)
CHECK(quest_id == nil, "detect_quest_fish returns nil with no API")

-- TQ7: reset zeroes all state fields
local state = { quest = { quest_fish_id = 27437, quest_fish_name = "Bloodtooth", last_check_time = 999 } }
QuestTracker.reset(state)
CHECK(state.quest.quest_fish_id == nil, "reset clears quest_fish_id")
CHECK(state.quest.quest_fish_name == nil, "reset clears quest_fish_name")
CHECK(state.quest.last_check_time == 0.0, "reset zeroes last_check_time")

print(string.format("PASS test_quest_tracker (%d assertions, %d failures)", assertions, failures))
return { assertions = assertions, failures = failures }
