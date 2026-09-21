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
-- Per-state (T10-T14): the tick half used to measure whichever state the fixture happened to
--        sit in, so a regression in any other state hid behind that one number. It now drives
--        five fixtures, each of which really settles in its state and stays there, and counts
--        that state's handler entries per tick, so a fixture that drifted cannot be measured as
--        if it had not. Measured on the pinned Lua 5.1.5 (n=300 / n=1000, two runs, identical):
--          WAITING    -0.43 /    0.00  clean — bound 8 (measured + 8, so any added byte fails)
--          IDLE      388.07 /  387.89  idle_state.run's seven head probes are inline
--                                      `pcall(function() ... end)` closures: the death check
--                                      (is_dead, get_health, one per aura method) and the
--                                      cast/channel pause (is_casting_spell, is_channelling_spell)
--          INTERACT  320.31 /  319.97  two Zygor step-info tables per tick: interact_state asks
--                                      zygor_reader.get_current_step_info() once for the
--                                      flight-path section and once for the frame handler, and
--                                      that reader builds a fresh three-field table per call
--          NAV       385.24 /  384.29  nav_state's inline is_in_combat closure (56) +
--                                      navigation.update's fallback mover probes (104) +
--                                      mount_manager.update → try_mount's four closures (225)
--          DEAD        0.00 /   -0.13  clean — bound 8 (measured + 8, so any added byte fails)
--        The three non-zero bounds are RATCHETS around today's measured cost, not an
--        endorsement of it: each is measured + 8 B, and the run-to-run spread above is under
--        1 B, so ANY added per-tick allocation fails in its own state — down to a no-upvalue
--        closure, which costs 20 B (a closure that captures an upvalue costs ~56). Removing the
--        known 388/320/385 (hoisting idle_state's head probes, the duplicate step-info read,
--        nav_state/navigation/mount_manager's closures) is a separate pass; these bounds only
--        stop the cost growing meanwhile.
-- What this cannot prove: anything about the in-game client's own per-call allocation (a real
--        aura read may hand back a fresh table, and the client's own callbacks are not measured
--        here), or the collector's timing under load. The render half (T4-T8) drives the real
--        `on_render` entry point through the same mock, but it pins a stub colour module and a
--        no-op graphics surface: the game's own colour and draw implementations are not
--        measured, and neither is the cost of the client actually rasterising those draws.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.menu = { get = function() return nil end }

local player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock.set_time(1.0)

local coordinator = require("quest_state/coordinator")

--- Gross bytes allocated per call of `fn`, collector stopped.
--- @param n number Calls to measure
--- @param fn function The entry point under measurement
--- @return number bytes_per_call
local function per_call_bytes(n, fn)
    for _ = 1, 5 do fn() end   -- warm the lazy loads: they must not be measured
    collectgarbage("collect")
    collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, n do fn() end
    local after = collectgarbage("count")
    collectgarbage("restart")
    return (after - before) * 1024 / n
end

--- Gross bytes allocated per coordinator tick.
--- @param n number Ticks to measure
--- @return number bytes_per_tick
local function per_tick_bytes(n) return per_call_bytes(n, coordinator.update) end

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

-- ============================================================================
-- T4-T8: the render path (on_render -> render_debug), same harness, collector stopped
-- ============================================================================
-- The tick gate above covers one per-frame entry point; `on_render` -> render_debug is the other,
-- and it used to allocate on every frame whether or not debug was on: two inline
-- `pcall(function() ... end)` closures, a `require("common/color")` retried on every draw when
-- the module is absent, and five colour instances the navigation marker rebuilt per frame.
-- Measured on the pinned Lua 5.1.5 (n=300, collector stopped), before -> after:
--   debug off, no destination       :  89.51 -> 0.00 B/frame
--   debug off, navigating (marker)  : 752.00 -> 0.00 B/frame
--   debug on , navigating (marker)  : 808.29 -> 0.29 B/frame  (the debug text, built by design)
--   debug off, client navmesh path  : 3440.00 -> 0.00 B/frame (a cyan instance per waypoint)
--
-- Fixtures, pinned the way T2 pins the aura table:
--   * `common/color` -- the game supplies it and the harness does not, so without the stub the
--     marker returns early and this gate would measure nothing. The stub allocates like the real
--     module (a fresh instance per call), which is exactly what the fix must stop doing.
--   * a simple_movement stand-in, so navigation commits and a destination really exists.
--   * no-op graphics entry points -- the harness has none of the 3d ones, and its own recorders
--     append a table per call.
-- The navigation module latches the colour module on the first draw, so each scenario loads its
-- own navigation + coordinator pair (the nav suites' fresh_nav idiom) instead of sharing one.

local COLOR_STUB = {
    green = function(a) return { r = 0, g = 255, b = 0, a = a or 255 } end,
    cyan = function(a) return { r = 0, g = 255, b = 255, a = a or 255 } end,
}

local function make_mover()
    local m = {}
    function m:move_to_position(pos) self.target = pos return true end
    function m:stop() end
    function m:process() return false end
    function m:is_moving() return true end
    return m
end

local DRAW_ENTRY_POINTS = { "draw_text", "draw_line", "draw_circle", "circle_3d", "line_3d", "circle_3d_filled" }

local function silence_graphics()
    for _, name in ipairs(DRAW_ENTRY_POINTS) do
        mock.graphics[name] = function() end
    end
end

--- Record every draw the plugin makes, so output identity can be asserted after measuring.
local function record_graphics(sink)
    for _, name in ipairs(DRAW_ENTRY_POINTS) do
        mock.graphics[name] = function(...)
            local call = { name }
            for i = 1, select("#", ...) do call[#call + 1] = select(i, ...) end
            sink[#sink + 1] = call
        end
    end
end

local menu = require("menu_sylvanas")
local real_menu_get = menu.get
local function set_debug(on)
    menu.get = function(k, fb) if k == "debug" then return on end return real_menu_get(k, fb) end
end

--- Load navigation + coordinator fresh, with the given fixtures.
--- @param opts table|nil { color = boolean, destination = boolean, debug = boolean }
--- @return table nav
--- @return table coordinator
local function fresh_world(opts)
    opts = opts or {}
    package.loaded["common/color"] = opts.color and COLOR_STUB or nil
    package.loaded["common/utility/simple_movement"] = make_mover()
    local ns_client = opts.client
    _G.SentinelNavClient = ns_client and { client = ns_client, create = function() return ns_client end } or nil
    package.loaded["navigation_sylvanas"] = nil
    package.loaded["quest_state/coordinator"] = nil
    local ns = _G.EaxAutoQuester
    if ns then ns.navigation = nil; ns.quest_state = nil end
    set_debug(opts.debug == true)

    mock.reset()
    local pl = mock.create_player({ pos = { x = 1, y = 2, z = 3 } })
    local pinned = {}
    pl.get_buffs = function() return pinned end
    pl.get_auras = pl.get_buffs
    pl.get_debuffs = pl.get_buffs
    mock._player = pl
    mock.set_time(1.0)
    silence_graphics()

    local nav = require("navigation_sylvanas")
    local coord = require("quest_state/coordinator")
    if opts.destination then
        nav.navigate_to({ x = 10, y = 20, z = 30 })
        assert(nav.get_state() == "NAVIGATING",
            "fixture FAIL: navigation did not commit, so the marker would never draw")
    end
    return nav, coord
end

-- 16 B/frame: measured 0.00 with noise under 0.5 B, and the SMALLEST regression this half has
-- to catch is the retried failed `require` at 33.5 B/frame, so the bound sits well under it.
-- (The tick half keeps 32 because its regression is a whole closure, 56 B.)
local RENDER_BOUND_BYTES = 16

-- T4: debug OFF while navigating -- the marker draws, i.e. the normal in-game frame
local _, coord4 = fresh_world({ color = true, destination = true })
local render_navigating = per_call_bytes(300, coord4.render_debug)
local drawn = {}
record_graphics(drawn)
coord4.render_debug()
assert(#drawn >= 4,
    "T4a FAIL: the measured scenario drew no marker (" .. tostring(#drawn) .. " draws), so T4 would be vacuous")
assert(render_navigating <= RENDER_BOUND_BYTES,
    string.format("T4b FAIL: the render path allocated %.2f B/frame while navigating (n=300), bound is %d",
        render_navigating, RENDER_BOUND_BYTES))
print(string.format("  T4 PASS: render path allocates %.2f B/frame while navigating with debug off, bound %d",
    render_navigating, RENDER_BOUND_BYTES))

-- T5: debug OFF with nothing to draw -- the retired per-frame failed `require` and closure
local _, coord5 = fresh_world({ color = true })
local render_idle = per_call_bytes(300, coord5.render_debug)
assert(render_idle <= RENDER_BOUND_BYTES,
    string.format("T5 FAIL: the render path allocated %.2f B/frame with nothing to draw (n=300), bound is %d",
        render_idle, RENDER_BOUND_BYTES))
print(string.format("  T5 PASS: render path allocates %.2f B/frame with debug off and no destination, bound %d",
    render_idle, RENDER_BOUND_BYTES))

-- T5b: the same frame with the colour module absent entirely -- no retried failed require
local _, coord5b = fresh_world({ color = false })
local render_nocolor = per_call_bytes(300, coord5b.render_debug)
assert(render_nocolor <= RENDER_BOUND_BYTES,
    string.format("T5b FAIL: the render path allocated %.2f B/frame without a colour module, bound is %d",
        render_nocolor, RENDER_BOUND_BYTES))
print(string.format("  T5b PASS: render path allocates %.2f B/frame with no colour module, bound %d",
    render_nocolor, RENDER_BOUND_BYTES))

-- T6: debug ON -- the overlay rebuilds its text by design, so this bound is loose on purpose:
-- identical text is interned and measures ~0, and 256 covers a state change inside the window.
local DEBUG_BOUND_BYTES = 256
local _, coord6 = fresh_world({ color = true, destination = true, debug = true })
local render_debug_on = per_call_bytes(300, coord6.render_debug)
assert(render_debug_on <= DEBUG_BOUND_BYTES,
    string.format("T6 FAIL: the debug overlay allocated %.2f B/frame (n=300), bound is %d",
        render_debug_on, DEBUG_BOUND_BYTES))
print(string.format("  T6 PASS: debug overlay allocates %.2f B/frame (text by design), bound %d",
    render_debug_on, DEBUG_BOUND_BYTES))

-- T7: output identity -- the same draws, in the same order, with the same arguments
local _, coord7 = fresh_world({ color = true, destination = true, debug = true })
local calls = {}
record_graphics(calls)
coord7.render_debug()
assert(#calls == 5, "T7a FAIL: expected 4 marker draws + 1 debug text, got " .. tostring(#calls))
local expected_names = { "circle_3d_filled", "circle_3d", "circle_3d", "line_3d", "draw_text" }
for i = 1, #expected_names do
    assert(calls[i][1] == expected_names[i],
        string.format("T7b FAIL: draw %d is %s, expected %s", i, tostring(calls[i][1]), expected_names[i]))
end
local expected_alphas = { 60, 200, 255, 150 }
for i = 1, 4 do
    local colour = calls[i][4]
    assert(type(colour) == "table" and colour.a == expected_alphas[i],
        string.format("T7c FAIL: draw %d colour alpha is %s, expected %d",
            i, tostring(colour and colour.a), expected_alphas[i]))
end
assert(calls[2][3] == 3 and calls[3][3] == 2, "T7d FAIL: the destination ring radii changed")
assert(calls[4][6] == 0.5 and calls[4][7] == false, "T7e FAIL: the player path line arguments changed")
local text = calls[5][4]
local state = coord7._test_inspect()
assert(type(text) == "string" and text:find("State: " .. tostring(state), 1, true),
    "T7f FAIL: the debug overlay text changed: " .. tostring(text))
assert(text:match("^EaxAutoQuester\nState: .-\nNav Retries: %d+/3\nStep: %d+$") ~= nil,
    "T7g FAIL: the debug overlay text layout changed: " .. tostring(text))
print("  T7 PASS: the render path draws the same 5 calls with the same arguments")

-- T8: control -- one allocation per frame must exceed the bound, so a silently vacuous render
-- scenario (early return, no destination, no colour module) cannot pass as clean.
local control = per_call_bytes(300, function() local _ = COLOR_STUB.green(60) end)
assert(control > RENDER_BOUND_BYTES,
    string.format("T8 FAIL: the gate cannot see a per-frame allocation (control measured %.2f B/frame)", control))
print(string.format("  T8 PASS: control allocates %.2f B/frame, over the %d bound", control, RENDER_BOUND_BYTES))

-- T9: the client navmesh path -- the branch the in-game client actually drives, and the one that
-- built a cyan instance per waypoint per frame (measured 3440.00 -> 0.00 B/frame on a 14-node
-- path). T4 draws through the fallback mover and never reaches these lines, so the cyan cache
-- would be unpinned without this scenario.
local CLIENT_PATH = {}
for i = 1, 14 do CLIENT_PATH[i] = { x = i, y = 0, z = 0 } end

local function make_client()
    local c = {}
    function c:get_current_path() return CLIENT_PATH end
    function c:validate_destination(_, cb) if cb then cb(true, nil, 50) end end
    function c:health_check(cb) if cb then cb(true) end end
    function c:is_server_available() return true end
    function c:get_state() return "navigating" end
    function c:get_progress()
        return { percent = 0.5, waypoints_remaining = 5, total_waypoints = 14, current_index = 1 }
    end
    function c:move_to(target, cb) self.target = target; self.completion = cb end
    function c:stop() end
    function c:replan(reason) end
    function c:is_moving() return true end
    return c
end

local nav9, coord9 = fresh_world({ color = true, destination = true, client = make_client() })
assert(nav9.get_nav_type() == "sentinel", "fixture FAIL: the client path was not taken")
local render_client = per_call_bytes(300, coord9.render_debug)
local client_calls = {}
record_graphics(client_calls)
coord9.render_debug()
local cyan_nodes, cyan_segments, player_line = 0, 0, 0
for _, call in ipairs(client_calls) do
    local colour = call[4]
    if call[1] == "circle_3d" and type(colour) == "table" and colour.a == 180 then cyan_nodes = cyan_nodes + 1 end
    if call[1] == "line_3d" and type(colour) == "table" and colour.a == 70 then cyan_segments = cyan_segments + 1 end
    if call[1] == "line_3d" and type(colour) == "table" and colour.a == 150 then player_line = player_line + 1 end
end
assert(cyan_nodes >= 1 and cyan_segments >= 1,
    string.format("T9a FAIL: the client path drew no cyan waypoints (%d nodes / %d segments), so T9 would be vacuous",
        cyan_nodes, cyan_segments))
assert(player_line == 1, "T9b FAIL: the player path line is missing from the client-path frame")
assert(render_client <= RENDER_BOUND_BYTES,
    string.format("T9c FAIL: the client-path render allocated %.2f B/frame (n=300), bound is %d",
        render_client, RENDER_BOUND_BYTES))
print(string.format("  T9 PASS: client-path render allocates %.2f B/frame (%d nodes / %d segments drawn), bound %d",
    render_client, cyan_nodes, cyan_segments, RENDER_BOUND_BYTES))

-- ============================================================================
-- T10-T14: the tick path, measured once per coordinator state
-- ============================================================================
-- Why one scenario per state: the T2/T3 half measures whichever state the fixture sits in, so
-- a regression confined to WAITING, INTERACT, NAV or DEAD never reaches the number. Each
-- scenario below asserts three things: the fixture settled in its state, every measured tick
-- dispatched exactly that state's handler and no other, and the per-tick cost is within the
-- state's bound.

local STATE_HANDLER = {
    WAITING = "quest_state/waiting_state",
    IDLE = "quest_state/idle_state",
    INTERACT = "quest_state/interact_state",
    NAV = "quest_state/nav_state",
    DEAD = "quest_state/dead_state",
    DO_ACTION = "quest_state/do_action_state",
}

-- Fresh per state: the module-level caches (the coordinator's submodule handles, the handlers'
-- own throttles and lazy loads, navigation's committed destination, utils' throttle clock) must
-- not carry one scenario into the next one's measurement.
local STATE_FRESH = {
    "quest_state/coordinator", "quest_state/idle_state", "quest_state/nav_state",
    "quest_state/interact_state", "quest_state/do_action_state", "quest_state/waiting_state",
    "quest_state/dead_state", "navigation_sylvanas", "quest_interaction_sylvanas",
    "zygor_reader_sylvanas", "utils_sylvanas", "anti_detection_sylvanas",
    "waypoint_fixer_sylvanas", "flight_path_sylvanas", "mount_manager_sylvanas",
    "static_popup_sylvanas", "loot_manager_sylvanas", "combat_helper_sylvanas",
    "service_gossip_sylvanas", "goal_resolver_sylvanas", "object_scanner",
    "shared/corpse_loot",
    -- menu_sylvanas publishes itself at _G.EaxAutoQuester.menu and answers unknown keys with the
    -- caller's fallback, which is where navigation gets its arrival tolerance (3) from. A stub
    -- that answers every key with false makes navigation throw on `false * false`.
    "menu_sylvanas",
}

-- The mock records every input call by appending a table (harness allocation) and performs none
-- of the movement the plugin asks for. Replaced with no-ops for the same reason T2 pins the aura
-- fixture. `loot_item` matters twice: a looted slot drains the window, and the INTERACT fixture
-- needs it held open.
local INPUT_STUBS = { "jump", "turn_left_start", "turn_left_stop", "turn_right_start",
    "turn_right_stop", "loot_item", "loot_object", "close_loot", "set_target",
    "interact_with_object", "use_object", "use_item", "move_to", "look_at", "look_at_3d" }

local function silence_inputs()
    for i = 1, #INPUT_STUBS do core.input[INPUT_STUBS[i]] = function() end end
end

-- Zygor waypoints reach the world through coords_helper (waypoint_fixer.map_to_world_fixed) and
-- the harness has no such module, so the NAV fixture could not produce a destination without
-- this stand-in — it converts the way the documented fallback does (map coords * 100).
local COORDS_STUB = {
    map_to_world = function(_, map_id, pos) return { x = pos.x * 100, y = pos.y * 100, z = 0 } end,
    get_terrain_height = function() return 0 end,
}

local STEP_BARE = { num = 1, is_complete = false, goals = {}, waypoint = nil, waypoints = {} }
-- A waypoint 70yd away: far past IDLE's 40yd nav threshold but inside the same map.
local STEP_FAR = { num = 1, is_complete = false, goals = {},
    waypoint = { map_id = 1, x = 0.5, y = 0.5 }, waypoints = {} }
local LOOT_WINDOW = {
    { id = 11, name = "First", is_gold = false },
    { id = 12, name = "Second", is_gold = false },
}

local TICK_STATES = {
    {
        label = "T10", name = "WAITING", bound = 8, note = "no guidance available",
        fixture = function() end,  -- no Zygor step: IDLE hands over to WAITING, which holds it
    },
    {
        label = "T11", name = "IDLE", bound = 396, note = "mid-cast gather channel",
        zygor = STEP_BARE,
        -- Mid-cast is the documented reason IDLE exists (idle_state.lua:143-150): the bot must
        -- not move, re-target or re-interact while a gather channel is running.
        fixture = function(player) player._casting = true end,
    },
    {
        label = "T12", name = "INTERACT", bound = 328, note = "loot window open",
        zygor = STEP_BARE,
        fixture = function() mock._loot_items = LOOT_WINDOW end,
    },
    {
        label = "T13", name = "NAV", bound = 393, note = "navigating to a waypoint",
        zygor = STEP_FAR,
        fixture = function() end,
    },
    {
        label = "T14", name = "DEAD", bound = 8, note = "player dead",
        zygor = STEP_BARE,
        fixture = function(player) player._dead = true; player._hp = 0 end,
    },
}

--- Build a world in `spec`'s fixture and return the coordinator plus per-handler entry counts.
--- @param spec table
--- @return table coordinator
--- @return table entered handler name -> entries
--- @return function reset_counts
local function state_scenario(spec)
    for i = 1, #STATE_FRESH do package.loaded[STATE_FRESH[i]] = nil end
    package.loaded["common/utility/simple_movement"] = make_mover()
    package.loaded["common/utility/coords_helper"] = COORDS_STUB
    package.loaded["common/color"] = nil
    _G.SentinelNavClient = nil
    mock.reset()
    _G.EaxAutoQuester = {}
    silence_inputs()
    silence_graphics()

    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local pinned_auras = {}
    player.get_buffs = function() return pinned_auras end
    player.get_auras = player.get_buffs
    player.get_debuffs = player.get_buffs
    if spec.zygor then
        mock._addon_loaded.zygor = true
        mock._zygor_step = spec.zygor
    end
    spec.fixture(player)
    mock.set_time(1.0)

    local coordinator = require("quest_state/coordinator")

    local entered = {}
    for state in pairs(STATE_HANDLER) do entered[state] = 0 end
    for state, module_name in pairs(STATE_HANDLER) do
        local handler = require(module_name)
        local real_run = handler.run
        handler.run = function(shared, ctx)
            entered[state] = entered[state] + 1
            return real_run(shared, ctx)
        end
    end
    local function reset_counts()
        for state in pairs(entered) do entered[state] = 0 end
    end
    return coordinator, entered, reset_counts
end

for i = 1, #TICK_STATES do
    local spec = TICK_STATES[i]
    local coordinator, entered, reset_counts = state_scenario(spec)
    for _ = 1, 3 do coordinator.update() end  -- settle: the first tick is the transition into it
    local settled = coordinator._test_inspect()
    assert(settled == spec.name, string.format(
        "%sa FAIL: the %s fixture (%s) settled in %s, not %s — it would measure the wrong state",
        spec.label, spec.name, spec.note, tostring(settled), spec.name))

    reset_counts()
    local bytes_300 = per_call_bytes(300, coordinator.update)
    local others = ""
    for state, count in pairs(entered) do
        if state ~= spec.name and count > 0 then
            others = others .. " " .. state .. "=" .. tostring(count)
        end
    end
    local entered_300 = entered[spec.name]
    local held_300 = coordinator._test_inspect()

    reset_counts()
    local bytes_1000 = per_call_bytes(1000, coordinator.update)
    local entered_1000 = entered[spec.name]
    local held_1000 = coordinator._test_inspect()

    assert(held_300 == spec.name and held_1000 == spec.name, string.format(
        "%sb FAIL: the machine left %s during measurement (%s after n=300, %s after n=1000)",
        spec.label, spec.name, tostring(held_300), tostring(held_1000)))
    assert(entered_300 >= 300 and entered_1000 >= 1000, string.format(
        "%sc FAIL: %s ran %d times in the n=300 window and %d in the n=1000 window — a fixture " ..
        "that never dispatches the handler measures nothing",
        spec.label, spec.name, entered_300, entered_1000))
    assert(others == "", string.format(
        "%sd FAIL: another handler ran during the %s window:%s — the fixture is not state-pure",
        spec.label, spec.name, others))
    assert(bytes_300 <= spec.bound and bytes_1000 <= spec.bound, string.format(
        "%se FAIL: the %s tick allocated %.2f B/tick (n=300) and %.2f B/tick (n=1000), bound is %d",
        spec.label, spec.name, bytes_300, bytes_1000, spec.bound))

    print(string.format(
        "  %s PASS: %s tick allocates %.2f B/tick (n=300) and %.2f (n=1000), bound %d; " ..
        "%s dispatched every tick (%d/%d) with no other handler running",
        spec.label, spec.name, bytes_300, bytes_1000, spec.bound,
        spec.name, entered_300, entered_1000))
end

print("PASS test_tick_allocation")
