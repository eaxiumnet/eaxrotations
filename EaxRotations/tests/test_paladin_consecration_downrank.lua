-- test_paladin_consecration_downrank.lua -- Paladin tests.
-- WHAT:  Paladin tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Paladin Protection Consecration Downrank (TK3)
-- ----------------------------------------------------------------------------
-- Verifies that protection_sylvanas.lua casts downranked Consecration
-- when mana is below thresholds, and highest rank when mana is sufficient.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS + captured casts
-- ============================================================================
local _last_cast_spell = nil
local _last_cast_tag = nil
_G.EaxRotations = {
    PaladinSpells = {
        Consecration = 27173,  -- R6 (highest)
        RighteousFury = 25780,
        HolyShield = 27179,
        AvengerShield = 32700,
        Judgement = 20271,
        SealCommand = 27170,
        SealRighteousness = 27155,
        FlashOfLight = 27137,
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
    },
    spell_ready = function(spell, target, opts) return true end,
    buff_up = function(me, buff_list) return false end,
    debuff_up = function(target, ids) return false end,
    debuff_remains = function(target, ids) return 0 end,
    buff_remains = function(unit, ids) return 0 end,
    buff_points = function(unit, ids) return nil end,
    try_cast = function(spell, target, tag, opts)
        _last_cast_spell = spell
        _last_cast_tag = tag
        return true
    end,
    is_spell_learned = function(id) return true end,
    get_spell_cooldown = function(spell) return 0 end,
    log = function() end,
    time_now = function() return 1000 end,
    GetPlayer = function() return {} end,
    GetPet = function() return nil end,
    unit_alive = function(unit) return true end,
    unit_mana_pct = function(unit) return 100 end,
    unit_health_pct = function(unit) return 100 end,
    is_casting = function(unit) return false end,
    is_in_combat = function(unit) return true end,
    has_breakable_cc_nearby = function() return false end,
    rotation_registry = {
        register = function(self, spec, strategies, opts)
            _G.captured_strategies = strategies
        end,
    },
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

local consecration = find_strategy("Consecration")
assert_true(consecration, "Consecration strategy should exist")

local function make_context(mana_pct, settings)
    return {
        me = {},
        target = {},
        mana_pct = mana_pct or 100,
        settings = settings or {},
        in_combat = true,
        enemy_count = 3,
        cc_nearby = false,
    }
end

local function make_state(mana_pct)
    return {
        consecration_ready = true,
        mana_pct = mana_pct or 100,
        enemy_count = 3,
        cc_nearby = false,
        consecration_remains = 0,
    }
end

-- ============================================================================
-- Contract 1: High mana (100%) → cast highest rank (27173)
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(100))
assert_eq(_last_cast_spell, 27173, "C1: high mana → should cast rank 6 (27173)")
print("  [ PASS ] C1: high mana → cast rank 6")

-- ============================================================================
-- Contract 2: Mid mana (55%) → cast rank 5 (20924)
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(55))
assert_eq(_last_cast_spell, 20924, "C2: 55% mana → should cast rank 5 (20924)")
print("  [ PASS ] C2: 55% mana → cast rank 5")

-- ============================================================================
-- Contract 3: Low mana (45%) → cast rank 4 (20923)
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(45))
assert_eq(_last_cast_spell, 20923, "C3: 45% mana → should cast rank 4 (20923)")
print("  [ PASS ] C3: 45% mana → cast rank 4")

-- ============================================================================
-- Contract 4: Very low mana (38%) → cast rank 3 (20922)
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(38))
assert_eq(_last_cast_spell, 20922, "C4: 38% mana → should cast rank 3 (20922)")
print("  [ PASS ] C4: 38% mana → cast rank 3")

-- ============================================================================
-- Contract 5: Below minimum (30%) → no downrank available, falls back to full spell
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(30))
assert_eq(_last_cast_spell, 27173, "C5: 30% mana → below floor, fallback to rank 6")
print("  [ PASS ] C5: below floor → fallback to highest rank")

-- ============================================================================
-- Contract 6: Boundary test — exactly 60% → rank 6
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(60))
assert_eq(_last_cast_spell, 27173, "C6: exactly 60% mana → should cast rank 6")
print("  [ PASS ] C6: boundary 60% → rank 6")

-- ============================================================================
-- Contract 7: Boundary test — exactly 50% → rank 5
-- ============================================================================
_last_cast_spell = nil
consecration.execute(make_context(50))
assert_eq(_last_cast_spell, 20924, "C7: exactly 50% mana → should cast rank 5")
print("  [ PASS ] C7: boundary 50% → rank 5")

print("PASS test_paladin_consecration_downrank")
