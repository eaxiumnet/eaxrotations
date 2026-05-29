-- Unified strategy registry regression test.
-- Validates register_strategy, priority ordering, run_unified_strategies, and clear_strategies.

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_eq(a, b, label) if a ~= b then error((label or "assert_eq") .. ": " .. tostring(a) .. " ~= " .. tostring(b), 2) end end

local NS = {
    time_now = function() return 100 end,
    log = function() end,
    log_warning = function() end,
    log_error = function() end,
}
_G.EaxRotations = NS

dofile("EaxRotations/core_sylvanas.lua")

-- Test 1: register_strategy validates entry
assert_true(NS.register_strategy({ name = "Test", priority = 10, execute = function() return true end }) == true, "valid entry should register")
assert_true(NS.register_strategy({ name = "Bad", execute = nil }) == false, "nil execute should fail")
assert_true(NS.register_strategy({ name = "AlsoBad" }) == false, "missing execute should fail")

-- Test 2: priority ordering (higher runs first)
NS.clear_strategies()
local order = {}
NS.register_strategy({ name = "Low", priority = 1, execute = function() table.insert(order, "Low"); return false end })
NS.register_strategy({ name = "High", priority = 10, execute = function() table.insert(order, "High"); return false end })
NS.register_strategy({ name = "Mid", priority = 5, execute = function() table.insert(order, "Mid"); return false end })
NS.run_unified_strategies({})
assert_eq(order[1], "High", "highest priority should run first")
assert_eq(order[2], "Mid", "mid priority should run second")
assert_eq(order[3], "Low", "low priority should run last")

-- Test 3: matches gate + execute success
NS.clear_strategies()
local executed = false
NS.register_strategy({
    name = "Gated",
    priority = 1,
    matches = function(ctx) return ctx and ctx.allow == true end,
    execute = function(ctx) executed = true; return true end,
})
assert_true(NS.run_unified_strategies({ allow = true }) == true, "matching strategy should execute")
assert_true(executed, "execute should have been called")
assert_true(NS.run_unified_strategies({ allow = false }) == false, "non-matching strategy should not execute")

-- Test 4: first successful execute stops the loop
NS.clear_strategies()
local second_ran = false
NS.register_strategy({ name = "First", priority = 2, execute = function() return true end })
NS.register_strategy({ name = "Second", priority = 1, execute = function() second_ran = true; return true end })
NS.run_unified_strategies({})
assert_true(not second_ran, "second strategy should not run after first succeeds")

-- Test 5: clear_strategies empties registry
NS.clear_strategies()
assert_true(NS.run_unified_strategies({}) == false, "empty registry should return false")

print("PASS unified_registry")
