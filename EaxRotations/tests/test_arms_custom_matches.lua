-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "tests/test_arms_custom_matches.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
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

-- ============================================================================
-- Heroic Strike: delegates to action_matches (no custom gate)
-- ============================================================================

local hs = find_strategy("HeroicStrike")
action_calls = {}
spell_ready_calls = {}
assert_true(hs.matches({ target = {}, rage = 60, me = {} }), "HeroicStrike should always delegate to spell_ready")
assert_true(#spell_ready_calls > 0, "spell_ready should be called for HeroicStrike (build_state + match)")

print("PASS test_arms_custom_matches")
