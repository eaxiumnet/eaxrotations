-- test_cat_pool_for_rip.lua -- regression for PoolForRip strategy fix.
-- WHAT: verifies PoolForRip uses should_pool_for_rip + should_wait_for_tick
--       instead of the old pool_for_builder_matches / execute_bite.
-- WHEN: run via run_rotation_tests.lua after cat_sylvanas.lua changes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

_G.EaxRotations = {
    DruidSpells = { Shred = 5221, Rip = 1079, Rake = 1822, MangleCat = 33876, FerociousBite = 22568 },
    action_matches = function(ctx, act) return true end,
    debuff_remains = function(target, ids) return target and target._debuff_remains or 0 end,
    buff_up = function(me, ids) return me and me._buff_up or false end,
    is_spell_learned = function(id) return true end,
    spell_exists = function(id) return true end,
    has_form = function(form) return form == "cat" end,
    setting_number = function(s, k, d)
        return type(s) == "table" and type(s[k]) == "number" and s[k] or d
    end,
    setting_bool = function(s, k, d)
        local v = s and s[k]
        if v == nil then return d end
        return v ~= false
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
local strategies = result.strategies or result
assert_true(strategies, "strategies table should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local pool = find_strategy("PoolForRip")
assert_true(pool, "PoolForRip strategy should exist")

-- RIP_COST = 30, ENERGY_PER_TICK = 20, MIN_RIP_TTD = 10
-- should_pool_for_rip: CP >= 5 AND energy < 30 AND target_lives(>10s ttd)
-- should_wait_for_tick: energy < 30 AND next_tick_in <= 0.45 AND energy + 20 >= 30 (i.e. energy >= 10)
-- Combined: CP >= 5, energy in [10, 29], next_tick_in <= 0.45, ttd > 10

-- Helper: create a mock me object that controls energy tick prediction.
-- next_tick_val: value to return from energy_time_to_x (seconds until next tick)
local function make_me(next_tick_val)
    return {
        energy_predicted = function() return nil end,  -- enter IZI path but no prediction
        energy_time_to_x = function(self, target) return next_tick_val end,
    }
end

-- Test 1: PoolForRip MATCHES when should_pool_for_rip is true and tick is imminent
local ctx_match = {
    in_combat = true, combo_points = 5, energy = 15,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.3),  -- tick imminent
}
assert_true(pool.matches(ctx_match), "PoolForRip should match when CP>=5, energy<30, tick imminent, target lives")

-- Test 2: PoolForRip does NOT match when CP < 5 (not enough combo points for Rip)
local ctx_low_cp = {
    in_combat = true, combo_points = 3, energy = 15,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.3),
}
assert_false(pool.matches(ctx_low_cp), "PoolForRip must NOT match when CP < 5")

-- Test 3: PoolForRip does NOT match when energy >= RIP_COST (30)
local ctx_high_energy = {
    in_combat = true, combo_points = 5, energy = 30,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.3),
}
assert_false(pool.matches(ctx_high_energy), "PoolForRip must NOT match when energy >= RIP_COST (30)")

-- Test 4: PoolForRip does NOT match when no tick is imminent (next_tick_in > 0.45)
local ctx_no_tick = {
    in_combat = true, combo_points = 5, energy = 15,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.8),  -- tick NOT imminent
}
assert_false(pool.matches(ctx_no_tick), "PoolForRip must NOT match when next_tick_in > 0.45")

-- Test 4b: PoolForRip does NOT match when energy too low for tick to cover (energy+20 < 30)
local ctx_low_energy = {
    in_combat = true, combo_points = 5, energy = 5,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.3),
}
assert_false(pool.matches(ctx_low_energy), "PoolForRip must NOT match when energy+tick < RIP_COST")

-- Test 5: PoolForRip execute returns true (no-op wait)
local exec_result = pool.execute(ctx_match)
assert_true(exec_result == true, "PoolForRip execute should return true (no-op wait)")

print("test_cat_pool_for_rip: ALL PASS")
