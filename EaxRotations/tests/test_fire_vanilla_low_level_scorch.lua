-- test_fire_vanilla_low_level_scorch.lua -- Fire Vanilla low-level Scorch fallback.
-- WHAT:  Verifies Fireball is not gated behind 5-stack Scorch when Scorch is unlearned.
-- WHEN:  During rotation test suite execution.
-- WHY:   Low-level Vanilla mages do not have Scorch; Fireball must still fire.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local learned_spells = {}
_G.EaxRotations = {
    MageSpells = {
        Scorch = 2948,
        Fireball = 133,
        FireBlast = 2136,
        Flamestrike = 2120,
        Blizzard = 10,
        IceBarrier = 11426,
        ManaShield = 1463,
        Evocation = 12051,
        Counterspell = 2139,
        Pyroblast = 11366,
        PresenceOfMind = 12043,
        Combustion = 11129,
    },
    PLAYER_UNIT = {},
    spell_ready = function(spell, target, opts) return true end,
    is_spell_learned = function(spell)
        return learned_spells[spell] ~= false
    end,
    has_player_buff = function(buff_list) return false end,
    log = function() end,
    should_use_long_cd = function() return false end,
    rotation_registry = { register = function() end },
    gate_cooldown_boss_only = function() return true end,
    broken_api_throttled = function() return false end,
}

local result = dofile("EaxRotations/classes/mage/fire_vanilla.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local fireball = find_strategy("Fireball")

-- Scorch learned, stacks < 5 -> Fireball should NOT match
learned_spells = { [2948] = true }
assert_false(fireball.matches({ is_moving = false, target = {}, scorch_stacks = 3 }, {}), "Fireball should not match when Scorch learned and stacks < 5")

-- Scorch unlearned (low-level) -> Fireball should match even with stacks < 5
learned_spells = { [2948] = false }
assert_true(fireball.matches({ is_moving = false, target = {}, scorch_stacks = 3 }, {}), "Fireball should match when Scorch is unlearned (low-level)")

print("PASS test_fire_vanilla_low_level_scorch")
