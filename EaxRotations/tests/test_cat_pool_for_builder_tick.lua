-- test_cat_pool_for_builder_tick.lua -- regression for PoolForBuilderTick strategy fix.
-- WHAT: verifies PoolForBuilderTick matches the builder-pooling condition
--       (CP < 5, energy < MANGLE_COST, tick imminent) and that its execute is
--       a no-op wait (returns true) instead of casting FerociousBite.
-- WHY:  the old execute was execute_bite (casts FerociousBite), which
--       misfired FB at < 5 CP instead of waiting for a tick to afford Shred/Mangle.
-- WHEN: run via run_rotation_tests.lua after cat_sylvanas.lua changes.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Track ANY try_cast call. A no-op PoolForBuilderTick execute must never reach
-- try_cast at all, regardless of how spec_kit wraps the spell (table vs id).
local try_cast_count = 0

_G.EaxRotations = {
    DruidSpells = { Shred = 5221, Rip = 1079, Rake = 1822, MangleCat = 33876, FerociousBite = 22568 },
    action_matches = function(ctx, act) return true end,
    debuff_remains = function(target, ids) return target and target._debuff_remains or 0 end,
    buff_up = function(me, ids) return me and me._buff_up or false end,
    is_spell_learned = function(id) return true end,
    spell_exists = function(id) return true end,
    has_form = function(form) return form == "cat" end,
    -- try_cast is what execute_bite calls to cast FerociousBite.
    -- The fixed PoolForBuilderTick execute must NOT reach this path at all.
    try_cast = function(spell, target, label, opts)
        try_cast_count = try_cast_count + 1
        return true
    end,
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

local pool = find_strategy("PoolForBuilderTick")
assert_true(pool, "PoolForBuilderTick strategy should exist")

-- MANGLE_COST = 40, ENERGY_PER_TICK = 20
-- pool_for_builder_matches: CP < 5 AND energy < 40 AND next_tick_in <= 0.6
-- should_wait_for_tick is NOT used by pool_for_builder_matches (unlike PoolForRip).

-- Helper: create a mock me object that controls energy tick prediction.
local function make_me(next_tick_val)
    return {
        energy_predicted = function() return nil end,  -- enter IZI path but no prediction
        energy_time_to_x = function(self, target) return next_tick_val end,
    }
end

-- Test 1: PoolForBuilderTick MATCHES when CP < 5, energy < MANGLE_COST, tick imminent
local ctx_match = {
    in_combat = true, combo_points = 2, energy = 20,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.4),  -- tick imminent (<= 0.6)
}
assert_true(pool.matches(ctx_match), "PoolForBuilderTick should match when CP<5, energy<40, tick imminent")

-- Test 2: PoolForBuilderTick does NOT match when CP >= 5 (finisher territory, not builder pool)
local ctx_high_cp = {
    in_combat = true, combo_points = 5, energy = 20,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.4),
}
assert_false(pool.matches(ctx_high_cp), "PoolForBuilderTick must NOT match when CP >= 5")

-- Test 3: PoolForBuilderTick does NOT match when energy >= MANGLE_COST (40)
local ctx_high_energy = {
    in_combat = true, combo_points = 2, energy = 40,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(0.4),
}
assert_false(pool.matches(ctx_high_energy), "PoolForBuilderTick must NOT match when energy >= MANGLE_COST (40)")

-- Test 4: PoolForBuilderTick does NOT match when no tick is imminent (next_tick_in > 0.6)
local ctx_no_tick = {
    in_combat = true, combo_points = 2, energy = 20,
    ttd = 60, mana_pct = 80,
    target = { _debuff_remains = 0 }, settings = {},
    me = make_me(1.2),  -- tick NOT imminent
}
assert_false(pool.matches(ctx_no_tick), "PoolForBuilderTick must NOT match when next_tick_in > 0.6")

-- Test 5: PoolForBuilderTick execute returns true (no-op wait) and does NOT call try_cast at all
try_cast_count = 0
local exec_result = pool.execute(ctx_match)
assert_true(exec_result == true, "PoolForBuilderTick execute should return true (no-op wait)")
assert_true(try_cast_count == 0, "PoolForBuilderTick execute must NOT call try_cast (was the old FB-casting bug)")

print("test_cat_pool_for_builder_tick: ALL PASS")
