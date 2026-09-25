-- What: Unit tests for EaxAutoQuester/quest_state/coordinator.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify state dispatch, stop_navigation, render_debug, and combat override
--      (must NOT block user mouse movement, must NOT call look_at_target on invalid targets)

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local coordinator = require("quest_state/coordinator")

-- Test update runs without error
assert(type(coordinator.update) == "function", "coordinator.update is function")
assert(type(coordinator.stop_navigation) == "function", "coordinator.stop_navigation is function")
assert(type(coordinator.render_debug) == "function", "coordinator.render_debug is function")

-- The live capture seam is public and inert after the session is stopped. This proves the
-- coordinator owns the start/stop/export contract rather than only the recorder in isolation.
assert(type(coordinator.start_session_recording) == "function", "coordinator session start is function")
assert(type(coordinator.stop_session_recording) == "function", "coordinator session stop is function")
assert(type(coordinator.export_session_log) == "function", "coordinator session export is function")
assert(coordinator.start_session_recording() == true, "S4a FAIL: session recording must start")
local session_jsonl = coordinator.stop_session_recording()
assert(session_jsonl:find('"kind":"session_start"', 1, true) and
    session_jsonl:find('"kind":"session_stop"', 1, true),
    "S4b FAIL: the coordinator session API must return start/stop JSONL markers")

-- Test stop_navigation
coordinator.stop_navigation()

-- Test render_debug (no crash)
coordinator.render_debug()

-- =============================================================================
-- Combat override scenarios — coordinator must not block user input or crash on
-- stale targets. Live bugs: pause_movement_light(0.5) every tick prevented
-- mouse movement; look_at_target with invalid target → "Invalid game object"
-- errors in movement_handler.lua:206.
-- =============================================================================

-- Install a mock movement_handler that records every call
local mh_calls = { pause_movement_light = 0, look_at_target = 0, look_at_target_invalid = 0 }
package.loaded["common/utility/movement_handler"] = {
    pause_movement_light = function(self)
        mh_calls.pause_movement_light = mh_calls.pause_movement_light + 1
    end,
    look_at_target = function(self, _, _, target)
        mh_calls.look_at_target = mh_calls.look_at_target + 1
        if target and target.is_valid and not target:is_valid() then
            mh_calls.look_at_target_invalid = mh_calls.look_at_target_invalid + 1
        end
    end,
}

-- S5 — combat + valid target → coordinator must NOT call pause_movement_light
-- (the user needs to be able to move the mouse during combat)
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 10, y = 0, z = 0 },
        name = "Defias Thug",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_100",
    })
    target._target = target  -- player target = this enemy
    mock._objects = { target }
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    mock._player._target = target

    -- Reset the call counters
    mh_calls.pause_movement_light = 0
    mh_calls.look_at_target = 0

    coordinator.update()

    assert(mh_calls.pause_movement_light == 0,
        "S5 FAIL: coordinator's combat block must NOT call pause_movement_light " ..
        "(user can't move mouse). Got " .. tostring(mh_calls.pause_movement_light) .. " calls.")
    print("  S5 PASS: combat override does NOT call pause_movement_light (mouse stays free)")
end

-- S6 — combat + INVALID target → coordinator must NOT call look_at_target
-- (causes "Invalid game object" errors in movement_handler.lua:206)
do
    mock.reset()
    local dead_target = mock.create_object({
        pos = { x = 5, y = 0, z = 0 },
        name = "Dead Enemy",
        npc_id = 100,
        unit = true,
        valid = false,  -- invalid!
        dead = true,
        guid = "dead_enemy",
    })
    mock._objects = { dead_target }
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    mock._player._target = dead_target

    mh_calls.look_at_target = 0
    mh_calls.look_at_target_invalid = 0

    coordinator.update()

    assert(mh_calls.look_at_target_invalid == 0,
        "S6 FAIL: coordinator must NOT call look_at_target on invalid target " ..
        "(causes 'Invalid game object' error). Got " .. tostring(mh_calls.look_at_target_invalid) .. " invalid calls.")
    print("  S6 PASS: combat override guards look_at_target with is_valid()")
end

-- S7 — combat + valid target → core.input.look_at NOT called
-- The auto-quester does NOT auto-face in combat. EaxRotations handles facing
-- for casts via face_for_cast / face_for_spell. The user reported the bot
-- was doing a jarring 180° turn on combat entry — that was the
-- auto-quester snapping to face the enemy. EaxRotations rotates when
-- actually needed (before a cast), not continuously.
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Enemy Behind",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_behind",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S7 FAIL: auto-quester must NOT call look_at in combat. " ..
        "EaxRotations handles facing for casts. Got " .. tostring(look_at_count) ..
        " look_at calls — this is what caused the 180° turn on combat entry.")
    print("  S7 PASS: combat facing removed (EaxRotations handles it) — no 180° snap")
end

-- S7b — combat + valid target IN FRONT of player → core.input.look_at NOT called
-- With the 90° soft-facing threshold, the bot does NOT rotate when the enemy
-- is within 90° of the current facing. This prevents camera-snap desync — the
-- user can keep moving the mouse without the bot fighting their camera control.
do
    mock.reset()
    -- Player faces NORTH (rotation 0). Enemy is directly NORTH (pos y = 10).
    -- Angle between facing and enemy = 0° → < 90° → bot should NOT rotate.
    local target = mock.create_object({
        pos = { x = 0, y = 10, z = 0 },
        name = "Enemy In Front",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_in_front",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0  -- facing north (same direction as enemy)
    mock._player._target = target

    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S7b FAIL: enemy directly in front (0° off) should NOT trigger rotation " ..
        "(soft facing protects camera control). Got " .. tostring(look_at_count) .. " calls.")
    print("  S7b PASS: soft facing — enemy in front → look_at NOT called (no desync)")
end

-- S8 — combat + same target across 5 ticks → core.input.look_at NEVER called
-- The auto-quester does NOT auto-face in combat — at all. EaxRotations handles
-- facing for casts. The previous "throttled to once" behavior was a 0.3s
-- re-rotation that caused the 180° snap. Now: never rotate from the quester.
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Throttle Test Enemy",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "throttle_test_enemy",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    for i = 1, 5 do coordinator.update() end

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S8 FAIL: auto-quester must NEVER call look_at in combat. " ..
        "EaxRotations handles facing for casts. Got " .. tostring(look_at_count) ..
        " look_at calls across 5 ticks — this is what caused the 180° turn spam.")
    print("  S8 PASS: combat — same target across 5 ticks → look_at NEVER called (EaxRotations handles facing)")
end

-- S9 — combat + target moves > 5yd → core.input.look_at NEVER called
-- (auto-quester never auto-faces; EaxRotations handles facing for casts)
do
    mock.reset()
    local target = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Moving Enemy",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "moving_enemy",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target

    coordinator.update()
    target._pos = { x = 0, y = -20, z = 0 }
    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S9 FAIL: target movement must not trigger look_at. " ..
        "EaxRotations handles facing. Got " .. tostring(look_at_count) .. " calls.")
    print("  S9 PASS: target moves > 5yd → look_at NEVER called (no auto-face)")
end

-- S10 — combat + new target GUID → core.input.look_at NEVER called
-- (auto-quester never auto-faces; EaxRotations handles facing for casts)
do
    mock.reset()
    local target_a = mock.create_object({
        pos = { x = 0, y = -10, z = 0 },
        name = "Enemy A",
        npc_id = 100,
        unit = true,
        valid = true,
        guid = "enemy_a",
    })
    local target_b = mock.create_object({
        pos = { x = 5, y = -10, z = 0 },
        name = "Enemy B",
        npc_id = 101,
        unit = true,
        valid = true,
        guid = "enemy_b",
    })
    mock._objects = { target_a, target_b }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true })
    player._rotation = 0
    mock._player._target = target_a

    coordinator.update()
    mock._player._target = target_b
    coordinator.update()

    local look_at_count = 0
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "look_at" then look_at_count = look_at_count + 1 end
    end
    assert(look_at_count == 0,
        "S10 FAIL: new target GUID must not trigger look_at. " ..
        "EaxRotations handles facing. Got " .. tostring(look_at_count) .. " calls.")
    print("  S10 PASS: new target GUID → look_at NEVER called (no auto-face)")
end

-- =============================================================================
-- S11 — a nearby player must never pause the machine.
-- Live logs: the coordinator armed shared._action_pause_timer for 3s on every tick a
-- player stood within 30yd, and IDLE returns early while that timer is set, so the quester
-- stood still for 15 minutes at a time. This drives the real update() with a player parked
-- in range and asserts the pause is never armed.
-- =============================================================================
do
    mock.reset()
    local me = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, class = 5 })
    local stranger = mock.create_object({
        pos = { x = 10, y = 0, z = 0 }, name = "Stranger",
        unit = true, player = true, valid = true, guid = "stranger_pause",
    })
    mock._objects = { stranger }

    local shared = coordinator._test_shared()
    -- WAITING isolates the tick: its handler never touches the pause timer, so any pause
    -- seen here would be a regression to a retired proximity/stall path.
    shared._state = "WAITING"
    shared._action_pause_timer = 0

    local armed = 0
    for i = 1, 200 do
        mock.set_time(i * 0.05)
        coordinator.update()
        if (shared._action_pause_timer or 0) > 0 then armed = armed + 1 end
    end
    assert(armed == 0,
        "S11 FAIL: a nearby player armed the action pause on " .. tostring(armed) ..
        " of 200 ticks — that freeze is what the quester shipped with")
    print("  S11 PASS: 200 ticks beside a player → action pause never armed")
end

-- =============================================================================
-- S11b/S11c — recorded failures are consumed by the real coordinator tick.
-- The failed goal is first in the guide list. Goal resolution must skip it and choose the
-- healthy goal; the following DO_ACTION tick must skip the already-selected failed goal.
-- A step transition repeats the choice, proving the session mark survives step cleanup.
-- =============================================================================
do
    local nav_destination = require("shared/nav_destination")
    local progress = require("progress_tracker_sylvanas")
    local blacklist = require("quest_blacklist_sylvanas")
    progress.clear_all()
    blacklist.reset()

    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 100, max_hp = 100,
        mana = 100, max_mana = 100 })
    local failed_target = mock.create_object({
        pos = { x = 2, y = 0, z = 0 }, name = "Broken Target",
        unit = true, valid = true, guid = "persistent_failure_target",
    })
    local healthy_target = mock.create_object({
        pos = { x = 2, y = 0, z = 0 }, name = "Healthy NPC",
        unit = true, valid = true, guid = "persistent_failure_healthy",
    })
    mock._objects = { failed_target, healthy_target }
    mock._addon_loaded.zygor = true
    mock._zygor_step = {
        num = 41,
        is_complete = false,
        goals = {
            -- The failing guide goal has no quest_id; the recorder's existing step-level
            -- fallback finds the completed sibling's ID, which is the production shape.
            { type = "area", target = "Broken Target", npc_id = 0 },
            { type = "area", quest_id = 4242, is_complete = true, target = "Broken Target", npc_id = 0 },
            { type = "talk", quest_id = 4243, target = "Healthy NPC", npc_id = 0 },
        },
    }
    mock._zygor_next_wp = nil

    _G.EaxAutoQuester = _G.EaxAutoQuester or {}
    _G.EaxAutoQuester._force_vendor_soon = nil
    local warning_count = 0
    local old_set_warning = _G.EaxAutoQuester.set_warning
    _G.EaxAutoQuester.set_warning = function() warning_count = warning_count + 1 end

    local shared = coordinator._test_shared()
    nav_destination.clear(shared)
    shared._state = "IDLE"
    shared._last_step_num = 40
    shared._action_pause_timer = 0
    shared._area_wait_timer = 0
    shared._post_interact_timer = 0
    shared._at_quest_object_timer = 0
    shared._respawn_wait_until = 0
    shared._respawn_last_scan = 0
    shared._area_fail_count = 0
    shared._area_last_target_guid = nil
    shared._last_goal_type = nil
    shared._last_action_type = nil
    shared._action_loop_count = 0
    shared._visited_waypoints = {}
    shared._sweep_lap_at = 0
    shared._should_enter_interact = nil
    shared._interact_cooldown = 0
    shared._loot_cooldown = 0
    shared._just_arrived = false
    shared._last_target_valid = false
    shared._debug = false
    shared._combat_override_logged = nil

    -- Seed exactly the production record: the area handler emits this after its repeated
    -- attempts, and the policy then acts through the ordinary tick path below.
    blacklist.record_failure(4242, "area_fail")

    local function has_action_input()
        for _, call in ipairs(mock._input_calls) do
            if call[1] == "set_target" or call[1] == "use_object"
                or call[1] == "interact_with_object" then
                return true
            end
        end
        return false
    end

    mock._input_calls = {}
    coordinator.update()
    assert(coordinator._test_inspect() == "DO_ACTION",
        "S11b FAIL: the persistent goal must be skipped during real goal resolution")
    assert(shared._last_goal_type == "talk",
        "S11b FAIL: resolution must select the healthy later goal, got " ..
        tostring(shared._last_goal_type))
    assert(not has_action_input(),
        "S11b FAIL: the failed goal must not act while a healthy goal is available")

    -- The coordinator is now in DO_ACTION with the failed goal still first in the step.
    -- This proves the current-step guard, not just the next IDLE re-evaluation.
    mock._input_calls = {}
    coordinator.update()
    assert(coordinator._test_inspect() == "IDLE",
        "S11c FAIL: the current failed goal must hand control back to IDLE")
    assert(not has_action_input(),
        "S11c FAIL: the current failed goal must not target, use, or interact")

    -- A new step clears progress-tracker state, not the recorded-failure policy. The same
    -- guide list must still avoid the marked quest on the next real tick.
    mock._zygor_step.num = 42
    mock._input_calls = {}
    coordinator.update()
    assert(coordinator._test_inspect() == "DO_ACTION",
        "S11d FAIL: later-step resolution should continue to the healthy goal")
    assert(shared._last_goal_type == "talk",
        "S11d FAIL: later-step resolution selected the persistent goal")
    assert(not has_action_input(),
        "S11d FAIL: later-step resolution must not act on the persistent goal")

    local abandon_call = "abandon_" .. "quest"
    for _, call in ipairs(mock._input_calls) do
        assert(call[1] ~= abandon_call and call[1] ~= "set_" .. abandon_call,
            "S11e FAIL: the failure policy must never delete a quest")
    end
    assert(warning_count == 0,
        "S11f FAIL: the quiet policy must not add user-facing warning messaging")

    _G.EaxAutoQuester.set_warning = old_set_warning
    blacklist.reset()
    progress.clear_all()
    print("  S11b-S11f PASS: real coordinator ticks avoid and skip a persistently failing goal")
end

-- =============================================================================
-- S12 — the dispatcher contract: a handler must never be able to park the machine. A falsy
-- return means "stay this tick", and an unusable current state is repaired instead of being
-- carried into the next tick. Reload the coordinator over a handler that returns false.
-- =============================================================================
do
    package.loaded["quest_state/waiting_state"] = { run = function() return false end }
    package.loaded["quest_state/coordinator"] = nil
    local coord2 = require("quest_state/coordinator")

    local shared = coord2._test_shared()
    shared._state = "WAITING"
    coord2.update()
    local state = coord2._test_inspect()
    assert(state == "WAITING",
        "S12 FAIL: a false return must leave the state alone (got " .. tostring(state) .. ")")

    -- And an already-broken state is repaired at the top of the tick instead of being
    -- carried through it (the transition log itself assumes a state name).
    shared._state = false
    coord2.update()
    state = coord2._test_inspect()
    assert(type(state) == "string",
        "S12 FAIL: an unusable state must be repaired, not preserved (got " .. tostring(state) .. ")")
    print("  S12 PASS: falsy handler return stays; unusable state recovers to IDLE")
end

-- =============================================================================
-- S13 — entering combat while mounted dismounts. A mounted player cannot cast, so
-- the whole rotation is dead until this happens. Both call sites (combat entry and
-- the hard stop) used to be `if nav.dismount then nav.dismount() end`, and the
-- navigation module has no dismount member: the field was always nil, the guard
-- turned a missing member into a silent no-op, and the player rode into every fight.
-- =============================================================================
do
    local function count_input(name)
        local n = 0
        for _, c in ipairs(mock._input_calls) do
            if c[1] == name then n = n + 1 end
        end
        return n
    end

    -- Mounted, in combat with a target: the override runs and must take the player off.
    mock.reset()
    local target = mock.create_object({
        pos = { x = 10, y = 0, z = 0 }, name = "Defias Thug", npc_id = 100,
        unit = true, valid = true, guid = "enemy_mounted",
    })
    mock._objects = { target }
    local player = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true, mounted = true })
    mock._player = player
    player._target = target

    coordinator.update()
    assert(count_input("dismount") == 1,
        "S13 FAIL: combat entry must dismount a mounted player (got " ..
        tostring(count_input("dismount")) .. " calls)")

    -- On foot: no dismount call, so the path is not firing blindly every combat tick.
    mock.reset()
    local target2 = mock.create_object({
        pos = { x = 10, y = 0, z = 0 }, name = "Defias Thug", npc_id = 100,
        unit = true, valid = true, guid = "enemy_onfoot",
    })
    mock._objects = { target2 }
    local player2 = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, combat = true, mounted = false })
    mock._player = player2
    player2._target = target2

    coordinator.update()
    assert(count_input("dismount") == 0,
        "S13 FAIL: an unmounted player must not be dismounted")

    -- The hard stop (plugin disabled) dismounts too, mounted or not on the client's mind.
    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, mounted = true })
    coordinator.stop_navigation()
    assert(count_input("dismount") == 1,
        "S13 FAIL: the hard stop must dismount a mounted player")
    print("  S13 PASS: combat entry and the hard stop both dismount")
end

print("PASS test_coordinator")
os.exit(0)
