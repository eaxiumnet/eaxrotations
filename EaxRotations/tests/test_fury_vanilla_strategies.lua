-- test_fury_vanilla_strategies.lua — Fury Vanilla strategy match coverage.
-- WHAT:  Exercises Execute / Bloodthirst / SweepingStrikes gates on fury_vanilla.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for warrior fury vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308, BattleShout = 6673, Bloodthirst = 23881, Overpower = 7384,
        Whirlwind = 1680, HeroicStrike = 78, Hamstring = 1715, Cleave = 845,
        BerserkerRage = 18499, DeathWish = 12292, Bloodrage = 2687, Slam = 1464,
        SunderArmor = 7386, DemoralizingShout = 1160, ThunderClap = 6343,
        Intercept = 20252, Pummel = 6552, Recklessness = 1719, SweepingStrikes = 12292,
        Rend = 772, BattleStance = 2457, BerserkerStance = 2458, DefensiveStance = 71,
        Charge = 100,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
        BATTLE_SHOUT_IDS = { 11551, 11550, 11549, 6192, 5242, 6673 },
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    get_debuff_stacks = function() return 0 end,
    should_use_long_cd = function() return true end,
    aoe_target_meets = function() return false end,
    AOE_RADIUS = { TARGET_8 = 8 },
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/aoe_hit_volume_sylvanas"] = { install = function() end }

local strategies = dofile("EaxRotations/classes/warrior/fury_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "fury_vanilla strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local execute = find("Execute")
local bt = find("Bloodthirst")
local ss = find("SweepingStrikes")

-- Execute: target_hp <= 20 and rage >= 25 and execute_ready
assert_false(execute.matches({}, { execute_ready = true, target_hp = 50, rage = 50 }),
    "Fury Execute must not match above 20% HP")
assert_false(execute.matches({}, { execute_ready = true, target_hp = 15, rage = 10 }),
    "Fury Execute must not match with low rage")
assert_false(execute.matches({}, { execute_ready = false, target_hp = 15, rage = 50 }),
    "Fury Execute must not match when not ready")
assert_true(execute.matches({}, { execute_ready = true, target_hp = 15, rage = 50 }),
    "Fury Execute matches in execute with rage")

-- Bloodthirst: ready + rage >= 30
assert_false(bt.matches({}, { bloodthirst_ready = true, rage = 20 }),
    "Bloodthirst must not match with rage < 30")
assert_false(bt.matches({}, { bloodthirst_ready = false, rage = 50 }),
    "Bloodthirst must not match when not ready")
assert_true(bt.matches({}, { bloodthirst_ready = true, rage = 50 }),
    "Bloodthirst matches when ready with rage")

-- Sweeping Strikes: needs 2+ targets
assert_false(ss.matches({}, { sweeping_strikes_ready = true, target_count = 1 }),
    "SweepingStrikes must not match single target")
assert_true(ss.matches({}, { sweeping_strikes_ready = true, target_count = 2 }),
    "SweepingStrikes matches with 2+ targets")

print("PASS test_fury_vanilla_strategies")
