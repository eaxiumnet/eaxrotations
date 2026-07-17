-- test_wotlk_leveling_ladders.lua — WotLK 1–80 leveling ladder coverage.
-- WHAT:  Loads every *_wotlk.lua leveling rotation and asserts at least one
--        strategy matches at levels 10/30/50/60/70/80.
-- WHEN:  run_leveling_tests.lua suite.
-- WHY:   Proves no dead rotation at any WotLK leveling band (incl. Death Knight).
-- SAFETY: Pure mocks via leveling_ladder_helper; no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/tests/?.lua;./?.lua;"
    .. (package.path or "")

local H = require("leveling_ladder_helper")

local LEVELS = { 10, 30, 50, 60, 70, 80 }

local FILES = {
    "EaxRotations/classes/warrior/leveling_wotlk.lua",
    "EaxRotations/classes/paladin/leveling_wotlk.lua",
    "EaxRotations/classes/hunter/leveling_wotlk.lua",
    "EaxRotations/classes/rogue/leveling_wotlk.lua",
    "EaxRotations/classes/priest/leveling_wotlk.lua",
    "EaxRotations/classes/mage/leveling_wotlk.lua",
    "EaxRotations/classes/warlock/leveling_wotlk.lua",
    "EaxRotations/classes/druid/leveling_wotlk.lua",
    "EaxRotations/classes/shaman/leveling_wotlk.lua",
    "EaxRotations/classes/deathknight/leveling_wotlk.lua",
}

local passed, total = 0, 0
local failures = {}

for _, path in ipairs(FILES) do
    total = total + 1
    local failures_for_path = H.run_ladder(path, LEVELS)
    if #failures_for_path == 0 then
        passed = passed + 1
    else
        failures[#failures + 1] = path .. " :: levels " .. table.concat(failures_for_path, ",")
    end
end

print("=== test_wotlk_leveling_ladders ===")
print("PASS " .. passed .. "/" .. total)
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f)
    end
    error("test_wotlk_leveling_ladders failed", 0)
end
