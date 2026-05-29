-- Test: NS.reset_api_health() integration with SpellValidation + TalentInference
-- Uses debug.setupvalue to control the real _api_health_broken flag, verifying
-- that both modules respond correctly through the real NS.is_spell_learned →
-- NS.spell_id_is_known() → _api_health_broken chain.
--
-- Unlike the spy-based test (test_spell_validation_talent_inference_health.lua),
-- this test does NOT mock NS.is_spell_learned. Instead it provides a real
-- spell_book.is_spell_learned that returns false, and toggles _api_health_broken
-- directly via debug.setupvalue to observe the effect on the real code path.

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

-- Helper: find a named upvalue index on a function
local function find_upval(fn, name)
    for i = 1, 30 do
        local n = debug.getupvalue(fn, i)
        if n == nil then return nil end
        if n == name then return i end
    end
    return nil
end

-- Helper: write a named upvalue on a function
local function set_upval(fn, name, value)
    local idx = find_upval(fn, name)
    if not idx then error("upvalue '" .. name .. "' not found on " .. tostring(fn)) end
    debug.setupvalue(fn, idx, value)
end

-- ====================================================================
-- SETUP: Minimal core mock with spell_book that always returns false
-- ====================================================================
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

_G.core = {
    get_game_version = function() return "wow_tbc" end,
    get_exact_game_version = function() return "wow_tbc" end,  -- non-PS
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

-- Verify non-PS build: _api_health_broken starts false
assert_false(NS.is_api_health_broken(), "non-PS: initially not broken")

-- Load SpellValidation
local SV = require("shared/spell_validation_sylvanas")

-- Load TalentInference
local TI = require("shared/talent_inference_sylvanas")

-- ====================================================================
-- SECTION 1: _api_health_broken=true — spells are "learned" via broken-API fallback
-- ====================================================================
io.write("--- Section 1: _api_health_broken=true (spells learned via fallback) ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "broken=true: flag is set")

-- SpellValidation: validate_spell returns "present" even though real API returns false
local result = SV.validate_spell(12294, true)  -- Mortal Strike (required)
assert_eq(result.status, "present", "broken=true: required spell is 'present'")

result = SV.validate_spell(23881, false)  -- Bloodthirst (optional)
assert_eq(result.status, "present", "broken=true: optional spell is 'present'")

-- validate_spell with a nil spell_id also works
result = SV.validate_spell(nil, true)
assert_eq(result.status, "missing_required", "broken=true: nil required spell is 'missing_required'")

result = SV.validate_spell(nil, false)
assert_eq(result.status, "missing_optional", "broken=true: nil optional spell is 'missing_optional'")

-- TalentInference: mortal_strike signature spells are "learned"
assert_true(TI.has_talent("warrior", "Mortal Strike"), "broken=true: warrior has mortal_strike talent")

-- TalentInference: spec inferred as Arms
local spec = TI.get_inferred_spec("warrior")
assert_eq(spec, "Arms", "broken=true: warrior spec inferred as Arms")

-- ====================================================================
-- SECTION 2: Call NS.reset_api_health() → _api_health_broken=false
-- ====================================================================
io.write("--- Section 2: After NS.reset_api_health() (broken cleared) ---\n")

NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "after reset: flag is cleared")

-- SpellValidation: validate_spell returns "missing_required" because real API returns false
local result = SV.validate_spell(12294, true)
assert_eq(result.status, "missing_required", "after reset: required spell is 'missing_required'")

result = SV.validate_spell(23881, false)
assert_eq(result.status, "missing_optional", "after reset: optional spell is 'missing_optional'")

-- TalentInference: mortal_strike not learned
assert_false(TI.has_talent("warrior", "Mortal Strike"), "after reset: warrior does NOT have mortal_strike")

-- TalentInference: spec unknown
local spec = TI.get_inferred_spec("warrior")
assert_eq(spec, "unknown", "after reset: warrior spec is 'unknown'")

-- ====================================================================
-- SECTION 3: Set broken=true again — modules re-detect the change
-- ====================================================================
io.write("--- Section 3: Toggle broken=true again ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "toggle back: flag is set again")

-- SpellValidation: back to "present"
local result = SV.validate_spell(12294, true)
assert_eq(result.status, "present", "toggle back: required spell is 'present'")

-- TalentInference: back to learned
assert_true(TI.has_talent("warrior", "Mortal Strike"), "toggle back: warrior has mortal_strike again")
assert_eq(TI.get_inferred_spec("warrior"), "Arms", "toggle back: spec is Arms again")

-- ====================================================================
-- SECTION 4: Reset again — back to "not learned"
-- ====================================================================
io.write("--- Section 4: Reset again ---\n")

NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "reset again: flag cleared")

-- SpellValidation
local result = SV.validate_spell(12294, true)
assert_eq(result.status, "missing_required", "reset again: required spell is 'missing_required'")

result = SV.validate_spell(23881, false)
assert_eq(result.status, "missing_optional", "reset again: optional spell is 'missing_optional'")

-- TalentInference
assert_false(TI.has_talent("warrior", "Mortal Strike"), "reset again: no mortal_strike")
assert_eq(TI.get_inferred_spec("warrior"), "unknown", "reset again: spec is 'unknown'")

-- ====================================================================
-- SECTION 5: Toggle broken=true then reset via pcall (simulating /reload guard)
-- ====================================================================
io.write("--- Section 5: pcall-safe reset guard ---\n")

set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "pcall guard: flag set")

-- This is the pattern used in dispatcher/reload: pcall(NS.reset_api_health)
local ok, err = pcall(NS.reset_api_health)
assert_true(ok, "pcall guard: reset_api_health did not error")
if err then io.write("  (reset error: " .. tostring(err) .. ")\n") end

assert_false(NS.is_api_health_broken(), "pcall guard: flag cleared after pcall reset")
assert_eq(TI.get_inferred_spec("warrior"), "unknown", "pcall guard: spec is unknown")

-- ====================================================================
io.write("\nAll tests passed!\n")
