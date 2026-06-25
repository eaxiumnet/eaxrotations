-- What: Unit tests for npc_db_sylvanas.lua find_transport_npc function
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify transport NPC lookup by zone with keyword matching and kind classification

-- Preload mock spawn module with 3 transport NPCs
local mock_spawns_db = {
    { npc_id = 3155, name = "Boat Officer", map_id = 1, x = -100, y = 200, z = 30 },
    { npc_id = 3626, name = "Zeppelin Master", map_id = 0, x = -500, y = -300, z = 40 },
    { npc_id = 3310, name = "Gryphon Master (Orgrimmar)", map_id = 1, x = 1570, y = -4400, z = 15 },
}

local mock_spawn_module = {
    find_npc_spawn = function() return nil end,  -- needed for ensure_spawn_module() check
    search_npc_by_name = function(search)
        if not search or search == "" then return {} end
        local search_lower = string.lower(search)
        local results = {}
        for _, entry in ipairs(mock_spawns_db) do
            if string.find(string.lower(entry.name or ""), search_lower, 1, true) then
                results[#results + 1] = entry
            end
        end
        return results
    end,
}
package.loaded["EaxAutoQuester.npc_spawns"] = mock_spawn_module

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local npc_db = require("EaxAutoQuester/npc_db_sylvanas")

-- S1: zone_hint "Ratchet" → returns boat NPC (map 1, kind="boat")
do
    local r = npc_db.find_transport_npc("Ratchet")
    assert(r ~= nil, "S1 FAIL: Ratchet should return a transport NPC")
    assert(r.kind == "boat", "S1 FAIL: Ratchet kind should be boat, got " .. tostring(r.kind))
    assert(r.npc_id == 3155, "S1 FAIL: Ratchet NPC id should be 3155, got " .. tostring(r.npc_id))
    assert(r.map_id == 1, "S1 FAIL: Ratchet map_id should be 1, got " .. tostring(r.map_id))
    print("  S1 PASS: Ratchet → boat NPC (id=3155)")
end

-- S2: zone_hint "Stranglethorn" → returns zeppelin NPC (map 0, kind="zeppelin")
do
    local r = npc_db.find_transport_npc("Stranglethorn")
    assert(r ~= nil, "S2 FAIL: Stranglethorn should return a transport NPC")
    assert(r.kind == "zeppelin", "S2 FAIL: Stranglethorn kind should be zeppelin, got " .. tostring(r.kind))
    assert(r.npc_id == 3626, "S2 FAIL: Stranglethorn NPC id should be 3626, got " .. tostring(r.npc_id))
    print("  S2 PASS: Stranglethorn → zeppelin NPC (id=3626)")
end

-- S3: zone_hint "Orgrimmar" → returns flight master (map 1, kind="flight")
do
    local r = npc_db.find_transport_npc("Orgrimmar")
    assert(r ~= nil, "S3 FAIL: Orgrimmar should return a transport NPC")
    assert(r.kind == "flight", "S3 FAIL: Orgrimmar kind should be flight, got " .. tostring(r.kind))
    assert(r.npc_id == 3310, "S3 FAIL: Orgrimmar NPC id should be 3310, got " .. tostring(r.npc_id))
    print("  S3 PASS: Orgrimmar → flight NPC (id=3310)")
end

-- S4: zone_hint "Unknown Zone" → returns nil
do
    local r = npc_db.find_transport_npc("Unknown Zone")
    assert(r == nil, "S4 FAIL: Unknown Zone should return nil, got " .. tostring(r and r.name))
    print("  S4 PASS: Unknown Zone → nil")
end

-- S5: case-insensitive: "ratchet" lowercase → same as S1
do
    local r = npc_db.find_transport_npc("ratchet")
    assert(r ~= nil, "S5 FAIL: lowercase 'ratchet' should return a transport NPC")
    assert(r.kind == "boat", "S5 FAIL: 'ratchet' kind should be boat, got " .. tostring(r.kind))
    assert(r.npc_id == 3155, "S5 FAIL: 'ratchet' NPC id should be 3155, got " .. tostring(r.npc_id))
    print("  S5 PASS: 'ratchet' lowercase → boat NPC (case-insensitive match)")
end

print("PASS test_transport_helper")
os.exit(0)
