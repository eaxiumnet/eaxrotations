-- test_tick_allocation.lua — item 15: the per-tick path allocates nothing, and stays that way.
-- What:  measures allocation in the REAL coordinator tick path, driven by tests/mock_core's
--        core (not a synthetic loop), with the collector stopped so the number is gross
--        allocation rather than "whatever the GC happened to free".
-- Why:   coordinator.build_context built a fresh 21-field context table on every tick, and the
--        unit probes were written inline as `pcall(function() ... end)`, which allocates a
--        closure per call site per tick. That is Pattern 4 ("do not create garbage in tight
--        loops") violated on the hottest path in the plugin.
-- Measured on the pinned Lua 5.1.5 (n=300 and n=1000, identical):
--        1520.00 B/tick before  ->  0.00 B/tick after.
-- Bounds: T2 is 32 B/tick — measured 0.00, so the slack is half a closure and reinstating even
--        ONE closure (56 B) fails. T3 is 256 B/tick on the unpinned fixture, because
--        mock_core's p:get_buffs builds a fresh table on every call: that is harness noise
--        (95.57 B/tick), not plugin cost, and T2 pins the fixture to show the difference.
-- What this cannot prove: anything about the in-game client's own per-call allocation (a real
--        aura read may hand back a fresh table, and the client's own callbacks are not measured
--        here), the collector's timing under load, or the render path — this gate covers the
--        tick path only.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = { get = function() return nil end }

local player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock.set_time(1.0)

local coordinator = require("quest_state/coordinator")

--- Gross bytes allocated per coordinator.update() call, collector stopped.
--- @param n number Ticks to measure
--- @return number bytes_per_tick
local function per_tick_bytes(n)
    for _ = 1, 5 do coordinator.update() end   -- warm the lazy loads: they must not be measured
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, n do coordinator.update() end
    local after = collectgarbage("count")
    collectgarbage("restart")
    return (after - before) * 1024 / n
end

-- ============================================================================
-- T1: the per-tick context is ONE table, reused
-- ============================================================================
coordinator.update()
local first = coordinator._test_context()
local ctx_field_count = 0
for _ in pairs(first) do ctx_field_count = ctx_field_count + 1 end
coordinator.update()
local second = coordinator._test_context()
assert(type(first) == "table", "T1a FAIL: the per-tick context must be a table")
assert(first == second,
    "T1b FAIL: build_context must hand the handlers the SAME table every tick (Pattern 4)")
assert(ctx_field_count >= 15,
    "T1c FAIL: the context should still carry every handler field, got " .. tostring(ctx_field_count))
print("  T1 PASS: one context table reused across ticks (" .. tostring(ctx_field_count) .. " fields)")

-- ============================================================================
-- T2: plugin tick cost, with the harness aura fixture pinned to the plugin's question
-- ============================================================================
-- mock_core's p:get_buffs builds a fresh table on every call, so the fixture is pinned to one
-- cached table for the measurement: what is being bounded is the PLUGIN's per-tick allocation.
local cached_auras = {}
player.get_buffs = function() return cached_auras end
player.get_auras = player.get_buffs
player.get_debuffs = player.get_buffs

local PLUGIN_BOUND_BYTES = 32
local pinned_300 = per_tick_bytes(300)
local pinned_1000 = per_tick_bytes(1000)
assert(pinned_300 <= PLUGIN_BOUND_BYTES,
    string.format("T2a FAIL: the tick path allocated %.2f B/tick (n=300), bound is %d",
        pinned_300, PLUGIN_BOUND_BYTES))
assert(pinned_1000 <= PLUGIN_BOUND_BYTES,
    string.format("T2b FAIL: the tick path allocated %.2f B/tick (n=1000), bound is %d",
        pinned_1000, PLUGIN_BOUND_BYTES))
print(string.format("  T2 PASS: tick allocates %.2f B/tick (n=300) and %.2f B/tick (n=1000), bound %d",
    pinned_300, pinned_1000, PLUGIN_BOUND_BYTES))

-- ============================================================================
-- T3: the same tick with the harness fixture doing its own allocation
-- ============================================================================
-- Loose bound on purpose: this run is dominated by mock_core's aura tables, and it is here so a
-- regression on the tick path is caught even by someone who removes the pin above.
local UNPINNED_BOUND_BYTES = 256
mock.reset()
player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock.set_time(1.0)
local unpinned = per_tick_bytes(300)
assert(unpinned <= UNPINNED_BOUND_BYTES,
    string.format("T3 FAIL: with the harness fixture allocating, the tick cost %.2f B/tick, bound is %d",
        unpinned, UNPINNED_BOUND_BYTES))
print(string.format("  T3 PASS: unpinned tick %.2f B/tick (harness aura fixture), bound %d",
    unpinned, UNPINNED_BOUND_BYTES))

print("PASS test_tick_allocation")
