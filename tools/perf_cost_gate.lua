-- perf_cost_gate.lua — per-frame allocation cost gate (P3 of the number-one
-- roadmap: makes the repo's no-per-frame-allocation rule enforced, not stated).
--
-- WHAT:  under the repo's capturing mock, runs a representative hot-path
--        workload and measures allocation via the forced-GC delta technique
--        (collect, run a batch, collect; KB delta = retained growth — the
--        same standard the swing-diagnostics zero-alloc pin uses). Paths:
--          tick_off            real main_sylvanas on_rotation_update,
--                              Diagnostics -> Trace Casts OFF
--          tick_on             same tick with a DSL lane firing + trace ON
--          trace_off_record    CastTrace.record with the toggle off
--          trace_on_record     CastTrace.record (DSL watch) with the toggle on
--          readout_idle        Diagnostics "Last Casts" render, nothing recorded
--          readout_live        same render with a full 32-entry ring
--          cp_reconcile_idle   ControlPanel.reconcile() (no role change)
--          cp_legacy_render    real ControlPanel.render_legacy_rows() through
--                              the registered legacy callback (row cache hit)
--        Two metrics per path:
--          retained  full collect before AND after the batch (objects the batch
--                    leaves behind — the swing-pin standard)
--          churn     collectgarbage('stop') during the batch (nothing freed
--                    while stopped), so the delta counts per-frame TEMPORARIES
--                    too — the metric the retained technique cannot see. The
--                    collector is restored and a full collect runs afterwards.
--        Gate: disabled/idle paths must show amortized zero retained growth and
--        near-zero churn; enabled paths stay within named bounds; a regression
--        in either metric fails the gate with the measured delta printed.
--
-- WHEN:  lua tools/perf_cost_gate.lua [--check]  (wired into run_verify_all as
--        the "perf cost gate" component).
-- WHY:   the repo's no-per-frame-allocation rule lived in prose + one micro
--        pin; this turns it into a hard gate with named thresholds.
-- SAFETY: read-only measurement under mocks; no writes, no engine calls.
--        collectgarbage('stop'/'restart') is always paired, even on failure.
-- EXIT:  0 = every path within its named threshold ([PASS] printed); 1 = a
--        threshold exceeded ([FAIL] + measured delta printed).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

-- ============================================================================
-- Named thresholds (KB of RETAINED growth over the measured batch).
-- 0.0 is the repo's no-per-frame-allocation standard; sub-KB float noise on
-- some Lua builds is absorbed by HARD_ZERO.
-- ============================================================================
local HARD_ZERO = 0.05        -- disabled/idle paths must be ~0 retained
local CHURN_DISABLED = 4.0    -- direct disabled/idle paths over 20k iterations.
                              -- Measured steady state is 0.06-1.44 KB (heap-step
                              -- granularity only: cache-hit paths allocate
                              -- nothing); a fresh-table-per-frame regression
                              -- (32 B/frame * 20000 = 640 KB) still fails 160x
                              -- over the bound while run-to-run jitter stays
                              -- far under it
local CHURN_TICK = 96.0       -- full-engine tick over 6000 ticks. The real
                              -- per-tick context/state build IS legitimate
                              -- churn: measured steady state is 47.0 KB
                              -- (stable to 0.01 KB across runs), so a bound of
                              -- ~2x catches a NEW per-frame allocation (which
                              -- adds its full batch volume) while tolerating
                              -- engine-side context-build drift.
local CHURN_MARGINAL = 16.0   -- the trace feature's OWN added per-tick churn
                              -- (tick_on minus tick_off). Measured steady state
                              -- is 0.36 KB; a per-tick closure/table in the
                              -- trace path adds its full 6000-tick volume, so a
                              -- 16 KB bound catches any new allocation while
                              -- never false-failing the measured 0.36 KB.
local TICK_OFF_BOUND = 1.0    -- full-engine tick: absorbs GC-accounting jitter
                              -- (same 1.0 KB tolerance as the swing-diagnostics
                              -- zero-alloc pin) while still failing on any real
                              -- per-tick retained growth (a bounded cache fill
                              -- of ~100 B/tick would blow 6000 * 0.1 KB)
local TRACE_ON_BOUND = 8.0    -- enabled record: bounded ring retention only
local READOUT_LIVE_BOUND = 8.0
local TICK_ON_BOUND = 8.0     -- trace-on tick adds at most the ring constant

local FAILS = 0

local function assert_metric(name, kb, bound, metric)
    local ok = kb <= bound
    if not ok then FAILS = FAILS + 1 end
    print(string.format("  %-24s %-8s %7.2f KB (bound %6.2f KB)  %s",
        name, metric, kb, bound, ok and "ok" or "THRESHOLD FAIL"))
end

-- Retained growth over `iters` calls of fn(): full collect before AND after so
-- only objects the batch leaves behind are counted (the swing-pin standard).
local function measure_retained(fn, iters)
    collectgarbage("collect")
    collectgarbage("collect")
    local before = collectgarbage("count")
    for _ = 1, iters do fn() end
    collectgarbage("collect")
    collectgarbage("collect")
    return collectgarbage("count") - before
end

-- Gross allocation over `iters` calls of fn(): the collector is STOPPED for the
-- whole batch, so nothing created inside the batch is freed before the final
-- count — the delta therefore includes per-frame temporaries the retained
-- metric cannot see. The collector is always restarted afterwards (even if
-- fn() errors) and a full collect releases the batch's garbage.
local function measure_churn(fn, iters)
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    local ok, err = pcall(fn, iters)
    local after = collectgarbage("count")
    collectgarbage("restart")
    if not ok then
        collectgarbage("collect")
        error("measure_churn workload failed: " .. tostring(err))
    end
    -- Settle the heap fully: a stopped-GC phase leaves the collector in a
    -- state where one or two collects do not fully reclaim (empirically a
    -- later retained measurement then reads ~0.1-0.2 KB of phantom growth).
    -- Repeated collects + a full gc cycle release everything the batch built.
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    collectgarbage("collect")
    return after - before
end

-- Both metrics for one workload, printed on one line each.
local function measure_both(name, fn, iters, retained_bound, churn_bound)
    local retained = measure_retained(fn, iters)
    assert_metric(name, retained, retained_bound, "retained")
    local churn = measure_churn(fn, iters)
    assert_metric(name, churn, churn_bound, "churn")
    return retained, churn
end

-- ============================================================================
-- Capturing mock environment for the real dispatcher tick (mirrors the
-- dispatcher-role-mode / warlock-boot suites: real main_sylvanas, real DSL
-- compile, mocked API surface).
-- ============================================================================
local function build_env()
    local casts = 0
    local player = {
        is_alive = function() return true end,
        is_valid = function() return true end,
        get_health_percentage = function() return 100 end,
        get_mana_percentage = function() return 100 end,
        get_power = function() return 1000 end,
        get_class = function() return 9 end,
        get_target = function()
            return {
                is_alive = function() return true end,
                is_valid = function() return true end,
                is_enemy_with = function() return true end,
                get_health_percentage = function() return 80 end,
                get_distance = function() return 15 end,
            }
        end,
        is_in_combat = function() return true end,
        gcd_remains = function() return 0 end,
        is_moving = function() return false end,
        is_casting = function() return false end,
        is_channeling = function() return false end,
    }
    _G.core = {
        time = function() return 100 end,
        game_time = function() return 100000 end,
        log = function(...) end,
        log_warning = function(...) end,
        log_error = function(...) end,
        object_manager = {
            get_local_player = function() return player end,
            get_visible_objects = function() return {} end,
        },
        spell_book = {
            is_spell_learned = function() return true end,
            get_global_cooldown = function() return 0, 0 end,
            get_spell_cooldown = function() return 0 end,
            get_spell_costs = function() return {} end,
            is_spell_in_range = function() return true end,
        },
        input = {},
    }
    package.loaded.core_sylvanas = nil
    package.loaded.main_sylvanas = nil
    _G.EaxRotations = nil
    local NS = require("core_sylvanas")
    NS.try_cast = function() casts = casts + 1; return true end
    local dsl = require("shared/strategy_dsl_sylvanas")
    local arcane = dsl.compile_strategy({
        name = "ArcaneBlast",
        conditions = {
            { type = "state", field = "in_combat", op = "truthy" },
            { type = "state", field = "arcane_blast_stacks", op = ">=", value = 2 },
            { type = "state", field = "mana_pct", op = ">=", value = 40 },
        },
        action = { type = "cast", spell = 30451, target = "target" },
    })
    -- Reused state table: the gate measures RETAINED growth, not the fresh
    -- per-tick context build (which is churn, freed at the final collect).
    local state = { in_combat = true, arcane_blast_stacks = 3, mana_pct = 62 }
    NS.rotation_registry = {
        class_config = { class_key = "mage", default_playstyle = "arcane" },
        playstyles = { arcane = { arcane } },
        options = { arcane = { get_state = function() return state end } },
    }
    NS.class_middleware = { mage = {} }
    NS.set_setting("playstyle", "arcane")
    NS.set_setting("active_playstyle", nil)
    NS.refresh_settings_cache()
    local dispatcher = require("main_sylvanas")
    return { NS = NS, dispatcher = dispatcher, CastTrace = NS.CastTrace, state = state }
end

-- ============================================================================
-- Workloads
-- ============================================================================
local env = build_env()
local NS = env.NS
local CastTrace = env.CastTrace
local dispatcher = env.dispatcher

if not CastTrace then
    print("FAIL: CastTrace not loaded with the dispatcher (core/diagnostics)")
    os.exit(1)
end

-- Real DSL strategy used by the direct record + readout paths.
local dsl = require("shared/strategy_dsl_sylvanas")
local rip = dsl.compile_strategy({
    name = "Rip",
    conditions = {
        { type = "state", field = "rip_remains", op = "<", value = 3 },
        { type = "state", field = "combo_points", op = ">=", value = 5 },
        { type = "state", field = "energy", op = ">=", value = 30 },
    },
    action = { type = "cast", spell = 1079, target = "target" },
})
local rip_state = { rip_remains = 0.4, combo_points = 5, energy = 40 }
local ctx = { target = { is_valid = function() return true end } }

-- ControlPanel module (real file): reconcile (v2 idle) + the legacy
-- per-frame render callback (the row-cache path added by the P3 audit fix).
local cp_mod_ok, ControlPanel = pcall(dofile, "EaxRotations/shared/control_panel_sylvanas.lua")
if not cp_mod_ok or type(ControlPanel) ~= "table" or type(ControlPanel.reconcile) ~= "function" then
    print("FAIL: ControlPanel module unavailable for perf gate")
    os.exit(1)
end

-- Register a legacy-mode env (no menu.control_panel -> legacy) with stable
-- mock keybinds so render_legacy_rows builds its row cache once and the
-- measured frames are steady-state cache hits (the path the audit asked to
-- drive: the legacy callback that used to allocate a fresh row table every
-- frame). schema_widgets returns ONE shared table so the cache signature is
-- stable across calls.
local shared_schema = {}
local cp_controls = {}
for i = 1, 3 do
    cp_controls[i] = { get_key_code = function() return 7 end } -- unbound sentinel
end
_G.menu = {}
ControlPanel.register({
    core = { register_on_render_control_panel_callback = function() end, log = function() end },
    framework_core = { runtime_generation = 1, get_setting = function() return nil end },
    runtime_generation = 1,
    MenuTheme = {
        role_for_playstyle = function() return "tank" end,
        def_allowed = function() return true end,
    },
    class_key = "warrior",
    active_playstyle = function() return "arms" end,
    quick_toggle_defs = {
        { key = "ct1", label = "Toggle One", capability = "damage", control = cp_controls[1] },
        { key = "ct2", label = "Toggle Two", capability = "utility", control = cp_controls[2] },
        { key = "ct3", label = "Toggle Three", capability = "defense", control = cp_controls[3] },
    },
    playstyle_combo = {},
    playstyle_options = {},
    schema_widgets = function() return shared_schema end,
})

-- Replica of the Diagnostics "Last Casts" render callback (the readout header
-- line in main.lua's Diagnostics tree: lines(4) -> concat or fallback string,
-- header:render). Exercises the real CastTrace surface per frame.
local function readout_render()
    local lines = CastTrace.lines(4)
    if #lines > 0 then
        local _ = table.concat(lines, "  |  ")
    else
        local _ = "(none recorded - enable Trace Casts and enter combat)"
    end
end

local function cp_legacy_render()
    ControlPanel.render_legacy_rows()
end

print("perf cost gate: retained (forced-GC delta) + churn (GC-stop delta), batch standard")
print("  workloads under capturing mock: dispatcher tick, cast trace, readout, CP reconcile + legacy render")

-- ---------------------------------------------------------------------------
-- 1. Disabled / idle paths — amortized ZERO retained AND near-zero churn.
-- ---------------------------------------------------------------------------
NS._TRACE_CASTS = false
CastTrace.clear()
local _r, _c = measure_both("trace_off_record", function()
    CastTrace.record("rotation", { name = "PoolForExecuteBite" }, ctx, rip_state)
end, 20000, HARD_ZERO, CHURN_DISABLED)

CastTrace.clear()
NS._TRACE_CASTS = false
_r, _c = measure_both("readout_idle", readout_render, 20000, HARD_ZERO, CHURN_DISABLED)

_r, _c = measure_both("cp_reconcile_idle", function()
    ControlPanel.reconcile()
end, 20000, HARD_ZERO, CHURN_DISABLED)

-- The legacy per-frame render the P3 audit called the largest real per-frame
-- allocation in the product. After the row-cache fix, steady-state frames must
-- be amortized-zero on BOTH metrics. Warm up one frame so the row-cache build
-- happens BEFORE the measured batches; the batches then measure steady-state
-- cache hits only.
cp_legacy_render()
local leg_r_kb = measure_retained(cp_legacy_render, 20000)
assert_metric("cp_legacy_render", leg_r_kb, HARD_ZERO, "retained")
cp_legacy_render() -- re-warm (a churn phase of a PRIOR path can evict the cache)
local leg_c_kb = measure_churn(cp_legacy_render, 20000)
assert_metric("cp_legacy_render", leg_c_kb, CHURN_DISABLED, "churn")

-- ---------------------------------------------------------------------------
-- 2. Dispatcher tick paths (real main_sylvanas dispatch/context build).
-- ---------------------------------------------------------------------------
-- Warm up to steady state: trace-throttle keys, per-playstyle category
-- caches, and (once trace-on) the full 32-entry ring must exist BEFORE the
-- baseline collect, otherwise the first batch absorbs one-time cache fills.
-- Measured over a long batch so per-tick growth — not bounded-cache fills —
-- is what a nonzero delta means (empirically 0.000 KB retained at 6000 ticks).
NS._TRACE_CASTS = false
for _ = 1, 3000 do dispatcher.on_rotation_update() end
local tick_off_kb, tick_off_churn = measure_both("tick_off", function()
    dispatcher.on_rotation_update()
end, 6000, TICK_OFF_BOUND, CHURN_TICK)

NS._TRACE_CASTS = true
CastTrace.clear()
for _ = 1, 200 do dispatcher.on_rotation_update() end -- refill ring to steady state
local tick_on_kb, tick_on_churn = measure_both("tick_on", function()
    dispatcher.on_rotation_update()
end, 6000, TICK_ON_BOUND, CHURN_TICK)
local tick_marginal_kb = tick_on_kb - tick_off_kb
if tick_marginal_kb > TICK_ON_BOUND then FAILS = FAILS + 1 end
print(string.format("  %-24s %-8s %7.2f KB (bound %6.2f KB)  %s",
    "tick_marginal(on-off)", "retained", tick_marginal_kb, TICK_ON_BOUND,
    tick_marginal_kb <= TICK_ON_BOUND and "ok" or "THRESHOLD FAIL"))
local tick_marginal_churn = tick_on_churn - tick_off_churn
if tick_marginal_churn > CHURN_MARGINAL then FAILS = FAILS + 1 end
print(string.format("  %-24s %-8s %7.2f KB (bound %6.2f KB)  %s",
    "tick_marginal(on-off)", "churn", tick_marginal_churn, CHURN_MARGINAL,
    tick_marginal_churn <= CHURN_MARGINAL and "ok" or "THRESHOLD FAIL"))

-- ---------------------------------------------------------------------------
-- 3. Enabled cast-trace paths — bounded retention, bounded per-frame churn
--    (the ring itself is preallocated; entries copy only formatted strings).
-- ---------------------------------------------------------------------------
CastTrace.clear()
NS._TRACE_CASTS = true
for _ = 1, 100 do CastTrace.record("rotation", rip, ctx, rip_state) end -- fill ring
_r, _c = measure_both("trace_on_record", function()
    CastTrace.record("rotation", rip, ctx, rip_state)
end, 20000, TRACE_ON_BOUND, CHURN_DISABLED)

CastTrace.clear()
for _ = 1, 40 do CastTrace.record("rotation", rip, ctx, rip_state) end -- live ring
_r, _c = measure_both("readout_live", readout_render, 20000, READOUT_LIVE_BOUND, CHURN_DISABLED)

NS._TRACE_CASTS = false
CastTrace.clear()

-- ---------------------------------------------------------------------------
print("=" .. string.rep("=", 62))
if FAILS == 0 then
    print("[PASS] perf cost gate: all paths within named thresholds (retained + churn)")
    os.exit(0)
end
print("[FAIL] perf cost gate: " .. tostring(FAILS) .. " metric(s) exceeded threshold")
os.exit(1)
