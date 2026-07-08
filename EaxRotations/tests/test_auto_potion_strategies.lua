-- test_auto_potion_strategies.lua -- auto-cast logic potion helper strategy tests.
-- WHAT:  auto-cast logic potion helper strategy tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Integration tests for auto-potion strategies.
-- Loads mage fire_vanilla.lua and exercises its ManaPotion strategy to verify:
-- settings gate (use_auto_potions), combat gate, context-flag gate (has_mana_potion),
-- mana threshold (20%), and potion_helper.try_use_potion integration.
-- The same gate pattern applies to HealthPotion (35% HP) and DamagePotion (should_burst).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- ============================================================================
-- Track use_item_by_id calls
-- ============================================================================
local use_item_calls = {}

_G.EaxRotations = {
    MageSpells = {
        ArcaneExplosion = 1449, ArcaneIntellect = 1459, BlastWave = 11113, Blizzard = 1194,
        Combustion = 11129, ConjureManaEmerald = 10054, Counterspell = 2139, Evocation = 12051,
        FireBlast = 2136, Fireball = 133, Flamestrike = 2120, FlamestrikeRank6 = 10216,
        IceBarrier = 11426, ManaShield = 1463, Polymorph = 118, PresenceOfMind = 12043,
        Pyroblast = 11366, RemoveCurse = 475, Scorch = 2948, UnavailableClassicMageFire = nil,
    },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    get_debuff_stacks = function() return 0 end,
    debuff_remains = function() return 0 end,
    has_player_buff = function() return false end,
    buff_up = function() return false end,
    try_cast = function() return true end,
    try_cast_position = function() return true end,
    is_item_ready = function() return true end,
    use_item_by_id = function(id, target)
        use_item_calls[#use_item_calls + 1] = { id = id, target = target }
        return true
    end,
    log = function() end,
    should_use_long_cd = function() return true end,
    get_setting = function() return nil end,
    rotation_registry = { register = function() end },
}

-- ============================================================================
-- Load the spec file
-- ============================================================================
local strategies = dofile("EaxRotations/classes/mage/fire_vanilla.lua")
assert_true(strategies, "strategies table should load")
assert_true(#strategies > 0, "strategies table should have entries")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local mana_potion = find_strategy("ManaPotion")
assert_true(mana_potion, "ManaPotion strategy should exist")
assert_true(type(mana_potion.matches) == "function", "ManaPotion.matches should be a function")
assert_true(type(mana_potion.execute) == "function", "ManaPotion.execute should be a function")

-- ============================================================================
-- Gate tests: settings
-- ============================================================================
use_item_calls = {}
assert_false(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 15, settings = { use_auto_potions = false } }),
    "ManaPotion should NOT match when use_auto_potions == false")
assert_true(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 15, settings = nil }),
    "ManaPotion should match when settings is nil (default ON)")
assert_true(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 15, settings = {} }),
    "ManaPotion should match when use_auto_potions is absent (default ON)")
assert_true(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 15, settings = { use_auto_potions = true } }),
    "ManaPotion should match when use_auto_potions == true")

-- ============================================================================
-- Gate tests: combat
-- ============================================================================
assert_false(mana_potion.matches({ in_combat = false, has_mana_potion = true, mana_pct = 15, settings = {} }),
    "ManaPotion should NOT match when out of combat")

-- ============================================================================
-- Gate tests: context flag (has_mana_potion)
-- ============================================================================
assert_false(mana_potion.matches({ in_combat = true, has_mana_potion = false, mana_pct = 15, settings = {} }),
    "ManaPotion should NOT match when has_mana_potion is false")
assert_false(mana_potion.matches({ in_combat = true, has_mana_potion = nil, mana_pct = 15, settings = {} }),
    "ManaPotion should NOT match when has_mana_potion is nil (falsy)")

-- ============================================================================
-- Gate tests: mana threshold (20% for mage)
-- ============================================================================
assert_false(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 30, settings = {} }),
    "ManaPotion should NOT match when mana_pct 30 > 20")
assert_true(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 20, settings = {} }),
    "ManaPotion should match when mana_pct == 20 (at threshold)")
assert_true(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = 10, settings = {} }),
    "ManaPotion should match when mana_pct 10 < 20")
assert_false(mana_potion.matches({ in_combat = true, has_mana_potion = true, mana_pct = nil, settings = {} }),
    "ManaPotion should NOT match when mana_pct is nil (or 100 => 100 > 20)")

-- ============================================================================
-- Execute tests: use_item_by_id integration
-- ============================================================================
use_item_calls = {}
local ctx = { in_combat = true, has_mana_potion = true, mana_pct = 10, me = { name = "TestMage" }, settings = {} }
assert_true(mana_potion.matches(ctx), "should match before execute")
assert_true(mana_potion.execute(ctx), "execute should return true on success")
assert_true(#use_item_calls > 0, "use_item_by_id should have been called")
assert_eq(use_item_calls[1].target, ctx.me, "use_item_by_id should receive context.me as target")

-- Execute returns false when all items fail
_G.EaxRotations.use_item_by_id = function() return false end
assert_false(mana_potion.execute(ctx), "execute should return false when all potions fail")

print("PASS test_auto_potion_strategies")
