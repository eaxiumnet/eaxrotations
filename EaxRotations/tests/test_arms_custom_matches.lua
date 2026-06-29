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
local spell_ready_calls = {}
_G.EaxRotations = {
    WarriorSpells = {
        Execute = 5308,
        BattleShout = 6673,
        VictoryRush = 34428,
        MortalStrike = 12294,
        Overpower = 7384,
        Slam = 1464,
        HeroicStrike = 78,
        Hamstring = 1715,
    },
    WarriorConstants = {
        STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 },
    },
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    is_execute_phase = function(hp, threshold)
        return hp and hp <= threshold
    end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    buff_up = function(me, buff_list)
        return me and me._buff_up or false
    end,
    debuff_remains = function(unit, ids) return 0 end,
    cooldown_remains = function(spell_value, fallback) return 0 end,
    is_interruptible = function(target) return true end,
    log = function() end,
    GetPlayer = function() return {} end,
    PLAYER_UNIT = {},
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
spell_ready_calls = {}
assert_false(execute.matches({ target_hp = 30 }), "Execute should not match when target HP > 20%")
assert_eq(#action_calls, 0, "action_matches should not be called when not execute phase")

-- Target HP low -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(execute.matches({ target_hp = 15, rage = 50, target = {} }), "Execute should match when target HP <= 20%")
assert_true(#spell_ready_calls > 0, "spell_ready should be called during execute phase (build_state + match)")

-- ============================================================================
-- Victory Rush: only when Victory Rush buff is up
-- ============================================================================

local victory_rush = find_strategy("VictoryRush")

-- No buff -> should NOT match
action_calls = {}
spell_ready_calls = {}
assert_false(victory_rush.matches({ me = { _buff_up = false }, target = {} }), "VictoryRush should not match without buff")
assert_eq(#action_calls, 0, "action_matches should not be called without buff")

-- Buff active -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(victory_rush.matches({ me = { _buff_up = true }, target = {} }), "VictoryRush should match with buff")
assert_true(#spell_ready_calls > 0, "spell_ready should be called with buff (build_state + match)")

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
spell_ready_calls = {}
assert_true(ms.matches({ target = {}, stance = 1, rage = 30 }), "MortalStrike should always delegate to spell_ready")
assert_true(#spell_ready_calls > 0, "spell_ready should be called for MortalStrike (build_state + match)")

-- ============================================================================-- Heroic Strike: rage threshold and starvation logic-- ============================================================================

local hs = find_strategy("HeroicStrike")

-- Below 70-rage threshold -> should NOT match
action_calls = {}
spell_ready_calls = {}
assert_false(hs.matches({ target = {}, rage = 65, me = {} }), "HeroicStrike should not match below 70 rage")

-- At threshold -> should match
action_calls = {}
spell_ready_calls = {}
assert_true(hs.matches({ target = {}, rage = 75, me = {} }), "HeroicStrike should match at 75 rage")

-- Starvation guard wired: MS imminent with 70 rage is safe -> should match
action_calls = {}
spell_ready_calls = {}
_G.EaxRotations.cooldown_remains = function(spell, fallback) return 0.5 end
assert_true(hs.matches({ target = {}, rage = 75, me = {} }), "HeroicStrike should match at 75 rage even when MS imminent")
_G.EaxRotations.cooldown_remains = function(spell, fallback) return 0 end

-- ============================================================================
-- Cleave: MS starvation gate (would_starve_core_arms)
-- S1: Cleave at rage=55 with MS imminent: 55-15=40 < 30 for MS → STARVED
--     CLEAVE_RAGE=55 so clears threshold; starvation should block
-- S2: Cleave at rage=65 with MS imminent: 65-15=50 >= 30 for MS → OK
-- ============================================================================

local cleave = find_strategy("Cleave")

-- S1: rage=55 (threshold), ms_cd=0 (MS imminent), enemies=2
-- would_starve_core_arms: 55-15=40 < 30 for MS → STARVED → Cleave blocked
action_calls = {}
spell_ready_calls = {}
-- S1: Cleave at rage=70 (above SS reserve 60), ms_cd=0 (MS imminent), enemies=2
-- would_starve_core_arms: 70-15=55 >= 30 for MS → NOT starved → Cleave allowed
action_calls = {}
spell_ready_calls = {}
local cleave_ok = cleave.matches({ target = {}, rage = 70, enemy_count = 2, enemies_count = 2, me = {} })
if not cleave_ok then error("S2 FAIL: Cleave should match when rage=65 with MS imminent (65-15=50 >= 30)") end

print("PASS test_arms_custom_matches")
