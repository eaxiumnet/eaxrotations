-- Test: NS.reset_api_health() clears _api_health_broken on non-PS builds
-- Uses debug.setupvalue to directly manipulate the local variable since
-- on non-PS builds there is no code path that sets _api_health_broken = true.

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

-- Helper: read a named upvalue value from a function
local function get_upval(fn, name)
    local idx = find_upval(fn, name)
    if not idx then return nil end
    local _, val = debug.getupvalue(fn, idx)
    return val
end

-- Helper: write a named upvalue on a function
local function set_upval(fn, name, value)
    local idx = find_upval(fn, name)
    if not idx then error("upvalue '" .. name .. "' not found on " .. tostring(fn)) end
    debug.setupvalue(fn, idx, value)
end

-- ====================================================================
-- SECTION 1: Non-PS build — reset clears the flag
-- ====================================================================
io.write("--- Section 1: Non-PS build ---\n")

-- Clear any previously loaded module
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

-- Minimal core mock with NO get_exact_game_version => non-PS build
_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}

local NS = require("core_sylvanas")
_G.EaxRotations = NS

-- Verify initially not broken (non-PS build, no get_exact_game_version)
assert_false(NS.is_api_health_broken(), "non-PS: initially not broken")

-- Use debug.setupvalue to set _api_health_broken = true directly
set_upval(NS.reset_api_health, "_api_health_broken", true)

-- Verify the flag is now set (shared upvalue, so is_api_health_broken sees it)
assert_true(NS.is_api_health_broken(), "non-PS: broken after direct upvalue set")

-- Call reset_api_health() — should clear the flag on non-PS
NS.reset_api_health()

-- Verify flag is cleared
assert_false(NS.is_api_health_broken(), "non-PS: reset_api_health clears _api_health_broken")

-- Verify counter variables are also reset
assert_eq(get_upval(NS.reset_api_health, "_api_health_calls"), 0, "non-PS: _api_health_calls reset to 0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_hits"), 0, "non-PS: _api_health_hits reset to 0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_warned"), false, "non-PS: _api_health_warned reset to false")

-- ====================================================================
-- SECTION 2: Non-PS build — set then clear with more calls/scenarios
-- ====================================================================
io.write("--- Section 2: Non-PS build — toggle broken flag ---\n")

-- Set broken again
set_upval(NS.reset_api_health, "_api_health_broken", true)
assert_true(NS.is_api_health_broken(), "non-PS toggle: broken after set")

-- Also set counters to non-zero values before reset
set_upval(NS.reset_api_health, "_api_health_calls", 50)
set_upval(NS.reset_api_health, "_api_health_hits", 10)
set_upval(NS.reset_api_health, "_api_health_warned", true)

-- Call reset
NS.reset_api_health()

-- Verify everything is zeroed and flag is false
assert_false(NS.is_api_health_broken(), "non-PS toggle: cleared after reset")
assert_eq(get_upval(NS.reset_api_health, "_api_health_calls"), 0, "non-PS toggle: calls=0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_hits"), 0, "non-PS toggle: hits=0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_warned"), false, "non-PS toggle: warned=false")

-- ====================================================================
-- SECTION 3: Non-PS build — idempotent: reset when already clean is a no-op
-- ====================================================================
io.write("--- Section 3: Non-PS build — idempotent reset ---\n")

-- Flag is already false from previous test
assert_false(NS.is_api_health_broken(), "idempotent: already clean")

-- Call reset again
NS.reset_api_health()

-- Still clean
assert_false(NS.is_api_health_broken(), "idempotent: still clean after second reset")
assert_eq(get_upval(NS.reset_api_health, "_api_health_calls"), 0, "idempotent: calls=0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_hits"), 0, "idempotent: hits=0")
assert_eq(get_upval(NS.reset_api_health, "_api_health_warned"), false, "idempotent: warned=false")

-- ====================================================================
-- SECTION 4: PS build — reset preserves the broken flag
-- ====================================================================
io.write("--- Section 4: PS build ---\n")

-- Reload with PS build version mock
package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

-- Core mock with get_exact_game_version returning "wow_tbc_ps"
_G.core = {
    get_exact_game_version = function() return "wow_tbc_ps" end,
    get_game_version = function() return "wow_tbc" end,
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}

local NS_PS = require("core_sylvanas")
_G.EaxRotations = NS_PS

-- On PS build, _api_health_broken is set to true at module load time
assert_true(NS_PS.is_api_health_broken(), "PS: initially broken at load")

-- Call reset_api_health() — on PS builds the flag is preserved
NS_PS.reset_api_health()

-- Verify flag is still true (preserved, not cleared)
assert_true(NS_PS.is_api_health_broken(), "PS: reset preserves broken flag for PS builds")

-- Verify counters are reset even though flag is preserved
assert_eq(get_upval(NS_PS.reset_api_health, "_api_health_calls"), 0, "PS: _api_health_calls reset to 0")
assert_eq(get_upval(NS_PS.reset_api_health, "_api_health_hits"), 0, "PS: _api_health_hits reset to 0")
assert_eq(get_upval(NS_PS.reset_api_health, "_api_health_warned"), false, "PS: _api_health_warned reset to false")

-- ====================================================================
-- SECTION 5: PS build — second reset also preserves
-- ====================================================================
io.write("--- Section 5: PS build — idempotent preserve ---\n")

assert_true(NS_PS.is_api_health_broken(), "PS idempotent: still broken")

NS_PS.reset_api_health()

assert_true(NS_PS.is_api_health_broken(), "PS idempotent: preserved after second reset")

-- ====================================================================
-- SECTION 6: Verify that is_api_health_broken returns false after non-PS reload
-- ====================================================================
io.write("--- Section 6: Non-PS reload — clean slate ---\n")

package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil
_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}

local NS_CLEAN = require("core_sylvanas")
_G.EaxRotations = NS_CLEAN

assert_false(NS_CLEAN.is_api_health_broken(), "clean reload: not broken")
assert_eq(get_upval(NS_CLEAN.reset_api_health, "_api_health_calls"), 0, "clean reload: calls=0")
assert_eq(get_upval(NS_CLEAN.reset_api_health, "_api_health_hits"), 0, "clean reload: hits=0")
assert_eq(get_upval(NS_CLEAN.reset_api_health, "_api_health_warned"), false, "clean reload: warned=false")

-- ====================================================================
io.write("\nAll tests passed!\n")
