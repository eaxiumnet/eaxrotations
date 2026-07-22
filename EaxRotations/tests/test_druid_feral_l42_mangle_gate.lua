-- test_druid_feral_l42_mangle_gate.lua -- Druid Feral L42 Mangle-debuff silent-gate regression.
-- WHAT:  Verifies Shred/StealthShred are not silently gated behind Mangle debuff
--        when Mangle (Cat) is not yet learned (level < 50).
-- WHEN:  During rotation test suite execution.
-- WHY:   Low-level Feral druids lack Mangle (Cat) until level 50; the rotation must
--        still use Shred/Rake finishers without the Mangle debuff.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local function make_ns(mangle_learned)
    return {
        DruidSpells = {
            CatForm = 768,
            Prowl = 5215,
            Shred = 27002,
            Rake = 27003,
            Rip = 27008,
            MangleCat = 33983,
            FerociousBite = 27012,
            TigersFury = 9846,
            FaerieFireFeral = 27011,
            Ravage = 27005,
            Pounce = 27006,
            Claw = 27001,
            Dash = 33357,
            Barkskin = 27007,
            TrackHumanoids = 5225,
            TravelForm = 783,
        },
        PLAYER_UNIT = {},
        spell_ready = function(spell, target, opts) return true end,
        spell_exists = function(spell)
            if spell == nil then return false end
            if mangle_learned == false then
                if spell == 33983 or spell == 33876 or spell == 33982 then return false end
            end
            return true
        end,
        is_spell_learned = function(spell) return true end,
        buff_up = function(me, buff_list) return false end,
        debuff_remains = function(target, debuff_list) return 0 end,
        try_cast = function(spell, target, label) return true end,
        has_form = function(form) return form == "cat" end,
        is_behind_target = function(target) return true end,
        GetPlayer = function() return {} end,
        log = function() end,
        rotation_registry = {
            _registrations = {},
            register = function(self, key, strategies, opts)
                self._registrations[key] = { strategies = strategies, opts = opts }
            end,
        },
    }
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

-- ============================================================================
-- cat_sylvanas.lua
-- ============================================================================
local function load_cat_strats(mangle_learned)
    _G.EaxRotations = make_ns(mangle_learned)
    local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
    return cat.strategies or cat
end

local cat_strats_no_mangle = load_cat_strats(false)
local shred_no_mangle = find_strategy(cat_strats_no_mangle, "Shred")
local stealth_shred_no_mangle = find_strategy(cat_strats_no_mangle, "StealthShred")

assert_true(shred_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_behind = true, combo_points = 0, energy = 60, target_ttd = 60, mangle_remains = 0, pooling = false, target = {} },
    {}
), "cat_sylvanas Shred should match when Mangle is not learned even without Mangle debuff")

assert_true(stealth_shred_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_stealthed = true, is_behind = true, energy = 60, mangle_remains = 0, target = {} },
    {}
), "cat_sylvanas StealthShred should match when Mangle is not learned even without Mangle debuff")

local cat_strats_mangle = load_cat_strats(true)
local shred_mangle = find_strategy(cat_strats_mangle, "Shred")
local stealth_shred_mangle = find_strategy(cat_strats_mangle, "StealthShred")

assert_false(shred_mangle.matches(
    { has_valid_enemy_target = true, level = 70, is_behind = true, combo_points = 0, energy = 60, target_ttd = 60, mangle_remains = 0, pooling = false, target = {} },
    {}
), "cat_sylvanas Shred should not match when Mangle is learned and debuff is missing")

assert_false(stealth_shred_mangle.matches(
    { has_valid_enemy_target = true, level = 70, is_stealthed = true, is_behind = true, energy = 60, mangle_remains = 0, target = {} },
    {}
), "cat_sylvanas StealthShred should not match when Mangle is learned and debuff is missing")

-- ============================================================================
-- leveling_sylvanas.lua
-- ============================================================================
_G.EaxRotations = make_ns(true)
dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
local leveling_strats = _G.EaxRotations.rotation_registry._registrations["leveling"].strategies

local leveling_shred = find_strategy(leveling_strats, "Shred")

local state_no_mangle = { is_cat = true, target = {}, shred_ready = true, energy = 60, combo_points = 0, is_behind = true, level = 70, mangle_remains = 0, mangle_cat_ready = false }
assert_true(leveling_shred.matches({}, state_no_mangle), "leveling_sylvanas Shred should match when Mangle is not learned even without Mangle debuff")

local state_mangle_missing = { is_cat = true, target = {}, shred_ready = true, energy = 60, combo_points = 0, is_behind = true, level = 70, mangle_remains = 0, mangle_cat_ready = true }
assert_false(leveling_shred.matches({}, state_mangle_missing), "leveling_sylvanas Shred should not match when Mangle is learned and debuff is missing")

print("PASS test_druid_feral_l42_mangle_gate")
