-- test_reset_api_health.lua -- API lint health thresholds tests.
-- WHAT:  API lint health thresholds tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Protects against regressions in rotation logic and state handling.
-- SAFETY: Pure unit tests with mocked API context.

-- Test: NS.is_api_health_broken() and NS.reset_api_health() contract.
-- Updated for v2.1.x: PS build API health tracking was removed; both functions
-- are now no-op stubs (is_api_health_broken always returns false, reset is a no-op).
-- This test verifies the stubs exist, are callable, and return the expected
-- constant values without crashing.

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
-- SECTION 1: Non-PS build — stubs exist and return expected values
-- ====================================================================
io.write("--- Section 1: Non-PS build ---\n")

package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

_G.core = {
    time = function() return 0 end,
    game_time = function() return 0 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}

local NS = require("core_sylvanas")
_G.EaxRotations = NS

-- Stubs must exist
assert_true(type(NS.is_api_health_broken) == "function", "non-PS: is_api_health_broken is a function")
assert_true(type(NS.reset_api_health) == "function", "non-PS: reset_api_health is a function")

-- is_api_health_broken always returns false (tracking removed in v2.1.x)
assert_false(NS.is_api_health_broken(), "non-PS: is_api_health_broken returns false")

-- reset_api_health is a safe no-op (callable, doesn't crash)
NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "non-PS: still false after reset")

-- ====================================================================
-- SECTION 2: Idempotent — repeated calls are safe
-- ====================================================================
io.write("--- Section 2: Idempotent calls ---\n")

NS.reset_api_health()
NS.reset_api_health()
assert_false(NS.is_api_health_broken(), "idempotent: false after multiple resets")

-- ====================================================================
-- SECTION 3: PS build — same no-op contract (tracking removed for all builds)
-- ====================================================================
io.write("--- Section 3: PS build ---\n")

package.loaded["core_sylvanas"] = nil
_G.EaxRotations = nil

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

assert_true(type(NS_PS.is_api_health_broken) == "function", "PS: is_api_health_broken is a function")
assert_true(type(NS_PS.reset_api_health) == "function", "PS: reset_api_health is a function")
assert_false(NS_PS.is_api_health_broken(), "PS: is_api_health_broken returns false (tracking removed)")
NS_PS.reset_api_health()
assert_false(NS_PS.is_api_health_broken(), "PS: still false after reset")

-- ====================================================================
-- SECTION 4: Backward compat — NS.isfalse alias exists
-- ====================================================================
io.write("--- Section 4: Backward compat alias ---\n")

assert_true(type(NS.isfalse) == "function", "isfalse alias exists")
assert_false(NS.isfalse(), "isfalse returns false (alias of is_api_health_broken)")

-- ====================================================================
io.write("\nAll tests passed!\n")
