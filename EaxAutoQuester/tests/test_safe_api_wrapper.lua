-- What: Unit tests for EaxAutoQuester/safe_api_wrapper.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify probe, call, call_pcall, wrap, probe_batch correctly handle probed APIs

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local safe_api = require("EaxAutoQuester/safe_api_wrapper")

-- ============================================================================
-- S1: probe() with available function
-- ============================================================================
do
    local probe = safe_api.probe(function() return 42 end)
    assert(probe.available == true, "S1 FAIL: probe should mark available function")
    assert(type(probe.fn) == "function", "S1 FAIL: probe.fn should be the function")
    print("  S1 PASS: probe() correctly identifies available function")
end

-- ============================================================================
-- S2: probe() with nil function
-- ============================================================================
do
    local probe = safe_api.probe(nil)
    assert(probe.available == false, "S2 FAIL: probe(nil) should mark unavailable")
    print("  S2 PASS: probe(nil) returns unavailable")
end

-- ============================================================================
-- S3: probe() with failing function marks as maybe
-- ============================================================================
do
    local probe = safe_api.probe(function() error("intentional") end)
    assert(probe.available == false, "S3 FAIL: failing probe should not be available")
    assert(probe.maybe == true, "S3 FAIL: failing probe should be marked maybe")
    print("  S3 PASS: probe() marks failing function as maybe")
end

-- ============================================================================
-- S4: call() fast-path with available probed handle
-- ============================================================================
do
    local probe = safe_api.probe(function() return 42 end)
    local result = safe_api.call(probe)
    assert(result == 42, "S4 FAIL: call() should invoke probed function. Got " .. tostring(result))
    print("  S4 PASS: call() invokes probed function with args")
end

-- ============================================================================
-- S5: call() returns nil for unavailable handle
-- ============================================================================
do
    local result = safe_api.call({ available = false })
    assert(result == nil, "S5 FAIL: call() on unavailable should return nil")
    print("  S5 PASS: call() returns nil for unavailable handles")
end

-- ============================================================================
-- S6: call_pcall() translates errors to nil
-- ============================================================================
do
    local result = safe_api.call_pcall(function() error("intentional") end)
    assert(result == nil, "S6 FAIL: call_pcall should return nil on error")
    print("  S6 PASS: call_pcall() translates errors to nil")
end

-- ============================================================================
-- S7: call_pcall() passes through successful results
-- ============================================================================
do
    local result = safe_api.call_pcall(function() return "ok" end)
    assert(result == "ok", "S7 FAIL: call_pcall should return result")
    print("  S7 PASS: call_pcall() returns successful results")
end

-- ============================================================================
-- S8: call_pcall() returns nil for non-function input
-- ============================================================================
do
    local result = safe_api.call_pcall(nil)
    assert(result == nil, "S8 FAIL: call_pcall(nil) should return nil")
    print("  S8 PASS: call_pcall() returns nil for nil input")
end

-- ============================================================================
-- S9: wrap() returns callable that uses fast path when available
-- ============================================================================
do
    local wrapped = safe_api.wrap(function(x) return x + 100 end)
    assert(wrapped(5) == 105, "S9 FAIL: wrap() should expose fast-path callable")
    print("  S9 PASS: wrap() exposes fast-path callable")
end

-- ============================================================================
-- S10: wrap() falls back to pcall when not available
-- ============================================================================
do
    local wrapped = safe_api.wrap(function() error("wrapped") end)
    local result = wrapped()
    assert(result == nil, "S10 FAIL: wrap() should fall back to pcall for failures")
    print("  S10 PASS: wrap() falls back to pcall for unavailable probes")
end

-- ============================================================================
-- S11: probe_batch() probes multiple APIs in one call
-- ============================================================================
do
    local batch = safe_api.probe_batch({
        a = function() return 1 end,
        b = function() return 2 end,
        c = function() error("c fails") end,
    })
    assert(batch.a.available == true, "S11 FAIL: batch.a should be available")
    assert(batch.a.fn() == 1, "S11 FAIL: batch.a.fn should return 1")
    assert(batch.b.available == true, "S11 FAIL: batch.b should be available")
    assert(batch.b.fn() == 2, "S11 FAIL: batch.b.fn should return 2")
    assert(batch.c.available == false, "S11 FAIL: batch.c should not be available")
    assert(batch.c.maybe == true, "S11 FAIL: batch.c should be maybe")
    print("  S11 PASS: probe_batch() handles bulk probing correctly")
end

print("PASS test_safe_api_wrapper")
os.exit(0)
