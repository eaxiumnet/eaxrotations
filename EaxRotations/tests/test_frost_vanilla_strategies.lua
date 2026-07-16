-- test_frost_vanilla_strategies.lua — Frost Vanilla strategy match coverage.
-- WHAT:  Exercises IceBlock HP gate / Frostbolt primary / FrostNova range gate.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for mage frost vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    MageSpells = {
        ArcaneExplosion = 1449, ArcaneIntellect = 1459, ArcaneMissiles = 5143,
        Blizzard = 10, ColdSnap = 12472, ConeOfCold = 120, Counterspell = 2139,
        Evocation = 12051, FireBlast = 2136, FrostNova = 122, FrostWard = 6143,
        Frostbolt = 116, IceBarrier = 11426, IceBlock = 45438, ManaShield = 1463,
        Polymorph = 118, PresenceOfMind = 12043, RemoveCurse = 475, Scorch = 2948,
        ConjureManaEmerald = 10054, WintersChill = 12579,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    is_item_ready = function() return false end,
    should_use_long_cd = function() return true end,
    broken_api_throttled = function() return false end,
    aoe_cone_meets = function() return false end,
    AOE_RADIUS = { SELF_10 = 10, GROUND_8 = 8 },
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}

local strategies = dofile("EaxRotations/classes/mage/frost_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "frost_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local ice_block = find("IceBlock")
local frostbolt = find("Frostbolt")
local frost_nova = find("FrostNova")

local high_hp_me = { get_health_percentage = function() return 80 end }
local low_hp_me = { get_health_percentage = function() return 15 end }

assert_false(ice_block.matches({ me = high_hp_me }), "IceBlock must not match above 20% HP")
assert_true(ice_block.matches({ me = low_hp_me }), "IceBlock matches at low HP")
assert_false(ice_block.matches({}), "IceBlock must not match without me")

assert_false(frostbolt.matches({ target = {}, is_moving = true }, { frostbolt_ready = true }),
    "Frostbolt must not match while moving")
assert_true(frostbolt.matches({ target = {}, is_moving = false }, { frostbolt_ready = true }),
    "Frostbolt matches stationary with target")

local far_me = {
    get_distance = function() return 20 end,
}
local near_me = {
    get_distance = function() return 5 end,
}
assert_false(frost_nova.matches({ target = {}, me = far_me }),
    "FrostNova must not match beyond 10yd")
assert_true(frost_nova.matches({ target = {}, me = near_me }),
    "FrostNova matches within 10yd when not rooted")

print("PASS test_frost_vanilla_strategies")
