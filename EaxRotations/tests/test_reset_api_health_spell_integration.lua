-- Test: SpellValidation + TalentInference integration with is_api_health_broken.
-- Updated for v2.1.x: API health tracking was removed; is_api_health_broken is
-- a constant false stub. This test verifies that SpellValidation and
-- TalentInference work correctly when spell_book.is_spell_learned returns false
-- (the normal non-broken code path), and that reset_api_health is pcall-safe.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local assert_eq = function(a, b, msg)
    if a ~= b then
        io.write("FAIL: " .. tostring(msg or "assert_eq") .. " expected=" .. tostring(b) .. " actual=" .. tostring(a) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_eq") .. "\n")
end

local assert_true = function(v, msg)
    if v ~= true then
        io.write("FAIL: " .. tostring(msg or "assert_true") .. " expected=true actual=" .. tostring(v) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_true") .. "\n")
end

local assert_false = function(v, msg)
    if v ~= false then
        io.write("FAIL: " .. tostring(msg or "assert_false") .. " expected=false actual=" .. tostring(v) .. "\n")
        os.exit(1)
    end
    io.write("PASS: " .. tostring(msg or "assert_false") .. "\n")
end

-- ====================================================================
-- SETUP: Minimal core mock with spell_book that always returns false
-- ====================================================================
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

_G.core = {
    get_game_version = function() return "wow_tbc" end,
    get_exact_game_version = function() return "wow_tbc" end,
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
    spell_book = {
        is_spell_learned = function(id) return false end,  -- always false
    },
    input = {},
}

local NS = require("core_sylvanas")
_G.EaxRotations = NS

-- is_api_health_broken is a no-op stub (tracking removed in v2.1.x)
assert_false(NS.is_api_health_broken(), "initially not broken (stub)")

-- Load SpellValidation and TalentInference
local SV = require("shared/spell_validation_sylvanas")
local TI = require("shared/talent_inference_sylvanas")

-- ====================================================================
-- SECTION 1: spell_book returns false — spells are NOT learned
-- ====================================================================
io.write("--- Section 1: spell_book=false (spells not learned) ---\n")

-- SpellValidation: required spell is missing
local result = SV.validate_spell(12294, true)  -- Mortal Strike (required)
assert_eq(result.status, "missing_required", "required spell is 'missing_required'")

result = SV.validate_spell(23881, false)  -- Bloodthirst (optional)
assert_eq(result.status, "missing_optional", "optional spell is 'missing_optional'")

-- validate_spell with nil spell_id
result = SV.validate_spell(nil, true)
assert_eq(result.status, "missing_required", "nil required spell is 'missing_required'")

result = SV.validate_spell(nil, false)
assert_eq(result.status, "missing_optional", "nil optional spell is 'missing_optional'")

-- TalentInference: mortal_strike not learned
assert_false(TI.has_talent("warrior", "Mortal Strike"), "warrior does NOT have mortal_strike")

-- TalentInference: spec unknown (no spells learned)
local spec = TI.get_inferred_spec("warrior")
assert_eq(spec, "unknown", "warrior spec is 'unknown'")

-- ====================================================================
-- SECTION 2: reset_api_health is pcall-safe (no-op stub)
-- ====================================================================
io.write("--- Section 2: pcall-safe reset ---\n")

local ok, err = pcall(NS.reset_api_health)
assert_true(ok, "pcall: reset_api_health did not error")

-- Still not broken after reset
assert_false(NS.is_api_health_broken(), "still false after reset")

-- Modules still report correct state
assert_eq(SV.validate_spell(12294, true).status, "missing_required", "still missing after reset")
assert_eq(TI.get_inferred_spec("warrior"), "unknown", "spec still unknown after reset")

-- ====================================================================
-- SECTION 3: Idempotent — multiple resets are safe
-- ====================================================================
io.write("--- Section 3: Idempotent resets ---\n")

NS.reset_api_health()
NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "false after multiple resets")
assert_eq(TI.get_inferred_spec("warrior"), "unknown", "spec still unknown after multiple resets")

-- ====================================================================
io.write("\nAll tests passed!\n")
