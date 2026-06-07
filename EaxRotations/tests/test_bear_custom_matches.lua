-- unit tests for bear_sylvanas custom matches functions.

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
    DruidSpells = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    debuff_remains = function(target, debuff_list)
        return target and target._debuff_remains or 0
    end,
    get_debuff_stacks = function(target, debuff_list)
        return target and target._debuff_stacks or 0
    end,
    setting_number = function(settings, key, default)
        return type(settings) == "table" and type(settings[key]) == "number" and settings[key] or default
    end,
    setting_bool = function(settings, key, default)
        local value = settings and settings[key]
        if value == nil then return default end
        return value ~= false
    end,
    log = function() end,
    rotation_registry = {
        register = function() end,
    },
}

local strategies = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
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
-- Faerie Fire Feral: only when debuff <= 4 sec
-- ============================================================================

local faerie_fire = find_strategy("FaerieFireFeral")

-- Debuff fresh -> should NOT match
action_calls = {}
assert_false(faerie_fire.matches({ target = { _debuff_remains = 10 }, target_armor = 5000 }), "FaerieFireFeral should not match when debuff > 4 sec")
assert_eq(#action_calls, 0, "action_matches should not be called when debuff fresh")

-- Debuff low -> should match
action_calls = {}
assert_true(faerie_fire.matches({ target = { _debuff_remains = 2 }, target_armor = 5000 }), "FaerieFireFeral should match when debuff <= 4 sec")

-- No target -> should return false
assert_false(faerie_fire.matches({}), "FaerieFireFeral should not match without target")

-- ============================================================================
-- Lacerate: stack to 5 ASAP, then maintain
-- ============================================================================

local lacerate = find_strategy("Lacerate")

-- Stacks < 5 -> should match (regardless of remains)
action_calls = {}
assert_true(lacerate.matches({ target = { _debuff_stacks = 3, _debuff_remains = 10 } }), "Lacerate should match when stacks < 5")

-- Stacks at 5, remains > 3 -> should NOT match
action_calls = {}
assert_false(lacerate.matches({ target = { _debuff_stacks = 5, _debuff_remains = 8 } }), "Lacerate should not match when 5-stack maintained")
assert_eq(#action_calls, 0, "action_matches should not be called when 5-stack maintained")

-- Stacks at 5, remains <= 3 -> should match
action_calls = {}
assert_true(lacerate.matches({ target = { _debuff_stacks = 5, _debuff_remains = 2 } }), "Lacerate should match when 5-stack about to drop")

-- No target -> should return false
assert_false(lacerate.matches({}), "Lacerate should not match without target")

-- ============================================================================
-- Swipe AoE: only when 3+ enemies
-- ============================================================================

local swipe_aoe = find_strategy("SwipeAoE")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(swipe_aoe.matches({ enemy_count = 2 }), "SwipeAoE should not match with < 3 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 3 enemies")

-- 3+ enemies -> should match
action_calls = {}
assert_true(swipe_aoe.matches({ enemy_count = 4 }), "SwipeAoE should match with >= 3 enemies")

-- ============================================================================
-- Swipe: only when 2+ enemies
-- ============================================================================

local swipe = find_strategy("Swipe")

-- Too few enemies -> should NOT match
action_calls = {}
assert_false(swipe.matches({ enemy_count = 1 }), "Swipe should not match with < 2 enemies")
assert_eq(#action_calls, 0, "action_matches should not be called with < 2 enemies")

-- 2+ enemies -> should match
action_calls = {}
assert_true(swipe.matches({ enemy_count = 3 }), "Swipe should match with >= 2 enemies")

-- ============================================================================
-- Maul: only when rage >= 35 and lacerate at 5 stacks
-- ============================================================================

local maul = find_strategy("Maul")

-- Low rage -> should NOT match
action_calls = {}
assert_false(maul.matches({ rage = 20, target = { _debuff_stacks = 5 } }), "Maul should not match when rage < 35")
assert_eq(#action_calls, 0, "action_matches should not be called when rage < 35")

-- High rage but lacerate < 5 -> should NOT match
action_calls = {}
assert_false(maul.matches({ rage = 50, target = { _debuff_stacks = 3 } }), "Maul should not match when lacerate < 5")
assert_eq(#action_calls, 0, "action_matches should not be called when lacerate < 5")

-- High rage, lacerate at 5 -> should match
action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 5 } }), "Maul should match when rage >= 35 and lacerate at 5")

-- No target -> spec falls through to action_matches (which handles target validation in real framework); mock returns true
assert_true(maul.matches({ rage = 50 }), "Maul without target falls through to action_matches (mock returns true)")

print("PASS test_bear_custom_matches")
