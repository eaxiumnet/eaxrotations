-- What: Unit tests for EaxAutoQuester/combat_helper_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify target acquisition and combat helpers

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local player = mock.create_player({ pos = {x=0, y=0, z=0} })
local enemy = mock.create_object({ pos = {x=5, y=0, z=0}, name = "Enemy", unit = true, valid = true, dead = false, enemy = true, attackable = true })
local dead_enemy = mock.create_object({ pos = {x=3, y=0, z=0}, name = "DeadEnemy", unit = true, valid = true, dead = true, enemy = true, attackable = true })
local player_obj = mock.create_object({ pos = {x=0, y=0, z=0}, name = "Player", unit = true, player = true, valid = true })

mock._objects = { enemy, dead_enemy, player_obj }

local combat_helper = require("combat_helper_sylvanas")

-- Test target_and_tag_nearest
local tagged = combat_helper.target_and_tag_nearest(50)
assert(tagged == true, "target_and_tag_nearest should tag enemy")
assert(player:get_target() == enemy, "target_and_tag_nearest should set target to enemy")

-- Test is_current_target_valid
assert(combat_helper.is_current_target_valid(30) == true, "is_current_target_valid should be true for enemy in range")
assert(combat_helper.is_current_target_valid(3) == false, "is_current_target_valid should be false for enemy out of range (5yd > 3yd)")

-- Test use_quest_item_on_target
local used = combat_helper.use_quest_item_on_target(12345)
assert(used == true or used == false, "use_quest_item_on_target should return boolean")

-- Reset target and test with no valid enemies
player._target = nil
mock._objects = {}  -- clear all enemies
local not_tagged = combat_helper.target_and_tag_nearest(50)
assert(not_tagged == false, "target_and_tag_nearest should fail with no valid enemies")

-- =============================================================================
-- Engagement stand-off — each ranged class stops at its OWN maximum attack range,
-- not at one number for everyone. Live: the priest walked into the mob's face.
-- =============================================================================
do
    local hunter = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 3 })
    local priest = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 5 })
    local warrior = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 1 })

    assert(combat_helper.ranged_engage_yds(hunter) == 35,
        "stand-off FAIL: a hunter fights from its 35yd ranged weapon (got " ..
        tostring(combat_helper.ranged_engage_yds(hunter)) .. ")")
    assert(combat_helper.ranged_engage_yds(priest) == combat_helper.ENGAGE_RANGED_YDS,
        "stand-off FAIL: a caster's stand-off must be the caster value")
    assert(combat_helper.ranged_engage_yds(warrior) == nil,
        "stand-off FAIL: a melee class has no ranged stand-off")
    assert(combat_helper.is_ranged_class(priest) == true, "stand-off FAIL: priest is ranged")
    assert(combat_helper.is_ranged_class(warrior) == false, "stand-off FAIL: warrior is melee")
    assert(combat_helper.engage_distance_sq(priest) == combat_helper.ENGAGE_RANGED_YDS ^ 2,
        "stand-off FAIL: the caster stop distance must be the caster range squared")
    assert(combat_helper.engage_distance_sq(hunter) == 1225,
        "stand-off FAIL: the hunter stop distance must be 35yd squared (got " ..
        tostring(combat_helper.engage_distance_sq(hunter)) .. ")")
    assert(combat_helper.engage_distance_sq(warrior) == 9,
        "stand-off FAIL: melee still closes to 3yd")
    -- The ceiling that makes 28 the caster value: standing further out than the class's own 30yd
    -- casts would mean never being able to cast at all.
    assert(combat_helper.ENGAGE_RANGED_YDS < 30,
        "stand-off FAIL: a caster value at or beyond 30yd leaves the class unable to cast")
    assert(combat_helper.ENGAGE_RANGED_YDS > 5,
        "stand-off FAIL: a caster value inside melee reach is not a stand-off")
    print("  STAND-OFF PASS: hunter 35yd, casters 28yd, melee 3yd")
end

print("PASS test_combat_helper")
os.exit(0)
