-- test_tbc_leveling_ladders.lua — TBC 1–70 leveling ladder coverage.
-- WHAT:  Loads every *_sylvanas.lua leveling rotation and asserts at least one
--        strategy matches at levels 10/20/30/40/50/60/70.
-- WHEN:  run_leveling_tests.lua suite.
-- WHY:   Proves no dead rotation at any TBC leveling band (Scenario 5).
-- SAFETY: Pure mocks via leveling_ladder_helper; no real API calls.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/tests/?.lua;./?.lua;"
    .. (package.path or "")

local H = require("leveling_ladder_helper")

local LEVELS = { 10, 20, 30, 40, 50, 60, 70 }

local FILES = {
    "EaxRotations/classes/warrior/leveling_sylvanas.lua",
    "EaxRotations/classes/paladin/leveling_sylvanas.lua",
    "EaxRotations/classes/hunter/leveling_sylvanas.lua",
    "EaxRotations/classes/rogue/leveling_sylvanas.lua",
    "EaxRotations/classes/priest/leveling_sylvanas.lua",
    "EaxRotations/classes/mage/leveling_sylvanas.lua",
    "EaxRotations/classes/warlock/leveling_sylvanas.lua",
    "EaxRotations/classes/druid/leveling_sylvanas.lua",
    "EaxRotations/classes/shaman/leveling_sylvanas.lua",
}

local passed, total = 0, 0
local failures = {}

for _, path in ipairs(FILES) do
    total = total + 1
    local ok, failures_for_path = pcall(H.run_ladder, path, LEVELS)
    if not ok then
        failures[#failures + 1] = path .. " :: load error: " .. tostring(failures_for_path)
    elseif #failures_for_path == 0 then
        passed = passed + 1
    else
        failures[#failures + 1] = path .. " :: levels " .. table.concat(failures_for_path, ",")
    end
end

print("=== test_tbc_leveling_ladders ===")
print("PASS " .. passed .. "/" .. total)
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f)
    end
    error("test_tbc_leveling_ladders failed", 0)
end
