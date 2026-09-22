-- What: Contract tests for EaxAutoQuester/navigation_sylvanas.lua on the sentinel-nav client.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Item 13. The module used to commit blind, ignore the reason a move failed, and read
--      arrival/stuck from position deltas — none of the documented client signals was used
--      anywhere in the plugin. These scenarios pin the four mechanisms that replaced it:
--        C1/C2  the destination is validated before anything is committed
--        C3     a failure is replanned or reported by its documented reason, never blindly
--        C5/C6  arrival comes from the client's state, stuck from its progress snapshot
--        C4     health_check decides whether the client is trusted, per navigation--        plus the fallback identity (C7), the startup probe (C8), the validate timeout (C9),
--      the generation guard that keeps a stale probe from committing (C10) and the
--      fallback-parity guards found by the HEAD A/B: no mover reports no_navigation (C11),
--      the fallback stuck ladder runs without the nil-arithmetic crash HEAD had (C12), and a
--      reason-less failed event keeps its legacy label (C13).
-- Safety: mock-only; no io.popen/os.execute/ffi.C/debug.*/math.sqrt

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()

-- ============================================================================
-- Harness — a documented client stand-in and a documented simple_movement stand-in
-- ============================================================================

local function vec(x, y, z) return { x = x, y = y, z = z } end

--- Build a client with the documented surface. Every call is recorded, so the tests assert
--- what the module asked the client to do, not what the module believes it did.
--- @param opts table
local function make_client(opts)
    opts = opts or {}
    local c = {
        calls = {},              -- ordered { name, detail }
        events = {},             -- legacy event subscriptions: name -> callback
        state = opts.state or "navigating",
        progress = opts.progress or { percent = 0.5, waypoints_remaining = 1,
            total_waypoints = 1, current_index = 1 },
        health = opts.health,            -- nil = the probe never answers
        reachable = opts.reachable,      -- nil = build without validate_destination
        validate_reason = opts.validate_reason,
        validate_distance = opts.validate_distance,
        validate_answers = (opts.validate_answers ~= false),
        server_available = opts.server_available,
        move_cb = nil,                   -- captured completion callback
        validate_cb = nil,
        version = "0.0.8",
    }

    local function record(name, detail)
        c.calls[#c.calls + 1] = { name = name, detail = detail }
    end
    c.record = record

    function c:on(event, cb)
        self.events[event] = cb
        record("on", event)
    end
    function c:off(event) self.events[event] = nil; record("off", event) end

    function c:move_to(target, cb)
        record("move_to", target)
        self.move_cb = cb
    end
    function c:move_direct(target, cb) record("move_direct", target); self.move_cb = cb end
    function c:follow_path(waypoints, cb)
        record("follow_path", waypoints and #waypoints or 0)
        self.move_cb = cb
    end
    function c:plan_route(nodes, cb)
        record("plan_route", nodes and #nodes or 0)
        if cb then cb(true, { waypoints = nodes }) end
    end
    function c:replan(reason) record("replan", reason) end
    function c:stop() record("stop") end

    if opts.reachable ~= nil or opts.validate_answers == false then
        function c:validate_destination(target, cb)
            record("validate_destination", target)
            self.validate_cb = cb
            if not self.validate_answers then return end       -- never answers
            if cb then
                cb(self.reachable == true, self.validate_reason, self.validate_distance)
            end
        end
    end

    function c:get_state() return self.state end
    function c:get_full_state() return self.state end
    function c:is_moving() return self.state == "navigating" end
    function c:get_destination() return self.destination end
    function c:get_current_path() return self.path end
    function c:get_path_index() return 1 end
    function c:get_progress() return self.progress end
    function c:is_server_available()
        if self.server_available == nil then return true end
        return self.server_available
    end
    function c:health_check(cb)
        record("health_check")
        self.health_cb = cb
        if self.health ~= nil and cb then cb(self.health) end
    end

    return c
end

--- Build the simple_movement stand-in.
local function make_fallback()
    local f = { calls = {}, moving = true, target = nil }
    function f:move_to_position(pos)
        self.calls[#self.calls + 1] = { name = "move_to_position", detail = pos }
        self.target = pos
        self.moving = true
        return true
    end
    function f:stop() self.calls[#self.calls + 1] = { name = "stop" }; self.moving = false end
    function f:process() self.calls[#self.calls + 1] = { name = "process" }; return false end
    function f:is_moving() return self.moving end
    return f
end

--- A fresh module, with the client and the fallback swapped underneath it.
local function fresh_nav(client, fallback)
    package.loaded["navigation_sylvanas"] = nil
    package.loaded["common/utility/simple_movement"] = fallback
    local ns = _G.EaxAutoQuester
    if ns then ns.navigation = nil end
    if client == nil then
        _G.SentinelNavClient = nil
    else
        _G.SentinelNavClient = { client = client, create = function() return client end,
            version = client.version }
    end
    return require("navigation_sylvanas")
end

local function has_call(client, name)
    for _, call in ipairs(client.calls) do
        if call.name == name then return true end
    end
    return false
end

local function count_call(client, name)
    local n = 0
    for _, call in ipairs(client.calls) do
        if call.name == name then n = n + 1 end
    end
    return n
end

local function call_index(client, name)
    for i, call in ipairs(client.calls) do
        if call.name == name then return i end
    end
    return nil
end

local DEST = vec(100, 0, 0)

-- ============================================================================
-- C1: an unreachable destination is never committed
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = false, validate_reason = "unreachable" })
    local nav = fresh_nav(client, make_fallback())

    local cb_ok, cb_reason = nil, nil
    nav.navigate_to(DEST, function(ok, reason) cb_ok, cb_reason = ok, reason end)

    assert(has_call(client, "validate_destination"),
        "C1 FAIL: the destination must be probed before committing")
    assert(not has_call(client, "move_to"),
        "C1 FAIL: an unreachable destination must never be committed to the client")
    assert(nav.get_state() == "FAILED", "C1 FAIL: unreachable must report FAILED, got " ..
        tostring(nav.get_state()))
    assert(cb_ok == false and cb_reason == "unreachable",
        "C1 FAIL: the client's own reason must reach the caller, got " ..
        tostring(cb_reason))
    assert(nav.get_fail_reason() == "unreachable",
        "C1 FAIL: the failure reason must be readable, got " ..
        tostring(nav.get_fail_reason()))
    print("C1 PASS: unreachable destination never committed (reason passed through)")
end

-- ============================================================================
-- C2: a reachable destination is probed first, then committed
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true, validate_distance = 100 })
    local nav = fresh_nav(client, make_fallback())

    nav.navigate_to(DEST, function() end)

    local probe = call_index(client, "validate_destination")
    local commit = call_index(client, "move_to")
    assert(probe, "C2 FAIL: a reachable destination is still probed")
    assert(commit, "C2 FAIL: a reachable destination must be committed")
    assert(probe < commit,
        "C2 FAIL: the probe must precede the commit (probe at " .. tostring(probe) ..
        ", move_to at " .. tostring(commit) .. ")")
    assert(nav.get_state() == "NAVIGATING",
        "C2 FAIL: a committed navigation is NAVIGATING, got " .. tostring(nav.get_state()))
    assert(nav.get_nav_type() == "sentinel",
        "C2 FAIL: nav type should be sentinel, got " .. tostring(nav.get_nav_type()))
    print("C2 PASS: probe then commit, in that order")
end

-- ============================================================================
-- C3: failures are handled by the documented reason, not by blind retry
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())

    local failures = {}
    nav.navigate_to(DEST, function(ok, reason)
        failures[#failures + 1] = { ok = ok, reason = reason }
    end)
    assert(type(client.move_cb) == "function",
        "C3 FAIL: the module must hand the client a completion callback")

    -- max_stuck_exceeded is one of the reasons a fresh path can fix: one replan, then wait.
    client.move_cb(false, "max_stuck_exceeded")
    assert(count_call(client, "replan") == 1,
        "C3 FAIL: max_stuck_exceeded must ask the client to replan")
    assert(client.calls[#client.calls].name == "replan" and client.calls[#client.calls].detail
        == "max_stuck_exceeded",
        "C3 FAIL: the replan must carry the documented reason")
    assert(nav.get_state() == "NAVIGATING",
        "C3 FAIL: after a replan the navigation is still running, got " ..
        tostring(nav.get_state()))

    -- A second failure is not replanned again: one attempt per navigation, then report.
    client.move_cb(false, "max_stuck_exceeded")
    assert(count_call(client, "replan") == 1,
        "C3 FAIL: replans must be bounded (one per navigation), got " ..
        tostring(count_call(client, "replan")))
    assert(nav.get_state() == "FAILED", "C3 FAIL: a second failure must be reported")
    assert(failures[1] and failures[1].reason == "max_stuck_exceeded",
        "C3 FAIL: the caller must receive the documented reason")
    print("C3 PASS: max_stuck_exceeded replans once, then reports the reason")
end

do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    local expected = nil
    nav.navigate_to(DEST, function(ok, reason) expected = reason end)

    -- unreachable cannot be fixed by a new path.
    client.move_cb(false, "unreachable")
    assert(count_call(client, "replan") == 0,
        "C3b FAIL: unreachable must not be replanned — a new path cannot fix it")
    assert(nav.get_state() == "FAILED" and expected == "unreachable",
        "C3b FAIL: unreachable must be reported with its reason, got " ..
        tostring(expected))
    print("C3b PASS: unreachable is reported, never replanned")
end

do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true, health = true })
    local nav = fresh_nav(client, make_fallback())
    nav.navigate_to(DEST, function() end)

    -- server_timeout is the documented "server did not respond".
    client.move_cb(false, "server_timeout")
    assert(count_call(client, "replan") == 0,
        "C3c FAIL: server_timeout must not be replanned into a dead server")
    assert(nav.get_state() == "FAILED", "C3c FAIL: server_timeout must be reported")
    assert(nav.get_status().health.ok == false,
        "C3c FAIL: a server timeout must mark the client untrusted")

    -- The untrusted client must not be latched: a fresh module whose health probe answers
    -- true uses the client again. (The same client instance is reused, so count the commits.)
    local fallback = make_fallback()
    nav = fresh_nav(client, fallback)
    nav.install()                      -- health probe asks again: this client answers true
    local commits_before = count_call(client, "move_to")
    nav.navigate_to(DEST, function() end)
    assert(count_call(client, "move_to") == commits_before + 1,
        "C3d FAIL: after a successful health probe the client must be used again (no latch); " ..
        "move_to calls: " .. tostring(count_call(client, "move_to")))
    assert(#fallback.calls == 0,
        "C3d FAIL: the fallback must not run while the client is trusted")
    print("C3c PASS: server_timeout marks the client untrusted; a later probe re-enables it")
end

-- ============================================================================
-- C4: health_check decides whether the client is trusted
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true, health = false })
    local fallback = make_fallback()
    local nav = fresh_nav(client, fallback)

    assert(nav.install() == true, "C4 FAIL: install must succeed with a client present")
    assert(count_call(client, "health_check") == 1,
        "C4 FAIL: the startup probe must ask the client for a health result")

    nav.navigate_to(DEST, function() end)
    assert(not has_call(client, "move_to"),
        "C4 FAIL: a client that failed its health_check must not be committed to")
    assert(not has_call(client, "validate_destination"),
        "C4 FAIL: an untrusted client must not even be probed")
    assert(fallback.calls[1] and fallback.calls[1].name == "move_to_position",
        "C4 FAIL: an untrusted client must fall back to simple_movement")
    assert(nav.get_nav_type() == "simple",
        "C4 FAIL: nav type should be simple, got " .. tostring(nav.get_nav_type()))

    -- Re-probe on the interval; a healthy answer puts the client back in charge.
    client.health = true
    mock.set_time(31.0)
    nav.navigate_to(DEST, function() end)
    assert(count_call(client, "health_check") == 2,
        "C4 FAIL: an untrusted client must be re-probed on the interval, got " ..
        tostring(count_call(client, "health_check")) .. " health checks")
    assert(has_call(client, "move_to"),
        "C4 FAIL: a recovered client must be trusted again (nothing may latch)")
    print("C4 PASS: unhealthy client falls back; a later healthy probe re-trusts it")
end

-- ============================================================================
-- C4b: an unanswered probe must not block the client (no regression)
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true })     -- health_check never answers
    local fallback = make_fallback()
    local nav = fresh_nav(client, fallback)

    nav.install()
    assert(nav.get_status().health.checked == false,
        "C4b FAIL: an unanswered probe must leave health unknown, not failed")

    nav.navigate_to(DEST, function() end)
    assert(has_call(client, "move_to"),
        "C4b FAIL: today a present client is used — an unanswered health_check may not block it")
    assert(#fallback.calls == 0, "C4b FAIL: the fallback must not run here")
    print("C4b PASS: unanswered probe leaves the client in use (unchanged behavior)")
end

-- ============================================================================
-- C5: arrival comes from the client's state, not from the distance
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local player = mock.create_player({ pos = vec(0, 0, 0) })
    mock._player = player
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    nav.navigate_to(DEST, function() end)

    -- The client says arrived although the player is 100 yd away: the documented off-mesh
    -- snap means the arrival is the client's call, and a distance check would overrule it.
    client.state = "arrived"
    nav.update()
    assert(nav.get_state() == "ARRIVED",
        "C5 FAIL: the client's arrival must be taken as arrival, got " ..
        tostring(nav.get_state()))
    print("C5a PASS: client-reported arrival accepted though the player is far")
end

do
    mock.reset(); mock.set_time(0)
    local player = mock.create_player({ pos = DEST })     -- standing ON the destination
    mock._player = player
    local client = make_client({ reachable = true })       -- ...but the client is not done
    local nav = fresh_nav(client, make_fallback())
    local arrived = false
    nav.navigate_to(DEST, function() arrived = true end)

    nav.update()
    assert(nav.get_state() == "NAVIGATING",
        "C5b FAIL: standing on the destination is not arrival while the client is navigating")
    assert(arrived == false, "C5b FAIL: no arrival callback before the client reports one")

    -- The documented arrival event is the other signal for the same fact.
    client.events.arrived()
    assert(nav.get_state() == "ARRIVED" and arrived == true,
        "C5b FAIL: the arrived event must report arrival")
    print("C5b PASS: position is not arrival; the client's state/event is")
end

-- ============================================================================
-- C6: stuck detection from the client's progress snapshot
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    local reason = nil
    nav.navigate_to(DEST, function(ok, why) reason = why end)

    -- First tick establishes the progress baseline (one sample proves nothing), then the
    -- client reports it is recovering while the snapshot does not budge.
    mock.set_time(0)
    nav.update()
    client.events.stuck()
    for t = 1, 7 do
        mock.set_time(t)
        nav.update()
    end

    -- The first stall is answered with the documented replan — an explicit recovery, not a
    -- silent retry — and the navigation stays alive waiting for the new path.
    assert(nav.get_state() == "NAVIGATING",
        "C6a FAIL: the first stall must ask for a replan, got " .. tostring(nav.get_state()))
    assert(count_call(client, "replan") == 1,
        "C6a FAIL: the stall must be answered with exactly one replan, got " ..
        tostring(count_call(client, "replan")))
    assert(client.calls[#client.calls].detail == "max_stuck_exceeded",
        "C6a FAIL: the replan must carry the documented reason (max_stuck_exceeded), got " ..
        tostring(client.calls[#client.calls].detail))

    -- A second stall, with the one replan already used, is reported.
    client.events.stuck()
    for t = 8, 15 do
        mock.set_time(t)
        nav.update()
    end
    assert(nav.get_state() == "FAILED",
        "C6a FAIL: a second stall must be reported, got " .. tostring(nav.get_state()))
    assert(nav.get_fail_reason() == "max_stuck_exceeded",
        "C6a FAIL: expected the documented max_stuck_exceeded, got " ..
        tostring(nav.get_fail_reason()))
    assert(reason == "max_stuck_exceeded", "C6a FAIL: the caller must get the reason")
    assert(count_call(client, "replan") == 1,
        "C6a FAIL: replans stay bounded at one per navigation")
    print("C6a PASS: stall replans once, then reports the documented max_stuck_exceeded")
end

do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    nav.navigate_to(DEST, function() end)

    -- Same stuck events, but the snapshot keeps moving: the client IS making progress.
    mock.set_time(0)
    nav.update()
    client.events.stuck()
    for t = 1, 7 do
        mock.set_time(t)
        client.progress = { percent = 0.5 + t * 0.05, waypoints_remaining = 1,
            total_waypoints = 1, current_index = 1 + t }
        nav.update()
    end
    assert(nav.get_state() == "NAVIGATING",
        "C6b FAIL: progress must never be mistaken for a stall, got " ..
        tostring(nav.get_state()))
    print("C6b PASS: stuck events with real progress stay NAVIGATING")
end

-- ============================================================================
-- C7: no client → the fallback path, exactly as before
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local fallback = make_fallback()
    local nav = fresh_nav(nil, fallback)

    assert(nav.install() == false, "C7 FAIL: install must be a no-op with no client")

    local arrived = false
    nav.navigate_to(DEST, function(ok) arrived = ok end)
    assert(fallback.calls[1] and fallback.calls[1].name == "move_to_position",
        "C7 FAIL: with no client the fallback must receive the destination")
    assert(nav.get_nav_type() == "simple",
        "C7 FAIL: nav type should be simple, got " .. tostring(nav.get_nav_type()))
    assert(nav.get_state() == "NAVIGATING", "C7 FAIL: fallback navigation starts")

    -- Arrival on the fallback path is the position check, unchanged.
    mock._player._pos = vec(0, 0, 0)
    nav.update()
    assert(nav.get_state() == "NAVIGATING", "C7 FAIL: still far from the destination")
    mock._player._pos = vec(99, 0, 0)          -- within 3 yd of (100,0,0)
    nav.update()
    assert(nav.get_state() == "ARRIVED" and arrived == true,
        "C7 FAIL: the fallback must still arrive on the position check")
    print("C7 PASS: no client → simple_movement + position arrival, unchanged")
end

-- ============================================================================
-- C8: the startup probe is wired — loading the plugin installs the client
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true, health = true })
    local nav = fresh_nav(client, make_fallback())
    package.loaded["main"] = nil

    local ok = pcall(require, "main")
    assert(ok, "C8 FAIL: main.lua must load under the mock")
    assert(count_call(client, "health_check") >= 1,
        "C8 FAIL: loading the plugin must run the navigation health probe")
    assert(nav.install() == true, "C8 FAIL: install must report the client as installed")
    print("C8 PASS: loading main.lua probes the navigation client")
end

-- ============================================================================
-- C9: a reachability probe that never answers cannot hold the machine
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local client = make_client({ validate_answers = false })
    local nav = fresh_nav(client, make_fallback())

    local reason = nil
    nav.navigate_to(DEST, function(ok, why) reason = why end)
    assert(nav.get_state() == "VALIDATING",
        "C9 FAIL: a pending probe is VALIDATING, got " .. tostring(nav.get_state()))
    assert(not has_call(client, "move_to"), "C9 FAIL: nothing may be committed while probing")

    mock.set_time(4.0)
    nav.update()
    assert(nav.get_state() == "FAILED", "C9 FAIL: an unanswered probe must time out")
    assert(reason == "validate_timeout",
        "C9 FAIL: expected validate_timeout, got " .. tostring(reason))
    print("C9 PASS: unanswered probe times out to validate_timeout")
end

-- ============================================================================
-- C10: a stale probe callback cannot commit after the navigation was superseded
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local client = make_client({ validate_answers = false })
    local nav = fresh_nav(client, make_fallback())

    nav.navigate_to(DEST, function() end)
    local stale_cb = client.validate_cb
    assert(type(stale_cb) == "function", "C10 FAIL: the probe callback must be captured")

    nav.stop()                                  -- e.g. combat cancelled the navigation
    stale_cb(true, nil, 100)                    -- the probe finally answers "reachable"
    assert(not has_call(client, "move_to"),
        "C10 FAIL: a superseded probe must not commit a move after stop()")
    assert(nav.get_state() == "IDLE",
        "C10 FAIL: the machine must stay stopped, got " .. tostring(nav.get_state()))
    print("C10 PASS: generation guard — a stale probe cannot commit")
end

-- ============================================================================
-- C11: no mover at all — the caller is told, as before
-- (The A/B against HEAD caught a regression here: commit_fallback cleared the stored
-- callback before firing it, so a build with neither client nor simple_movement failed
-- silently instead of reporting no_navigation.)
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local nav = fresh_nav(nil, nil)                  -- no client, no simple_movement
    local ok_cb, reason = nil, nil
    nav.navigate_to(DEST, function(ok, why) ok_cb, reason = ok, why end)

    assert(nav.get_state() == "FAILED",
        "C11 FAIL: no mover must report FAILED, got " .. tostring(nav.get_state()))
    assert(ok_cb == false and reason == "no_navigation",
        "C11 FAIL: the caller must be told no_navigation, got " ..
        tostring(ok_cb) .. "/" .. tostring(reason))
    print("C11 PASS: no navigation available is reported to the caller")
end

-- ============================================================================
-- C12: the fallback stuck ladder runs and resumes
-- (HEAD declared none of _stuck_level/_stuck_attempts/_stuck_recovery_timer, so its first
-- stuck on the no-client path raised "arithmetic on global '_stuck_attempts'" out of
-- update() — no suite covered it until this one. The locals are now declared; the ladder
-- rules themselves are unchanged.)
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local fallback = make_fallback()
    local nav = fresh_nav(nil, fallback)
    local reason = nil
    nav.navigate_to(DEST, function(ok, why) reason = why end)

    local seen = {}
    for i = 0, 12 do
        mock.set_time(i * 1.0)
        mock._player._pos = vec(0, 0, 0)             -- standing still the whole time
        nav.update()
        local s = nav.get_state()
        if seen[#seen] ~= s then seen[#seen + 1] = s end
    end

    local stuck, resumed = false, false
    for _, s in ipairs(seen) do
        if s == "STUCK" then stuck = true
        elseif stuck and s == "NAVIGATING" then resumed = true end
    end
    assert(stuck, "C12 FAIL: standing still must trip the fallback stuck timer, saw " ..
        table.concat(seen, ">"))
    assert(resumed, "C12 FAIL: the recovery ladder must resume navigation, saw " ..
        table.concat(seen, ">"))
    assert(reason == "stuck_timeout",
        "C12 FAIL: the caller must get stuck_timeout, got " .. tostring(reason))
    assert(nav.get_state() ~= "FAILED",
        "C12 FAIL: recovery must not leave the navigation failed, got " ..
        tostring(nav.get_state()))
    print("C12 PASS: fallback stuck ladder runs and resumes (" .. table.concat(seen, ">") .. ")")
end

-- ============================================================================
-- C13: the legacy `failed` event with no reason keeps HEAD's label
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    local reason = nil
    nav.navigate_to(DEST, function(ok, why) reason = why end)

    -- The documented failed event carries no reason; the move_to callback is where one is
    -- documented to arrive. With no reason delivered, the label this path always produced
    -- must not drift.
    client.events.failed()
    assert(nav.get_state() == "FAILED",
        "C13 FAIL: the failed event must end the navigation, got " .. tostring(nav.get_state()))
    assert(reason == "sentinel_failed",
        "C13 FAIL: expected the legacy label sentinel_failed, got " .. tostring(reason))
    print("C13 PASS: a reason-less failed event reports the legacy label")
end

-- ============================================================================
-- C15: the direct-movement rescue — nav_state's last escalation — reaches a mover.
-- The handler asks the navigation module (`nav.move_direct`); the module has to answer,
-- or the branch is a no-op whatever the handler does.
-- ============================================================================
do
    mock.reset(); mock.set_time(0)
    local player = mock.create_player({ pos = vec(0, 0, 0) })
    mock._player = player
    local client = make_client({ reachable = true })
    local nav = fresh_nav(client, make_fallback())
    assert(type(nav.move_direct) == "function",
        "C15a FAIL: navigation_sylvanas must export move_direct (nav_state asks for it as " ..
        "nav.move_direct; without the export the rescue can never fire)")
    nav.move_direct(DEST)
    assert(count_call(client, "move_direct") == 1,
        "C15a FAIL: the destination must reach the client's own move_direct")
    assert(nav.get_state() == "NAVIGATING", "C15a FAIL: the rescue must start a walk")
    assert(count_call(client, "validate_destination") == 0,
        "C15b FAIL: the rescue must not re-validate a destination pathfinding already refused")
    print("C15a/C15b PASS: the rescue reaches the client's move_direct without re-validating")
end

do
    -- No client at all: the rescue is still a walk — simple_movement moves directly too.
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local fallback = make_fallback()
    local nav = fresh_nav(nil, fallback)
    nav.move_direct(DEST)
    assert(#fallback.calls == 1 and fallback.calls[1].name == "move_to_position",
        "C15c FAIL: without a client the rescue must walk with simple_movement")
    assert(fallback.calls[1].detail == DEST,
        "C15c FAIL: the fallback must be handed the destination asked for")
    print("C15c PASS: the rescue falls back to simple_movement when no client exists")
end

do
    -- An older client without the documented method must still walk, not dead-end.
    mock.reset(); mock.set_time(0)
    mock._player = mock.create_player({ pos = vec(0, 0, 0) })
    local client = make_client({ reachable = true })
    client.move_direct = nil
    local fallback = make_fallback()
    local nav = fresh_nav(client, fallback)
    nav.move_direct(DEST)
    assert(#fallback.calls == 1,
        "C15d FAIL: a client without move_direct must fall back instead of dead-ending")
    print("C15d PASS: a client without move_direct falls back")
end

print("PASS test_nav_client_contract")
os.exit(0)
