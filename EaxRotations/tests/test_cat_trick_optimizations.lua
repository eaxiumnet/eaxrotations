-- test_cat_trick_optimizations.lua -- regression for Feral rip trick + shred trick.
-- WHAT: verifies rip_trick (Rip at low CP in [Rip,Mangle) energy window) and
--       shred_trick (Shred>Mangle builder when bleed active) from wowsims feral.
--       Both default OFF and must never fire unless opted in.
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

local rip_trick = find_strategy("RipTrick")
local shred_trick = find_strategy("ShredTrick")
assert_true(rip_trick, "RipTrick strategy should exist")
assert_true(shred_trick, "ShredTrick strategy should exist")

-- RipTrick: defaults OFF
local ctx_off = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 0 },
    ttd = 60, mana_pct = 80, energy = 35, settings = {},
}
assert_false(rip_trick.matches(ctx_off), "RipTrick must NOT fire when setting off")

-- RipTrick: fires when ON + energy in [RIP,MANGLE) window + mana ok
local ctx_on = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 0 },
    ttd = 60, mana_pct = 80, energy = 35, settings = { cat_use_rip_trick = true },
}
assert_true(rip_trick.matches(ctx_on), "RipTrick should fire in window with setting on")

-- RipTrick: NOT when energy >= MANGLE_COST
local ctx_high = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 0 },
    ttd = 60, mana_pct = 80, energy = 45, settings = { cat_use_rip_trick = true },
}
assert_false(rip_trick.matches(ctx_high), "RipTrick must NOT fire when energy >= Mangle cost")

-- RipTrick: NOT when Rip already active
local ctx_rip = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 12 },
    ttd = 60, mana_pct = 80, energy = 35, settings = { cat_use_rip_trick = true },
}
assert_false(rip_trick.matches(ctx_rip), "RipTrick must NOT fire when Rip active")

-- RipTrick: NOT when mana too low
local ctx_lm = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 0 },
    ttd = 60, mana_pct = 5, energy = 35, settings = { cat_use_rip_trick = true },
}
assert_false(rip_trick.matches(ctx_lm), "RipTrick must NOT fire when mana too low")

-- ShredTrick: defaults OFF
local ctx_so = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 10 },
    ttd = 60, mana_pct = 90, energy = 50, settings = {},
}
assert_false(shred_trick.matches(ctx_so), "ShredTrick must NOT fire when setting off")

-- ShredTrick: fires when ON + bleed + energy + behind + mana
local ctx_sn = {
    in_combat = true, combo_points = 2, target = { _debuff_remains = 10 },
    ttd = 60, mana_pct = 90, energy = 50, is_behind = true, next_tick_in = 1.5,
    settings = { cat_use_shred_trick = true },
}
assert_true(shred_trick.matches(ctx_sn), "ShredTrick should fire when all conditions met")

-- ShredTrick: NOT at 5 CP
local ctx_s5 = {
    in_combat = true, combo_points = 5, target = { _debuff_remains = 10 },
    ttd = 60, mana_pct = 90, energy = 50, is_behind = true, next_tick_in = 1.5,
    settings = { cat_use_shred_trick = true },
}
assert_false(shred_trick.matches(ctx_s5), "ShredTrick must NOT fire at 5 CP")

print("PASS test_cat_trick_optimizations")
