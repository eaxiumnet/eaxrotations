-- test_druid_vanilla_low_level_gating.lua -- Vanilla Druid low-level silent-gate regression.
-- WHAT:  Verifies Faerie Fire Feral is not gated behind target armor at low levels
--         for Bear and Caster Vanilla Druid specs.
-- WHEN:  During rotation test suite execution.
-- WHY:   Low-level Vanilla druids may lack target armor data; the rotation must not
--         silently skip Faerie Fire Feral when it is available and useful.
-- SAFETY: Pure unit tests with mocked API context.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_false
local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

local function make_ns()
    return {
        DruidSpells = {
            FaerieFireFeral = 770,
            FaerieFire = 770,
            Moonfire = 8921,
            Wrath = 5176,
            Innervate = 29166,
            Barkskin = 22812,
            Thorns = 467,
            CatForm = 768,
            BearForm = 5487,
            Growl = 6795,
            SwipeBear = 779,
            Maul = 6807,
            DemoralizingRoar = 99,
            ChallengingRoar = 5209,
            Enrage = 5229,
            Bash = 5211,
            FrenziedRegeneration = 22842,
        },
        PLAYER_UNIT = {},
        spell_ready = function(spell, target, opts) return true end,
        spell_exists = function(spell) return true end,
        is_spell_learned = function(spell) return true end,
        buff_up = function(me, buff_list) return false end,
        debuff_remains = function(target, debuff_list) return 0 end,
        buff_remains = function(me, buff_list) return 0 end,
        try_cast = function(spell, target, label) return true end,
        has_form = function(form) return form == "bear" end,
        is_behind_target = function(target) return true end,
        GetPlayer = function() return {} end,
        log = function() end,
        rotation_registry = { register = function() end },
    }
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

_G.EaxRotations = make_ns()
local bear = dofile("EaxRotations/classes/druid/bear_vanilla.lua")
local bear_strats = bear.strategies or bear

local bear_ff = find_strategy(bear_strats, "FaerieFireFeral")
local bear_ff_pull = find_strategy(bear_strats, "FaerieFirePull")

assert_true(bear_ff.matches(
    { target = {}, target_armor = 0, in_combat = true, level = 20, stance = 1, target_range = 5 },
    {}
), "Bear FaerieFireFeral should match at low level even when target_armor is missing")

assert_false(bear_ff.matches(
    { target = {}, target_armor = 0, in_combat = true, level = 70, stance = 1, target_range = 5 },
    {}
), "Bear FaerieFireFeral should not match at high level when target_armor is missing")

assert_true(bear_ff.matches(
    { target = {}, target_armor = 1000, in_combat = true, level = 70, stance = 1, target_range = 5 },
    {}
), "Bear FaerieFireFeral should match at high level when target_armor is present")

assert_true(bear_ff_pull.matches(
    { target = {}, target_armor = 0, in_combat = false, level = 20, has_valid_enemy_target = true, stance = 1, target_range = 25 },
    {}
), "Bear FaerieFirePull should match at low level even when target_armor is missing")

assert_true(bear_ff.matches(
    { target = {}, target_armor = 0, in_combat = true, level = 49, stance = 1, target_range = 5 },
    {}
), "Bear FaerieFireFeral should match at level 49 with missing armor")

assert_false(bear_ff.matches(
    { target = {}, target_armor = 0, in_combat = true, level = 50, stance = 1, target_range = 5 },
    {}
), "Bear FaerieFireFeral should not match at level 50 with missing armor")

_G.EaxRotations = make_ns()
local caster = dofile("EaxRotations/classes/druid/caster_vanilla.lua")
local caster_strats = caster.strategies or caster

local caster_ff = find_strategy(caster_strats, "FaerieFire")

assert_true(caster_ff.matches(
    { target = {}, target_armor = 0, is_leveling = true, level = 20 },
    { level = 20 }
), "Caster FaerieFire should match at low level even when target_armor is missing")

assert_false(caster_ff.matches(
    { target = {}, target_armor = 0, is_leveling = true, level = 70 },
    { level = 70 }
), "Caster FaerieFire should not match at high level when target_armor is missing")

assert_true(caster_ff.matches(
    { target = {}, target_armor = 1000, is_leveling = true, level = 70 },
    { level = 70 }
), "Caster FaerieFire should match at high level when target_armor is present")

assert_true(caster_ff.matches(
    { target = {}, target_armor = 0, is_leveling = true, level = 49 },
    { level = 49 }
), "Caster FaerieFire should match at level 49 with missing armor")

assert_false(caster_ff.matches(
    { target = {}, target_armor = 0, is_leveling = true, level = 50 },
    { level = 50 }
), "Caster FaerieFire should not match at level 50 with missing armor")

print("PASS test_druid_vanilla_low_level_gating")
