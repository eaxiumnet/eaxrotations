-- What: Unit tests for npc_db_sylvanas.lua find_transport_npc function
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify transport NPC lookup by type with keyword matching

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Override read_data_file with tiny mock dataset (avoids Lua 5.1 constant-table overflow)
core.read_data_file = function(path)
    if path == "tbc_db/creature_spawn_index.json" then
        return '{"by_entry":{'
            .. '"3155":{"name":"Boat Officer","maps":[{"map_id":1,"x":-100,"y":200,"z":30}]},'
            .. '"3626":{"name":"Zeppelin Master","maps":[{"map_id":0,"x":-500,"y":-300,"z":40}]},'
            .. '"3310":{"name":"Gryphon Master (Orgrimmar)","maps":[{"map_id":1,"x":1570,"y":-4400,"z":15}]},'
            .. '"6929":{"name":"Innkeeper Gryshka","maps":[{"map_id":1,"x":1620,"y":-4300,"z":20}]},'
            .. '"5517":{"name":"Blacksmith Trainer","maps":[{"map_id":0,"x":-1000,"y":-500,"z":10}]},'
            .. '"8403":{"name":"General Goods Merchant","maps":[{"map_id":0,"x":-2000,"y":-1000,"z":5}]}}}'
    end
    return nil
end

local npc_db = require("EaxAutoQuester/npc_db_sylvanas")

-- S1: type_hint "flight" → returns flight master
local r1 = npc_db.find_transport_npc("flight", 1)
assert(r1 ~= nil, "S1 FAIL: flight on map 1 should return a flight master")
assert(r1.npc_id == 3310, "S1 FAIL: flight NPC id should be 3310, got " .. tostring(r1.npc_id))
print("  S1 PASS: flight → Gryphon Master (id=3310)")

-- S2: type_hint "inn" → returns innkeeper
local r2 = npc_db.find_transport_npc("inn", 1)
assert(r2 ~= nil, "S2 FAIL: inn on map 1 should return an innkeeper")
assert(r2.npc_id == 6929, "S2 FAIL: inn NPC id should be 6929, got " .. tostring(r2.npc_id))
print("  S2 PASS: inn → Innkeeper Gryshka (id=6929)")

-- S3: type_hint "repair" → returns blacksmith
local r3 = npc_db.find_transport_npc("repair", 0)
assert(r3 ~= nil, "S3 FAIL: repair on map 0 should return a blacksmith")
assert(r3.npc_id == 5517, "S3 FAIL: repair NPC id should be 5517, got " .. tostring(r3.npc_id))
print("  S3 PASS: repair → Blacksmith Trainer (id=5517)")

-- S4: type_hint "vendor" → returns merchant
local r4 = npc_db.find_transport_npc("vendor", 0)
assert(r4 ~= nil, "S4 FAIL: vendor on map 0 should return a merchant")
assert(r4.npc_id == 8403, "S4 FAIL: vendor NPC id should be 8403, got " .. tostring(r4.npc_id))
print("  S4 PASS: vendor → General Goods Merchant (id=8403)")

-- S5: case-insensitive type_hint
local r5 = npc_db.find_transport_npc("FLIGHT", 1)
assert(r5 ~= nil, "S5 FAIL: uppercase 'FLIGHT' should match")
assert(r5.npc_id == 3310, "S5 FAIL: uppercase flight should return 3310")
print("  S5 PASS: case-insensitive type hint works")

-- S6: unknown type → returns nil
local r6 = npc_db.find_transport_npc("unknown_type")
assert(r6 == nil, "S6 FAIL: unknown type should return nil")
print("  S6 PASS: unknown type returns nil")

-- S7: nil type_hint → returns nil
local r7 = npc_db.find_transport_npc(nil)
assert(r7 == nil, "S7 FAIL: nil type_hint should return nil")
print("  S7 PASS: nil type_hint returns nil")

-- S8: no match on wrong map → cross-map fallback returns first match (current behavior)
local r8 = npc_db.find_transport_npc("flight", 99)
assert(r8 ~= nil, "S8 FAIL: flight on non-existent map should return cross-map fallback")
assert(r8.npc_id == 3310, "S8 FAIL: cross-map fallback should return first match (3310)")
print("  S8 PASS: cross-map fallback returns first match (id=3310)")

print("PASS test_transport_helper")
os.exit(0)
