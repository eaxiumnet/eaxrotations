-- unit tests for arms_sylvanas custom matches functions.

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
        Execute = 5308,
        VictoryRush = 34428,
        MortalStrike = 12294,
        Overpower = 7384,
        Slam = 1464,
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    is_execute_phase = function(hp, threshold)
        return hp and hp <= threshold
    end,
    spell_ready = function(spell, target, opts)
        return true
    end,
    buff_up = function(me, buff_list)
        return me and me._buff_up or false
    end,
    log = function() end,
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
-- Execute: only when target HP <= 20%
-- ============================================================================

local execute = find_strategy("Execute")

-- Target HP high -> should NOT match
action_calls = {}
assert_false(execute.matches({ target_hp = 30 }), "Execute should not match when target HP > 20%")
assert_eq(#action_calls, 0, "action_matches should not be called when not execute phase")

-- Target HP low -> should match
action_calls = {}
assert_true(execute.matches({ target_hp = 15 }), "Execute should match when target HP <= 20%")
assert_eq(#action_calls, 1, "action_matches should be called during execute phase")

-- ============================================================================
-- Victory Rush: only when Victory Rush buff is up
-- ============================================================================

local victory_rush = find_strategy("VictoryRush")

-- No buff -> should NOT match
action_calls = {}
assert_false(victory_rush.matches({ me = { _buff_up = false } }), "VictoryRush should not match without buff")
assert_eq(#action_calls, 0, "action_matches should not be called without buff")

-- Buff active -> should match
action_calls = {}
assert_true(victory_rush.matches({ me = { _buff_up = true } }), "VictoryRush should match with buff")
assert_eq(#action_calls, 1, "action_matches should be called with buff")

-- No me -> should return false
assert_false(victory_rush.matches({}), "VictoryRush should not match without me")

-- ============================================================================
-- Slam: only when swing timer allows and rage is safe
-- ============================================================================

local slam = find_strategy("Slam")

-- No SwingTimer module -> should NOT match (module not loaded)
action_calls = {}
assert_false(slam.matches({ is_moving = false, rage = 50 }), "Slam should not match without SwingTimer")

-- ============================================================================
-- Mortal Strike: delegates to action_matches (no custom gate beyond standard)
-- ============================================================================

local ms = find_strategy("MortalStrike")
action_calls = {}
assert_true(ms.matches({}), "MortalStrike should always delegate to action_matches")
assert_eq(#action_calls, 1, "action_matches should be called for MortalStrike")

-- ============================================================================
-- Heroic Strike: delegates to action_matches (no custom gate)
-- ============================================================================

local hs = find_strategy("HeroicStrike")
action_calls = {}
assert_true(hs.matches({}), "HeroicStrike should always delegate to action_matches")
assert_eq(#action_calls, 1, "action_matches should be called for HeroicStrike")

print("PASS test_arms_custom_matches")
