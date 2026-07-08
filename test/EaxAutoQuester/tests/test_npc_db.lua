-- What: Unit tests for EaxAutoQuester/npc_db_sylvanas.lua (spawn database)
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NPC spawn lookups, name search, and data loading

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Override read_data_file to return a tiny mock dataset (avoids Lua 5.1 constant-table overflow on 7MB real JSON)
core.read_data_file = function(path)
    if path == "tbc_db/creature_spawn_index.json" then
        return '{"by_entry":{"823":{"name":"Deputy Willem","maps":[{"map_id":0,"x":-8900,"y":-100,"z":80}]},'
            .. '"240":{"name":"Marshal Dughan","maps":[{"map_id":0,"x":-9500,"y":-100,"z":60}]},'
            .. '"100":{"name":"Gruff Swiftbite","maps":[{"map_id":0,"x":0,"y":0,"z":0}]},'
            .. '"2987":{"name":"Eyahn Eagletalon","maps":[{"map_id":1,"x":100,"y":200,"z":30}]},'
            .. '"5831":{"name":"Swiftmane","maps":[{"map_id":1,"x":500,"y":600,"z":40}]},'
            .. '"11715":{"name":"Talendria","maps":[{"map_id":0,"x":200,"y":300,"z":50}]},'
            .. '"18000":{"name":"Serpent Steam Pump Credit Marker","maps":[{"map_id":0,"x":300,"y":400,"z":60}]}}}'
    end
    return nil
end

local npc_db = require("EaxAutoQuester/npc_db_sylvanas")

-- Test 1: Find NPC 823 (Deputy Willem)
local deputy = npc_db.find_npc_spawn(823, 0)
assert(deputy ~= nil, "find_npc_spawn(823) should return Deputy Willem")
assert(deputy.name == "Deputy Willem", "NPC 823 should be Deputy Willem, got: " .. tostring(deputy.name))
assert(deputy.map_id == 0, "Deputy Willem should be on map 0")
assert(deputy.x == -8900, "Deputy Willem x mismatch, got: " .. tostring(deputy.x))
print("  Test 1 PASS: Deputy Willem found")

-- Test 2: Find NPC 240 (Marshal Dughan)
local dughan = npc_db.find_npc_spawn(240, 0)
assert(dughan ~= nil, "find_npc_spawn(240) should return Marshal Dughan")
assert(dughan.name == "Marshal Dughan", "NPC 240 should be Marshal Dughan, got: " .. tostring(dughan.name))
print("  Test 2 PASS: Marshal Dughan found")

-- Test 3: Find NPC with no map filter
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
-- Empty string matches every name (find("", 1, true) matches at pos 1)
local empty2 = npc_db.search_npc_by_name("")
assert(#empty2 > 0, "Search with empty string should return all entries, got " .. tostring(#empty2))
print("  Test 8 PASS: nil returns 0, empty string returns all entries")

-- Test 9: Verify NPCs from various ranges
local n100 = npc_db.find_npc_spawn(100, 0)
assert(n100 ~= nil and n100.name == "Gruff Swiftbite", "NPC 100 should load")
local n2987 = npc_db.find_npc_spawn(2987, 1)
assert(n2987 ~= nil and n2987.name == "Eyahn Eagletalon", "NPC 2987 should load")
local n5831 = npc_db.find_npc_spawn(5831, 1)
assert(n5831 ~= nil and n5831.name == "Swiftmane", "NPC 5831 should load")
local n11715 = npc_db.find_npc_spawn(11715, 0)
assert(n11715 ~= nil and n11715.name == "Talendria", "NPC 11715 should load")
local n18000 = npc_db.find_npc_spawn(18000, 0)
assert(n18000 ~= nil and n18000.name == "Serpent Steam Pump Credit Marker", "NPC 18000 should load")
print("  Test 9 PASS: NPCs from all ranges load correctly")

print("PASS test_npc_db")
os.exit(0)
