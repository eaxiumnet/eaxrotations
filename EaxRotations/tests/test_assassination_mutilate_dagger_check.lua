-- ============================================================================
-- Test: Rogue Assassination Mutilate Dagger Check (RO4)
-- ----------------------------------------------------------------------------
-- Verifies that assassination_sylvanas.lua correctly gates Mutilate on
-- equipped daggers in BOTH hands, and falls back to Sinister Strike when
-- daggers are missing.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock dagger set
-- ============================================================================
package.loaded["shared/dagger_set_sylvanas"] = {
    is_dagger = {
        [28729] = true,  -- Spiteblade (dagger)
        [29381] = true,  -- Choker... wait, that's a necklace. Use a real dagger
        [32044] = true,  -- Merciless Gladiator's Shanker
        [32046] = true,  -- Merciless Gladiator's Shiv
    }
}

-- ============================================================================
-- Mock NS + registry hook
-- ============================================================================
local captured_strategies
local _equipped_ids = {}
_G.EaxRotations = {
    RogueSpells = {
        Stealth = 1784, AdrenalineRush = 13750, BladeFlurry = 13877,
        SliceAndDice = 6774, Rupture = 1943, Eviscerate = 11300,
        SinisterStrike = 26862, Kick = 1766, Gouge = 1776, Sprint = 2983,
        Vanish = 1857, Feint = 1966, Hemorrhage = 26864, Backstab = 26863,
        GhostlyStrike = 14278, KidneyShot = 8643, ExposeArmor = 11198,
        Shiv = 5938, Evasion = 26669, CloakOfShadows = 31224,
        DeadlyThrow = 26679, Blind = 2094, Mutilate = 1329,
    },
    get_equipped_item_id = function(slot)
        return _equipped_ids[slot] or nil
    end,
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    buff_up = function(me, buff_list) return me and me._buff_up or false end,
    buff_remains = function(me, buff_ids) return me and me._buff_remains or 0 end,
    debuff_remains = function(target, ids) return 0 end,
    spell_ready = function(spell, target, opts) return true end,
    is_spell_learned = function(id) return true end,
    spell_exists = function(id) return true end,
    is_interruptible = function(target) return true end,
    get_spell_cooldown = function(spell) return 0 end,
    gate_cooldown_boss_only = function() return true end,
    log = function() end,
    time_now = function() return 1000 end,
    broken_api_throttled = function(spell, seconds) return false end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            captured_strategies = strategies
        end,
    },
    GetPlayer = function() return { _buff_up = false, _buff_remains = 0 } end,
}

-- ============================================================================
-- Load spec
-- ============================================================================
dofile("EaxRotations/classes/rogue/assassination_sylvanas.lua")
local strategies = captured_strategies
assert_true(strategies, "strategies table should be captured")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local mutilate = find_strategy("Mutilate")
local ss_fallback = find_strategy("SinisterStrikeFallback")
assert_true(mutilate, "Mutilate strategy should exist")
assert_true(ss_fallback, "SinisterStrikeFallback strategy should exist")

local function make_state(has_daggers, target_poisoned, energy)
    return {
        in_combat = true,
        is_stealthed = false,
        has_snd = true, snd_needs_refresh = false,
        rupture_remains = 10, garrote_remains = 0,
        dp_stacks = 1, dp_remains = 10,
        combo = 3, energy = energy or 60,
        energy_low = false, energy_pool_finisher = false,
        target_poisoned = target_poisoned ~= false,
        has_daggers = has_daggers,
        slice_and_dice_ready = true, kidney_shot_ready = true,
        expose_armor_ready = true, shiv_ready = false, shiv_purge_name = nil,
        healing_item_id = nil, hp_pct = 100,
        kick_ready = true, gouge_ready = true, sprint_ready = true,
        vanish_ready = true, feint_ready = true, evasion_ready = true,
        cloak_ready = true, hemorrhage_ready = true, backstab_ready = true,
        ghostly_strike_ready = true, adrenaline_rush_ready = true,
        blade_flurry_ready = true,
    }
end

-- ============================================================================
-- Contract 1: Both daggers equipped → Mutilate fires
-- ============================================================================
_equipped_ids = { [16] = 28729, [17] = 32044 }
local state1 = make_state(true, true, 60)
assert_true(mutilate.matches({ target = true }, state1),
    "C1: both daggers + poisoned → Mutilate should fire")
print("  [ PASS ] C1: both daggers equipped → Mutilate fires")

-- ============================================================================
-- Contract 2: Main hand not dagger → Mutilate blocked, SS fallback fires
-- ============================================================================
_equipped_ids = { [16] = 28295, [17] = 32044 }  -- main = sword, off = dagger
local state2 = make_state(false, true, 60)
assert_false(mutilate.matches({ target = true }, state2),
    "C2: main hand not dagger → Mutilate should NOT fire")
assert_true(ss_fallback.matches({ target = true, player_level = 70 }, state2),
    "C2: main hand not dagger → SS fallback should fire")
print("  [ PASS ] C2: main hand not dagger → Mutilate blocked, SS fallback fires")

-- ============================================================================
-- Contract 3: Off hand not dagger → Mutilate blocked, SS fallback fires
-- ============================================================================
_equipped_ids = { [16] = 28729, [17] = 28295 }  -- main = dagger, off = sword
local state3 = make_state(false, true, 60)
assert_false(mutilate.matches({ target = true }, state3),
    "C3: off hand not dagger → Mutilate should NOT fire")
assert_true(ss_fallback.matches({ target = true, player_level = 70 }, state3),
    "C3: off hand not dagger → SS fallback should fire")
print("  [ PASS ] C3: off hand not dagger → Mutilate blocked, SS fallback fires")

-- ============================================================================
-- Contract 4: Neither hand has dagger → Mutilate blocked, SS fallback fires
-- ============================================================================
_equipped_ids = { [16] = 28295, [17] = 28295 }  -- both swords
local state4 = make_state(false, true, 60)
assert_false(mutilate.matches({ target = true }, state4),
    "C4: neither dagger → Mutilate should NOT fire")
assert_true(ss_fallback.matches({ target = true, player_level = 70 }, state4),
    "C4: neither dagger → SS fallback should fire")
print("  [ PASS ] C4: neither hand has dagger → Mutilate blocked, SS fallback fires")

-- ============================================================================
-- Contract 5: Unarmed (no weapons) → Mutilate blocked
-- ============================================================================
_equipped_ids = {}
local state5 = make_state(false, true, 60)
assert_false(mutilate.matches({ target = true }, state5),
    "C5: unarmed → Mutilate should NOT fire")
print("  [ PASS ] C5: unarmed → Mutilate blocked")

-- ============================================================================
-- Contract 6: Daggers equipped but target unpoisoned → Mutilate still fires
-- ============================================================================
_equipped_ids = { [16] = 28729, [17] = 32044 }
local state6 = make_state(true, false, 60)
assert_true(mutilate.matches({ target = true }, state6),
    "C6: both daggers + unpoisoned → Mutilate should still fire")
print("  [ PASS ] C6: daggers equipped, target unpoisoned → Mutilate still fires")

print("PASS test_assassination_mutilate_dagger_check")
