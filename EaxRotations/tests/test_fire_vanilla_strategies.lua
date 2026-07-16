-- test_fire_vanilla_strategies.lua — Fire Vanilla strategy match coverage.
-- WHAT:  Exercises Scorch stack build / Fireball scorch gate / Combustion combat gate.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for mage fire vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local learned = {}
_G.EaxRotations = {
    MageSpells = {
        Scorch = 2948, Fireball = 133, FireBlast = 2136, Flamestrike = 2120,
        Blizzard = 10, IceBarrier = 11426, ManaShield = 1463, Evocation = 12051,
        Counterspell = 2139, Pyroblast = 11366, PresenceOfMind = 12043,
        Combustion = 11129, Polymorph = 118, RemoveCurse = 475,
        ConjureManaEmerald = 10054, ArcaneExplosion = 1449,
    },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    is_spell_learned = function(spell) return learned[spell] ~= false end,
    has_player_buff = function() return false end,
    log = function() end,
    should_use_long_cd = function() return true end,
    gate_cooldown_boss_only = function() return true end,
    broken_api_throttled = function() return false end,
    try_cast = function() return true end,
    is_item_ready = function() return false end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    MANA_POTION_IDS = {},
}

local strategies = dofile("EaxRotations/classes/mage/fire_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "fire_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local scorch = find("Scorch")
local fireball = find("Fireball")
local combustion = find("Combustion")

learned[2948] = true

assert_true(scorch.matches({ is_moving = false, target = {}, settings = {} }, { scorch_stacks = 3, scorch_remains = 10 }),
    "Scorch matches while building stacks")
assert_false(scorch.matches({ is_moving = false, target = {}, settings = {} }, { scorch_stacks = 5, scorch_remains = 10 }),
    "Scorch must not match at 5 stacks with long remains")
assert_true(scorch.matches({ is_moving = false, target = {}, settings = {} }, { scorch_stacks = 5, scorch_remains = 2 }),
    "Scorch matches to refresh near drop")

assert_false(fireball.matches({ is_moving = false, target = {}, settings = {}, scorch_stacks = 3 }, { scorch_stacks = 3 }),
    "Fireball waits for 5 Scorch stacks when Scorch known")
assert_true(fireball.matches({ is_moving = false, target = {}, settings = {}, scorch_stacks = 5 }, { scorch_stacks = 5 }),
    "Fireball matches at 5 Scorch stacks")

assert_false(combustion.matches({ in_combat = false, settings = {} }, { combustion_ready = true }),
    "Combustion must not match OOC")
assert_true(combustion.matches({ in_combat = true, settings = {} }, { combustion_ready = true }),
    "Combustion matches in combat when ready")

print("PASS test_fire_vanilla_strategies")
