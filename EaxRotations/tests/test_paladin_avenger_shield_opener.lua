-- test_paladin_avenger_shield_opener.lua -- Paladin shield logic tests.
-- WHAT:  Paladin shield logic tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Paladin Protection Avenger's Shield Opener (TK4)
-- ----------------------------------------------------------------------------
-- Verifies that avenger_shield_matches() in protection_sylvanas.lua allows
-- pre-pull casts when prot_avenger_opener is enabled, and correctly blocks
-- them when disabled or conditions aren't met.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- ============================================================================
-- Mock NS
-- ============================================================================
_G.EaxRotations = {
    PaladinSpells = {
        AvengerShield = 32700,
        Consecration = 27173,
        HolyShield = 27179,
        Judgement = 20271,
        SealRighteousness = 27155,
        SealCommand = 27170,
        FlashOfLight = 27137,
        RighteousFury = 25780,
        BlessingOfSanctuary = 27168,
        DevotionAura = 27149,
        DivineShield = 642,
        Cleanse = 4987,
        HammerOfWrath = 27180,
        Exorcism = 27138,
        HolyWrath = 27139,
        LayOnHands = 27145,
        HandOfReckoning = 62124,
        RighteousDefense = 31789,
        HammerOfJustice = 10308,
        HolyShock = 33072,
    },
    spell_ready = function() return true end,
    buff_up = function() return false end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    buff_remains = function() return 0 end,
    buff_points = function() return nil end,
    try_cast = function() return true end,
    is_spell_learned = function() return true end,
    get_spell_cooldown = function() return 0 end,
    gate_cooldown_boss_only = function() return true end,
    broken_api_throttled = function() return false end,
    log = function() end,
    time_now = function() return 1000 end,
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    unit_alive = function() return true end,
    unit_mana_pct = function() return 100 end,
    unit_health_pct = function() return 100 end,
    is_casting = function() return false end,
    is_in_combat = function() return false end,
    has_breakable_cc_nearby = function() return false end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            _G.captured_strategies = strategies
        end,
    },
    setting = function(context, key, default)
        local s = (type(context) == "table" and context.settings) or {}
        if s[key] ~= nil then return s[key] end
        return default
    end,
}

-- ============================================================================
-- Mock potion_helper
-- ============================================================================
package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {},
    MANA_POTION_IDS = {},
}

-- ============================================================================
-- Load spec
-- ============================================================================
dofile("EaxRotations/classes/paladin/protection_sylvanas.lua")
local strategies = _G.captured_strategies
assert_true(strategies, "strategies table should be captured")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local avenger = find_strategy("AvengerShield")
assert_true(avenger, "AvengerShield strategy should exist")

local function make_context(in_combat, has_target, settings)
    return {
        me = {},
        target = has_target and {} or nil,
        has_valid_enemy_target = has_target == true,
        in_combat = in_combat == true,
        settings = settings or {},
        mana_pct = 100,
        enemy_count = 1,
        cc_nearby = false,
    }
end

local function make_state(ready)
    return {
        avenger_ready = ready ~= false,
        cc_nearby = false,
    }
end

-- ============================================================================
-- Contract 1: Pre-pull, opener enabled, target exists, ready → match
-- ============================================================================
assert_true(avenger.matches(make_context(false, true, { prot_avenger_opener = true }), make_state(true)),
    "C1: pre-pull + opener enabled + target + ready → should match")
print("  [ PASS ] C1: pre-pull opener → match")

-- ============================================================================
-- Contract 2: Pre-pull, opener disabled → no match
-- ============================================================================
assert_false(avenger.matches(make_context(false, true, { prot_avenger_opener = false }), make_state(true)),
    "C2: pre-pull + opener disabled → should NOT match")
print("  [ PASS ] C2: pre-pull opener disabled → no match")

-- ============================================================================
-- Contract 3: In combat, normal usage → match
-- ============================================================================
assert_true(avenger.matches(make_context(true, true, {}), make_state(true)),
    "C3: in combat + target + ready → should match")
print("  [ PASS ] C3: in combat → match")

-- ============================================================================
-- Contract 4: No target → no match
-- ============================================================================
assert_false(avenger.matches(make_context(false, false, { prot_avenger_opener = true }), make_state(true)),
    "C4: no target → should NOT match")
print("  [ PASS ] C4: no target → no match")

-- ============================================================================
-- Contract 5: Not ready → no match
-- ============================================================================
assert_false(avenger.matches(make_context(false, true, { prot_avenger_opener = true }), make_state(false)),
    "C5: not ready → should NOT match")
print("  [ PASS ] C5: not ready → no match")

-- ============================================================================
-- Contract 6: CC nearby → no match (even pre-pull)
-- ============================================================================
local state_cc = { avenger_ready = true, cc_nearby = true }
assert_false(avenger.matches(make_context(false, true, { prot_avenger_opener = true }), state_cc),
    "C6: CC nearby → should NOT match")
print("  [ PASS ] C6: CC nearby → no match")

-- ============================================================================
-- Contract 7: Avenger's Shield disabled entirely → no match
-- ============================================================================
assert_false(avenger.matches(make_context(true, true, { prot_avenger_shield = false }), make_state(true)),
    "C7: prot_avenger_shield=false → should NOT match")
print("  [ PASS ] C7: disabled entirely → no match")

print("PASS test_paladin_avenger_shield_opener")
