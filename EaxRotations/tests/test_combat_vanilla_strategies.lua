-- test_combat_vanilla_strategies.lua — Combat Vanilla strategy match coverage.
-- WHAT:  Exercises Eviscerate / SliceAndDice / Kick / BladeFlurry gates.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for rogue combat vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    RogueSpells = {
        AdrenalineRush = 13750, Ambush = 8676, Backstab = 53, Blind = 2094,
        BladeFlurry = 13877, CheapShot = 1833, Evasion = 5277, Eviscerate = 2098,
        ExposeArmor = 8647, Feint = 1966, Garrote = 703, GhostlyStrike = 14278,
        Gouge = 1776, Hemorrhage = 16511, Kick = 1766, KidneyShot = 408,
        Rupture = 1943, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1784, Vanish = 1856,
    },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    broken_api_throttled = function() return false end,
    should_use_long_cd = function() return true end,
    time_now = function() return 0 end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}

local strategies = dofile("EaxRotations/classes/rogue/combat_vanilla.lua")
if type(strategies) == "table" and strategies.strategies then strategies = strategies.strategies end
assert_true(type(strategies) == "table" and #strategies > 0, "combat strategies load")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local evis = find("Eviscerate")
local snd = find("SliceAndDice")
local kick = find("Kick")
local bf = find("BladeFlurry")

assert_false(evis.matches({ settings = {} }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 2 }),
    "Eviscerate must not match below 4 CP")
assert_false(evis.matches({ settings = {} }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 20, combo_points = 5 }),
    "Eviscerate must not match below 35 energy")
assert_true(evis.matches({ settings = {} }, { eviscerate_ready = true, energy_pool_finisher = false, energy = 50, combo_points = 5 }),
    "Eviscerate matches at 4+ CP with energy")

assert_false(snd.matches({ settings = {} }, { slice_and_dice_ready = true, has_snd = true, snd_needs_refresh = false, combo_points = 5 }),
    "SliceAndDice must not match when up and not refreshing")
assert_false(snd.matches({ settings = {} }, { slice_and_dice_ready = true, has_snd = false, combo_points = 1 }),
    "SliceAndDice must not match below 2 CP")
assert_true(snd.matches({ settings = {} }, { slice_and_dice_ready = true, has_snd = false, combo_points = 3 }),
    "SliceAndDice matches with 2+ CP when down")

assert_false(kick.matches({}, { target_casting = false, kick_ready = true }),
    "Kick must not match when target not casting")
assert_true(kick.matches({}, { target_casting = true, kick_ready = true }),
    "Kick matches when target casting")

assert_false(bf.matches({ settings = {} }, { in_combat = true, has_blade_flurry = false, blade_flurry_ready = true, target_count = 1 }),
    "BladeFlurry must not match single target")
assert_true(bf.matches({ settings = {} }, { in_combat = true, has_blade_flurry = false, blade_flurry_ready = true, target_count = 2 }),
    "BladeFlurry matches with 2+ targets in combat")

print("PASS test_combat_vanilla_strategies")
