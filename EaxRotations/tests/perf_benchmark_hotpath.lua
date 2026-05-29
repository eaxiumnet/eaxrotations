-- ============================================================================
-- Performance Microbenchmark: Hot-Path Optimizations
-- Measures CPU time saved by each optimization in isolation (A/B comparison).
-- Each test runs N iterations of the hot-path code and reports per-tick cost.
-- ============================================================================

local NS = _G.EaxRotations or {}
_G.EaxRotations = NS

-- ============================================================================
-- Mock environment — replicates production APIs with minimal overhead
-- ============================================================================
local mock_time = 1234567890
local mock_debug_setting = false            -- default: debug OFF (hot path)

local mock_settings = {
    debug_system = false,
}

NS.get_setting = function(key, default)
    return mock_settings[key] ~= nil and mock_settings[key] or default
end

NS.game_time_ms = function() return mock_time end
NS.time_now = function() return mock_time end

local log_sink = {}
NS.log = function(msg) table.insert(log_sink, msg) end
NS.log_warning = function(msg) table.insert(log_sink, "[WARN] " .. msg) end

local function reset_log_sink()
    for i = #log_sink, 1, -1 do log_sink[i] = nil end
end

-- ============================================================================
-- Strategy factory
-- ============================================================================
local function make_strategy(name)
    return {
        name = name,
        matches = function(ctx, state)
            local hp = ctx.hp or 100
            local mana = ctx.mana or 100
            return hp > 20 and mana > 10
        end,
        execute = function(ctx, state)
            return true
        end,
    }
end

-- ============================================================================
-- Build list of strategies for benchmarking (25 = typical playstyle depth)
-- ============================================================================
local NUM_STRATEGIES = 25
local strategy_list = {}
for i = 1, NUM_STRATEGIES do
    strategy_list[i] = make_strategy("Strategy_" .. i)
end

-- ============================================================================
-- Context mock
-- ============================================================================
local context = {
    hp = 50, mana = 50, gcd_remains = 0,
    in_combat = true, has_valid_enemy_target = true,
    target_hp = 75, settings = {},
    active_playstyle = "fury",
}

-- ============================================================================
-- Safe() wrapper (BEFORE optimization: pcall on matches)
-- ============================================================================
local _last_error_time = 0
local function safe_old(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    return nil
end

-- ============================================================================
-- Trace function (BEFORE optimization: checks setting every call)
-- ============================================================================
local _trace_times = {}
local function trace_old(key, message, interval_ms)
    if not NS.get_setting("debug_system", false) then return end
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    local interval = interval_ms or 500
    local last = _trace_times[key] or -100000
    if now - last < interval then return end
    _trace_times[key] = now
end

-- ============================================================================
-- is_debug_enabled with 500ms cache (same as production)
-- ============================================================================
local _debug_cache = nil
local _debug_cache_time = -1
local function is_debug_enabled()
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    if now - _debug_cache_time > 500 then
        _debug_cache = NS.get_setting("debug_system", false)
        _debug_cache_time = now
    end
    return _debug_cache
end

-- ============================================================================
-- BENCHMARK 1: Trace call overhead with debug OFF
-- Measures cost of calling trace() vs guarding with if debug_enabled
-- ============================================================================
local function bench_trace_no_debug(iterations)
    -- BEFORE: call trace() unconditionally — string concat + function call + setting lookup
    local function run_list_before(name, list)
        for _, s in ipairs(list) do
            trace_old("strat:" .. name .. ":" .. tostring(s.name), "match " .. tostring(s.name), 2000)
        end
    end

    -- AFTER: guard trace behind cached debug flag
    local debug = false
    local function run_list_after(name, list)
        for _, s in ipairs(list) do
            if debug then
                trace_old("strat:" .. name .. ":" .. tostring(s.name), "match " .. tostring(s.name), 2000)
            end
        end
    end

    -- Warmup
    run_list_before("warmup", strategy_list)
    run_list_after("warmup", strategy_list)

    -- BEFORE
    local t0 = os.clock()
    for _ = 1, iterations do
        run_list_before("test", strategy_list)
    end
    local t1 = os.clock()

    -- AFTER
    local t2 = os.clock()
    for _ = 1, iterations do
        run_list_after("test", strategy_list)
    end
    local t3 = os.clock()

    local before_us = ((t1 - t0) / iterations) * 1e6
    local after_us = ((t3 - t2) / iterations) * 1e6

    return before_us, after_us
end

-- ============================================================================
-- BENCHMARK 2: safe() (pcall) overhead on matches() with debug OFF
-- ============================================================================
local function bench_pcall_matches(iterations)
    -- BEFORE: matches wrapped in safe() — pcall overhead
    local function run_list_before(name, list, ctx, state)
        for _, s in ipairs(list) do
            if type(s.execute) == "function" then
                local ok = true
                if type(s.matches) == "function" then
                    ok = safe_old(s.matches, ctx, state) == true
                end
            end
        end
    end

    -- AFTER: matches called directly — no pcall
    local function run_list_after(name, list, ctx, state)
        for _, s in ipairs(list) do
            if type(s.execute) == "function" then
                local ok = true
                if type(s.matches) == "function" then
                    ok = s.matches(ctx, state) == true
                end
            end
        end
    end

    local ctx = { hp = 50, mana = 50 }

    -- Warmup
    run_list_before("warmup", strategy_list, ctx, ctx)
    run_list_after("warmup", strategy_list, ctx, ctx)

    -- BEFORE
    local t0 = os.clock()
    for _ = 1, iterations do
        run_list_before("test", strategy_list, ctx, ctx)
    end
    local t1 = os.clock()

    -- AFTER
    local t2 = os.clock()
    for _ = 1, iterations do
        run_list_after("test", strategy_list, ctx, ctx)
    end
    local t3 = os.clock()

    local before_us = ((t1 - t0) / iterations) * 1e6
    local after_us = ((t3 - t2) / iterations) * 1e6

    return before_us, after_us
end

-- ============================================================================
-- BENCHMARK 3: debug_on nil-check vs `or` (eliminates is_debug_enabled call)
-- ============================================================================
local function bench_debug_nil_check(iterations)
    -- is_debug_enabled has 500ms cache, so the function call itself is the cost

    -- BEFORE: debug_on = debug_on or is_debug_enabled()
    --   When debug_on=false, `false or fn()` evaluates fn() unnecessarily
    local function old_gate(debug_on)
        debug_on = debug_on or is_debug_enabled()
        return debug_on
    end

    -- AFTER: if debug_on == nil then debug_on = is_debug_enabled() end
    --   When debug_on=false, skip the call entirely
    local function new_gate(debug_on)
        if debug_on == nil then debug_on = is_debug_enabled() end
        return debug_on
    end

    -- Warmup
    for _ = 1, 10000 do
        old_gate(false)
        new_gate(false)
        old_gate(true)
        new_gate(true)
        old_gate(nil)
        new_gate(nil)
    end

    -- Test: debug_on = false (hot path — most common state)
    local t0 = os.clock()
    for _ = 1, iterations do
        old_gate(false)
    end
    local t1 = os.clock()

    local t2 = os.clock()
    for _ = 1, iterations do
        new_gate(false)
    end
    local t3 = os.clock()

    -- Test: debug_on = nil (first call / backward compat)
    local t4 = os.clock()
    for _ = 1, iterations do
        old_gate(nil)
    end
    local t5 = os.clock()

    local t6 = os.clock()
    for _ = 1, iterations do
        new_gate(nil)
    end
    local t7 = os.clock()

    return {
        disabled_old = ((t1 - t0) / iterations) * 1e6,
        disabled_new = ((t3 - t2) / iterations) * 1e6,
        nil_old = ((t5 - t4) / iterations) * 1e6,
        nil_new = ((t7 - t6) / iterations) * 1e6,
    }
end

-- ============================================================================
-- BENCHMARK 4: Combined dispatch — full tick simulation
-- Replicates the actual run_list() dispatch loop with middleware + playstyle
-- ============================================================================
local function bench_full_tick(iterations)
    -- Build middleware list (~5 strategies)
    local middleware = {}
    for i = 1, 5 do
        middleware[i] = make_strategy("mw_" .. i)
    end

    -- Build playstyle list (~25 strategies)
    local playstyle = {}
    for i = 1, 25 do
        playstyle[i] = make_strategy("ps_" .. i)
    end

    -- BEFORE (all optimizations disabled):
    --  - trace() calls unconditional (but debug off, so they return early)
    --  - matches() wrapped in safe() (pcall)
    --  - debug_on = debug_on or is_debug_enabled() (calls is_debug_enabled even when false)
    --  - is_debug_enabled called independently in each run_list
    local function trace_unconditional(key, msg, interval)
        if not NS.get_setting("debug_system", false) then return end
    end
    local function run_list_before(name, list, ctx)
        local debug_on = is_debug_enabled()
        for _, s in ipairs(list) do
            if type(s.execute) == "function" then
                local ok = true
                if type(s.matches) == "function" then
                    ok = safe_old(s.matches, ctx, ctx) == true
                end
            end
        end
    end

    -- AFTER (all optimizations enabled):
    --  - trace() guarded behind cached debug flag (no string concat)
    --  - matches() called directly (no pcall)
    --  - debug_on = nil-check (no is_debug_enabled call when false)
    --  - debug_enabled computed once, passed to both run_list calls
    local function run_list_after(name, list, ctx, debug_on)
        if debug_on == nil then debug_on = is_debug_enabled() end
        for _, s in ipairs(list) do
            if type(s.execute) == "function" then
                local ok = true
                if type(s.matches) == "function" then
                    ok = s.matches(ctx, ctx) == true
                end
            end
        end
    end

    local function tick_before(ctx)
        local debug_enabled = is_debug_enabled()
        run_list_before("middleware", middleware, ctx)
        run_list_before("playstyle", playstyle, ctx)
    end

    local function tick_after(ctx)
        local debug_enabled = is_debug_enabled()
        run_list_after("middleware", middleware, ctx, debug_enabled)
        run_list_after("playstyle", playstyle, ctx, debug_enabled)
    end

    -- Warmup
    for _ = 1, 10000 do
        tick_before(context)
        tick_after(context)
    end

    -- BEFORE
    reset_log_sink()
    local t0 = os.clock()
    for _ = 1, iterations do
        tick_before(context)
    end
    local t1 = os.clock()

    -- AFTER
    local t2 = os.clock()
    for _ = 1, iterations do
        tick_after(context)
    end
    local t3 = os.clock()

    local before_us = ((t1 - t0) / iterations) * 1e6
    local after_us = ((t3 - t2) / iterations) * 1e6

    return before_us, after_us
end

-- ============================================================================
-- Run all benchmarks
-- ============================================================================
local ITERATIONS = 50000
local SUMMARY_ITERATIONS = 500000

print("========================================================================")
print("  HOT-PATH PERFORMANCE BENCHMARK")
print(string.format("  Debug mode: %s (production hot path)", tostring(mock_debug_setting)))
print(string.format("  Strategies per list: %d", NUM_STRATEGIES))
print("========================================================================")
print()

-- B1: Trace call overhead
print("--- Benchmark 1: Trace call gating (debug OFF) ---")
print(string.format("  Iterations: %d", ITERATIONS))
local t1_before, t1_after = bench_trace_no_debug(ITERATIONS)
local t1_saved = t1_before - t1_after
local t1_percent = (t1_before > 0) and (t1_saved / t1_before * 100) or 0
print(string.format("  BEFORE (unconditional trace):  %.4f μs/tick", t1_before))
print(string.format("  AFTER  (guarded trace):         %.4f μs/tick", t1_after))
print(string.format("  SAVED: %.4f μs/tick (%.1f%%)", t1_saved, t1_percent))
print()

-- B2: pcall overhead
print("--- Benchmark 2: pcall overhead on matches() ---")
print(string.format("  Iterations: %d", ITERATIONS))
local t2_before, t2_after = bench_pcall_matches(ITERATIONS)
local t2_saved = t2_before - t2_after
local t2_percent = (t2_before > 0) and (t2_saved / t2_before * 100) or 0
print(string.format("  BEFORE (safe() / pcall): %.4f μs/tick", t2_before))
print(string.format("  AFTER  (direct call):     %.4f μs/tick", t2_after))
print(string.format("  SAVED: %.4f μs/tick (%.1f%%)", t2_saved, t2_percent))
print()

-- B3: debug_on nil-check
print("--- Benchmark 3: debug_on nil-check vs `or` ---")
print(string.format("  Iterations: %d", SUMMARY_ITERATIONS))
local t3 = bench_debug_nil_check(SUMMARY_ITERATIONS)
print(string.format("  debug_on=false:"))
print(string.format("    BEFORE (`or` fallback):      %.4f μs", t3.disabled_old))
print(string.format("    AFTER  (nil-check):          %.4f μs", t3.disabled_new))
print(string.format("    SAVED: %.4f μs (%.1f%%)", t3.disabled_old - t3.disabled_new,
    (t3.disabled_old > 0) and ((t3.disabled_old - t3.disabled_new) / t3.disabled_old * 100) or 0))
print(string.format("  debug_on=nil (backward compat):"))
print(string.format("    BEFORE (`or` fallback):      %.4f μs", t3.nil_old))
print(string.format("    AFTER  (nil-check):          %.4f μs", t3.nil_new))
print(string.format("    SAVED: %.4f μs (%.1f%%)", t3.nil_old - t3.nil_new,
    (t3.nil_old > 0) and ((t3.nil_old - t3.nil_new) / t3.nil_old * 100) or 0))
print()

-- B4: Combined full-tick simulation
print("--- Benchmark 4: Full tick simulation (all optimizations combined) ---")
print(string.format("  Iterations: %d", ITERATIONS))
print(string.format("  Middleware: 5 strategies, Playstyle: 25 strategies"))
local t4_before, t4_after = bench_full_tick(ITERATIONS)
local t4_saved = t4_before - t4_after
local t4_percent = (t4_before > 0) and (t4_saved / t4_before * 100) or 0
print(string.format("  BEFORE (all old):  %.4f μs/tick", t4_before))
print(string.format("  AFTER  (all new):  %.4f μs/tick", t4_after))
print(string.format("  SAVED:  %.4f μs/tick (%.1f%%)", t4_saved, t4_percent))
print()

-- Projected savings
print("========================================================================")
print("  PROJECTED ANNUALIZED SAVINGS")
print("========================================================================")
local ticks_per_sec = 10  -- ~10 rotation ticks per second
local secs_per_hour = 3600
local hours_per_session = 4
local ticks_per_hour = ticks_per_sec * secs_per_hour
local ticks_per_session = ticks_per_hour * hours_per_session

local combined_saved_per_tick_us = t4_saved
local combined_saved_per_hour_ms = combined_saved_per_tick_us * ticks_per_hour / 1000
local combined_saved_per_session_ms = combined_saved_per_tick_us * ticks_per_session / 1000

print(string.format("  CPU time saved per tick:          %.4f μs", combined_saved_per_tick_us))
print(string.format("  CPU time saved per hour:           %.2f ms", combined_saved_per_hour_ms))
print(string.format("  CPU time saved per 4hr session:    %.2f ms", combined_saved_per_session_ms))
print(string.format("  Game ticks/sec:                     %d", ticks_per_sec))
print()

-- Scaling note
print(string.format("  Note: %.1f%% reduction means the rotation hot path now", t4_percent))
print(string.format("  takes %.2f× less CPU time per tick.", 100 / (100 - t4_percent)))
print("========================================================================")

-- Summary
print()
print("--- PASS (benchmarks complete) ---")
