-- test_middleware_scan_cache_regression.lua — pins
-- shared/middleware_scan_cache_sylvanas.lua.
-- WHAT:  Exercises the per-context scan memoization: cache_for's create/reuse
--        semantics, memoize's value / nil / false / error handling with the
--        NO_RESULT sentinel (nil and errors are cached as sentinel so the scan
--        runs at most once per tick), memoize_bool's false-as-meaningful-value
--        caching, pcall isolation, per-key and per-context independence.
--        The module is used by 7 middleware files to throttle expensive scans
--        to once per tick and previously had ZERO test references.
-- WHEN:  rotation suite execution.
-- WHY:   a future edit to the sentinel handling could silently re-run scans
--        every strategy (perf) or return stale true/false across ticks
--        (correctness); this test fails on regressions in the memo semantics.
-- SAFETY: Pure unit test. The module has NO NS/core dependency and loads with
--        a bare env; the real SDK is never touched.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end
local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local msc = dofile("EaxRotations/shared/middleware_scan_cache_sylvanas.lua")
assert_true(type(msc) == "table", "middleware_scan_cache must load with a bare env")

-- ---------------------------------------------------------------------------
-- 1. cache_for: fresh empty table per context; same table on reuse
-- ---------------------------------------------------------------------------
local fresh_nil = msc.cache_for(nil)
assert_eq(type(fresh_nil), "table", "cache_for(nil) returns a table")
assert_eq(#fresh_nil, 0, "cache_for(nil) returns an empty table")
assert_true(msc.cache_for(nil) ~= fresh_nil, "cache_for(nil) returns a fresh table each call")
local ctx = {}
local c1 = msc.cache_for(ctx)
assert_eq(c1, ctx._scan_cache, "cache_for creates context._scan_cache")
local c2 = msc.cache_for(ctx)
assert_eq(c2, c1, "cache_for reuses the same cache table for the context")
local ctx2 = {}
assert_true(msc.cache_for(ctx2) ~= c1, "distinct contexts get distinct caches")

-- ---------------------------------------------------------------------------
-- 2. memoize: first call runs fn and caches; later calls reuse
-- ---------------------------------------------------------------------------
local runs = 0
local ctxA = {}
local result = msc.memoize(ctxA, "scan", function()
    runs = runs + 1
    return 42
end)
assert_eq(result, 42, "memoize returns the freshly computed result")
assert_eq(runs, 1, "scan runs once on the first call")
assert_eq(msc.memoize(ctxA, "scan", function() error("must not run") end), 42,
    "memoize reuses the cached value on later calls")

-- ---------------------------------------------------------------------------
-- 3. memoize nil result -> NO_RESULT sentinel cached; fn NOT re-run
-- ---------------------------------------------------------------------------
local nil_runs = 0
local ctxB = {}
assert_eq(msc.memoize(ctxB, "nil-scan", function()
    nil_runs = nil_runs + 1
    return nil
end), nil, "memoize returns nil when fn returns nil")
assert_eq(nil_runs, 1, "nil-producing scan runs once")
assert_eq(msc.memoize(ctxB, "nil-scan", function()
    nil_runs = nil_runs + 1
    return 999
end), nil, "cached NO_RESULT keeps returning nil (fn not re-run)")
assert_eq(nil_runs, 1, "nil-producing scan NOT re-run after the sentinel is cached")

-- ---------------------------------------------------------------------------
-- 4. memoize erroring fn -> sentinel cached, no raise, fn not re-run
-- ---------------------------------------------------------------------------
local err_runs = 0
local ctxC = {}
assert_eq(msc.memoize(ctxC, "err-scan", function()
    err_runs = err_runs + 1
    error("boom")
end), nil, "erroring scan yields nil (pcall-isolated)")
assert_eq(err_runs, 1, "erroring scan runs once")
assert_eq(msc.memoize(ctxC, "err-scan", function()
    err_runs = err_runs + 1
    return 1
end), nil, "error result cached as sentinel")
assert_eq(err_runs, 1, "erroring scan NOT re-run after the sentinel is cached")

-- ---------------------------------------------------------------------------
-- 5. memoize false result IS a meaningful cached value (not sentinel)
-- ---------------------------------------------------------------------------
local false_runs = 0
local ctxD = {}
assert_eq(msc.memoize(ctxD, "false-scan", function()
    false_runs = false_runs + 1
    return false
end), false, "memoize returns false when fn returns false")
assert_eq(msc.memoize(ctxD, "false-scan", function()
    false_runs = false_runs + 1
    return true
end), false, "false is cached and reused (fn not re-run)")
assert_eq(false_runs, 1, "false-producing scan runs once")

-- ---------------------------------------------------------------------------
-- 6. memoize_bool: true and false both cached as meaningful values
-- ---------------------------------------------------------------------------
local t_runs = 0
local ctxE = {}
assert_eq(msc.memoize_bool(ctxE, "t", function()
    t_runs = t_runs + 1
    return true
end), true, "memoize_bool returns true")
assert_eq(msc.memoize_bool(ctxE, "t", function()
    t_runs = t_runs + 1
    return false
end), true, "cached true reused")
assert_eq(t_runs, 1, "true-producing scan runs once")

local f_runs = 0
local ctxF = {}
assert_eq(msc.memoize_bool(ctxF, "f", function()
    f_runs = f_runs + 1
    return false
end), false, "memoize_bool returns false (false IS cached)")
assert_eq(msc.memoize_bool(ctxF, "f", function()
    f_runs = f_runs + 1
    return true
end), false, "cached false reused")
assert_eq(f_runs, 1, "false-producing scan runs once")

-- ---------------------------------------------------------------------------
-- 7. memoize_bool non-boolean / erroring fn -> cached false, no raise
-- ---------------------------------------------------------------------------
local nb_runs = 0
local ctxG = {}
assert_eq(msc.memoize_bool(ctxG, "nb", function()
    nb_runs = nb_runs + 1
    return 42
end), false, "non-boolean result coerced to cached false")
assert_eq(msc.memoize_bool(ctxG, "nb", function()
    nb_runs = nb_runs + 1
    return true
end), false, "cached false reused")
assert_eq(nb_runs, 1, "non-boolean scan runs once")

local e_runs = 0
local ctxH = {}
assert_eq(msc.memoize_bool(ctxH, "e", function()
    e_runs = e_runs + 1
    error("boom")
end), false, "erroring boolean scan yields false (no raise)")
assert_eq(msc.memoize_bool(ctxH, "e", function()
    e_runs = e_runs + 1
    return true
end), false, "error cached as false")
assert_eq(e_runs, 1, "erroring boolean scan runs once")

-- ---------------------------------------------------------------------------
-- 8. Key independence within a context; context independence
-- ---------------------------------------------------------------------------
local ctxI = {}
local k1 = msc.memoize(ctxI, "k1", function() return "a" end)
local k2 = msc.memoize(ctxI, "k2", function() return "b" end)
assert_eq(k1, "a", "key 1 value")
assert_eq(k2, "b", "key 2 value independent of key 1")
local ctxJ = {}
assert_eq(msc.memoize(ctxJ, "k1", function() return "fresh" end), "fresh",
    "same key on a different context computes fresh")

print("PASS test_middleware_scan_cache_regression")
