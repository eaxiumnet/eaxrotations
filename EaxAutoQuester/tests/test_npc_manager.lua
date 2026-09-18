-- What: Unit tests for EaxAutoQuester/npc_manager_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NPC finding, object scanning, and enemy detection

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- Create player
local player = mock.create_player({ pos = {x=0, y=0, z=0} })

-- Create test NPCs
local npc1 = mock.create_object({ pos = {x=10, y=0, z=0}, name = "Quest NPC", npc_id = 123, unit = true, valid = true })
local npc2 = mock.create_object({ pos = {x=5, y=0, z=0}, name = "Another NPC", npc_id = 456, unit = true, valid = true })
local enemy = mock.create_object({ pos = {x=8, y=0, z=0}, name = "Enemy", unit = true, valid = true, dead = false, enemy = true, attackable = true })
local player_obj = mock.create_object({ pos = {x=0, y=0, z=0}, name = "Player", unit = true, player = true, valid = true })
local dead_obj = mock.create_object({ pos = {x=3, y=0, z=0}, name = "Dead", unit = true, valid = true, dead = true })
local crate = mock.create_object({ pos = {x=7, y=0, z=0}, name = "Quest Crate", unit = false, valid = true })

mock._objects = { npc1, npc2, enemy, player_obj, dead_obj, crate }

local npc_manager = require("EaxAutoQuester/npc_manager_sylvanas")

-- Test find_nearest_npc
local nearest = npc_manager.find_nearest_npc({123, 456}, 50)
assert(nearest ~= nil, "find_nearest_npc should find NPC")
local nearest_id = nearest and nearest:get_npc_id()
assert(nearest_id == 123 or nearest_id == 456, "find_nearest_npc should return a matching NPC (got " .. tostring(nearest_id) .. ")")

-- Test find_nearest_npc with no match
local none = npc_manager.find_nearest_npc({999}, 50)
assert(none == nil, "find_nearest_npc should return nil for no match")

-- Test find_interactable_objects
local objs = npc_manager.find_interactable_objects("Quest")
assert(objs ~= nil, "find_interactable_objects should find objects")
assert(#objs >= 1, "find_interactable_objects should find at least one")

-- Test find_interactable_objects no match
local no_objs = npc_manager.find_interactable_objects("NonExistent")
assert(no_objs == nil, "find_interactable_objects should return nil for no match")

-- Test get_nearest_enemy
local nearest_enemy = npc_manager.get_nearest_enemy(50)
assert(nearest_enemy ~= nil, "get_nearest_enemy should find enemy")
assert(nearest_enemy:get_name() == "Enemy", "get_nearest_enemy should return enemy")

-- Test get_interact_distance
local dist = npc_manager.get_interact_distance(npc1)
assert(dist >= 0, "get_interact_distance should be non-negative")
assert(dist < 20, "get_interact_distance should be ~10yd")

-- Regression test: find_nearest_npc must never return the local player.
-- Live bug observed: Questie can list the player's own GUID/entity, and the
-- bot targeted "Sutteflasken" (the player's own character) instead of the
-- real questgiver NPC. interact_with_object on yourself is a no-op → tight
-- re-target loop, no gossip frame ever opens.
do
    mock.reset()
    mock.create_player({ pos = {x=0, y=0, z=0} })
    local self_unit = mock.create_object({
        pos = {x=2, y=0, z=0},
        name = "Sutteflasken",
        npc_id = 103,
        unit = true,
        player = true,
        valid = true,
    })
    local real_questgiver = mock.create_object({
        pos = {x=20, y=0, z=0},
        name = "Real Questgiver",
        npc_id = 103,
        unit = true,
        valid = true,
    })
    mock._objects = { self_unit, real_questgiver }
    local picked = npc_manager.find_nearest_npc({103}, 50)
    assert(picked ~= nil, "find_nearest_npc should find the real NPC at 20yd")
    assert(not picked:is_player(),
        "find_nearest_npc MUST NOT return the local player (would target self)")
    assert(picked:get_name() == "Real Questgiver",
        "find_nearest_npc should return the real questgiver, not the player unit " ..
        "(got: " .. tostring(picked:get_name()) .. ")")
    print("  regression PASS: find_nearest_npc excludes local player")
end

-- Regression: find_nearest_npc must find an NPC even if a nil entry precedes it
-- in the visible objects list. The first loop used to break on nil entries,
-- which meant NPCs after a nil were never found. Live observed: Milly Osworth
-- (questgiver NPC) was in the list but find_nearest_npc returned nil because
-- a nil entry before her broke the search loop.
do
    mock.reset()
    local valid_npc = mock.create_object({
        pos = { x = 5, y = 0, z = 0 },
        name = "Milly Osworth",
        npc_id = 9296,
        unit = true,
        valid = true,
        guid = "milly_osworth",
    })
    mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    -- Force a nil entry at position 1, then the valid NPC at position 2
    mock._objects = { nil, valid_npc }

    local npc_manager = require("EaxAutoQuester/npc_manager_sylvanas")
    local result = npc_manager.find_nearest_npc({ 9296 }, 50)
    assert(result ~= nil,
        "S-NPC FAIL: find_nearest_npc must find NPC even when preceded by nil entry " ..
        "in the objects list. Live observed: Milly Osworth (questgiver) was missed " ..
        "because a nil entry before her broke the search loop.")
    assert(result:get_npc_id() == 9296,
        "S-NPC FAIL: should return NPC 9296 (Milly Osworth)")
    print("  S-NPC PASS: find_nearest_npc finds NPC after nil entry (no early break)")
end

print("PASS test_npc_manager")
os.exit(0)
