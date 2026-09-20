-- navigation_sylvanas.lua — movement for EaxAutoQuester: SentinelNavClient + simple_movement.
-- WHAT:  drives movement to a destination. Where the nav client is present it is driven on the
--        client's own documented contract: validate the destination before committing, replan
--        by the failure reason the client reports, take arrival and stuck detection from the
--        client's state and progress snapshot instead of comparing positions, and consult
--        health_check before trusting the client.
-- WHEN:  called by quest_state (navigate_to / follow_path / plan_route / update / get_state).
-- WHY:   the module used to commit blind, ignore every failure reason, and derive arrival and
--        stuck from position deltas. None of the documented client signals
--        (validate_destination, replan, get_state/get_progress, health_check/is_server_available,
--        the "stuck" event) was consulted anywhere in the plugin, so a client whose server was
--        down looked exactly like one that was walking.
-- SAFETY: additive, the same shape item 12 proved. The client is used only when it is present
--        and — once a health_check has answered — trusted; simple_movement stays the automatic
--        fallback with its rules unchanged, so a build without SentinelNavClient navigates
--        exactly as it does today. No latched mode switch: every navigation re-decides, and an
--        untrusted client is re-probed on an interval rather than remembered forever.
-- Decision: the reachability probe and the health ping are asynchronous, so a callback can
--        arrive after its navigation was superseded. Every navigation carries a generation
--        counter and a stale callback is ignored, which is what keeps a stop() during combat
--        from being followed by a committed move.

-- API caching at module load (Pattern 2)
local _core_time = core.time
local _core_log = core.log
local _get_local_player = core.object_manager.get_local_player

-- Module table
local M = {}

-- ============================================================================
-- Constants
-- ============================================================================

local NAV_TOLERANCE_SQ = 9        -- 3 yards (fallback arrival; the client decides its own)
local STUCK_TIMEOUT = 3.0         -- fallback: seconds without movement before STUCK
local STUCK_THRESHOLD_SQ = 1.0    -- fallback: movement that counts as progress

local VALIDATE_TIMEOUT = 3.0      -- documented validate_destination probe must answer
local STALL_WINDOW = 6.0          -- no progress + a recovering client for this long = stalled
local HEALTH_REPROBE_INTERVAL = 30.0
local MAX_REPLANS = 1             -- one documented replan per navigation, then report failure

--- Failure reasons the client can report (docs: sentinel-navigation, "Failure Reasons" —
--- unreachable, server_timeout, max_stuck_exceeded, max_repath_exceeded).
--- unreachable/server_timeout are deliberately absent: a new path cannot fix either, and a
--- server that did not answer is handled by marking the client untrusted instead.
--- The stall this module infers from the progress snapshot is reported as the documented
--- max_stuck_exceeded — the client's own name for "too many stuck recovery attempts" — so the
--- reason vocabulary stays the client's instead of growing a plugin-side term.
local REPLANNABLE = {
    max_stuck_exceeded = true,
    max_repath_exceeded = true,
}

-- ============================================================================
-- State
-- ============================================================================

local _state = "IDLE"             -- IDLE | VALIDATING | NAVIGATING | ARRIVED | FAILED | STUCK
local _client = nil               -- SentinelNavClient.client singleton
local _destination = nil          -- final vec3 target
local _arrived_cb = nil           -- callback on arrive/fail
local _generation = 0             -- bumped by every navigation and every stop()
local _is_fallback = false        -- using simple_movement for THIS navigation?
local _fallback_mover = nil
local _fail_reason = nil          -- last documented/normalized failure reason
local _replans = 0                -- replans used by the current navigation
local _validate_started = 0       -- core_time the reachability probe was issued

-- Fallback (position) heuristics — unchanged rules, only used on the fallback path
local _stuck_timer = 0
local _last_position = nil
local _last_pos_time = 0

-- Client-state tracking
-- at = when the last health request was issued (nil = never), so the re-probe throttle
-- does not depend on the clock ever being past zero.
local _health = { checked = false, ok = false, at = nil, pending = false }
local _last_client_state = nil
local _saw_arrived_event = false
local _saw_failed_event = false
local _stuck_events = 0           -- "stuck" events since the last observed progress
local _last_progress = nil        -- { percent =, index = } of the last progress change
local _stall_since = nil          -- core_time the no-progress window began (nil = on track)

local function now()
    return _core_time()
end

local function get_nav_tolerance_sq()
    local ns = _G.EaxAutoQuester
    if ns and ns.menu and ns.menu.get then
        local tol = ns.menu.get("nav_tolerance", 3)
        return tol * tol
    end
    return NAV_TOLERANCE_SQ
end

-- Color (lazy)
local _color = nil
local function get_color()
    if not _color then
        local ok, c = pcall(require, "common/color")
        if ok then _color = c end
    end
    return _color
end

-- Squared 2D distance
local function sq_distance(a, b)
    if not a or not b then return 0 end
    local dx = (a.x or 0) - (b.x or 0)
    local dy = (a.y or 0) - (b.y or 0)
    return dx * dx + dy * dy
end

-- Fire callback nil-guarded
local function fire_callback(success, reason)
    if not _arrived_cb then return end
    local cb = _arrived_cb
    _arrived_cb = nil
    local ok, err = pcall(cb, success, reason)
    if not ok and err then
        _core_log("[EaxAutoQuester] Nav callback err: " .. tostring(err))
    end
end

-- Reset the per-navigation client bookkeeping.
local function reset_client_tracking()
    _fail_reason = nil
    _replans = 0
    _saw_arrived_event = false
    _saw_failed_event = false
    _stuck_events = 0
    _last_progress = nil
    _stall_since = nil
    _last_client_state = nil
    _validate_started = 0
end

-- Stop movement
local function stop_internal()
    if _client and not _is_fallback then
        pcall(function() _client:stop() end)
    elseif _fallback_mover then
        pcall(function() _fallback_mover:stop() end)
    end
    _destination = nil
    _stuck_timer = 0
    _last_position = nil
    _last_pos_time = 0
    _validate_started = 0
end

-- ============================================================================
-- Client inspection — every read is pcall-guarded and returns nil when absent
-- ============================================================================

--- Read the client's top-level state ("idle"|"navigating"|"arrived"|"failed").
--- @return string|nil
local function client_state()
    if not _client or type(_client.get_state) ~= "function" then return nil end
    local ok, value = pcall(function() return _client:get_state() end)
    if ok and type(value) == "string" then
        _last_client_state = value
        return value
    end
    return nil
end

--- Read the client's progress snapshot (docs: percent, waypoints_remaining,
--- total_waypoints, current_index).
--- @return table|nil
local function client_progress()
    if not _client or type(_client.get_progress) ~= "function" then return nil end
    local ok, p = pcall(function() return _client:get_progress() end)
    if ok and type(p) == "table" then return p end
    return nil
end

--- Is the client's own service flag up? Used only to trigger a fresh health probe,
--- never to refuse the client outright: the flag is false until the first response.
--- @return boolean|nil
local function server_available()
    if not _client or type(_client.is_server_available) ~= "function" then return nil end
    local ok, value = pcall(function() return _client:is_server_available() end)
    if ok then return value == true end
    return nil
end

-- ============================================================================
-- Health — consulted before trusting the client
-- ============================================================================

--- Ask the client's server for a health result. Throttled by the caller.
--- @param reason string Label for the log line.
local function probe_health(reason)
    if not _client or _health.pending then return end
    if type(_client.health_check) ~= "function" then return end

    _health.pending = true
    _health.at = now()
    local ok = pcall(function()
        _client:health_check(function(healthy)
            _health.pending = false
            _health.checked = true
            _health.ok = healthy == true
            _health.at = now()
            _core_log("[EaxAutoQuester] nav health_check (" .. tostring(reason) .. ") -> " ..
                tostring(healthy == true))
        end)
    end)
    if not ok then _health.pending = false end
end

--- Re-probe when the client is untrusted and the interval has passed. This is what keeps
--- the fallback from being permanent: a recovered server is picked up on a later navigation.
local function probe_health_if_due(reason)
    if not _client or _health.pending then return end
    if _health.checked and _health.ok then return end
    if _health.at and (now() - _health.at) < HEALTH_REPROBE_INTERVAL then return end
    probe_health(reason)
end

--- May the client be trusted to drive this navigation?
--- @return boolean trusted
--- @return string reason
local function client_trusted()
    if not _client then return false, "no_client" end
    if _health.checked and not _health.ok then return false, "health_check_failed" end
    return true, "ok"
end

-- ============================================================================
-- Failure handling — one owner, driven by the reason the client reported
-- ============================================================================

local function fail_navigation(reason)
    _state = "FAILED"
    _fail_reason = reason
    stop_internal()
    fire_callback(false, reason)
end

--- A `server_timeout` is the documented "server did not respond": mark the client
--- untrusted so the next navigation falls back, instead of retrying into a dead server.
local function mark_server_unreachable()
    _health.checked = true
    _health.ok = false
    _health.at = now()
end

--- Handle a client-reported failure, using the reason the client gave.
--- @param reason string|nil Documented reason, normalized.
local function handle_client_failure(reason)
    if _state ~= "NAVIGATING" then return end
    if type(reason) ~= "string" or reason == "" then reason = "client_failed" end
    _fail_reason = reason

    if reason == "server_timeout" then
        mark_server_unreachable()
        _core_log("[EaxAutoQuester] nav server timeout — client untrusted until a health_check passes")
    end

    if REPLANNABLE[reason] and _replans < MAX_REPLANS
        and type(_client.replan) == "function" then
        _replans = _replans + 1
        _core_log("[EaxAutoQuester] nav failed (" .. reason .. ") — asking the client to replan")
        local ok = pcall(function() _client:replan(reason) end)
        if ok then
            -- The client is re-pathing to the same destination: stay in NAVIGATING and let
            -- its own state/progress report the outcome.
            _stall_since = nil
            _stuck_events = 0
            return
        end
    end

    fail_navigation(reason)
end

-- ============================================================================
-- Client events — subscribed once, at init
-- ============================================================================

local function on_sentinel_arrived()
    if _state ~= "NAVIGATING" and _state ~= "VALIDATING" then return end
    _saw_arrived_event = true
    -- Arrival is the client's call, not a distance comparison: it snaps off-mesh targets to
    -- the nearest reachable point, so "within 3 yards of the requested coordinate" is not
    -- the same question as "the client says it arrived".
    _state = "ARRIVED"
    stop_internal()
    fire_callback(true)
end

local function on_sentinel_failed()
    _saw_failed_event = true
    -- The legacy event carries no reason. The move_to callback is the documented place for
    -- one, so when it has already delivered a reason this is a no-op; otherwise the failure
    -- is handled here as a reason-less client failure and reported under the same label this
    -- event produced before this pass ("sentinel_failed"), not the normalization used for an
    -- empty reason arriving through the callback.
    handle_client_failure(_fail_reason or "sentinel_failed")
end

local function on_sentinel_stuck()
    if _state ~= "NAVIGATING" then return end
    _stuck_events = _stuck_events + 1
end

local function on_sentinel_state_change(data)
    if type(data) == "table" then
        _last_client_state = data.to or _last_client_state
    end
end

-- ============================================================================
-- Lazy-init SentinelNavClient
-- ============================================================================

local function init_sentinel()
    if _client then return true end

    local ok, ns = pcall(function() return _G.SentinelNavClient end)
    if not ok or not ns then return false end

    local c_ok, c = pcall(function() return ns.client end)
    if not c_ok or not c then return false end

    local reg_ok = pcall(function()
        if type(c.on) == "function" then
            c:on("arrived", on_sentinel_arrived)
            c:on("failed", on_sentinel_failed)
            c:on("stuck", on_sentinel_stuck)
            c:on("state_change", on_sentinel_state_change)
        end
    end)
    if not reg_ok then return false end

    _client = c
    _core_log("[EaxAutoQuester] SentinelNavClient initialized")
    return true
end

-- ============================================================================
-- Lazy-init simple_movement fallback
-- ============================================================================

local function init_fallback()
    if _fallback_mover then return true end
    local ok, m = pcall(require, "common/utility/simple_movement")
    if not ok or not m then return false end
    _fallback_mover = m
    _core_log("[EaxAutoQuester] simple_movement fallback initialized")
    return true
end

-- ============================================================================
-- Startup probe — resolve the client, subscribe, ask for health
-- ============================================================================

--- Called once at plugin load (main.lua). Additive: when no client is present this does
--- nothing at all and the module keeps working exactly as before.
--- @return boolean installed
function M.install()
    if not init_sentinel() then return false end
    probe_health("startup")
    return true
end

-- ============================================================================
-- Commit paths
-- ============================================================================

--- Start a navigation on the client, after the destination has been validated.
--- @param gen number Generation this navigation belongs to.
--- @param destination table vec3 target.
local function commit_client(gen, destination)
    if gen ~= _generation then return end

    _is_fallback = false
    _state = "NAVIGATING"
    _stall_since = nil
    _last_progress = nil

    local ok, err = pcall(function()
        _client:move_to(destination, function(success, reason)
            if gen ~= _generation then return end
            if success then return end          -- arrival is handled by state/events
            handle_client_failure(reason)
        end)
    end)
    if not ok then
        fail_navigation(tostring(err))
    end
end

--- Today's simple_movement path, unchanged.
--- @param gen number
--- @param destination table
local function commit_fallback(gen, destination)
    if gen ~= _generation then return end
    if not init_fallback() then
        -- No mover at all: report it to the caller. fire_callback() clears the stored
        -- callback itself, so it must not be cleared here first (that is how the caller
        -- ends up never hearing about it).
        _state = "FAILED"
        _destination = nil
        _core_log("[EaxAutoQuester] No navigation available")
        fire_callback(false, "no_navigation")
        return
    end

    _is_fallback = true
    _state = "NAVIGATING"
    _core_log("[EaxAutoQuester] SentinelNavClient unavailable — using simple_movement fallback")
    local ok, err = pcall(function() _fallback_mover:move_to_position(destination) end)
    if not ok then
        _state = "FAILED"
        _destination = nil
        fire_callback(false, tostring(err))
    end
end

--- Validate the destination with the client's documented probe and commit only if it is
--- reachable. Older clients without the probe commit as before.
--- @param gen number
--- @param destination table
local function validate_then_commit(gen, destination)
    if type(_client.validate_destination) ~= "function" then
        commit_client(gen, destination)
        return
    end

    _state = "VALIDATING"
    _validate_started = now()

    local ok = pcall(function()
        _client:validate_destination(destination, function(reachable, reason)
            if gen ~= _generation then return end
            _validate_started = 0
            if reachable == false then
                -- Deliberately not committed: an unreachable destination is reported with the
                -- client's own reason, and the state machine's existing escalation decides
                -- what to do (waypoint fallback, then direct movement, then give up).
                _fail_reason = reason or "unreachable"
                _state = "FAILED"
                _destination = nil
                fire_callback(false, _fail_reason)
                return
            end
            commit_client(gen, destination)
        end)
    end)
    if not ok then
        -- The probe itself failed to issue; fall back to committing as before.
        _validate_started = 0
        commit_client(gen, destination)
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Navigate to single destination.
--- Where the client is present and trusted this validates the target first, then hands the
--- client a completion callback so its failure reasons can be acted on.
--- @param destination table|nil vec3 target.
--- @param callback function|nil function(success, reason)
function M.navigate_to(destination, callback)
    if not destination then
        if callback then pcall(callback, false, "no_destination") end
        return
    end
    if _state == "NAVIGATING" or _state == "VALIDATING" then stop_internal() end

    _generation = _generation + 1
    local gen = _generation

    -- Fix Z=0 on destination: the client cannot path to z=0 (underground).
    -- Use the current player Z as fallback.
    if destination and (destination.z or 0) == 0 then
        local me_ok, me = pcall(core.object_manager.get_local_player)
        if me_ok and me then
            local _, pos = pcall(function() return me:get_position() end)
            if pos and pos.z and math.abs(pos.z) > 5 then
                destination = { x = destination.x, y = destination.y, z = pos.z }
            end
        end
    end

    _destination = destination
    _arrived_cb = callback
    _stuck_timer = 0; _last_position = nil; _last_pos_time = 0
    reset_client_tracking()

    -- Always try the client first (it may have become available since the last attempt).
    if init_sentinel() then
        local trusted, why = client_trusted()

        if not trusted then
            -- Ask for a fresh health result (throttled by the re-probe interval) and then
            -- re-decide with whatever is known at this point. A health_check that answers
            -- within this call can therefore re-trust the client immediately; one that
            -- answers later simply informs the next navigation. Nothing is latched.
            if server_available() == false then probe_health_if_due("server flag down") end
            probe_health_if_due(why)
            trusted, why = client_trusted()
        end

        if trusted then
            validate_then_commit(gen, destination)
            return
        end

        _core_log("[EaxAutoQuester] nav client not trusted (" .. tostring(why) ..
            ") — using simple_movement")
    end

    commit_fallback(gen, destination)
end

--- Follow multi-waypoint path.
--- The destination is the final waypoint, so that is what gets validated before committing.
--- @param waypoints table|nil vec3[]
--- @param callback function|nil
function M.follow_path(waypoints, callback)
    if not waypoints or #waypoints == 0 then
        if callback then pcall(callback, false, "no_waypoints") end
        return
    end
    if _state == "NAVIGATING" or _state == "VALIDATING" then stop_internal() end

    _generation = _generation + 1
    local gen = _generation

    local destination = waypoints[#waypoints]
    _destination = destination
    _arrived_cb = callback
    _stuck_timer = 0; _last_position = nil; _last_pos_time = 0
    reset_client_tracking()

    if init_sentinel() then
        local trusted, why = client_trusted()
        if trusted and type(_client.follow_path) == "function" then
            -- Validate the final destination, then hand the whole path to the client.
            local function do_follow()
                if gen ~= _generation then return end
                _is_fallback = false
                _state = "NAVIGATING"
                local ok = pcall(function()
                    _client:follow_path(waypoints, function(success, reason)
                        if gen ~= _generation then return end
                        if success then return end
                        handle_client_failure(reason)
                    end)
                end)
                if not ok then fail_navigation("follow_path_error") end
            end

            if type(_client.validate_destination) == "function" then
                _state = "VALIDATING"
                _validate_started = now()
                local issued = pcall(function()
                    _client:validate_destination(destination, function(reachable, reason)
                        if gen ~= _generation then return end
                        _validate_started = 0
                        if reachable == false then
                            _fail_reason = reason or "unreachable"
                            _state = "FAILED"
                            _destination = nil
                            fire_callback(false, _fail_reason)
                            return
                        end
                        do_follow()
                    end)
                end)
                if issued then return end
                _validate_started = 0
            end

            do_follow()
            return
        end

        if server_available() == false then probe_health_if_due("server flag down") end
        probe_health_if_due(why)
        _core_log("[EaxAutoQuester] Sentinel unavailable — single-wp fallback")
    end

    -- No client: today's behavior, walk to the final waypoint.
    M.navigate_to(waypoints[#waypoints], callback)
end

--- Plan TSP route + follow via the client. Unchanged routing; the commit it performs
--- (follow_path) now validates the destination.
--- @param nodes table|nil vec3[]
--- @param callback function|nil
function M.plan_route(nodes, callback)
    if not nodes or #nodes == 0 then
        if callback then pcall(callback, false, "no_nodes") end
        return
    end
    if not init_sentinel() then
        M.navigate_to(nodes[#nodes], callback); return end

    local pok, perr = pcall(function()
        _client:plan_route(nodes, function(ok, data)
            if ok and data and data.waypoints then
                M.follow_path(data.waypoints, callback)
            else
                local err = (data and data.error) or "route_failed"
                _core_log("[EaxAutoQuester] Route plan failed: " .. tostring(err))
                M.navigate_to(nodes[#nodes], callback)
            end
        end, { return_to_start = false })
    end)
    if not pok then
        _core_log("[EaxAutoQuester] Route plan error: " .. tostring(perr))
        M.navigate_to(nodes[#nodes], callback)
    end
end

--- Cancel navigation. Bumping the generation is what makes a pending validation or
--- completion callback unable to commit after the cancellation.
function M.stop()
    local was_nav = (_state == "NAVIGATING" or _state == "VALIDATING")
    _generation = _generation + 1
    _state = "IDLE"; stop_internal()
    if was_nav then fire_callback(false, "cancelled") end
end

function M.is_navigating()
    -- VALIDATING counts: a validation in flight is a navigation the caller must be able to
    -- stop (combat, a new destination), and stop() is what invalidates its callback.
    return _state == "NAVIGATING" or _state == "VALIDATING"
end

function M.get_state() return _state end
function M.get_fail_reason() return _fail_reason end
function M.get_nav_type() return _is_fallback and "simple" or (_client and "sentinel" or nil) end

--- Debug/test surface: what the module currently believes.
--- @return table
function M.get_status()
    return {
        state = _state,
        nav_type = M.get_nav_type(),
        fail_reason = _fail_reason,
        replans = _replans,
        validating = (_state == "VALIDATING"),
        health = { checked = _health.checked, ok = _health.ok,
            pending = _health.pending, at = _health.at or 0 },
        client_state = _last_client_state,
        progress = _last_progress,
        stuck_events = _stuck_events,
        stall_since = _stall_since or 0,
        saw_arrived = _saw_arrived_event,
        saw_failed = _saw_failed_event,
    }
end

--- Get the client's current path for visualization.
function M.get_current_path()
    if not _client or _is_fallback then return nil end
    local ok, path = pcall(function() return _client:get_current_path() end)
    return (ok and path) or nil
end

-- ============================================================================
-- Stuck Recovery — escalating routine (fallback path only)
-- ============================================================================

local _stuck_level = 0
local _stuck_attempts = 0
local _stuck_recovery_timer = 0

local function stuck_recovery()
    if _stuck_level == 0 then return false end
    if _core_time() < _stuck_recovery_timer then return true end  -- still in recovery phase

    if _stuck_level == 1 then
        -- Jump + random strafe
        pcall(core.input.jump)
        local dir = (math.random() > 0.5) and "left" or "right"
        pcall(core.input.strafe, dir, 1.0)
        _stuck_recovery_timer = _core_time() + 1.0
        _core_log("[EaxAutoQuester] Stuck recovery L1: jump + " .. dir)
        return true
    elseif _stuck_level == 2 then
        -- Turn 45-90° randomly + move forward 3-5 yards
        local angle = (math.random() > 0.5 and 1 or -1) * math.rad(45 + math.random() * 45)
        pcall(core.input.turn, angle)
        pcall(core.input.move_forward, 3.0 + math.random() * 2.0)
        _stuck_recovery_timer = _core_time() + 2.0
        _core_log("[EaxAutoQuester] Stuck recovery L2: turn + move")
        return true
    elseif _stuck_level == 3 then
        -- Dismount if mounted
        pcall(core.input.dismount)
        _stuck_recovery_timer = _core_time() + 1.5
        _core_log("[EaxAutoQuester] Stuck recovery L3: dismount")
        return true
    elseif _stuck_level == 4 then
        -- Hearthstone
        pcall(function()
            for bag = 0, 4 do
                local ok_items, items = pcall(core.inventory.get_items_in_bag, bag)
                if ok_items and items then
                    for _, item in ipairs(items) do
                        if item and item.object and item.object.get_item_id then
                            local iid = item.object:get_item_id()
                            if iid == 6948 then
                                pcall(core.input.use_container_item, bag, item.slot_id)
                                break
                            end
                        end
                    end
                end
            end
        end)
        _stuck_recovery_timer = _core_time() + 8.0
        _core_log("[EaxAutoQuester] Stuck recovery L4: hearthstone")
        return true
    end
    return false
end

-- ============================================================================
-- Per-tick update
-- ============================================================================

--- Client path: arrival and stuck come from the client's state and progress snapshot.
--- Fallback path: unchanged position heuristics.
local function update_client_path()
    local cstate = client_state()

    if cstate == "arrived" then
        _state = "ARRIVED"
        stop_internal()
        fire_callback(true)
        return
    end

    -- A failed top-level state is the documented signal when no completion callback carried
    -- a reason (the legacy event has no payload).
    if cstate == "failed" then
        handle_client_failure(_fail_reason or "client_failed")
        return
    end

    -- Progress snapshot: a change is movement. When it stops changing while the client is
    -- reporting recovery ("stuck" events) for a whole window, the client is not going to
    -- recover on its own, so the failure is reported and the state machine's escalation
    -- (waypoint fallback, direct movement) takes over instead of waiting forever.
    local p = client_progress()
    if p then
        local percent = tonumber(p.percent)
        local index = tonumber(p.current_index)
        local moved = (_last_progress == nil)
            or (index ~= _last_progress.index)
            or (percent ~= _last_progress.percent)
        if moved then
            _last_progress = { percent = percent, index = index }
            _stall_since = nil
            _stuck_events = 0
        else
            if not _stall_since then _stall_since = now() end
            if _stuck_events > 0 and (now() - _stall_since) >= STALL_WINDOW then
                handle_client_failure("max_stuck_exceeded")
                return
            end
        end
    end
end

function M.update()
    -- A reachability probe that never answers must not hold the machine forever: the client
    -- answers move_to with server_timeout in the same situation.
    if _state == "VALIDATING" then
        -- _validate_started is stamped on entry to VALIDATING, so it is always set here; the
        -- comparison must not treat 0 as "unset" (a clock can legitimately read 0).
        if (now() - _validate_started) >= VALIDATE_TIMEOUT then
            _validate_started = 0
            _fail_reason = "validate_timeout"
            _state = "FAILED"
            _destination = nil
            fire_callback(false, "validate_timeout")
        end
        return
    end

    -- Handle stuck recovery first
    if _state == "STUCK" then
        if not stuck_recovery() then
            -- Recovery exhausted or done — try to resume
            if _destination then
                _stuck_timer = 0
                _last_position = nil
                _last_pos_time = 0
                _state = "NAVIGATING"
                if _is_fallback and _fallback_mover then
                    pcall(function() _fallback_mover:move_to_position(_destination) end)
                elseif _client then
                    pcall(function() _client:move_to(_destination) end)
                end
            else
                _state = "FAILED"
                fire_callback(false, "stuck_no_dest")
            end
        end
        return
    end

    if _state ~= "NAVIGATING" or not _destination then
        if _state == "NAVIGATING" then M.stop() end; return
    end

    -- Client path: the client owns arrival and stuck detection.
    if not _is_fallback then
        if _client then update_client_path() end
        return
    end

    if not _fallback_mover then return end

    pcall(function() _fallback_mover:process() end)
    local me = _get_local_player()
    if not me then return end
    local _, pos = pcall(function() return me:get_position() end)
    if not pos then return end

    if sq_distance(pos, _destination) <= get_nav_tolerance_sq() then
        _state = "ARRIVED"; stop_internal(); fire_callback(true); return
    end

    local mov_ok, moving = pcall(function() return _fallback_mover:is_moving() end)
    if mov_ok and not moving then
        _state = "FAILED"; stop_internal(); fire_callback(false, "stopped"); return
    end

    local t = _core_time()
    if not _last_position then
        _last_position = { x = pos.x, y = pos.y, z = pos.z }
        _last_pos_time = t; return
    end

    local dx = (pos.x or 0) - (_last_position.x or 0)
    local dy = (pos.y or 0) - (_last_position.y or 0)
    local dz = (pos.z or 0) - (_last_position.z or 0)
    if dx * dx + dy * dy + dz * dz > STUCK_THRESHOLD_SQ then
        _last_position = { x = pos.x, y = pos.y, z = pos.z }
        _last_pos_time = t; _stuck_timer = 0
    else
        if _last_pos_time > 0 then _stuck_timer = _stuck_timer + (t - _last_pos_time) end
        _last_pos_time = t
        if _stuck_timer >= STUCK_TIMEOUT then
            _stuck_attempts = _stuck_attempts + 1
            if _stuck_attempts >= 3 then
                _stuck_level = math.min(_stuck_level + 1, 4)
                _stuck_attempts = 0
            end
            _stuck_recovery_timer = 0
            _state = "STUCK"
            fire_callback(false, "stuck_timeout")
        end
    end
end

-- ============================================================================
-- Visual Rendering — client navmesh path + destination marker
-- ============================================================================

function M.render_visual()
    local c = get_color()
    if not c or not _destination then return end

    -- Draw the client's navmesh path (multi-step waypoints)
    if _client and not _is_fallback then
        local ok, path = pcall(function() return _client:get_current_path() end)
        if ok and path and #path > 0 then
            for i = 1, #path do
                if i % 6 == 1 or i == 1 or i == #path then
                    pcall(core.graphics.circle_3d, path[i], 0.5, c.cyan(180), 5, 1.5)
                end
                if i < #path then
                    pcall(core.graphics.line_3d, path[i], path[i + 1], c.cyan(70), 1.5, 1.0, false)
                end
            end
        end
    end

    -- Destination marker (green rings)
    pcall(core.graphics.circle_3d_filled, _destination, 3.0, c.green(60))
    pcall(core.graphics.circle_3d, _destination, 3.0, c.green(200), 2.0, 0.3)
    pcall(core.graphics.circle_3d, _destination, 2.0, c.green(255), 1.5, 0.5)

    -- Path line from player
    local me = _get_local_player()
    if me then
        local _, pos = pcall(function() return me:get_position() end)
        if pos then pcall(core.graphics.line_3d, pos, _destination, c.green(150), 1.0, 0.5, false) end
    end
end

-- Exports
_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.navigation = M
return M
