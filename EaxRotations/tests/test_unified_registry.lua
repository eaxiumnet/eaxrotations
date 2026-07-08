-- test_unified_registry.lua -- unified registry tests.
-- WHAT:  unified registry tests
-- WHEN:  During rotation test suite execution.
-- WHY:   Validates rotation registry registration and lookup integrity.
-- SAFETY: Tests dispatcher plumbing without live client.

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

-- Test 6: playstyle filtering (strategies only run for their registered playstyle)
NS.clear_strategies()
local fury_executed = false
local mage_executed = false
NS.register_strategy({ name = "Fury:Test", playstyle = "fury", priority = 10, execute = function() fury_executed = true; return true end })
NS.register_strategy({ name = "Mage:Test", playstyle = "mage", priority = 5, execute = function() mage_executed = true; return true end })
-- Run with fury playstyle — only fury strategy should execute
assert_true(NS.run_unified_strategies({ active_playstyle = "fury" }) == true, "fury strategy should execute in fury playstyle")
assert_true(fury_executed, "fury strategy should have been called")
assert_true(not mage_executed, "mage strategy should NOT run in fury playstyle")
-- Reset and run with mage playstyle
fury_executed = false
mage_executed = false
assert_true(NS.run_unified_strategies({ active_playstyle = "mage" }) == true, "mage strategy should execute in mage playstyle")
assert_true(not fury_executed, "fury strategy should NOT run in mage playstyle")
assert_true(mage_executed, "mage strategy should have been called")

-- Test 7: _global strategies run in all playstyles
NS.clear_strategies()
local global_ran = false
NS.register_strategy({ name = "Global", priority = 1, execute = function() global_ran = true; return true end }) -- defaults to _global
assert_true(NS.run_unified_strategies({ active_playstyle = "fury" }) == true, "global strategy should execute")
assert_true(global_ran, "global strategy should run in fury playstyle")

global_ran = false
assert_true(NS.run_unified_strategies({ active_playstyle = "mage" }) == true, "global strategy should execute in mage too")
assert_true(global_ran, "global strategy should run in mage playstyle")

-- Test 8: state builder — registered builder is called and state is passed to matches/execute
NS.clear_strategies()
local builder_called = false
local match_state = nil
local exec_state = nil
NS.register_state_builder("fury", function(ctx)
    builder_called = true
    return { derived = "from_builder", original_hp = ctx.hp }
end)
NS.register_strategy({
    name = "Fury:StateTest",
    playstyle = "fury",
    priority = 1,
    matches = function(ctx, state)
        match_state = state
        return state and state.derived == "from_builder"
    end,
    execute = function(ctx, state)
        exec_state = state
        return true
    end,
})
assert_true(NS.run_unified_strategies({ active_playstyle = "fury", hp = 75 }) == true, "state-aware strategy should execute")
assert_true(builder_called, "state builder should have been called")
assert_true(match_state ~= nil and match_state.derived == "from_builder", "matches should receive built state")
assert_true(match_state.original_hp == 75, "state should contain original context fields")
assert_true(exec_state == match_state, "execute should receive same state as matches")

print("PASS unified_registry")
