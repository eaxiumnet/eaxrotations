-- test_lazy_context_sylvanas.lua — Lazy context regression tests.
-- WHAT:  Verifies lazy, dependency-aware context proxy behavior.
-- WHEN:  Run as part of the rotation test suite.
-- WHY:   Catches regressions in caching, invalidation, and re-registration.
-- SAFETY: Pure unit tests with no engine dependencies.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local logged = nil
_G.EaxRotations = { log_warning = function(msg) logged = msg end }
_G.NS = _G.EaxRotations

local lazy_context = require("shared/lazy_context_sylvanas")

local function assert_eq(a, b, label)
    if a ~= b then error((label or "assert_eq") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end

local function assert_true(v, label)
    if not v then error(label or "assert_true failed", 2) end
end

-- ============================================================================
-- Cache hits: resolver runs once, cached value returned on subsequent access.
-- ============================================================================
local ctx1 = lazy_context.create()
local calls = 0
ctx1._register("double", nil, function(c)
    calls = calls + 1
    return (c.base or 0) * 2
end)
ctx1.base = 21
assert_eq(ctx1.double, 42, "cache hit: first access computes value")
assert_eq(ctx1.double, 42, "cache hit: second access returns cached value")
assert_eq(calls, 1, "cache hit: resolver only ran once")

-- ============================================================================
-- Dependency invalidation on root change.
-- ============================================================================
local ctx2 = lazy_context.create()
ctx2._register("derived", { "base" }, function(c)
    return (c.base or 0) + 10
end)
ctx2.base = 5
assert_eq(ctx2.derived, 15, "dependency invalidation: initial derived value")
ctx2.base = 7
assert_eq(ctx2.derived, 17, "dependency invalidation: derived recomputed after root change")

-- ============================================================================
-- _resolve_all() force-resolves every registered field.
-- ============================================================================
local ctx3 = lazy_context.create()
local resolved_order = {}
ctx3._register("a", nil, function()
    table.insert(resolved_order, "a")
    return 1
end)
ctx3._register("b", nil, function()
    table.insert(resolved_order, "b")
    return 2
end)
local all = ctx3._resolve_all()
assert_eq(all.a, 1, "resolve_all: field a resolved")
assert_eq(all.b, 2, "resolve_all: field b resolved")
assert_eq(#resolved_order, 2, "resolve_all: both resolvers ran")

-- ============================================================================
-- Nil value caching: resolver returning nil should be cached, not re-run.
-- ============================================================================
local ctx4 = lazy_context.create()
local nil_calls = 0
ctx4._register("maybe", nil, function()
    nil_calls = nil_calls + 1
    return nil
end)
assert_eq(ctx4.maybe, nil, "nil cache: first access returns nil")
assert_eq(ctx4.maybe, nil, "nil cache: second access still nil")
assert_eq(nil_calls, 1, "nil cache: resolver only ran once for nil value")

-- ============================================================================
-- Resolver error handling: error is logged, subsequent access re-runs resolver.
-- ============================================================================
local ctx5 = lazy_context.create()
local error_calls = 0
ctx5._register("flaky", nil, function()
    error_calls = error_calls + 1
    if error_calls == 1 then
        error("first call fails")
    end
    return "ok"
end)
assert_eq(ctx5.flaky, nil, "error handling: returns nil when resolver errors")
assert_true(logged and logged:find("first call fails"), "error handling: error was logged")
assert_eq(ctx5.flaky, "ok", "error handling: subsequent access re-runs resolver")
assert_eq(error_calls, 2, "error handling: resolver ran twice")

-- ============================================================================
-- Duplicate registration invalidation: re-registering clears stale cached value.
-- ============================================================================
local ctx6 = lazy_context.create()
local version = 0
ctx6._register("value", nil, function()
    version = version + 1
    return version
end)
assert_eq(ctx6.value, 1, "duplicate registration: initial resolver runs")
ctx6._register("value", nil, function()
    version = version + 10
    return version
end)
assert_eq(ctx6.value, 11, "duplicate registration: new resolver runs after re-registration")
assert_eq(version, 11, "duplicate registration: resolver was not the old one")

print("PASS test_lazy_context_sylvanas (cache hits, dependency invalidation, resolve_all, nil cache, error handling, duplicate registration)")
