-- ============================================================================
-- Test: Rogue SnD Maintenance (RO2)
-- ----------------------------------------------------------------------------
-- Coverage for Slice and Dice priority ordering and refresh behavior in
-- EaxRotations/classes/rogue/assassination_sylvanas.lua,
-- EaxRotations/classes/rogue/combat_sylvanas.lua, and
-- EaxRotations/classes/rogue/subtlety_sylvanas.lua.
--
-- Canonical invariant: SnD is the FIRST finisher in every spec's priority list.
-- When SnD is missing or about to drop (<3s), it must match before any other
-- finisher (Envenom, Rupture, Eviscerate). Envenom must NEVER match when SnD
-- is missing or needs refresh — this is the guard that makes the ordering safe.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS
-- ============================================================================
local captured = {}

_G.EaxRotations = {
    RogueSpells = {
        SliceAndDice = 6774,
        Envenom = 32684,
        ColdBlood = 14177,
        Rupture = 1943,
        Eviscerate = 11300,
        Mutilate = 1329,
        SinisterStrike = 26862,
        Garrote = 703,
        Hemorrhage = 26864,
        Backstab = 26863,
        Ambush = 8676,
        ExposeArmor = 11198,
        DeadlyThrow = 26679,
        Blind = 2094,
        CheapShot = 1833,
        Sprint = 2983,
        Kick = 1766,
        Vanish = 1857,
        Shiv = 5938,
        Evasion = 26669,
        CloakOfShadows = 31224,
        Stealth = 1784,
        Premeditation = 14183,
        Shadowstep = 36554,
        Preparation = 14185,
        GhostlyStrike = 14278,
        KidneyShot = 8643,
        Feint = 1966,
        Gouge = 1776,
        ThistleTea = 7676,
        BladeFlurry = 13877,
        AdrenalineRush = 13750,
    },
    PLAYER_UNIT = "player",
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    has_player_buff = function() return false end,
    buff_remains = function() return 0 end,
    debuff_remains = function() return 0 end,
    spell_ready = function() return true end,
    broken_api_throttled = function() return false end,
    try_cast = function() return false end,
    spell_exists = function() return true end,
    is_spell_learned = function() return true end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            captured[spec] = { strategies = strategies, opts = opts }
        end,
    },
    log = function() end,
    time_now = function() return 1000 end,
    gate_cooldown_boss_only = function() return true end,
    get_equipped_item_id = function(slot) return nil end,
    spell_action = function(ids, label) return { ids = ids, label = label } end,
}

-- ============================================================================
-- Helper: load a spec and find a strategy by name
-- ============================================================================
local function load_spec(name)
    dofile("EaxRotations/classes/rogue/" .. name .. "_sylvanas.lua")
    assert_true(captured[name], "spec '" .. name .. "' should have been captured")
    return captured[name].strategies
end

local function find_strategy(strategies, name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i], i end
    end
    error("strategy not found: " .. name, 2)
end

-- ============================================================================
-- Helper: default states
-- ============================================================================
local function combat_state_overrides(overrides)
    local base = {
        in_combat = true, is_stealthed = false,
        has_snd = true, snd_needs_refresh = false,
        slice_and_dice_ready = true, combo_points = 5, energy = 80,
        rupture_ready = true, eviscerate_ready = true,
        sinister_strike_ready = true, blade_flurry_ready = true,
        adrenaline_rush_ready = true, has_blade_flurry = false,
        has_adrenaline_rush = false, heroism_active = false,
        target_count = 1, threat_pct = 0, hp_pct = 100,
        energy_low = false, energy_pool_finisher = false,
        kick_ready = true, gouge_ready = true, sprint_ready = true,
        vanish_ready = true, feint_ready = true,
        hemorrhage_ready = true, backstab_ready = true,
        ghostly_strike_ready = true, kidney_shot_ready = true,
        expose_armor_ready = true, shiv_ready = false, shiv_purge_name = nil,
    }
    if overrides then for k, v in pairs(overrides) do base[k] = v end end
    return base
end

local function assassin_state_overrides(overrides)
    local base = {
        slice_dice_active = true, snd_remains = 30, snd_needs_refresh = false,
        rupture_remains = 0, garrote_remains = 0, dp_stacks = 5,
        target_poisoned = true, combo = 5, energy = 100,
        energy_low = false, energy_pool_finisher = false,
        hp_pct = 100, find_weakness_active = true, has_cold_blood = false,
        healing_item_id = nil, shiv_ready = false, shiv_purge_name = nil,
        has_daggers = true, stealth_active = false,
    }
    if overrides then for k, v in pairs(overrides) do base[k] = v end end
    return base
end

local function subtlety_state_overrides(overrides)
    local base = {
        stealth_up = false, slice_remains = 30, rupture_remains = 0,
        hemo_remains = 0, expose_remains = 0, garrote_remains = 0,
        cheap_shot_remains = 0, kidney_remains = 0, shadowstep_buff = false,
        master_of_subtlety = false, combo = 5, energy = 100,
        energy_low = false, energy_pool_finisher = false,
        hp = 100, target_hp = 100, target_distance = 5,
        target_count = 1, is_behind = true, is_caster_target = false,
        control_active = false, threat_pct = 0, vanish_cd = 0,
        sprint_cd = 0, evasion_cd = 0, shiv_ready = false, shiv_purge_name = nil,
    }
    if overrides then for k, v in pairs(overrides) do base[k] = v end end
    return base
end

local function default_context()
    return {
        target = { guid = "test-1", is_alive = function() return true end, is_casting = function() return false end },
        in_combat = true, is_pvp = false, me = { _buff_up = false, _buff_remains = 0 },
        settings = {}, ttd = 30, ttd_known = true,
        target_bleed_immune = false, has_sunder = false,
        target_armor = 1000, enemy_count = 1,
    }
end

-- ============================================================================
-- COMBAT spec tests
-- ============================================================================
print("=== Combat Spec ===")
local combat_strats = load_spec("combat")
local combat_snd, combat_snd_idx = find_strategy(combat_strats, "SliceAndDice")
local combat_rupture, combat_rupture_idx = find_strategy(combat_strats, "Rupture")
local combat_evis, combat_evis_idx = find_strategy(combat_strats, "Eviscerate")

-- Contract C1: SnD is the FIRST finisher in combat
assert_true(combat_snd_idx < combat_rupture_idx, "Combat: SliceAndDice must come before Rupture")
assert_true(combat_snd_idx < combat_evis_idx, "Combat: SliceAndDice must come before Eviscerate")
print("  [ PASS ] Combat: SnD is first finisher")

-- Contract C2: SnD matches when missing and CP >= 2
assert_true(combat_snd.matches(default_context(), combat_state_overrides({ has_snd = false, combo_points = 3 })),
    "Combat: SnD should match when missing with 3 CP")
print("  [ PASS ] Combat: SnD matches when missing")

-- Contract C3: SnD matches when <3s remain and CP >= 2
assert_true(combat_snd.matches(default_context(), combat_state_overrides({ has_snd = true, snd_needs_refresh = true, combo_points = 3 })),
    "Combat: SnD should match when <3s remain")
print("  [ PASS ] Combat: SnD matches when refresh needed")

-- Contract C4: SnD does NOT match when up and >3s remain
assert_false(combat_snd.matches(default_context(), combat_state_overrides({ has_snd = true, snd_needs_refresh = false, combo_points = 5 })),
    "Combat: SnD should NOT match when buff healthy")
print("  [ PASS ] Combat: SnD does not match when healthy")

-- Contract C5: SnD does NOT match with <2 CP
assert_false(combat_snd.matches(default_context(), combat_state_overrides({ has_snd = false, combo_points = 1 })),
    "Combat: SnD should NOT match with 1 CP")
print("  [ PASS ] Combat: SnD does not match with 1 CP")

-- ============================================================================
-- ASSASSINATION spec tests
-- ============================================================================
print("=== Assassination Spec ===")
local assassin_strats = load_spec("assassination")
local assassin_snd, assassin_snd_idx = find_strategy(assassin_strats, "SliceAndDice")
local assassin_envenom, assassin_envenom_idx = find_strategy(assassin_strats, "EnvenomFinisher")
local assassin_cbe, assassin_cbe_idx = find_strategy(assassin_strats, "ColdBloodEnvenom")
local assassin_rupture, assassin_rupture_idx = find_strategy(assassin_strats, "RuptureBleed")

-- Contract A1: SnD is the FIRST finisher in assassination
assert_true(assassin_snd_idx < assassin_envenom_idx,
    "Assassination: SliceAndDice must come before EnvenomFinisher (RO2 fix)")
assert_true(assassin_snd_idx < assassin_cbe_idx,
    "Assassination: SliceAndDice must come before ColdBloodEnvenom (RO2 fix)")
assert_true(assassin_snd_idx < assassin_rupture_idx,
    "Assassination: SliceAndDice must come before RuptureBleed")
print("  [ PASS ] Assassination: SnD is first finisher")

-- Contract A2: SnD matches when missing and CP >= 2
assert_true(assassin_snd.matches(default_context(), assassin_state_overrides({ slice_dice_active = false, combo = 3 })),
    "Assassination: SnD should match when missing with 3 CP")
print("  [ PASS ] Assassination: SnD matches when missing")

-- Contract A3: SnD matches when <3s remain and CP >= 2
assert_true(assassin_snd.matches(default_context(), assassin_state_overrides({ slice_dice_active = true, snd_needs_refresh = true, combo = 3 })),
    "Assassination: SnD should match when <3s remain")
print("  [ PASS ] Assassination: SnD matches when refresh needed")

-- Contract A4: SnD does NOT match when up and >3s remain
assert_false(assassin_snd.matches(default_context(), assassin_state_overrides({ slice_dice_active = true, snd_needs_refresh = false, combo = 5 })),
    "Assassination: SnD should NOT match when buff healthy")
print("  [ PASS ] Assassination: SnD does not match when healthy")

-- Contract A5: Envenom does NOT match when SnD is missing (guard must work)
assert_false(assassin_envenom.matches(default_context(), assassin_state_overrides({ slice_dice_active = false, combo = 5, dp_stacks = 5 })),
    "Assassination: Envenom must NOT match when SnD is missing")
print("  [ PASS ] Assassination: Envenom blocked when SnD missing")

-- Contract A6: Envenom does NOT match when SnD needs refresh (guard must work)
assert_false(assassin_envenom.matches(default_context(), assassin_state_overrides({ slice_dice_active = true, snd_needs_refresh = true, combo = 5, dp_stacks = 5 })),
    "Assassination: Envenom must NOT match when SnD needs refresh")
print("  [ PASS ] Assassination: Envenom blocked when SnD needs refresh")

-- Contract A7: Envenom DOES match when SnD healthy, CP>=4, DP stacked
assert_true(assassin_envenom.matches(default_context(), assassin_state_overrides({ slice_dice_active = true, snd_needs_refresh = false, combo = 5, dp_stacks = 5 })),
    "Assassination: Envenom should match when SnD healthy")
print("  [ PASS ] Assassination: Envenom allowed when SnD healthy")

-- ============================================================================
-- SUBTLETY spec tests
-- ============================================================================
print("=== Subtlety Spec ===")
local sub_strats = load_spec("subtlety")
local sub_snd, sub_snd_idx = find_strategy(sub_strats, "SliceAndDice")
local sub_rupture, sub_rupture_idx = find_strategy(sub_strats, "Rupture")
local sub_evis, sub_evis_idx = find_strategy(sub_strats, "Eviscerate")

-- Contract S1: SnD is the FIRST finisher in subtlety
assert_true(sub_snd_idx < sub_rupture_idx, "Subtlety: SliceAndDice must come before Rupture")
assert_true(sub_snd_idx < sub_evis_idx, "Subtlety: SliceAndDice must come before Eviscerate")
print("  [ PASS ] Subtlety: SnD is first finisher")

-- Contract S2: SnD matches when missing and CP >= 2
assert_true(sub_snd.matches(default_context(), subtlety_state_overrides({ slice_remains = 0, combo = 3 })),
    "Subtlety: SnD should match when missing with 3 CP")
print("  [ PASS ] Subtlety: SnD matches when missing")

-- Contract S3: SnD matches when <3s remain and CP >= 2
assert_true(sub_snd.matches(default_context(), subtlety_state_overrides({ slice_remains = 2, combo = 3 })),
    "Subtlety: SnD should match when <3s remain")
print("  [ PASS ] Subtlety: SnD matches when refresh needed")

-- Contract S4: SnD does NOT match when up and >3s remain
assert_false(sub_snd.matches(default_context(), subtlety_state_overrides({ slice_remains = 5, combo = 5 })),
    "Subtlety: SnD should NOT match when buff healthy")
print("  [ PASS ] Subtlety: SnD does not match when healthy")

-- Contract S5: Subtlety SnD does NOT match with <2 CP
assert_false(sub_snd.matches(default_context(), subtlety_state_overrides({ slice_remains = 0, combo = 1 })),
    "Subtlety: SnD should NOT match with 1 CP")
print("  [ PASS ] Subtlety: SnD does not match with 1 CP")

print("PASS test_rogue_snd_maintenance")
