-- test_cat_vanilla_low_level_gating.lua -- Vanilla Feral Cat low-level silent-gate regression.
-- WHAT:  Verifies Faerie Fire Feral is not gated behind target armor at low levels
--         and that state.level is wired through build_state.
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

local learned_spells = {}
local has_buff = false

_G.EaxRotations = {
    DruidSpells = {
        CatForm = 768,
        Prowl = 5215,
        Shred = 5221,
        Rake = 1822,
        Rip = 1079,
        FerociousBite = 22568,
        TigersFury = 5217,
        FaerieFireFeral = 770,
        Dash = 1850,
        Barkskin = 22812,
        TrackHumanoids = 5225,
        Ravage = 6785,
        Pounce = 9005,
        TravelForm = 783,
    },
    PLAYER_UNIT = {},
    spell_ready = function(spell, target, opts) return true end,
    spell_exists = function(spell) return true end,
    is_spell_learned = function(spell) return learned_spells[spell] ~= false end,
    buff_up = function(me, buff_list) return has_buff end,
    debuff_remains = function(target, debuff_list) return 0 end,
    try_cast = function(spell, target, label) return true end,
    has_form = function(form) return form == "cat" end,
    is_behind_target = function(target) return true end,
    GetPlayer = function() return {} end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/cat_vanilla.lua")
local strategies = result.strategies or result
local build_state = result.build_state
assert_true(strategies, "strategies table should load")
assert_true(build_state, "build_state should be exported")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local faerie_fire = find_strategy("FaerieFireFeral")
local faerie_fire_stealth = find_strategy("FaerieFireStealthLock")

local state_low = build_state({ level = 20, has_valid_enemy_target = true, target = {}, in_combat = true })
assert_true(state_low.level == 20, "build_state should set level to 20")

local state_high = build_state({ level = 70, has_valid_enemy_target = true, target = {}, in_combat = true })
assert_true(state_high.level == 70, "build_state should set level to 70")

assert_true(faerie_fire.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_cat = true, faerie_fire_remains = 0, level = 20 }
), "FaerieFireFeral should match at low level even when target_armor is missing")

assert_false(faerie_fire.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_cat = true, faerie_fire_remains = 0, level = 70 }
), "FaerieFireFeral should not match at high level when target_armor is missing")

assert_true(faerie_fire.matches(
    { has_valid_enemy_target = true, target_armor = 1000 },
    { is_cat = true, faerie_fire_remains = 0, level = 70 }
), "FaerieFireFeral should match at high level when target_armor is present")

assert_true(faerie_fire_stealth.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_stealthed = true, faerie_fire_remains = 0, level = 20 }
), "FaerieFireStealthLock should match at low level even when target_armor is missing")

assert_false(faerie_fire_stealth.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_stealthed = true, faerie_fire_remains = 0, level = 70 }
), "FaerieFireStealthLock should not match at high level when target_armor is missing")

assert_true(faerie_fire.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_cat = true, faerie_fire_remains = 0, level = 49 }
), "FaerieFireFeral should match at level 49 with missing armor")

assert_false(faerie_fire.matches(
    { has_valid_enemy_target = true, target_armor = 0 },
    { is_cat = true, faerie_fire_remains = 0, level = 50 }
), "FaerieFireFeral should not match at level 50 with missing armor")

local rip = find_strategy("Rip")

assert_true(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 4, target_ttd = 30, rip_remains = 0, is_behind = false, level = 70 }
), "Rip should match without snapshot AP and not behind")

assert_false(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 2, target_ttd = 30, rip_remains = 0, is_behind = false, level = 70 }
), "Rip should not match with only 2 CP")

assert_true(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 3, target_ttd = 30, rip_remains = 0, is_behind = false, level = 20 }
), "Rip should match at low level with 3 CP")

assert_true(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 4, target_ttd = 30, rip_remains = 1, is_behind = false, level = 70 }
), "Rip should refresh when remains within window")

assert_false(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 3, target_ttd = 30, rip_remains = 0, is_behind = false, level = 70 }
), "Rip should require 4 CP at level 70")

assert_false(rip.matches(
    { has_valid_enemy_target = true },
    { is_cat = true, combo_points = 4, target_ttd = 30, rip_remains = 10, is_behind = false, level = 70 }
), "Rip should not refresh when remains above refresh window")

local ravage = find_strategy("RavageOpener")

assert_true(ravage.matches(
    { has_valid_enemy_target = true },
    { is_stealthed = true, is_cat = true, target_hp = 100, is_behind = true, energy = 70 }
), "RavageOpener should match at full HP when stealthed, behind, and has energy")

assert_false(ravage.matches(
    { has_valid_enemy_target = true },
    { is_stealthed = true, is_cat = true, target_hp = 100, is_behind = false, energy = 70 }
), "RavageOpener should not match when not behind target")

assert_false(ravage.matches(
    { has_valid_enemy_target = true },
    { is_stealthed = true, is_cat = true, target_hp = 10, is_behind = true, energy = 70 }
), "RavageOpener should not match when target is in execute range")

assert_false(ravage.matches(
    { has_valid_enemy_target = true },
    { is_stealthed = false, is_cat = true, target_hp = 100, is_behind = true, energy = 70 }
), "RavageOpener should not match when not stealthed")

print("PASS test_cat_vanilla_low_level_gating")
