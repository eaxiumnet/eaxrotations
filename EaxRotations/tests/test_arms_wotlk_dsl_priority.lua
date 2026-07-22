-- test_arms_wotlk_dsl_priority.lua — WotLK Arms warrior DSL priority order validation.
-- WHAT:  Asserts the 19 strategies appear in correct DSL-compiled priority order
--        and that key match gates (Execute, Rend, MortalStrike, Pummel, ShieldWall)
--        pass/fail correctly under mocked combat state.
-- WHEN:  During WotLK test suite execution.
-- WHY:   Regression guard for the first WotLK DSL adoption — ensures the
--        declarative conditions produce the same behavior as the original
--        imperative match functions.
-- SAFETY: Uses synthetic context/state; no live game data required.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

local me_mock = {
    get_rage = function() return 50 end,
    get_health_percentage = function() return 80 end,
    get_stance = function() return STANCE.BATTLE end,
}

_G.EaxRotations = {
    WarriorSpells = {
        BattleStance = make_action(2457, "BattleStance"),
        BerserkerStance = make_action(2458, "BerserkerStance"),
        BattleShout = make_action(47436, "BattleShout"),
        CommandingShout = make_action(47439, "CommandingShout"),
        Charge = make_action(11578, "Charge"),
        Rend = make_action(47465, "Rend"),
        MortalStrike = make_action(47486, "MortalStrike"),
        Overpower = make_action(11585, "Overpower"),
        Execute = make_action(47498, "Execute"),
        Bladestorm = make_action(46924, "Bladestorm"),
        SweepingStrikes = make_action(12328, "SweepingStrikes"),
        Slam = make_action(47475, "Slam"),
        HeroicStrike = make_action(47497, "HeroicStrike"),
        ThunderClap = make_action(47502, "ThunderClap"),
        DemoralizingShout = make_action(47437, "DemoralizingShout"),
        Hamstring = make_action(25212, "Hamstring"),
        Pummel = make_action(6554, "Pummel"),
        ShieldWall = make_action(871, "ShieldWall"),
        Retaliation = make_action(20230, "Retaliation"),
        Intercept = make_action(25275, "Intercept"),
    },
    WarriorConstants = { STANCE = STANCE },
    PLAYER_UNIT = {},
    GetPlayer = function() return me_mock end,
    me = me_mock,
    spell_action = function(ids, label)
        local id = type(ids) == "table" and ids[1] or ids
        return { id = id, name = label or tostring(id), cast_safe = function(self, t) return true end,
                cooldown_remaining = function(self) return 0 end, can_cast = function(self, t) return true end,
                is_learned = function(self) return true end }
    end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    cooldown_remains = function() return 0 end,
    is_interruptible = function() return true end,
    gate_cooldown_boss_only = function() return true end,
    aoe_target_meets = function() return false end,
    aoe_self_meets = function() return false end,
    should_use_long_cd = function() return true end,
    log = function() end,
    rotation_registry = { register = function(self, name, s, opts) end },
}

local result = dofile("EaxRotations/classes/warrior/arms_wotlk.lua")
local strategies = result.strategies or result
assert_true(strategies, "arms_wotlk strategies should load")

-- ============================================================================
-- Priority order assertions (must match DSL_DEFS order)
-- ============================================================================
local expected_order = {
    "ShieldWall", "Retaliation", "BattleShout", "Charge",
    "BerserkerStance", "BattleStance", "Intercept", "Pummel",
    "Rend", "MortalStrike", "Overpower", "Execute",
    "SweepingStrikes", "Bladestorm", "ThunderClap", "DemoralizingShout",
    "Hamstring", "Slam", "HeroicStrike",
}
assert_true(#strategies == #expected_order, "expected " .. #expected_order .. " strategies, got " .. #strategies)
for i = 1, #expected_order do
    assert_true(strategies[i].name == expected_order[i],
        "strategy[" .. i .. "] should be " .. expected_order[i] .. ", got " .. (strategies[i].name or "nil"))
end
print("[PASS] priority order: " .. #strategies .. " strategies match expected order")

-- ============================================================================
-- find_strategy helper
-- ============================================================================
local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- Build state helper
-- ============================================================================
local function make_state(ctx)
    return result.build_state(ctx or { target = {}, settings = {} })
end

-- ============================================================================
-- Match gate tests
-- ============================================================================

-- ShieldWall: HP < 30, in combat, cooldown ready
local sw = find_strategy("ShieldWall")
assert_true(type(sw.matches) == "function", "ShieldWall should have matches")
assert_false(sw.matches({}, make_state()), "ShieldWall should not match with no context")
-- Override HP to 20 via me mock for low-HP test
local orig_hp = me_mock.get_health_percentage
me_mock.get_health_percentage = function() return 20 end
local sw_low_ctx = { in_combat = true, target = {}, settings = {} }
assert_true(sw.matches(sw_low_ctx, make_state(sw_low_ctx)), "ShieldWall should match when hp < 30")
me_mock.get_health_percentage = orig_hp

-- Execute: target HP < 20%, in combat, rage >= 10
local ex = find_strategy("Execute")
assert_true(type(ex.matches) == "function", "Execute should have matches")
assert_false(ex.matches({}, make_state()), "Execute should not match with no context")
local ex_ctx = { in_combat = true, target = { get_health_percentage = function() return 15 end }, settings = {} }
local ex_state = make_state(ex_ctx)
assert_true(ex.matches(ex_ctx, ex_state), "Execute should match when target HP < 20%")
local ex_high_ctx = { in_combat = true, target = { get_health_percentage = function() return 50 end }, settings = {} }
local ex_high_state = make_state(ex_high_ctx)
assert_false(ex.matches(ex_high_ctx, ex_high_state), "Execute should not match when target HP >= 20%")

-- Rend: in combat, rage >= 10, debuff remains < 5s
local rend = find_strategy("Rend")
local rend_ctx = { in_combat = true, target = {}, settings = {} }
assert_true(rend.matches(rend_ctx, make_state(rend_ctx)), "Rend should match with debuff remains = 0")

-- Pummel: in combat, target casting, interruptible, ready
local pummel = find_strategy("Pummel")
local pummel_ctx = { in_combat = true, target = { is_casting = function() return true end }, settings = {} }
local pummel_state = make_state(pummel_ctx)
assert_true(pummel.matches(pummel_ctx, pummel_state), "Pummel should match when target is casting and interruptible")
local pummel_no_cast_ctx = { in_combat = true, target = { is_casting = function() return false end }, settings = {} }
local pummel_no_cast_state = make_state(pummel_no_cast_ctx)
assert_false(pummel.matches(pummel_no_cast_ctx, pummel_no_cast_state), "Pummel should not match when target is not casting")

-- BattleShout: no buff up
local bs = find_strategy("BattleShout")
local bs_ctx = { target = {}, settings = {} }
assert_true(bs.matches(bs_ctx, make_state(bs_ctx)), "BattleShout should match when buff is not up")

-- Charge: out of combat, in range
local charge = find_strategy("Charge")
local charge_ctx = { in_combat = false, target = {}, target_distance = 15, settings = {} }
local charge_state = make_state(charge_ctx)
assert_true(charge.matches(charge_ctx, charge_state), "Charge should match when out of combat and in range")
local charge_melee_ctx = { in_combat = false, target = {}, target_distance = 5, settings = {} }
local charge_melee_state = make_state(charge_melee_ctx)
assert_false(charge.matches(charge_melee_ctx, charge_melee_state), "Charge should not match when target is in melee range")

-- Slam: in combat, not moving, rage >= 15
local slam = find_strategy("Slam")
local slam_ctx = { in_combat = true, target = {}, settings = {} }
local slam_state = make_state(slam_ctx)
assert_true(slam.matches(slam_ctx, slam_state), "Slam should match when in combat, not moving, rage >= 15")
local slam_moving_ctx = { in_combat = true, target = {}, settings = {}, is_moving = true }
local slam_moving_state = make_state(slam_moving_ctx)
assert_false(slam.matches(slam_moving_ctx, slam_moving_state), "Slam should not match when moving")

print("[PASS] all match gate tests passed")
print("")
