-- test_mm_trueshot_aura.lua -- aura handling tests.
-- WHAT:  aura handling tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Hunter Marksmanship Trueshot Aura (HU3)
-- ----------------------------------------------------------------------------
-- Verifies that marksmanship_sylvanas.lua correctly casts Trueshot Aura
-- when in combat, not already active, and ready.
-- ============================================================================

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

-- ============================================================================
-- Mock NS + registry hook
-- ============================================================================
local captured_strategies
local _buff_up_result = false
_G.EaxRotations = {
    HunterSpells = {
        AimedShot = 27065, ArcaneShot = 27019, AspectOfTheHawk = 27044,
        AspectOfTheViper = 34074, BestialWrath = 19574, CallPet = 883,
        FeignDeath = 5384, FreezingTrap = 14311, HuntersMark = 14325,
        KillCommand = 34026, MendPet = 136, MultiShot = 27021,
        RapidFire = 3045, Readiness = 23989, RevivePet = 982,
        SerpentSting = 27016, SteadyShot = 34120, ViperSting = 3034,
        Volley = 27022, ExplosiveTrap = 27026, TrueshotAura = 19506,
    },
    spell_ready = function(spell, target, opts) return true end,
    buff_up = function(me, buff_list)
        if buff_list and #buff_list == 3 and buff_list[1] == 19506 then
            return _buff_up_result  -- Trueshot Aura buff check
        end
        return false
    end,
    debuff_up = function(target, ids) return false end,
    debuff_remains = function(target, ids) return 0 end,
    try_cast = function(spell, target, tag, opts) return true end,
    is_spell_learned = function(id) return true end,
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
    GetPet = function() return nil end,
    unit_alive = function(unit) return false end,
    unit_mana_pct = function(unit) return 100 end,
}

-- ============================================================================
-- Mock pet_manager
-- ============================================================================
package.loaded["shared/pet_manager_sylvanas"] = {
    on_update = function() end,
    set_passive = function() return true end,
    set_aggressive = function() return true end,
    set_defensive = function() return true end,
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
dofile("EaxRotations/classes/hunter/marksmanship_sylvanas.lua")
local strategies = captured_strategies
assert_true(strategies, "strategies table should be captured")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

local trueshot = find_strategy("TrueshotAura")
assert_true(trueshot, "TrueshotAura strategy should exist")

local function make_state(overrides)
    local s = {
        in_combat = true,
        trueshot_aura_ready = true,
        trueshot_aura_active = false,
        rapid_fire_ready = false,
        readiness_ready = false,
        bestial_wrath_ready = false,
    }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

local function make_context(overrides)
    local c = {
        settings = { use_cooldowns = true },
        ttd_known = false,
        ttd = 999,
    }
    if overrides then
        for k, v in pairs(overrides) do c[k] = v end
    end
    return c
end

-- ============================================================================
-- Contract 1: In combat, not active, ready → match
-- ============================================================================
_buff_up_result = false
assert_true(trueshot.matches(make_context(), make_state()),
    "C1: in combat, not active, ready → should match")
print("  [ PASS ] C1: in combat, not active, ready → match")

-- ============================================================================
-- Contract 2: Already active → no match
-- ============================================================================
_buff_up_result = true
assert_false(trueshot.matches(make_context(), make_state({ trueshot_aura_active = true })),
    "C2: already active → should NOT match")
print("  [ PASS ] C2: already active → no match")

-- ============================================================================
-- Contract 3: Not ready → no match
-- ============================================================================
_buff_up_result = false
assert_false(trueshot.matches(make_context(), make_state({ trueshot_aura_ready = false })),
    "C3: not ready → should NOT match")
print("  [ PASS ] C3: not ready → no match")

-- ============================================================================
-- Contract 4: Out of combat → no match
-- ============================================================================
assert_false(trueshot.matches(make_context(), make_state({ in_combat = false })),
    "C4: out of combat → should NOT match")
print("  [ PASS ] C4: out of combat → no match")

-- ============================================================================
-- Contract 5: Cooldowns disabled → no match
-- ============================================================================
assert_false(trueshot.matches(make_context({ settings = { use_cooldowns = false } }), make_state()),
    "C5: cooldowns disabled → should NOT match")
print("  [ PASS ] C5: cooldowns disabled → no match")

-- ============================================================================
-- Contract 6: Short TTD (<10s) → no match
-- ============================================================================
assert_false(trueshot.matches(make_context({ ttd_known = true, ttd = 5 }), make_state()),
    "C6: short TTD (5s) → should NOT match")
print("  [ PASS ] C6: short TTD → no match")

-- ============================================================================
-- Contract 7: Long TTD, all good → match
-- ============================================================================
assert_true(trueshot.matches(make_context({ ttd_known = true, ttd = 30 }), make_state()),
    "C7: long TTD (30s), all good → should match")
print("  [ PASS ] C7: long TTD → match")

print("PASS test_mm_trueshot_aura")
