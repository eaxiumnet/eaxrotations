-- test_druid_feral_level_42.lua -- Druid Feral level 42 silent-gate regression.
-- WHAT:  Verifies core Feral spells (Faerie Fire Feral, Shred, Ravage, Rip,
--        Ferocious Bite) are not silently skipped at level 42.
-- WHEN:  During rotation test suite execution.
-- WHY:   Low-level Feral druids lack Mangle (Cat) until level 50; the rotation
--        must still use Shred/Rip/Bite and not gate them behind missing spells.
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

local function load_cat(mangle_learned)
    _G.EaxRotations = make_ns(mangle_learned)
    local cat = dofile("EaxRotations/classes/druid/cat_sylvanas.lua")
    return cat.strategies or cat
end

local function load_leveling(mangle_learned)
    _G.EaxRotations = make_ns(mangle_learned)
    dofile("EaxRotations/classes/druid/leveling_sylvanas.lua")
    return _G.EaxRotations.rotation_registry._registrations["leveling"].strategies
end

-- ============================================================================
-- cat_sylvanas.lua at level 42
-- ============================================================================
local strats_no_mangle = load_cat(false)
local strats_mangle = load_cat(true)

local shred_no_mangle = find_strategy(strats_no_mangle, "Shred")
local stealth_shred_no_mangle = find_strategy(strats_no_mangle, "StealthShred")
local rip_no_mangle = find_strategy(strats_no_mangle, "Rip")
local ravage_no_mangle = find_strategy(strats_no_mangle, "RavageOpener")
local bite_no_mangle = find_strategy(strats_no_mangle, "FerociousBite")

-- Shred works without Mangle debuff at level 42
assert_true(shred_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_behind = true, combo_points = 0, energy = 60, target_ttd = 60, mangle_remains = 0, pooling = false, target = {} },
    {}
), "cat_sylvanas Shred should match at level 42 without Mangle debuff")

-- StealthShred works without Mangle debuff at level 42
assert_true(stealth_shred_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_stealthed = true, is_behind = true, energy = 60, mangle_remains = 0, target = {} },
    {}
), "cat_sylvanas StealthShred should match at level 42 without Mangle debuff")

assert_true(rip_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_cat = true, target = {}, combo_points = 4, ttd = 60, rip_remains = 0, is_behind = false, attack_power = 100, rip_ap = 0, energy = 35 },
    {}
), "cat_sylvanas Rip should match at level 42")

-- Ravage works at level 42 opener
assert_true(ravage_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_stealthed = true, is_cat = true, target_hp = 100, is_behind = true, energy = 60, target = {} },
    {}
), "cat_sylvanas Ravage should match at level 42 opener")

assert_true(bite_no_mangle.matches(
    { has_valid_enemy_target = true, level = 42, is_cat = true, target = {}, target_hp = 20, ttd = 4, combo_points = 4, should_execute = true, energy = 35, rip_remains = 10 },
    {}
), "cat_sylvanas FerociousBite should match at level 42 execute")

-- With Mangle learned, Shred should not match without Mangle debuff
local shred_mangle = find_strategy(strats_mangle, "Shred")
assert_false(shred_mangle.matches(
    { has_valid_enemy_target = true, level = 70, is_behind = true, combo_points = 0, energy = 60, target_ttd = 60, mangle_remains = 0, pooling = false, target = {} },
    {}
), "cat_sylvanas Shred should not match when Mangle is learned and debuff is missing")

-- ============================================================================
-- leveling_sylvanas.lua at level 42
-- ============================================================================
local leveling_no_mangle = load_leveling(false)
local leveling_mangle = load_leveling(true)

local leveling_shred_no_mangle = find_strategy(leveling_no_mangle, "Shred")
local leveling_shred_mangle = find_strategy(leveling_mangle, "Shred")

local state_no_mangle = { is_cat = true, target = {}, shred_ready = true, energy = 60, combo_points = 0, is_behind = true, level = 42, mangle_remains = 0, mangle_cat_ready = false }
assert_true(leveling_shred_no_mangle.matches({}, state_no_mangle), "leveling_sylvanas Shred should match at level 42 without Mangle")

local state_mangle_missing = { is_cat = true, target = {}, shred_ready = true, energy = 60, combo_points = 0, is_behind = true, level = 70, mangle_remains = 0, mangle_cat_ready = true }
assert_false(leveling_shred_mangle.matches({}, state_mangle_missing), "leveling_sylvanas Shred should not match when Mangle is learned and debuff is missing")

print("PASS test_druid_feral_level_42")
