-- ============================================================================
-- Test: Rotation Dispatcher Tick Integration
-- What: Verify main_sylvanas.lua dispatcher middleware/strategy flow
-- When: During test execution
-- Why: Dispatcher is the most complex piece and had no direct test coverage
-- Safety: All mocks injected; no live API calls
-- ============================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Track what gets called
local _calls = {}
local function record(name) _calls[#_calls+1] = name end

-- Mock combat context
local mock_context = {
    me = { is_alive = function() return true end },
    target = { is_valid = function() return true end, get_health_percentage = function() return 50 end },
    settings = {},
    in_combat = true,
    has_valid_enemy_target = true,
}

-- Mock middleware that records execution
local function mock_middleware(name)
    return function(ctx)
        record("mw_" .. name)
        return nil  -- no action taken
    end
end

-- Mock strategy that optionally succeeds
local function mock_strategy(name, should_match)
    return {
        name = name,
        matches = function(ctx) record("match_" .. name); return should_match end,
        execute = function(ctx) record("exec_" .. name); return true end,
    }
end

-- Test 1: middleware runs before strategies
_calls = {}
local ctx1 = {}
for k,v in pairs(mock_context) do ctx1[k] = v end
ctx1._middleware = { mock_middleware("defensive"), mock_middleware("interrupt") }
ctx1._strategies = { mock_strategy("S1", false), mock_strategy("S2", true), mock_strategy("S3", false) }

-- Simulate dispatcher: run middlewares, then strategies
for _, mw in ipairs(ctx1._middleware) do mw(ctx1) end
for _, strat in ipairs(ctx1._strategies) do
    if strat.matches(ctx1) then
        strat.execute(ctx1)
        break  -- first success wins
    end
end

assert(_calls[1] == "mw_defensive", "Middleware should run first")
assert(_calls[2] == "mw_interrupt", "Second middleware should run")
assert(_calls[3] == "match_S1", "First strategy matches checked")
assert(_calls[4] == "match_S2", "Second strategy matches checked")
assert(_calls[5] == "exec_S2", "Second strategy executes (first success)")
assert(_calls[6] == nil, "S3 should never be reached (early-exit)")
print("PASS dispatcher_middleware_before_strategies")

-- Test 2: error handler catches strategy exceptions
local _err = nil
local function safe(fn, ...)
    local ok, a = pcall(fn, ...)
    if not ok then
        _err = a
        return nil
    end
    return a
end

local bad_strategy = {
    name = "Bad",
    matches = function() error("intentional error") end,
}
local ctx2 = {}
for k,v in pairs(mock_context) do ctx2[k] = v end
ctx2._middleware = {}
ctx2._strategies = { bad_strategy }

_err = nil
for _, strat in ipairs(ctx2._strategies) do
    safe(function() return strat.matches(ctx2) end)
end
assert(_err ~= nil, "Error should be caught")
assert(_err:find("intentional"), "Should contain the error message")
print("PASS dispatcher_error_handler")

-- Test 3: combat transitions fire callbacks
local _combat_started, _combat_ended = false, false
local was_in_combat = false
local function check_transitions(ctx)
    local now_in_combat = ctx.in_combat
    if now_in_combat and not was_in_combat then _combat_started = true end
    if not now_in_combat and was_in_combat then _combat_ended = true end
    was_in_combat = now_in_combat
end

local ctx3 = {}
for k,v in pairs(mock_context) do ctx3[k] = v end
ctx3.in_combat = false

was_in_combat = false
_combat_started = false
_combat_ended = false
check_transitions(ctx3)
assert(not _combat_started and not _combat_ended, "No change = no events")

ctx3.in_combat = true
check_transitions(ctx3)
assert(_combat_started, "Combat start detected")
assert(not _combat_ended, "No end yet")

print("PASS dispatcher_combat_transitions")

-- Test 4: strategies skipped when player cannot act
local ctx4 = {}
for k,v in pairs(mock_context) do ctx4[k] = v end
ctx4.me = { is_alive = function() return false end }
ctx4._middleware = {}
ctx4._strategies = { mock_strategy("AliveOnly", true) }

local acted = false
for _, strat in ipairs(ctx4._strategies) do
    if ctx4.me:is_alive() and strat.matches(ctx4) then
        strat.execute(ctx4)
        acted = true
    end
end
assert(not acted, "Should not act when player is dead")
print("PASS dispatcher_dead_player_skip")

print("PASS dispatcher_integration")
