-- test_arcane_vanilla_strategies.lua — Arcane Vanilla strategy match coverage.
-- WHAT:  Exercises Frostbolt primary / FireBlast moving / Evocation mana gates.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for mage arcane vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    MageSpells = {
        ArcaneExplosion = 1449, ArcaneIntellect = 1459, ArcaneMissiles = 5143,
        ArcanePower = 12042, Blink = 1953, Blizzard = 10, ColdSnap = 12472,
        Combustion = 11129, ConeOfCold = 120, Counterspell = 2139,
        Evocation = 12051, FireBlast = 2136, Fireball = 133, FireWard = 543,
        Flamestrike = 2120, FrostArmor = 7302, FrostNova = 122, FrostWard = 6143,
        Frostbolt = 116, IceBarrier = 11426, IceBlock = 45438, ManaShield = 1463,
        Polymorph = 118, PresenceOfMind = 12043, Pyroblast = 11366,
        RemoveCurse = 475, Scorch = 2948, ManaGem = 5514, ConjureManaGem = 759,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    is_vanilla = function() return true end,
    is_item_ready = function() return false end,
    time_now = function() return 0 end,
    should_use_long_cd = function() return true end,
    gate_cooldown_boss_only = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
}

local strategies = dofile("EaxRotations/classes/mage/arcane_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "arcane_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local frostbolt = find("Frostbolt")
local fire_blast = find("FireBlast")
local evo = find("Evocation")

assert_false(frostbolt.matches({ target = {} }, { is_moving = true }),
    "Frostbolt must not match while moving")
assert_false(frostbolt.matches({ target = nil }, { is_moving = false }),
    "Frostbolt must not match without target")
assert_true(frostbolt.matches({ target = {} }, { is_moving = false }),
    "Frostbolt matches stationary with target")

assert_false(fire_blast.matches({ target = {} }, { is_moving = false }),
    "FireBlast must not match while stationary (Vanilla AP Frost)")
assert_true(fire_blast.matches({ target = {} }, { is_moving = true }),
    "FireBlast matches while moving")

assert_false(evo.matches({}, { in_combat = false, evocation_available = true, mana_pct = 10 }),
    "Evocation must not match OOC")
assert_true(evo.matches({}, { in_combat = true, evocation_available = true, mana_pct = 10, phase = "conserve" }),
    "Evocation matches at low mana in combat")

print("PASS test_arcane_vanilla_strategies")
