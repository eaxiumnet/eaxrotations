-- What: Unit tests for npc_db_sylvanas.lua find_transport_npc function
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify transport NPC lookup by type with keyword matching

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

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
            .. '"8403":{"name":"General Goods Merchant","maps":[{"map_id":0,"x":-2000,"y":-1000,"z":5}]},'
            .. '"9001":{"name":"Near Flight Master","maps":[{"map_id":7,"x":10,"y":0,"z":0}]},'
            .. '"9002":{"name":"Far Flight Master","maps":[{"map_id":7,"x":1000,"y":0,"z":0}]},'
            .. '"9003":{"name":"Other Map Flight Master","maps":[{"map_id":8,"x":0,"y":0,"z":0}]},'
            .. '"9011":{"name":"Near Innkeeper","maps":[{"map_id":7,"x":12,"y":0,"z":0}]},'
            .. '"9012":{"name":"Far Innkeeper","maps":[{"map_id":7,"x":1200,"y":0,"z":0}]},'
            .. '"9013":{"name":"Other Map Innkeeper","maps":[{"map_id":8,"x":0,"y":0,"z":0}]},'
            .. '"9021":{"name":"Near General Goods Merchant","maps":[{"map_id":7,"x":14,"y":0,"z":0}]},'
            .. '"9022":{"name":"Far General Goods Merchant","maps":[{"map_id":7,"x":1400,"y":0,"z":0}]},'
            .. '"9023":{"name":"Other Map General Goods Merchant","maps":[{"map_id":8,"x":0,"y":0,"z":0}]}}}'
    end
    return nil
end

local npc_db = require("npc_db_sylvanas")

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

-- S8: no match on the requested map → another-map spawns are unreachable
local r8 = npc_db.find_transport_npc("flight", 99)
assert(r8 == nil, "S8 FAIL: a transport NPC on another map must not be returned")
print("  S8 PASS: another-map transport is not a fallback")

-- S9: same-map candidates are ranked by the player's position, not table order
mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
mock._map_id = 7
local r9 = npc_db.find_transport_npc("flight", 7, mock._player:get_position())
assert(r9 ~= nil and r9.npc_id == 9001,
    "S9 FAIL: nearest local flight master should be selected")
local r10 = npc_db.find_transport_npc("inn", 7, mock._player:get_position())
assert(r10 ~= nil and r10.npc_id == 9011,
    "S9 FAIL: nearest local innkeeper should be selected")
local r11 = npc_db.find_transport_npc("vendor", 7, mock._player:get_position())
assert(r11 ~= nil and r11.npc_id == 9021,
    "S9 FAIL: nearest local vendor should be selected")
print("  S9 PASS: local transport selection uses player distance")

-- =============================================================================
-- S10-S12: the real IDLE/coordinator callers must carry locality through.
-- These scenarios use the production npc_db module, not a stubbed transport result.
-- =============================================================================
local idle_state = require("quest_state/idle_state")
local function new_idle_shared()
    return {
        _interact_cooldown = 0, _loot_cooldown = 0, _last_cooldown_log = 0,
        _post_interact_timer = 0, _at_quest_object_timer = 0, _debug = false,
        _last_step_num = 0, _nav_retries = 0, _area_fail_count = 0,
        _visited_waypoints = {}, _sweep_lap_at = 0, _respawn_wait_until = 0,
        _respawn_last_scan = 0, _nav_destination = nil,
    }
end

local function run_idle_transport(step_text, map_id)
    mock.reset()
    local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 100 })
    mock._map_id = map_id
    local utils = require("utils_sylvanas")
    local step = { text = step_text, is_complete = false, goals = {}, step_num = 700 }
    local ctx = {
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function() return step end,
            get_current_waypoint_world = function() return nil end,
        },
        nav = { is_navigating = function() return false end, stop = function() end },
        utils = utils, me = me, now = 100.0, frame_signalled = false,
        debug_log = function() end, log = function() end,
        safe = function(value, fallback) if value == nil then return fallback end return value end,
        detect_open_frame = function() return false end,
        object_scanner = { get_visible_objects = function() return {} end },
    }
    local shared = new_idle_shared()
    return idle_state.run(shared, ctx), shared
end

local flight_state, flight_shared = run_idle_transport("Fly to Azuremoore", 7)
assert(flight_state == "NAV" and flight_shared._nav_destination.npc_id == 9001,
    "S10 FAIL: flight caller must NAV to the nearest local flight master")
local flight_far_state, flight_far_shared = run_idle_transport("Fly to Azuremoore", 99)
assert(flight_far_state ~= "NAV" and flight_far_shared._nav_destination == nil,
    "S10 FAIL: flight caller must not fall back to another map")
print("  S10 PASS: real flight caller stays local and uses the nearest spawn")

local inn_state, inn_shared = run_idle_transport("Set your Hearthstone to Azuremoore", 7)
assert(inn_state == "NAV" and inn_shared._nav_destination.npc_id == 9011,
    "S11 FAIL: inn caller must NAV to the nearest local innkeeper")
local inn_far_state, inn_far_shared = run_idle_transport("Set your Hearthstone to Azuremoore", 99)
assert(inn_far_state ~= "NAV" and inn_far_shared._nav_destination == nil,
    "S11 FAIL: inn caller must not fall back to another map")
print("  S11 PASS: real inn caller stays local and uses the nearest spawn")

-- The coordinator's force-vendor path is a separate production caller. Stub only
-- unrelated state handlers; npc_db remains the real module loaded above.
package.loaded["quest_state/idle_state"] = { run = function() return "IDLE" end }
package.loaded["quest_state/nav_state"] = { run = function() end }
package.loaded["quest_state/interact_state"] = { run = function() end }
package.loaded["quest_state/do_action_state"] = { run = function() end }
package.loaded["quest_state/waiting_state"] = { run = function() end }
package.loaded["quest_state/dead_state"] = { run = function() end }
local coordinator = require("quest_state/coordinator")

local function run_vendor_transport(map_id)
    mock.reset()
    local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 100 })
    mock._map_id = map_id
    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = true
    local shared = coordinator._test_shared()
    require("shared/nav_destination").clear(shared)
    shared._state = "IDLE"
    coordinator.update()
    return coordinator._test_inspect()
end

local vendor_local_state, vendor_local_dest = run_vendor_transport(7)
assert(vendor_local_state == "NAV" and vendor_local_dest.npc_id == 9021,
    "S12 FAIL: force-vendor caller must NAV to the nearest local vendor")
local vendor_far_state, vendor_far_dest = run_vendor_transport(99)
assert(vendor_far_state ~= "NAV" and vendor_far_dest == nil,
    "S12 FAIL: force-vendor caller must not fall back to another map")
print("  S12 PASS: real vendor caller stays local and uses the nearest spawn")

print("PASS test_transport_helper")
os.exit(0)
