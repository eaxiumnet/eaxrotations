-- What: Unit tests for EaxAutoQuester/npc_db_sylvanas.lua (spawn database)
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NPC spawn lookups, name search, and chunked loading work correctly

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local npc_db = require("EaxAutoQuester/npc_db_sylvanas")

-- Test 1: Find NPC 823 (Deputy Willem) - known to be in Northshire Valley
local deputy = npc_db.find_npc_spawn(823, 0)
assert(deputy ~= nil, "find_npc_spawn(823) should return Deputy Willem")
assert(deputy.name == "Deputy Willem", "NPC 823 should be Deputy Willem, got: " .. tostring(deputy.name))
assert(deputy.map_id == 0, "Deputy Willem should be on map 0 (Eastern Kingdoms)")
assert(deputy.x < -8000 and deputy.x > -10000, "Deputy Willem x should be in Northshire range, got: " .. tostring(deputy.x))
assert(deputy.y > -200 and deputy.y < 200, "Deputy Willem y should be in Northshire range, got: " .. tostring(deputy.y))
print("  Test 1 PASS: Deputy Willem found at (" .. deputy.x .. ", " .. deputy.y .. ", " .. deputy.z .. ")")

-- Test 2: Find NPC 240 (Marshal Dughan) - Goldshire
local dughan = npc_db.find_npc_spawn(240, 0)
assert(dughan ~= nil, "find_npc_spawn(240) should return Marshal Dughan")
assert(dughan.name == "Marshal Dughan", "NPC 240 should be Marshal Dughan, got: " .. tostring(dughan.name))
print("  Test 2 PASS: Marshal Dughan found at (" .. dughan.x .. ", " .. dughan.y .. ")")

-- Test 3: Find NPC with no map filter (should still work)
local any = npc_db.find_npc_spawn(823, nil)
assert(any ~= nil, "find_npc_spawn(823, nil) should still work")
print("  Test 3 PASS: NPC lookup without map filter works")

-- Test 4: Find non-existent NPC
local missing = npc_db.find_npc_spawn(99999999, 0)
assert(missing == nil, "find_npc_spawn for invalid NPC should return nil")
print("  Test 4 PASS: Non-existent NPC returns nil")

-- Test 5: Find with nil NPC ID
local nil_result = npc_db.find_npc_spawn(nil, 0)
assert(nil_result == nil, "find_npc_spawn(nil) should return nil")
print("  Test 5 PASS: nil NPC ID returns nil")

-- Test 6: Search by name
local results = npc_db.search_npc_by_name("Deputy")
assert(#results > 0, "Search for 'Deputy' should find at least 1 NPC")
local found_823 = false
for i = 1, #results do
    if results[i].npc_id == 823 then
        found_823 = true
        break
    end
end
assert(found_823, "Search for 'Deputy' should find NPC 823 (Deputy Willem)")
print("  Test 6 PASS: Name search found " .. #results .. " NPCs including Deputy Willem")

-- Test 7: Search for non-existent name
local no_results = npc_db.search_npc_by_name("NonExistentNPC12345")
assert(#no_results == 0, "Search for non-existent name should return 0 results")
print("  Test 7 PASS: Non-existent name returns 0 results")

-- Test 8: Search with nil/empty string
local empty_results = npc_db.search_npc_by_name(nil)
assert(#empty_results == 0, "Search with nil should return 0 results")
local empty2 = npc_db.search_npc_by_name("")
assert(#empty2 == 0, "Search with empty string should return 0 results")
print("  Test 8 PASS: nil/empty search returns 0 results")

-- Test 9: Verify chunks load on demand (sample known NPCs from each range)
local n100 = npc_db.find_npc_spawn(100, 0)
assert(n100 ~= nil and n100.name == "Gruff Swiftbite", "NPC 100 (early range) should load")
local n2987 = npc_db.find_npc_spawn(2987, 0)
assert(n2987 ~= nil and n2987.name == "Eyahn Eagletalon", "NPC 2987 (mid range) should load")
local n5831 = npc_db.find_npc_spawn(5831, 0)
assert(n5831 ~= nil and n5831.name == "Swiftmane", "NPC 5831 (chunk 2) should load")
local n11715 = npc_db.find_npc_spawn(11715, 0)
assert(n11715 ~= nil and n11715.name == "Talendria", "NPC 11715 (chunk 5) should load")
local n18000 = npc_db.find_npc_spawn(18000, 0)
assert(n18000 ~= nil and n18000.name == "Serpent Steam Pump Credit Marker", "NPC 18000 (chunk 6) should load")
print("  Test 9 PASS: NPCs from all chunks load correctly")

-- Test 10: Verify NPC IDs > 14000 (last chunk) still work
local high_id = 14000
local found = false
for id = 14000, 18000 do
    local r = npc_db.find_npc_spawn(id, 0)
    if r then
        found = true
        break
    end
end
assert(found, "Should find at least one NPC in range 14000-18000")
print("  Test 10 PASS: High NPC IDs (chunk 6) load correctly")

print("PASS test_npc_db")
os.exit(0)
