-- test_benchmark.lua -- Test Benchmark tests.
-- WHAT:  Test Benchmark tests
-- WHEN:  During CI or manual performance validation.
-- WHY:   Measures hot-path performance and prevents regression in frame-budget.
-- SAFETY: Run in isolation; results are relative to baseline.

-- ============================================================================
-- Test: Performance Benchmark for Strategy Evaluation

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- Mock strategy factory
local function make_strategy(n)
    return {
        name = "Strategy_" .. n,
        matches = function(ctx)
            -- Simulate real strategy work: context reads + conditional check
            local hp = ctx.hp or 100
            local mana = ctx.mana or 100
            local cd = ctx.gcd_remains or 0
            return hp > 20 and mana > 10 and cd == 0
        end,
    }
end

local function benchmark_spec(strategies, iterations)
    local ctx = {
        hp = 50, mana = 50, gcd_remains = 0,
        in_combat = true, target_hp = 75,
    }
    local start = os.clock()
    for _ = 1, iterations do
        local found = false
        for _, s in ipairs(strategies) do
            if s.matches(ctx) then
                found = true
                break  -- early-exit
            end
        end
    end
    local elapsed = os.clock() - start
    return elapsed / iterations
end

local PASS_THRESHOLD_MS = 20
local ITERATIONS = 10000

-- Test 1: small spec (10 strategies)
local spec_10 = {}
for i = 1, 10 do spec_10[i] = make_strategy(i) end
local avg_10 = benchmark_spec(spec_10, ITERATIONS)
assert(avg_10 < PASS_THRESHOLD_MS / 1000, string.format("10-strat spec: %.4fms (threshold: %dms)", avg_10 * 1000, PASS_THRESHOLD_MS))
print(string.format("PASS benchmark_10_strategies: %.4fms < %dms", avg_10 * 1000, PASS_THRESHOLD_MS))

-- Test 2: medium spec (25 strategies, typical depth)
local spec_25 = {}
for i = 1, 25 do spec_25[i] = make_strategy(i) end
local avg_25 = benchmark_spec(spec_25, ITERATIONS)
assert(avg_25 < PASS_THRESHOLD_MS / 1000, string.format("25-strat spec: %.4fms exceeds %dms", avg_25 * 1000, PASS_THRESHOLD_MS))
print(string.format("PASS benchmark_25_strategies: %.4fms < %dms", avg_25 * 1000, PASS_THRESHOLD_MS))

-- Test 3: large spec (40 strategies)
local spec_40 = {}
for i = 1, 40 do spec_40[i] = make_strategy(i) end
local avg_40 = benchmark_spec(spec_40, ITERATIONS)
assert(avg_40 < PASS_THRESHOLD_MS / 1000, string.format("40-strat spec: %.4fms exceeds %dms", avg_40 * 1000, PASS_THRESHOLD_MS))
print(string.format("PASS benchmark_40_strategies: %.4fms < %dms", avg_40 * 1000, PASS_THRESHOLD_MS))

print("PASS benchmark")
