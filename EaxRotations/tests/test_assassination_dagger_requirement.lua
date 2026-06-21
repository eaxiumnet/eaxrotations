-- ============================================================================
-- Test: Rogue Assassination Dagger Requirement (RO4)
-- ----------------------------------------------------------------------------
-- Coverage for Mutilate dagger gating in
-- EaxRotations/classes/rogue/assassination_sylvanas.lua.
-- Pins the contract that Mutilate only matches when both hands have weapons
-- equipped, and SinisterStrikeFallback fires when daggers are missing.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- Registry hook captures the strategies table
local captured_strategies
local captured_spec

_G.EaxRotations = {
    RogueSpells = {
        SliceAndDice = 6774,
        Envenom = 32684,
        ColdBlood = 14177,
        Rupture = 1943,
        Garrote = 703,
        Mutilate = 1329,
        SinisterStrike = 26862,
        Eviscerate = 11300,
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
        Hemorrhage = 26864,
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
            captured_strategies = strategies
            captured_spec = spec
        end,
    },
    log = function() end,
    time_now = function() return 1000 end,
    gate_cooldown_boss_only = function() return true end,
}

-- Stub get_equipped_item_id so tests can control dagger state
local _equipped_ids = {}
_G.EaxRotations.get_equipped_item_id = function(slot)
    return _equipped_ids[slot] or nil
end

dofile("EaxRotations/classes/rogue/assassination_sylvanas.lua")
local strategies = captured_strategies
assert_eq(captured_spec, "assassination", "registration should target the assassination spec")
assert_true(type(strategies) == "table", "strategies table should be captured")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name, 2)
end

local function default_state()
    return {
        is_stealthed = false,
        slice_dice_active = true,
        snd_remains = 30,
        snd_needs_refresh = false,
        rupture_remains = 0,
        garrote_remains = 0,
        dp_stacks = 5,
        target_poisoned = true,
        combo = 5,
        energy = 100,
        energy_low = false,
        energy_pool_finisher = false,
        hp_pct = 100,
        find_weakness_active = true,
        has_cold_blood = false,
        healing_item_id = nil,
        shiv_ready = false,
        shiv_purge_name = nil,
        has_daggers = true,
    }
end

local function default_context()
    return {
        target = { guid = "test-1", is_alive = function() return true end },
        in_combat = true,
        is_pvp = false,
        player_level = 70,
        target_distance = 5,
        target_bleed_immune = false,
        ttd = 30,
        ttd_known = true,
        settings = {},
        combo_points = nil,
    }
end

local mut = find_strategy("Mutilate")
local ssf = find_strategy("SinisterStrikeFallback")

-- ============================================================================
-- Contract 1: Mutilate — has_daggers=true, poisoned, energy OK → match
-- ============================================================================
do
    _equipped_ids = { [16] = 12345, [17] = 12346 }
    local s = default_state()
    assert_true(mut.matches(default_context(), s),
        "Mutilate should match when daggers equipped, target poisoned, energy OK")
end
print("  [ PASS ] Mutilate: daggers + poisoned + energy → match")

-- ============================================================================
-- Contract 2: Mutilate — has_daggers=false → NO match (RO4 core fix)
-- ============================================================================
do
    _equipped_ids = { [16] = nil, [17] = nil }
    local s = default_state(); s.has_daggers = false
    assert_false(mut.matches(default_context(), s),
        "Mutilate should NOT match when daggers missing")
end
print("  [ PASS ] Mutilate: no daggers → no match")

-- ============================================================================
-- Contract 3: Mutilate — only mainhand equipped → NO match
-- ============================================================================
do
    _equipped_ids = { [16] = 12345, [17] = nil }
    local s = default_state(); s.has_daggers = false
    assert_false(mut.matches(default_context(), s),
        "Mutilate should NOT match when only mainhand equipped")
end
print("  [ PASS ] Mutilate: mainhand only → no match")

-- ============================================================================
-- Contract 4: SinisterStrikeFallback — no daggers → match (fallback kicks in)
-- ============================================================================
do
    _equipped_ids = { [16] = nil, [17] = nil }
    local s = default_state(); s.has_daggers = false
    assert_true(ssf.matches(default_context(), s),
        "SinisterStrikeFallback should match when daggers missing")
end
print("  [ PASS ] SinisterStrikeFallback: no daggers → match")

-- ============================================================================
-- Contract 5: SinisterStrikeFallback — daggers present, poisoned → NO match
-- ============================================================================
do
    _equipped_ids = { [16] = 12345, [17] = 12346 }
    local s = default_state(); s.has_daggers = true; s.target_poisoned = true
    assert_false(ssf.matches(default_context(), s),
        "SinisterStrikeFallback should NOT match when Mutilate CAN be used")
end
print("  [ PASS ] SinisterStrikeFallback: daggers + poisoned → no match")

-- ============================================================================
-- Contract 6: SinisterStrikeFallback — daggers present, NOT poisoned → NO match
-- (Mutilate fires on unpoisoned targets too, just without the +50% bonus)
-- ============================================================================
do
    _equipped_ids = { [16] = 12345, [17] = 12346 }
    local s = default_state(); s.has_daggers = true; s.target_poisoned = false
    assert_false(ssf.matches(default_context(), s),
        "SinisterStrikeFallback should NOT match when daggers present — Mutilate handles unpoisoned targets")
end
print("  [ PASS ] SinisterStrikeFallback: daggers + unpoisoned → no match (Mutilate covers)")

-- ============================================================================
-- Contract 7: Pattern 14 — nil has_daggers must not crash Mutilate matcher
-- ============================================================================
do
    local s = default_state(); s.has_daggers = nil
    local ok, ret = pcall(mut.matches, default_context(), s)
    assert_true(ok, "Mutilate.matches must not crash with nil has_daggers")
    assert_true(ret == false or ret == true,
        "Mutilate.matches must return boolean with nil has_daggers")
end
print("  [ PASS ] Pattern 14: nil has_daggers → no crash")

print("PASS test_assassination_dagger_requirement")
