-- test_bear_custom_matches.lua -- Guardian Bear custom match validation tests.
-- WHAT:  Guardian Bear custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

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
    same_unit = function(a, b)
        if a == nil or b == nil then return false end
        if a == b then return true end
        if a.get_guid and b.get_guid then
            local ok_a, guid_a = pcall(a.get_guid, a)
            local ok_b, guid_b = pcall(b.get_guid, b)
            if ok_a and ok_b and guid_a and guid_b then return guid_a == guid_b end
        end
        return false
    end,
}

local result = dofile("EaxRotations/classes/druid/bear_sylvanas.lua")
local strategies = result.strategies or result
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
-- Maul: pure rage dump (TBC community consensus)
-- ============================================================================

local maul = find_strategy("Maul")

local maul_settings = { bear_maul_rage = 50 }

action_calls = {}
assert_false(maul.matches({ rage = 20, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should not match when rage < maul_rage")
assert_eq(#action_calls, 0, "action_matches should not be called when rage < maul_rage")

action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should match when rage >= maul_rage and lacerate at 5")

action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 12, settings = maul_settings }), "Maul should match as rage dump when rage >= maul_rage, even with low lacerate")

action_calls = {}
assert_false(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 1, settings = maul_settings }), "Maul should not match when target_ttd < 3 (on-next-swing rage waste)")

assert_true(maul.matches({ rage = 50, settings = maul_settings }), "Maul without target falls through to action_matches (mock returns true)")

-- Boss bypass: Maul should match even at target_ttd=1 when target_is_boss=true
action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 3 }, target_ttd = 1, target_is_boss = true, settings = maul_settings }), "Maul should match on boss even with target_ttd < 3")

-- AoE suppression: 3+ enemies with rage < HIGH_RAGE (75) should NOT match
action_calls = {}
assert_false(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, enemy_count = 4, settings = maul_settings }), "Maul should not match in AoE (3+ enemies) with rage < 75")

-- Exact threshold: rage = maul_rage (50) should match; rage = 49 should not
action_calls = {}
assert_true(maul.matches({ rage = 50, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should match at exactly maul_rage threshold")
action_calls = {}
assert_false(maul.matches({ rage = 49, target = { _debuff_stacks = 5 }, settings = maul_settings }), "Maul should not match just below maul_rage threshold")

local demo_idx, ff_idx
for i, s in ipairs(strategies) do
    if s.name == "DemoralizingRoar" then demo_idx = i end
    if s.name == "FaerieFireFeral" then ff_idx = i end
end
assert_true(demo_idx and ff_idx, "Both DemoRoar and FF Feral must be registered")
assert_true(demo_idx < ff_idx, "DemoralizingRoar must be registered BEFORE FaerieFireFeral (TBC tanking priority)")

print("PASS test_bear_custom_matches")
