-- unit tests for combat_sylvanas custom matches functions.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_true, assert_eq, assert_false

local function setup_asserts()
    assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
    assert_eq = function(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end
    assert_false = function(v, label) if v then error(label or "assert_false failed", 2) end end
end
setup_asserts()

-- Mock NS namespace
local spell_ready_calls = {}
_G.EaxRotations = {
    RogueSpells = {
        Stealth = 1784,
        AdrenalineRush = 13750,
        BladeFlurry = 13877,
        SliceAndDice = 6774,
        Rupture = 1943,
        Eviscerate = 11300,
        SinisterStrike = 26862,
        Kick = 1766,
        Gouge = 1776,
        Sprint = 2983,
        Vanish = 1857,
        Feint = 1966,
        Hemorrhage = 26864,
        Backstab = 26863,
        GhostlyStrike = 14278,
        KidneyShot = 8643,
        ExposeArmor = 11198,
        Shiv = 5938,
        Evasion = 26669,
        CloakOfShadows = 31224,
        DeadlyThrow = 26679,
        Blind = 2094,
    },
    buff_up = function(me, buff_list) return me and me._buff_up or false end,
    buff_remains = function(me, buff_ids) return me and me._buff_remains or 0 end,
    debuff_remains = function(target, ids) return 0 end,
    spell_ready = function(spell, target, opts)
        spell_ready_calls[#spell_ready_calls + 1] = { spell = spell, target = target, opts = opts }
        return true
    end,
    is_spell_learned = function(id) return true end,
    is_interruptible = function(target) return true end,
    get_spell_cooldown = function(spell) return 0 end,
    gate_cooldown_boss_only = function() return true end,
    log = function() end,
    time_now = function() return 1000 end,
    broken_api_throttled = function(spell, seconds) return false end,
    rotation_registry = { register = function() end },
}

local strategies = dofile("EaxRotations/classes/rogue/combat_sylvanas.lua")
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
-- SliceAndDice: only when combo >= 2 and not already up (or needs refresh)
-- ============================================================================

local snd = find_strategy("SliceAndDice")

-- SND already active with >3s remaining -> should NOT match
spell_ready_calls = {}
assert_false(snd.matches({
    combo_points = 5,
    enemy_count = 1,
}, {
    has_snd = true, snd_needs_refresh = false,
    slice_and_dice_ready = true, combo_points = 5, energy = 80,
}), "SliceAndDice should not match when buff active and not near expiry")

-- SND active but near expiry -> should match
spell_ready_calls = {}
assert_true(snd.matches({
    combo_points = 4,
    enemy_count = 1,
}, {
    has_snd = true, snd_needs_refresh = true,
    slice_and_dice_ready = true, combo_points = 4, energy = 80,
}), "SliceAndDice should match when buff about to expire")

-- SND not active, combo >= 2 -> should match
spell_ready_calls = {}
assert_true(snd.matches({
    combo_points = 3,
    enemy_count = 1,
}, {
    has_snd = false, snd_needs_refresh = false,
    slice_and_dice_ready = true, combo_points = 3, energy = 80,
}), "SliceAndDice should match when buff is missing with sufficient CP")

-- Combo < 2 -> should NOT match
spell_ready_calls = {}
assert_false(snd.matches({
    combo_points = 1,
    enemy_count = 1,
}, {
    has_snd = false, snd_needs_refresh = false,
    slice_and_dice_ready = true, combo_points = 1, energy = 80,
}), "SliceAndDice should not match with <2 combo points")

-- ============================================================================
-- Eviscerate: only at 5 CP with sufficient energy
-- ============================================================================

local eviscerate = find_strategy("Eviscerate")

-- 5 CP, enough energy -> should match
spell_ready_calls = {}
assert_true(eviscerate.matches({
    energy = 60,
    enemy_count = 1,
}, {
    eviscerate_ready = true, combo_points = 5, energy = 60, energy_pool_finisher = false,
}), "Eviscerate should match at 5 CP with sufficient energy")

-- <5 CP -> should NOT match
spell_ready_calls = {}
assert_false(eviscerate.matches({
    energy = 60,
    enemy_count = 1,
}, {
    eviscerate_ready = true, combo_points = 4, energy = 60, energy_pool_finisher = false,
}), "Eviscerate should not match with <5 combo points")

-- Energy below 35 -> should NOT match (hard floor)
spell_ready_calls = {}
assert_false(eviscerate.matches({
    energy = 30,
    enemy_count = 1,
}, {
    eviscerate_ready = true, combo_points = 5, energy = 30, energy_pool_finisher = false,
}), "Eviscerate should not match when energy < 35")

-- Energy pool finisher -> should NOT match
spell_ready_calls = {}
assert_false(eviscerate.matches({
    energy = 50,
    enemy_count = 1,
}, {
    eviscerate_ready = true, combo_points = 5, energy = 50, energy_pool_finisher = true,
}), "Eviscerate should not match when energy pooling for finisher")

-- ============================================================================
-- Stealth: only OOC, not already stealthed
-- ============================================================================

local stealth = find_strategy("Stealth")

-- In combat -> should NOT match
assert_false(stealth.matches({}, {
    in_combat = true,     is_stealthed = false, stealth_ready = true,
}), "Stealth should not match when in combat")

-- Already stealthed -> should NOT match
assert_false(stealth.matches({}, {
    in_combat = false,     is_stealthed = true, stealth_ready = true,
}), "Stealth should not match when already stealthed")

-- OOC, no stealth -> should match
assert_true(stealth.matches({}, {
    in_combat = false,     is_stealthed = false, stealth_ready = true,
}), "Stealth should match when OOC and not stealthed")

-- ============================================================================
-- AdrenalineRush: only in combat, not already active, cooldowns enabled
-- ============================================================================

local ar = find_strategy("AdrenalineRush")

-- Not in combat -> should NOT match
spell_ready_calls = {}
assert_false(ar.matches({ settings = { use_cooldowns = true } }, {
    in_combat = false, has_adrenaline_rush = false, adrenaline_rush_ready = true,
    heroism_active = false,
}), "AdrenalineRush should not match when OOC")

-- Already active -> should NOT match
spell_ready_calls = {}
assert_false(ar.matches({ settings = { use_cooldowns = true } }, {
    in_combat = true, has_adrenaline_rush = true, adrenaline_rush_ready = true,
    heroism_active = false,
}), "AdrenalineRush should not match when already active")

-- Cooldowns disabled -> should NOT match
spell_ready_calls = {}
assert_false(ar.matches({ settings = { use_cooldowns = false } }, {
    in_combat = true, has_adrenaline_rush = false, adrenaline_rush_ready = true,
    heroism_active = false,
}), "AdrenalineRush should not match when cooldowns disabled")

-- In combat, not active, cooldowns enabled -> should match
spell_ready_calls = {}
assert_true(ar.matches({ settings = { use_cooldowns = true } }, {
    in_combat = true, has_adrenaline_rush = false, adrenaline_rush_ready = true,
    heroism_active = false,
}), "AdrenalineRush should match in combat with cooldowns enabled")

-- ============================================================================
-- Rupture: 5 CP, target lives long enough, within refresh window
-- ============================================================================

local rupture = find_strategy("Rupture")

-- <5 CP -> should NOT match (tested at match level, build_state would populate)
spell_ready_calls = {}
assert_false(rupture.matches({
    ttd_known = true, ttd = 30, target = {}, settings = { combat_rupture_ttd = 12 },
}, {
    rupture_ready = true, combo_points = 4, energy_pool_finisher = false,
}), "Rupture should not match with <5 CP")

-- TTD too short -> should NOT match
spell_ready_calls = {}
assert_false(rupture.matches({
    ttd_known = true, ttd = 5, target = {}, settings = { combat_rupture_ttd = 12 },
}, {
    rupture_ready = true, combo_points = 5, energy_pool_finisher = false,
}), "Rupture should not match when TTD < combat_rupture_ttd floor")

-- TTD unknown -> still checks CP (delegates to spell_ready for rest)
spell_ready_calls = {}
_G.EaxRotations.debuff_remains = function(target, ids) return 0 end
assert_true(rupture.matches({
    ttd_known = false, ttd = nil, target = {}, settings = {},
}, {
    rupture_ready = true, combo_points = 5, energy_pool_finisher = false,
}), "Rupture should match when TTD unknown and 5 CP")

print("PASS test_combat_custom_matches")
