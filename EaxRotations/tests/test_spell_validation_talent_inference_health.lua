-- test_spell_validation_talent_inference_health.lua -- spell resolution validation suite talent inference health thresholds tests.
-- WHAT:  spell resolution validation suite talent inference health thresholds tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- ============================================================================
-- Test: Spell Validation and Talent Inference × reset_api_health integration
-- ============================================================================
-- Uses spy-based approach: mock NS.is_spell_learned with a controllable
-- flag to simulate the broken API / reset behavior, matching the pattern
-- used in test_ooc_manager.lua (tests 7a/7b).

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Time helpers (only needed by infer_cached TTL)
local current_time = 100
NS.time_now = function() return current_time end
local function advance(sec) current_time = current_time + sec end

NS.game_time_ms = function() return current_time * 1000 end
NS.log = print

-- Controllable flag for is_spell_learned spy
local is_spell_learned_return = false

-- Mock NS.is_spell_learned with controllable spy
NS.is_spell_learned = function(spell)
    return is_spell_learned_return
end

NS.PLAYER_CLASS = "warrior"

-- Mock class spell tables (needed by SpellValidation.validate_class_spells)
-- NOTE: validate_class_spells checks spell_data.id (singular), not .ids (plural).
-- Entries must use `id = <number>` to be validated.
NS.WarriorSpells = {
    BattleShout = { id = 25289, name = "Battle Shout" },
    MortalStrike = { ids = { 12294, 21551 }, name = "Mortal Strike" },
    ThunderClap = { id = 8198, name = "Thunder Clap" },
    DemoralizingShout = { ids = { 1160, 6190, 11554 }, name = "Demoralizing Shout" },
}

-- Load modules
dofile("EaxRotations/shared/spell_validation_sylvanas.lua")
dofile("EaxRotations/shared/talent_inference_sylvanas.lua")

local SV = NS.SpellValidation
local TI = NS.TalentInference

-- Assertion helpers
local function assert_eq(a, b, msg)
    if a ~= b then
        error(string.format("FAIL: %s -- expected [%s], got [%s]", msg or "", tostring(b), tostring(a)))
    end
    print("PASS " .. (msg or ""))
end

local function assert_true(v, msg)
    if v ~= true then
        error(string.format("FAIL: %s -- expected true, got %s", msg or "", tostring(v)))
    end
    print("PASS " .. (msg or ""))
end

local function assert_false(v, msg)
    if v ~= false then
        error(string.format("FAIL: %s -- expected false, got %s", msg or "", tostring(v)))
    end
    print("PASS " .. (msg or ""))
end

-- ================================================================
-- 1. SPELL VALIDATION × is_spell_learned spy (single spell)
-- ================================================================

-- 1a. Before reset: is_spell_learned returns false -> missing_required
is_spell_learned_return = false
local result = SV.validate_spell(25289, true)
assert_eq(result.status, "missing_required", "sv_before_reset_required_missing")

-- 1b. After reset: is_spell_learned returns true -> present
is_spell_learned_return = true
result = SV.validate_spell(25289, true)
assert_eq(result.status, "present", "sv_after_reset_required_present")

-- 1c. Optional spell before reset
is_spell_learned_return = false
result = SV.validate_spell(8198, false)
assert_eq(result.status, "missing_optional", "sv_optional_before_reset_missing")

-- 1d. Optional spell after reset
is_spell_learned_return = true
result = SV.validate_spell(8198, false)
assert_eq(result.status, "present", "sv_optional_after_reset_present")

-- ================================================================
-- 2. SOPELL VALIDATION × is_spell_available quick check
-- ================================================================

-- 2a. Before reset: not available
is_spell_learned_return = false
assert_false(SV.is_spell_available("BattleShout", "warrior"), "sv_available_before_reset")

-- 2b. After reset: available
is_spell_learned_return = true
assert_true(SV.is_spell_available("BattleShout", "warrior"), "sv_available_after_reset")

-- 2c. Unknown class returns false
assert_false(SV.is_spell_available("BattleShout", "monk"), "sv_available_unknown_class")

-- ================================================================
-- 3. SPELL VALIDATION × validate_class_spells
-- ================================================================

-- 3a. Before reset: BattleShout (required) missing, ThunderClap (optional) missing
is_spell_learned_return = false
result = SV.validate_class_spells("warrior", {"BattleShout"}, {"ThunderClap"})
assert_true(result.has_errors, "sv_class_before_reset_has_errors")
assert_eq(#result.missing_required, 1, "sv_class_before_reset_missing_req")
assert_eq(#result.missing_optional, 1, "sv_class_before_reset_missing_opt")

-- 3b. After reset: all present
is_spell_learned_return = true
result = SV.validate_class_spells("warrior", {"BattleShout"}, {"ThunderClap"})
assert_false(result.has_errors, "sv_class_after_reset_no_errors")
assert_eq(#result.missing_required, 0, "sv_class_after_reset_no_missing_req")
assert_eq(#result.present, 2, "sv_class_after_reset_two_present")

-- ================================================================
-- 4. TALENT INFERENCE × is_spell_learned spy
-- ================================================================

-- 4a. Before reset: no talents detected
is_spell_learned_return = false
local inferred = TI.infer("warrior")
assert_eq(inferred.talents["Mortal Strike"], false, "ti_before_reset_no_mortal_strike")
assert_eq(inferred.talents["Bloodthirst"], false, "ti_before_reset_no_bloodthirst")
assert_eq(inferred.talents["Shield Slam"], false, "ti_before_reset_no_shield_slam")
assert_eq(inferred.primary_tree, nil, "ti_before_reset_no_primary_tree")

-- 4b. After reset: talents detected
is_spell_learned_return = true
inferred = TI.infer("warrior")
assert_eq(inferred.talents["Mortal Strike"], true, "ti_after_reset_mortal_strike")
assert_eq(inferred.talents["Bloodthirst"], true, "ti_after_reset_bloodthirst")
assert_eq(inferred.talents["Shield Slam"], true, "ti_after_reset_shield_slam")
assert_eq(inferred.talents["Tactical Mastery"], true, "ti_after_reset_tactical_mastery")
assert_eq(inferred.primary_tree, "arms", "ti_after_reset_primary_arms")

-- ================================================================
-- 5. has_talent helper
-- ================================================================

-- 5a. Before reset: false
is_spell_learned_return = false
assert_eq(TI.has_talent("warrior", "Mortal Strike"), false, "ti_has_talent_before_reset")

-- 5b. After reset: true
is_spell_learned_return = true
assert_eq(TI.has_talent("warrior", "Mortal Strike"), true, "ti_has_talent_after_reset")

-- 5c. Snake_case key matches Title Case result
is_spell_learned_return = false
local display_name_result = TI.has_talent("warrior", "Mortal Strike")
local snake_case_result = TI.has_talent("warrior", "mortal_strike")
assert_eq(snake_case_result, display_name_result, "ti_has_talent_snake_case_before_reset")

is_spell_learned_return = true
display_name_result = TI.has_talent("warrior", "Mortal Strike")
snake_case_result = TI.has_talent("warrior", "mortal_strike")
assert_eq(snake_case_result, display_name_result, "ti_has_talent_snake_case_after_reset")

-- 5d. Other snake_case talents also resolve correctly
assert_eq(TI.has_talent("warrior", "bloodthirst"), TI.has_talent("warrior", "Bloodthirst"), "ti_has_talent_snake_case_bloodthirst")
assert_eq(TI.has_talent("warrior", "shield_slam"), TI.has_talent("warrior", "Shield Slam"), "ti_has_talent_snake_case_shield_slam")
assert_eq(TI.has_talent("warrior", "tactical_mastery"), TI.has_talent("warrior", "Tactical Mastery"), "ti_has_talent_snake_case_tactical_mastery")

-- 5e. Apostrophe talent name: "Avenger's Shield"
TI.clear_cache()
assert_eq(TI.has_talent("paladin", "avenger's_shield"), TI.has_talent("paladin", "Avenger's Shield"), "ti_has_talent_snake_case_avengers_shield")

-- ================================================================
-- 6. get_inferred_spec
-- ================================================================

-- 6a. Before reset: unknown
is_spell_learned_return = false
assert_eq(TI.get_inferred_spec("warrior"), "unknown", "ti_spec_before_reset_unknown")

-- 6b. After reset: Arms (most Mortal Strike signatures)
is_spell_learned_return = true
assert_eq(TI.get_inferred_spec("warrior"), "Arms", "ti_spec_after_reset_arms")

-- ================================================================
-- 7. Cached infer (infer_cached) — tests TTL and clear_cache
-- ================================================================

-- 7a. Clear cache, infer before reset
TI.clear_cache()
is_spell_learned_return = false
local cached = TI.infer_cached("warrior", 60)
assert_eq(cached.talents["Mortal Strike"], false, "ti_cached_before_reset")

-- 7b. Change flag but cache hasn't expired — cached result persists
is_spell_learned_return = true
advance(2)  -- 2s < 60s TTL
cached = TI.infer_cached("warrior", 60)
assert_eq(cached.talents["Mortal Strike"], false, "ti_cached_still_old_value")

-- 7c. Clear cache, now fresh infer picks up reset state
TI.clear_cache()
cached = TI.infer_cached("warrior", 60)
assert_eq(cached.talents["Mortal Strike"], true, "ti_cached_after_clear_has_talent")

-- ================================================================
-- 8. REAL reset_api_health call (no-crash guard)
-- ================================================================
-- Ensures NS.reset_api_health() doesn't crash when called from a
-- test environment (even if the real internal state isn't available).
if NS.reset_api_health then
    local ok, err = pcall(NS.reset_api_health)
    assert_true(ok, "sv_ti_reset_api_health_no_crash -- " .. tostring(err))
end

-- ================================================================
-- Done
-- ================================================================
print("PASS spell_validation_talent_inference_health")
