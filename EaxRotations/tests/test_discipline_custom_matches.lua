-- test_discipline_custom_matches.lua -- Discipline custom match validation tests.
-- WHAT:  Discipline custom match validation tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Ensures spec-specific match functions behave correctly under mocked combat state.
-- SAFETY: Uses synthetic context; no live game data required.

-- unit tests for discipline_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

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
    PriestSpells = {
        PowerWordShield = 17,
        PrayerofMending = 33076,
        FlashHeal = 2061,
        GreaterHeal = 2060,
        Renew = 139,
        ShadowWordPain = 589,
        Smite = 585,
    },
    PLAYER_UNIT = {},
    action_matches = function(ctx, act)
        action_calls[#action_calls + 1] = { fn = "action_matches", ctx = ctx, act = act }
        return true
    end,
    spell_ready = function(spell, target, opts)
        return true
    end,
    spell_exists = function(spell)
        return true
    end,
    debuff_remains = function()
        return 0
    end,
    log = function() end,
    gate_overheal = function(spell_key, unit, call_time, settings)
        return false  -- never overheal in tests
    end,
    rotation_registry = {
        register = function() end,
    },
}

-- Mock healing module
local mock_healing = {
    scan_healing_targets = function()
        return {}, 0
    end,
}
package.loaded["classes/priest/healing_sylvanas"] = mock_healing

local result = dofile("EaxRotations/classes/priest/discipline_sylvanas.lua")
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
-- EmergencyPowerWordShield: only when lowest HP <= threshold and no weakened soul
-- ============================================================================

local pws = find_strategy("EmergencyPowerWordShield")

-- High HP -> should NOT match
action_calls = {}
local ctx_pws_high = {
    settings = { discipline_pws_hp = 35 },
}
assert_false(pws.matches(ctx_pws_high, { lowest = { effective_hp = 60, has_weakened_soul = false, unit = {} }, pws_ready = true }), "EmergencyPWS should not match when HP > threshold")
assert_eq(#action_calls, 0, "action_matches should not be called when HP high")

-- Low HP but weakened soul -> should NOT match
action_calls = {}
local ctx_pws_ws = {
    settings = { discipline_pws_hp = 35 },
}
assert_false(pws.matches(ctx_pws_ws, { lowest = { effective_hp = 20, has_weakened_soul = true, unit = {} }, pws_ready = true }), "EmergencyPWS should not match when weakened soul")
assert_eq(#action_calls, 0, "action_matches should not be called when weakened soul")

-- Low HP, no weakened soul -> should match
action_calls = {}
local ctx_pws_ok = {
    settings = { discipline_pws_hp = 35 },
}
assert_true(pws.matches(ctx_pws_ok, { lowest = { effective_hp = 20, has_weakened_soul = false, unit = {} }, pws_ready = true }), "EmergencyPWS should match when HP <= threshold and no weakened soul")

-- No lowest -> should NOT match
action_calls = {}
assert_false(pws.matches({}, { lowest = nil }), "EmergencyPWS should not match without lowest")

-- ============================================================================
-- PrayerOfMendingTank: pre-pull enabled by disc_prepull_pom setting
-- ============================================================================

local pom = find_strategy("PrayerOfMendingTank")

-- OOC + disc_prepull_pom default (true) -> SHOULD match
action_calls = {}
local ctx_pom_ooc = {
    in_combat = false,
    settings = {},
}
assert_true(pom.matches(ctx_pom_ooc, { tank = { unit = {} }, lowest = { unit = {} }, pom_ready = true }), "PrayerOfMendingTank should match OOC when disc_prepull_pom defaults to true")
assert_eq(#action_calls, 0, "action_matches should not be called")

-- OOC + disc_prepull_pom=false -> should NOT match
action_calls = {}
local ctx_pom_ooc_off = {
    in_combat = false,
    settings = { disc_prepull_pom = false },
}
assert_false(pom.matches(ctx_pom_ooc_off, { tank = { unit = {} }, lowest = { unit = {} }, pom_ready = true }), "PrayerOfMendingTank should not match OOC when disc_prepull_pom=false")

-- In combat -> should match
action_calls = {}
local ctx_pom_ok = {
    in_combat = true,
    settings = {},
}
assert_true(pom.matches(ctx_pom_ok, { tank = { unit = {} }, lowest = { unit = {} }, pom_ready = true }), "PrayerOfMendingTank should match when in combat")

-- No tank or lowest -> should NOT match
action_calls = {}
assert_false(pom.matches({ in_combat = true, settings = {} }, { tank = nil, lowest = nil }), "PrayerOfMendingTank should not match without tank or lowest")

-- ============================================================================
-- EmergencyFlashHeal: only in combat, not moving, lowest HP <= threshold
-- ============================================================================

local fh = find_strategy("EmergencyFlashHeal")

-- Not in combat -> spec does NOT gate on in_combat; should still match when HP low
action_calls = {}
assert_true(fh.matches({ in_combat = false, is_moving = false, settings = { discipline_flash_hp = 55 } }, { lowest = { effective_hp = 30 }, flash_heal_ready = true }), "EmergencyFlashHeal should match when HP low even OOC (spec has no in_combat gate)")

-- Moving -> should NOT match
action_calls = {}
assert_false(fh.matches({ in_combat = true, is_moving = true, settings = { discipline_flash_hp = 55 } }, { lowest = { effective_hp = 30 }, flash_heal_ready = true }), "EmergencyFlashHeal should not match when moving")

-- High HP -> should NOT match
action_calls = {}
assert_false(fh.matches({ in_combat = true, is_moving = false, settings = { discipline_flash_hp = 55 } }, { lowest = { effective_hp = 70 }, flash_heal_ready = true }), "EmergencyFlashHeal should not match when HP > threshold")

-- Low HP, in combat, not moving -> should match
action_calls = {}
assert_true(fh.matches({ in_combat = true, is_moving = false, settings = { discipline_flash_hp = 55 } }, { lowest = { effective_hp = 30 }, flash_heal_ready = true }), "EmergencyFlashHeal should match when HP <= threshold")

-- No lowest -> should NOT match
action_calls = {}
assert_false(fh.matches({ in_combat = true, is_moving = false, settings = { discipline_flash_hp = 55 } }, { lowest = nil }), "EmergencyFlashHeal should not match without lowest")

-- ============================================================================
-- GreaterHeal: only in combat, not moving, HP in flash_hp < HP <= greater_heal_hp range
-- ============================================================================

local gh = find_strategy("GreaterHeal")

-- Not in combat -> should NOT match
action_calls = {}
assert_false(gh.matches({ in_combat = false, is_moving = false, settings = { discipline_greater_heal_hp = 82, discipline_flash_hp = 55 } }, { lowest = { effective_hp = 60 }, greater_heal_ready = true }), "GreaterHeal should not match when OOC")

-- Moving -> should NOT match
action_calls = {}
assert_false(gh.matches({ in_combat = true, is_moving = true, settings = { discipline_greater_heal_hp = 82, discipline_flash_hp = 55 } }, { lowest = { effective_hp = 60 }, greater_heal_ready = true }), "GreaterHeal should not match when moving")

-- HP below flash threshold -> should NOT match
action_calls = {}
assert_false(gh.matches({ in_combat = true, is_moving = false, settings = { discipline_greater_heal_hp = 82, discipline_flash_hp = 55 } }, { lowest = { effective_hp = 40 }, greater_heal_ready = true }), "GreaterHeal should not match when HP below flash threshold")

-- HP in range -> should match
action_calls = {}
assert_true(gh.matches({ in_combat = true, is_moving = false, settings = { discipline_greater_heal_hp = 82, discipline_flash_hp = 55 } }, { lowest = { effective_hp = 60 }, greater_heal_ready = true }), "GreaterHeal should match when HP in range")

-- No lowest -> should NOT match
action_calls = {}
assert_false(gh.matches({ in_combat = true, is_moving = false, settings = { discipline_greater_heal_hp = 82, discipline_flash_hp = 55 } }, { lowest = nil }), "GreaterHeal should not match without lowest")

-- ============================================================================
-- IdleShadowWordPain: only in combat, dps_when_idle, valid enemy, group stable
-- ============================================================================

local idle_swp = find_strategy("IdleShadowWordPain")

-- Not in combat -> should NOT match
action_calls = {}
local ctx_swp_ooc = {
    in_combat = false,
    settings = { discipline_idle_hp = 92 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_ooc, { lowest = { effective_hp = 95 }, shadow_word_pain_ready = true }), "IdleSWP should not match when OOC")

-- DPS disabled -> should NOT match
action_calls = {}
local ctx_swp_no = {
    in_combat = true,
    settings = { discipline_idle_hp = 92 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_no, { lowest = { effective_hp = 95 }, shadow_word_pain_ready = true }), "IdleSWP should not match when dps_when_idle not set")

-- No valid enemy target -> should NOT match
action_calls = {}
local ctx_swp_no_target = {
    in_combat = true,
    settings = { discipline_idle_hp = 92 },
    has_valid_enemy_target = false,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_no_target, { lowest = { effective_hp = 95 }, shadow_word_pain_ready = true }), "IdleSWP should not match without valid enemy target")

-- Group needs healing -> should NOT match
action_calls = {}
local ctx_swp_heal = {
    in_combat = true,
    settings = { discipline_idle_hp = 92 },
    has_valid_enemy_target = true,
    target = {},
}
assert_false(idle_swp.matches(ctx_swp_heal, { lowest = { effective_hp = 80 }, shadow_word_pain_ready = true }), "IdleSWP should not match when group needs healing")

-- All conditions met -> should match
action_calls = {}
local ctx_swp_ok = {
    in_combat = true,
    settings = { discipline_idle_hp = 92, discipline_dps_when_idle = true },
    has_valid_enemy_target = true,
    target = {},
}
assert_true(idle_swp.matches(ctx_swp_ok, { lowest = { effective_hp = 95 }, shadow_word_pain_ready = true }), "IdleSWP should match when all conditions met")

print("PASS test_discipline_custom_matches")
