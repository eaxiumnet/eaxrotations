-- What: Parity between the SentinelNavClient path and the simple_movement fallback (item 13).
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Item 13 puts navigation on the client's documented contract while keeping the fallback,
--      so a build without SentinelNavClient navigates exactly as it does today. The claim that
--      matters is that the two drives are indistinguishable: one scripted route through the
--      real NAV handler, once with the client present and once without, must produce the same
--      state transitions, tokens and navigation calls, tick for tick. The world movement is the
--      harness's business (as the game's own movement is), so both paths observe the same world
--      instead of one being scripted to agree with the other.
--      Two entries are path-only by construction and are asserted per path rather than
--      compared: the nav type (the difference itself) and the reachability probe (the feature).
--      P3 then pins the one place the paths may legitimately differ — a client that resolves the
--      nearest reachable point and reports arrival off-mesh — and shows the fallback's behavior
--      in that same world is unchanged.
-- Safety: mock-only; no io.popen/os.execute/ffi.C/debug.*/math.sqrt

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()

local nav_state = require("quest_state/nav_state")
local utils = require("utils_sylvanas")

local DEST = { x = 0, y = 30, z = 0 }
local TOLERANCE = 3.0
local START = { x = 0, y = 0, z = 0 }

local function vec(x, y, z) return { x = x, y = y, z = z } end

local function dist(a, b)
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================================
-- World — the game's movement, observed by both paths
-- ============================================================================

--- Walk the player one yard along the route. Every drive calls this identically, so the
--- client's verdict and the fallback's distance check see the same world.
local function advance_player(player, dest, step)
    local cur = player._pos
    local remaining = dist(cur, dest)
    if remaining <= 0 then return end
    local moved = math.min(step, remaining)
    local t = moved / remaining
    player._pos = vec(cur.x + (dest.x - cur.x) * t, cur.y + (dest.y - cur.y) * t, cur.z)
end

-- ============================================================================
-- The client stand-in — its state is DERIVED from the world, as the real client's is
-- ============================================================================

local function make_world_client(player, dest, opts)
    opts = opts or {}
    local report = opts.report_distance or TOLERANCE
    local c = { calls = {}, events = {}, target = nil, completion = nil }

    local function arrived()
        return dist(player._pos, dest) <= report
    end

    local function record(name, detail)
        c.calls[#c.calls + 1] = { name = name, detail = detail }
    end

    function c:on(event, cb) self.events[event] = cb end
    function c:move_to(target, cb)
        record("move_to", target)
        self.target = target
        self.completion = cb
    end
    function c:stop() record("stop") end
    function c:replan(reason) record("replan", reason) end
    function c:validate_destination(target, cb)
        record("validate_destination", target)
        if cb then cb(true, nil, dist(player._pos, target)) end
    end
    function c:health_check(cb) record("health_check"); if cb then cb(true) end end
    function c:is_server_available() return true end
    function c:get_state() return arrived() and "arrived" or "navigating" end
    function c:get_progress()
        local total = dist(START, dest)
        local left = dist(player._pos, dest)
        return { percent = 1 - (left / (total > 0 and total or 1)),
            waypoints_remaining = 1, total_waypoints = 1, current_index = 1 }
    end
    function c:get_current_path() return nil end
    function c:is_moving() return not arrived() end
    return c
end

--- The simple_movement stand-in. It moves nothing (the world above does); it records what
--- the module asked of the fallback, including its per-tick pump.
local function make_world_fallback()
    local f = { calls = {} }
    function f:move_to_position(pos)
        self.calls[#self.calls + 1] = { name = "move_to_position", detail = pos }
        self.target = pos
        return true
    end
    function f:stop() self.calls[#self.calls + 1] = { name = "stop" } end
    function f:process() self.calls[#self.calls + 1] = { name = "process" }; return false end
    function f:is_moving() return true end
    return f
end

local function fresh_nav(client, fallback)
    package.loaded["navigation_sylvanas"] = nil
    package.loaded["common/utility/simple_movement"] = fallback
    local ns = _G.EaxAutoQuester
    if ns then ns.navigation = nil end
    _G.SentinelNavClient = client and { client = client, create = function() return client end } or nil
    return require("navigation_sylvanas")
end

-- ============================================================================
-- Drive — one route through the real NAV handler, logged per tick
-- ============================================================================

--- @param use_client boolean
--- @param opts table|nil { report_distance = } for the off-mesh divergence scenario
--- @return table lines Per-tick log; each entry is "<shared> |<path-only>".
--- @return table nav The module that was driven.
--- @return table client The client stand-in (nil when there is none).
--- @return table fallback The fallback stand-in.
local function drive(use_client, opts)
    opts = opts or {}

    mock.reset()
    mock.set_time(0)
    -- The NAV handler jumps occasionally on a random timer; the same seed gives both drives
    -- the same sequence, so randomness cannot masquerade as a behavioral difference.
    math.randomseed(20260920)

    local player = mock.create_player({ pos = vec(START.x, START.y, START.z),
        hp = 10000, max_hp = 10000, mana = 10000, max_mana = 10000 })
    mock._player = player
    mock._objects = {}

    local client = use_client and make_world_client(player, DEST, opts) or nil
    local fallback = make_world_fallback()
    local nav = fresh_nav(client, fallback)
    if use_client then nav.install() end

    local shared = {
        _state = "NAV",
        _nav_destination = vec(DEST.x, DEST.y, DEST.z),
        _nav_retries = 0,
        _nav_retry_timer = 0,
        _nav_wp_fallback = false,
        _nav_mesh_fallback = false,
    }

    local ctx = {
        nav = nav,
        utils = utils,
        me = player,
        now = 0,
        debug_log = function() end,
        log = function() end,
        safe = function(v, fallback_value) if v == nil then return fallback_value end return v end,
        zygor = { has_current_step = function() return false end },
        npc_manager = { find_nearest_npc = function() return nil end },
        object_scanner = { get_visible_objects = function() return {} end },
    }

    local lines = {}
    for tick = 1, 60 do
        advance_player(player, DEST, 1.0)          -- the game's own movement
        local now = tick * 0.5
        mock.set_time(now)
        ctx.now = now

        local inputs_before = #mock._input_calls
        local f_before = #fallback.calls
        local c_before = client and #client.calls or 0
        local from = shared._state
        local to = nav_state.run(shared, ctx)

        local shared_parts, path_parts = {}, {}

        -- What both paths report about the same navigation.
        shared_parts[#shared_parts + 1] = "nav=" .. tostring(nav.get_state())
        shared_parts[#shared_parts + 1] = "retries=" .. tostring(shared._nav_retries or 0)
        shared_parts[#shared_parts + 1] = "dest=" ..
            (shared._nav_destination and "set" or "nil")
        shared_parts[#shared_parts + 1] = "arrived=" .. tostring(shared._just_arrived == true)
        shared_parts[#shared_parts + 1] = "dist=" .. string.format("%.1f", dist(player._pos, DEST))
        if (shared._nav_retry_timer or 0) > 0 then
            shared_parts[#shared_parts + 1] = "retry_timer=on"
        end

        -- Navigation calls made during this tick, normalized to the shared vocabulary: a
        -- movement request is "move" whichever path issued it, a cancel is "stop".
        for i = f_before + 1, #fallback.calls do
            local name = fallback.calls[i].name
            if name == "move_to_position" then
                shared_parts[#shared_parts + 1] = "move"
            elseif name == "stop" then
                shared_parts[#shared_parts + 1] = "stop"
            else
                path_parts[#path_parts + 1] = "pump"       -- the fallback's per-tick pump
            end
        end
        if client then
            for i = c_before + 1, #client.calls do
                local name = client.calls[i].name
                if name == "move_to" then
                    shared_parts[#shared_parts + 1] = "move"
                elseif name == "stop" then
                    shared_parts[#shared_parts + 1] = "stop"
                else
                    path_parts[#path_parts + 1] = name        -- probe / health / replan
                end
            end
        end
        for i = inputs_before + 1, #mock._input_calls do
            shared_parts[#shared_parts + 1] = "input:" .. tostring(mock._input_calls[i][1])
        end

        -- Path-only entries, first in the block so each path's extras are easy to assert.
        table.insert(path_parts, 1, "type=" .. tostring(nav.get_nav_type()))

        lines[#lines + 1] = string.format("%02d %-4s -> %-4s %s |%s", tick, from, to,
            table.concat(shared_parts, " "), table.concat(path_parts, " "))

        shared._state = to
        if to ~= "NAV" then break end
    end

    return lines, nav, client, fallback
end

--- Compare only the shared part of each line: state transitions, tokens and nav calls.
local function shared_of(line)
    local at = line:find("|", 1, true)
    if at then return line:sub(1, at - 1) end
    return line
end

local function assert_same_route(label, a, b)
    assert(#a == #b, label .. " FAIL: tick counts differ (" .. #a .. " vs " .. #b .. ")")
    for i = 1, #a do
        local sa, sb = shared_of(a[i]), shared_of(b[i])
        assert(sa == sb, label .. " FAIL: tick " .. i .. " differs\n  client:   " ..
            sa .. "\n  fallback: " .. sb)
    end
end

local function count_in(lines, needle)
    local n = 0
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function count_calls(list, name)
    local n = 0
    for _, call in ipairs(list) do
        if call.name == name then n = n + 1 end
    end
    return n
end

-- ============================================================================
-- P1: the client path and the fallback drive the same route
-- ============================================================================
local client_lines, client_nav, client = drive(true)
local fallback_lines, fallback_nav, _, fallback = drive(false)

assert_same_route("P1", client_lines, fallback_lines)
print("P1 PASS: client and fallback drove the same " .. #client_lines ..
    "-tick route (states, tokens, nav calls)")

-- ============================================================================
-- P2: the route is non-vacuous, and only the client path probes
-- ============================================================================
assert(#client_lines >= 20,
    "P2 FAIL: the route is too short to prove anything (" .. tostring(#client_lines) .. ")")
assert(client_lines[1]:find("|type=sentinel", 1, true),
    "P2 FAIL: the client drive must be on the sentinel path\n" .. client_lines[1])
assert(fallback_lines[1]:find("|type=simple", 1, true),
    "P2 FAIL: the fallback drive must be on the simple path\n" .. fallback_lines[1])
assert(count_in(client_lines, "-> IDLE") >= 1,
    "P2 FAIL: the route must reach IDLE\n" .. table.concat(client_lines, "\n"))
local last = shared_of(client_lines[#client_lines])
assert(last:find("dest=nil", 1, true) and last:find("retries=0", 1, true),
    "P2 FAIL: the route must end with a cleared destination and no retries\n" .. last)
assert(count_in(client_lines, "move") >= 1 and count_in(client_lines, "stop") >= 1,
    "P2 FAIL: the route must commit a movement and cancel it on arrival")
assert(count_calls(client.calls, "move_to") == 1,
    "P2 FAIL: exactly one destination commit expected, got " ..
    tostring(count_calls(client.calls, "move_to")))
assert(count_calls(client.calls, "validate_destination") == 1,
    "P2 FAIL: the client path must probe the destination exactly once, got " ..
    tostring(count_calls(client.calls, "validate_destination")))
assert(count_calls(client.calls, "health_check") == 1,
    "P2 FAIL: the startup probe must health-check once, got " ..
    tostring(count_calls(client.calls, "health_check")))
assert(count_calls(client.calls, "replan") == 0,
    "P2 FAIL: a clean route must not need a replan")
print("P2 PASS: one probe, one commit, no replans, arrival reached")

-- ============================================================================
-- P3: where the client has better information it wins — and the fallback is unchanged
-- ============================================================================
-- The client resolves the nearest reachable point for an off-mesh target, so it can report
-- arrival while the requested coordinate is still far away. In that same world the fallback
-- walks on, which is today's behavior for a build without the client — and the client's extra
-- information reaches nav_state, whose own distance cross-check then retries (a rule this pass
-- does not touch). Both facts are asserted below.
local near_lines = drive(true, { report_distance = 20.0 })
local far_lines = drive(false, { report_distance = 20.0 })

-- The off-mesh client report must not leak into the fallback drive: with no client the route
-- is exactly the one P1 compared.
assert_same_route("P3-no-leak", fallback_lines, far_lines)

local split = nil
for i = 1, math.min(#near_lines, #far_lines) do
    if shared_of(near_lines[i]) ~= shared_of(far_lines[i]) then split = i; break end
end
assert(split, "P3 FAIL: the off-mesh arrival must make the paths differ somewhere")

for i = 1, split - 1 do
    assert(shared_of(near_lines[i]) == shared_of(far_lines[i]),
        "P3 FAIL: tick " .. i .. " must be identical before the off-mesh arrival\n  client:   " ..
        shared_of(near_lines[i]) .. "\n  fallback: " .. shared_of(far_lines[i]))
end

-- At the split the client has reported arrival while the player is still 20 yd from the
-- requested coordinate: the arrival is acted on (stop, then a fresh commit). The fallback, on
-- the same world at the same distance, is still simply walking.
local near_line, far_line = shared_of(near_lines[split]), shared_of(far_lines[split])
assert(near_line:find("retries=1", 1, true) and near_line:find("stop", 1, true)
    and near_line:find("move", 1, true),
    "P3 FAIL: the client-reported arrival must have been acted on at tick " ..
    tostring(split) .. "\n" .. near_line)
assert(far_line:find("nav=NAVIGATING", 1, true) and far_line:find("retries=0", 1, true)
    and not far_line:find("stop", 1, true),
    "P3 FAIL: the fallback must keep navigating on the same world\n" .. far_line)

local near_dist = near_line:match("dist=([%d%.]+)")
local far_dist = far_line:match("dist=([%d%.]+)")
assert(near_dist == far_dist,
    "P3 FAIL: the two drives must see the same world at the split (" ..
    tostring(near_dist) .. " vs " .. tostring(far_dist) .. ")")
print("P3 PASS: off-mesh arrival from the client at tick " .. tostring(split) ..
    " (still " .. tostring(far_dist) .. " yd out); the fallback walks on, unchanged")

-- ============================================================================
-- P4: the fallback path issues no client calls, and pumps instead
-- ============================================================================
assert(count_calls(client.calls, "move_to") == 1,
    "P4 FAIL: the fallback must not drive the client")
assert(fallback_nav.get_nav_type() == "simple",
    "P4 FAIL: nav type should be simple, got " .. tostring(fallback_nav.get_nav_type()))
assert(count_in(fallback_lines, "|type=simple") == #fallback_lines,
    "P4 FAIL: every fallback tick must report the simple path")
assert(count_in(fallback_lines, "pump") >= 20,
    "P4 FAIL: the fallback must be pumped every tick while navigating, got " ..
    tostring(count_in(fallback_lines, "pump")))
assert(count_in(client_lines, "pump") == 0,
    "P4 FAIL: the client pumps itself — the module must not pump it")
assert(count_in(client_lines, "validate_destination") == 1,
    "P4 FAIL: only the client path probes")
-- On arrival nav_state stops the module, so the final line reads IDLE: what identifies the
-- fallback arrival is that it happened on the position check, at the tolerance distance.
local fallback_last = shared_of(fallback_lines[#fallback_lines])
assert(fallback_last:find("-> IDLE", 1, true) and fallback_last:find("arrived=true", 1, true)
    and fallback_last:find("dist=3.0", 1, true) and fallback_last:find("dest=nil", 1, true),
    "P4 FAIL: the fallback must arrive on its own position check: " .. fallback_last)
print("P4 PASS: no client calls on the fallback path; it pumps and arrives by position")

print("PASS test_nav_client_parity")
os.exit(0)
