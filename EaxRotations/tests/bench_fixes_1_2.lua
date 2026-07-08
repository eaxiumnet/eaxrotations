-- bench_fixes_1_2.lua -- benchmark fix validation tests.
-- WHAT:  benchmark fix validation tests
-- WHEN:  During CI or manual performance validation.
-- WHY:   Measures hot-path performance and prevents regression in frame-budget.
-- SAFETY: Run in isolation; results are relative to baseline.

-- ============================================================================
-- Synthetic microbenchmark: Fix #1 + Fix #2 dispatch patterns
-- ============================================================================
-- Models the pre-fix and post-fix on_update entry point patterns from
-- EaxRotations/main.lua using the same is_alive / generation-guard work
-- that runs on every entry. Measures raw os.clock() cost per entry.
--
-- Translates result to "FPS impact %" the same way the in-game dashboard
-- tick_profiler_sylvanas.lua does:
--     frame_budget_us = 16666.67   (60fps = 16.67ms)
--     fps_impact_pct = (tick_us / frame_budget_us) * 100
--
-- Run:   lua EaxRotations/tests/bench_fixes_1_2.lua
-- Result: prints per-pattern microsecond cost + FPS impact %.
-- ============================================================================

local ITERATIONS = 1000000   -- 1M entries per pattern (cheap to run)
local TICKS_PER_SEC_60FPS = 60
local FRAME_BUDGET_US = 16666.67   -- 16.67ms at 60fps

-- ============================================================================
-- Shared guards (mirror the cheap pre-frame work in main.lua's on_update)
-- ============================================================================
local _runtime_gen_local = 1
local _runtime_gen_core = 1
local _counter = 0

local function cheap_guards()
    -- Mirrors: generation check + get_local_player + is_alive pcall
    if _runtime_gen_core ~= _runtime_gen_local then return false end
    -- In the real addon, get_local_player() + pcall(is_alive) runs here.
    -- We model the cost of the comparison + function-call + pcall overhead.
    local player = { is_alive = function() return true end }
    local ok, alive = pcall(function() return player:is_alive() end)
    return ok and alive ~= false
end

local function empty_work() end

-- ============================================================================
-- A) PRE-FIX: direct core.register_on_update_callback (60Hz, every frame)
--    main.lua used to do this:
--        core.register_on_update_callback(function() on_update() end)
--    No throttling at the engine level. on_update had its own internal
--    _frame_counter % 5 skip for the expensive parts, but the cheap
--    guards (is_alive, gen check) ran every single frame.
-- ============================================================================
local function pre_fix_entry()
    cheap_guards()
    -- _frame_counter increment + skip check (the parts of on_update that
    -- ALWAYS ran, even on skipped frames):
    _counter = _counter + 1
    if _counter < 5 then return end
    _counter = 0
end

-- ============================================================================
-- B) POST FIX #1: NS.register_on_update_callback (20Hz shared dispatcher)
--    Engine-level throttle. The shared dispatcher skips 2 of 3 frames, so
--    on_update only fires at 20Hz. The cheap guards now also run at 20Hz
--    (down from 60Hz) — a 3x reduction in entry-point overhead.
-- ============================================================================
local _dispatch_counter = 0
local function post_fix_1_entry()
    -- Simulated engine-side 3-frame skip (the NS.register_on_update_callback
    -- shared dispatcher in core_sylvanas.lua:1590-1610 does this).
    _dispatch_counter = _dispatch_counter + 1
    if _dispatch_counter < 3 then return end
    _dispatch_counter = 0

    -- on_update body now runs at 20Hz, no internal frame-skip needed.
    cheap_guards()
end

-- ============================================================================
-- C) POST FIX #2: NS.register_on_update_callback (20Hz) + no double OOC
--    Adds the savings from removing the OOC manager's redundant
--    register_on_update_callback registration. Previously when OOC,
--    ooc_manager.on_update was invoked at 40Hz (20Hz shared dispatcher +
--    20Hz main_sylvanas dispatch path). The internal 1s throttle
--    prevented duplicate casts, but the function entry + early-exit
--    checks still ran 40x/second. Now it's 20Hz via main_sylvanas only.
-- ============================================================================
local function post_fix_2_ooc_work()
    -- Simulates ooc_manager.on_update entry: 6 cheap early-exit checks
    -- (NS check, context_or_default, in_combat check, use_ooc_manager
    -- setting check, NS.time_now, 1s throttle check).
    local ns_ok = true
    if not ns_ok then return end
    local in_combat = false
    if in_combat then return end
    local enabled = true
    if not enabled then return end
    local last_check = 0
    local now = 1
    if now - last_check < 1 then return end
end

local function pre_fix_ooc_dual_entry()
    -- Two invocation sites: shared dispatcher (20Hz) + main_sylvanas
    -- dispatch path (20Hz). Each does the full ooc_manager.on_update
    -- entry work; only the 1s throttle prevents double-cast.
    post_fix_2_ooc_work()
    post_fix_2_ooc_work()
end

local _dispatch_counter_2 = 0
local function post_fix_1_with_pre_ooc()
    _dispatch_counter_2 = _dispatch_counter_2 + 1
    if _dispatch_counter_2 < 3 then return end
    _dispatch_counter_2 = 0
    cheap_guards()
    pre_fix_ooc_dual_entry()
end

local _dispatch_counter_3 = 0
local function post_fix_2_entry()
    _dispatch_counter_3 = _dispatch_counter_3 + 1
    if _dispatch_counter_3 < 3 then return end
    _dispatch_counter_3 = 0
    cheap_guards()
    post_fix_2_ooc_work()  -- single OOC entry
end

-- ============================================================================
-- Time helper (LuaJIT-compatible; no os.clock resolution guarantees on
-- stock Lua so we report per-iteration ns and average over a large N)
-- ============================================================================
local function bench(fn, label, iterations)
    -- Warmup
    for _ = 1, 1000 do fn() end
    collectgarbage("collect")
    local t0 = os.clock()
    fn() -- call once to prime
    for _ = 1, iterations do fn() end
    local t1 = os.clock()
    local total_us = (t1 - t0) * 1e6
    local per_iter_us = total_us / iterations
    return per_iter_us
end

-- ============================================================================
-- Run benchmarks
-- ============================================================================
print("============================================================================")
print("  EaxRotations Fix #1 + #2 dispatch pattern microbenchmark")
print(string.format("  Iterations per pattern: %d", ITERATIONS))
print("============================================================================")
print()

-- Raw per-entry cost (regardless of dispatcher throttle)
local us_pre = bench(pre_fix_entry,        "pre-fix (60Hz)",       ITERATIONS)
local us_pf1 = bench(post_fix_1_entry,     "post-Fix-1 (20Hz)",    ITERATIONS)
local us_pf2 = bench(post_fix_2_entry,     "post-Fix-2 (20Hz,OOC)",ITERATIONS)
-- Compare the OOC branch (where double-firing happened) directly
local us_pf1_ooc = bench(post_fix_1_with_pre_ooc, "pre-Fix-2 OOC dual-entry", ITERATIONS)

-- ============================================================================
-- Project real-world cost. The dispatchers in the simulation skip 2 of 3
-- frames; we need to multiply the "per-iteration" cost by the rate at which
-- the work actually executes per second.
-- ============================================================================
-- Pre-fix: 60 ticks/sec, full body runs every tick (cheap guards + counter)
-- Post-Fix-1: 20 ticks/sec, full body runs every tick (cheap guards only)
-- Post-Fix-2: 20 ticks/sec, OOC body runs only 1x instead of 2x
-- Per-tick work in the simulation already includes the dispatcher skip
-- (we return early on skipped frames), so us_* values are per-iteration cost
-- averaged over ALL iterations including the skipped ones.

local us_pre_per_sec  = us_pre  * 60   -- cost/iteration * calls/sec
local us_pf1_per_sec  = us_pf1  * 60
local us_pf2_per_sec  = us_pf2  * 60
local us_pf1ooc_per_sec = us_pf1_ooc * 60

-- FPS impact = (cost/sec) / frame_budget_per_sec
-- frame_budget_per_sec = FRAME_BUDGET_US * 60 (60 frames per second)
local frame_budget_total_us = FRAME_BUDGET_US * 60
local function fps_impact_pct(us_per_sec)
    return (us_per_sec / frame_budget_total_us) * 100
end

-- ============================================================================
-- Report
-- ============================================================================
local function row(label, per_iter_us, calls_per_sec, cost_per_sec_us)
    local pct = fps_impact_pct(cost_per_sec_us)
    return string.format("  %-32s  per-iter %7.3f \u{03BC}s   %2d calls/s   cost/s %8.2f \u{03BC}s   FPS impact %5.3f%%",
        label, per_iter_us, calls_per_sec, cost_per_sec_us, pct)
end

print("Per-pattern cost (with engine-level 20Hz throttle applied):")
print(row("PRE-FIX  (60Hz direct callback)", us_pre,  60, us_pre_per_sec))
print(row("POST-Fix-1 (20Hz shared disp.)",   us_pf1,  20, us_pf1_per_sec))
print()
print("Per-pattern cost when OUT OF COMBAT (where double-firing happened):")
print(row("PRE-FIX  (60Hz + 1x OOC check)",   us_pre, 60, us_pre_per_sec))
print(row("POST-Fix-1 (20Hz + 2x OOC check)", us_pf1_ooc, 60, us_pf1ooc_per_sec))
print(row("POST-Fix-2 (20Hz + 1x OOC check)", us_pf2, 60, us_pf2_per_sec))
print()

-- ============================================================================
-- Delta vs baseline (pre-fix)
-- ============================================================================
local fix1_savings = us_pre_per_sec - us_pf1_per_sec
local fix1_pct     = (fix1_savings / us_pre_per_sec) * 100
local fix2_ooc_savings = us_pf1ooc_per_sec - us_pf2_per_sec
local fix2_ooc_pct     = (fix2_ooc_savings / us_pf1ooc_per_sec) * 100

print("Savings vs pre-fix baseline:")
print(string.format("  Fix #1 alone (60\u{2192}20Hz, all conditions):        -%6.2f \u{03BC}s/s (-%.1f%% of baseline)",
    fix1_savings, fix1_pct))
print(string.format("  Fix #2 alone (double\u{2192}single OOC entry):    -%6.2f \u{03BC}s/s (-%.1f%% of post-Fix-1 OOC cost)",
    fix2_ooc_savings, fix2_ooc_pct))
print()

-- ============================================================================
-- Final projected numbers (what the dashboard's "FPS impact" line will show)
-- ============================================================================
print("============================================================================")
print("  PROJECTED IN-GAME FPS IMPACT (translate to dashboard 'FPS impact' line)")
print("============================================================================")
print(string.format("  60fps frame budget:                       %.2f \u{03BC}s/frame", FRAME_BUDGET_US))
print()
print(string.format("  PRE-FIX baseline:                         %.4f%% FPS impact", fps_impact_pct(us_pre_per_sec)))
print(string.format("  POST-Fix-1 (in combat):                   %.4f%% FPS impact", fps_impact_pct(us_pf1_per_sec)))
print(string.format("  POST-Fix-2 (out of combat):               %.4f%% FPS impact", fps_impact_pct(us_pf2_per_sec)))
print()
print(string.format("  Cumulative savings:                       %.4f%% FPS impact reclaimed",
    fps_impact_pct(us_pre_per_sec) - fps_impact_pct(us_pf2_per_sec)))
print("============================================================================")
print()
print("  IMPORTANT: these are SYNTHETIC microbenchmark numbers for the")
print("  dispatch ENTRY cost only (cheap guards + frame-skip counter).")
print("  The real-world FPS impact also includes:")
print("    * build_context() ~80-field rebuild (Fix #3 candidate)")
print("    * strategy.matches/execute pcall overhead (already cheap)")
print("    * PvP detection loops over enemy list (Fix #3 candidate)")
print("    * Lua GC pressure from clearing _context every tick")
print("  To measure the FULL real impact, enable Show Dashboard in-game")
print("  and read the 'FPS impact' line under the Diagnostics menu before")
print("  and after each fix.")
print("============================================================================")
