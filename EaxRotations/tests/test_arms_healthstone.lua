-- Unit tests for arms_sylvanas auto_charge gate and use_cooldowns gate.
-- Tests: auto_charge setting gates Charge/Intercept, use_cooldowns gates cooldown abilities
-- Note: Healthstone auto-use is not yet implemented in arms_sylvanas.lua (FrostByte gap)

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local action_calls = {}
_G.EaxRotations = {
    WarriorSpells = {
        BattleShout = 6673,
        BattleStance = 2457,
        BerserkerRage = 18499,
        BerserkerStance = 2458,
        Bloodrage = 2687,
        Charge = 100,
        Cleave = 845,
        DeathWish = 12292,
        DefensiveStance = 71,
        DemoralizingShout = 1160,
        Disarm = 676,
        Execute = 5308,
        Hamstring = 1715,
        HeroicStrike = 78,
        Intercept = 20252,
        IntimidatingShout = 20511,
        MortalStrike = 12294,
        Overpower = 7384,
        PiercingHowl = 12323,
        Pummel = 6554,
        Recklessness = 1719,
        Rend = 772,
        Retaliation = 20230,
        ShieldWall = 871,
        Slam = 1464,
        SpellReflection = 23920,
        SweepingStrikes = 12328,
        ThunderClap = 6343,
        VictoryRush = 34428,
        Whirlwind = 1680,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    action_execute = function(ctx, act, prefix) return true end,
    spell_ready = function(spell, target, opts) return true end,
    spell_action = function(ids, name) return { name = name, ids = ids } end,
    buff_up = function(unit, buff_list) return false end,
    debuff_remains = function(unit, ids) return 0 end,
    cooldown_remains = function(spell_id, fallback) return 0 end,
    is_execute_phase = function(hp, threshold) return hp and hp <= threshold end,
    log = function() end,
    get_setting = function(key, fallback) return fallback end,
    GetPlayer = function() return {} end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/warrior/arms_sylvanas.lua")
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then
            return strategies[i]
        end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Charge: auto_charge toggle gating
-- ============================================================================

local charge = find_strategy("Charge")

-- Case 1: auto_charge enabled, OOC, in range -> should match
action_calls = {}
local ctx_charge_enabled = {
    in_combat = false,
    settings = { auto_charge = true, charge_only_ooc = false },
    target = {},
    target_distance = 15,
    target_in_combat = false,
    stance = 1,
}
assert_true(charge.matches(ctx_charge_enabled), "Charge should match when auto_charge enabled")
assert_eq(#action_calls, 1, "action_matches should be called for Charge")

-- Case 2: auto_charge disabled -> should NOT match
action_calls = {}
local ctx_charge_disabled = {
    in_combat = false,
    settings = { auto_charge = false, charge_only_ooc = false },
    target = {},
    target_distance = 15,
    target_in_combat = false,
    stance = 1,
}
assert_false(charge.matches(ctx_charge_disabled), "Charge should not match when auto_charge disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for Charge when auto_charge disabled")

-- Case 3: In combat (Charge only works OOC) -> should NOT match
action_calls = {}
local ctx_charge_combat = {
    in_combat = true,
    settings = { auto_charge = true },
    target = {},
    target_distance = 15,
    stance = 1,
}
assert_false(charge.matches(ctx_charge_combat), "Charge should not match when in combat")
assert_eq(#action_calls, 0, "action_matches should not be called for Charge in combat")

-- ============================================================================
-- Intercept: auto_charge toggle gating
-- ============================================================================

local intercept = find_strategy("Intercept")

-- Case 4: auto_charge enabled, in combat, in range -> should match
action_calls = {}
local ctx_intercept_enabled = {
    in_combat = true,
    settings = { auto_charge = true },
    target = {},
    target_distance = 15,
    stance = 3,
    last_charge_time = 0,
}
-- Need to mock game_time_ms to return a time far enough past last_charge_time
_G.EaxRotations.game_time_ms = function() return 10000 end
assert_true(intercept.matches(ctx_intercept_enabled), "Intercept should match when auto_charge enabled")
assert_eq(#action_calls, 1, "action_matches should be called for Intercept")

-- Case 5: auto_charge disabled -> should NOT match
action_calls = {}
local ctx_intercept_disabled = {
    in_combat = true,
    settings = { auto_charge = false },
    target = {},
    target_distance = 15,
    stance = 3,
    last_charge_time = 0,
}
assert_false(intercept.matches(ctx_intercept_disabled), "Intercept should not match when auto_charge disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for Intercept when auto_charge disabled")

-- Case 6: Too close (< 8 yards) -> should NOT match
action_calls = {}
local ctx_intercept_close = {
    in_combat = true,
    settings = { auto_charge = true },
    target = {},
    target_distance = 5,
    stance = 3,
    last_charge_time = 0,
}
assert_false(intercept.matches(ctx_intercept_close), "Intercept should not match when target < 8 yards")
assert_eq(#action_calls, 0, "action_matches should not be called for Intercept too close")

-- ============================================================================
-- Bloodrage: use_cooldowns toggle gating
-- ============================================================================

local bloodrage = find_strategy("Bloodrage")

-- Case 7: use_cooldowns enabled, not full rage -> should match
action_calls = {}
local ctx_cds_on = {
    in_combat = true,
    settings = { use_cooldowns = true },
    rage = 10,
    hp = 100,
    target = {},
    stance = 1,
}
assert_true(bloodrage.matches(ctx_cds_on), "Bloodrage should match when use_cooldowns enabled")
assert_eq(#action_calls, 1, "action_matches should be called for Bloodrage")

-- Case 8: use_cooldowns disabled -> should NOT match
action_calls = {}
local ctx_cds_off = {
    in_combat = true,
    settings = { use_cooldowns = false },
    rage = 10,
    hp = 100,
    target = {},
    stance = 1,
}
assert_false(bloodrage.matches(ctx_cds_off), "Bloodrage should not match when use_cooldowns disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for Bloodrage when use_cooldowns disabled")

-- ============================================================================
-- Note: Healthstone auto-use is NOT yet implemented (Frost.txt feature gap)
-- The following specs have Healthstone in Frost.txt but no implementation:
-- Frost.txt line ~399: "Auto Healthstone — use the healthstone trinket when HP <= 35"
-- arms_sylvanas.lua has no reference to Healthstone at all.
-- ============================================================================

-- Verify cooldowns_allowed is checked for other major CD abilities too
local death_wish = find_strategy("DeathWish")

-- Case 9: DeathWish with cooldowns disabled -> should NOT match
action_calls = {}
local ctx_dw_off = {
    in_combat = true,
    settings = { use_cooldowns = false },
    hp = 80,
    target_hp = 50,
    rage = 50,
    target = {},
    stance = 1,
}
_G.EaxRotations.game_time_ms = function() return 0 end  -- Clean up mock
assert_false(death_wish.matches(ctx_dw_off), "DeathWish should not match when use_cooldowns disabled")
assert_eq(#action_calls, 0, "action_matches should not be called for DeathWish when use_cooldowns disabled")

print("PASS test_arms_healthstone")
