-- What: Unit tests for EaxAutoQuester/quest_state/nav_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NAV state transitions: IDLE (combat/arrived/failed/stuck), NAV

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local nav_state = require("quest_state/nav_state")

-- Mount inputs, installed before the first tick that can reach the mount gate. The handler
-- requires mount_manager_sylvanas lazily and that module caches its input calls at load
-- (Pattern 2), so a stub installed inside the mount scenarios below would never be reached —
-- the very first navigation tick would have already cached the mock's table entries.
local _mount_casts, _dismount_calls = 0, 0
core.input.mount = function() _mount_casts = _mount_casts + 1 end
core.input.dismount = function() _dismount_calls = _dismount_calls + 1 end
local mount_manager = require("mount_manager_sylvanas")

-- Test run with combat
local combat_player = mock.create_player({ pos = {x=0, y=0, z=0}, combat = true })
local mock_nav = { get_state = function() return "NAVIGATING" end, stop = function() end, update = function() end }
local shared = { _nav_retry_timer = 0 }
local ctx = { me = combat_player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav combat → IDLE")

-- Test run arrived
local player = mock.create_player({ pos = {x=0, y=0, z=0} })
mock_nav = { get_state = function() return "ARRIVED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav arrived → IDLE")
assert(shared._nav_destination == nil, "nav arrived clears destination")

-- Test run failed
mock_nav = { get_state = function() return "FAILED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "NAV", "nav failed retry → NAV")

-- Test run stuck
mock_nav = { get_state = function() return "STUCK" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "NAV", "nav stuck retry → NAV")

-- Test run max retries
mock_nav = { get_state = function() return "FAILED" end, stop = function() end, update = function() end }
shared = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = {x=1,y=1,z=1} }
ctx = { me = player, nav = mock_nav, now = 0, debug_log = function() end, safe = function(v, fallback) return v or fallback end, log = function() end }
assert(nav_state.run(shared, ctx) == "IDLE", "nav max retries → IDLE")

-- =============================================================================
-- Phase 1 ports — stuck escalation, arrival settle, en-route pre-tag, random
-- jump (docs/phase1_port_list.md items 4-7). Ported out of the deleted monolith
-- into this handler, so the contract lives here now.
-- =============================================================================

local utils = require("utils_sylvanas")

-- Counters for the movement inputs the mock does not record.
local _jump_calls, _turn_calls = 0, 0
core.input.jump = function() _jump_calls = _jump_calls + 1 end
core.input.turn_left_start = function() _turn_calls = _turn_calls + 1 end
core.input.turn_left_stop = function() end
core.input.turn_right_start = function() _turn_calls = _turn_calls + 1 end
core.input.turn_right_stop = function() end

local function nav_ctx(extra)
    local c = {
        me = mock.create_player({ pos = { x = 0, y = 0, z = 0 } }),
        nav = { get_state = function() return "NAVIGATING" end, stop = function() end,
            update = function() end },
        now = 0,
        debug_log = function() end,
        safe = function(v, fallback) if v == nil then return fallback end return v end,
        log = function() end,
        utils = utils,
    }
    if extra then for k, v in pairs(extra) do c[k] = v end end
    return c
end

-- N7 — anti-cheat random jump while navigating (runs first: the real throttle
-- key "random_jump_nav" is consumed by the first call in the process)
do
    _jump_calls = 0
    local c = nav_ctx()
    local s = { _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }
    nav_state.run(s, c)
    assert(_jump_calls == 1,
        "N7 FAIL: navigation should issue one anti-cheat jump (got " .. tostring(_jump_calls) .. ")")
    assert(mock._input_calls ~= nil, "N7 FAIL: no targeting should happen without a goal")
    print("  N7 PASS: navigating out of combat → random jump issued")
end

-- N6 — en-route pre-tag: while walking, a hostile goal NPC keeps its existing
-- combat scan behavior (tag + interact at the 50yd scan radius).
do
    mock.reset()
    local npc_obj = mock.create_object({ pos = { x = 20, y = 0, z = 0 }, name = "Elder Tiger",
        unit = true, valid = true, attackable = true, enemy = true, guid = "npc_pretag" })
    local seen_ids = nil
    local c = nav_ctx({
        -- Deterministic throttle: the intervals themselves are not under test here.
        utils = { squared_distance = utils.squared_distance,
            throttle = function() return true end },
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function()
                return { goals = {
                    { is_complete = true, npc_id = 111 },            -- already done → skipped
                    { is_complete = false, npc_id = 0, target_id = 222 },  -- npc_id 0 → target_id
                } }
            end,
        },
        npc_manager = {
            find_nearest_npc = function(ids)
                seen_ids = ids
                return npc_obj
            end,
        },
        object_scanner = { get_visible_objects = function() return { npc_obj } end },
    })
    local s = { _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }
    nav_state.run(s, c)
    assert(seen_ids ~= nil and seen_ids[1] == 222,
        "N6 FAIL: pre-tag should resolve the incomplete goal's target_id (got " ..
        tostring(seen_ids and seen_ids[1]) .. ")")
    local tagged, interacted = false, false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == npc_obj then tagged = true end
        if call[1] == "interact_with_object" and call[2] == npc_obj then interacted = true end
    end
    assert(tagged, "N6 FAIL: en-route pre-tag should set_target on the quest NPC")
    assert(interacted, "N6 FAIL: en-route pre-tag should interact_with_object on the quest NPC")
    print("  N6 PASS: hostile en-route pre-tag — tagged/interacted at the 50yd scan (target_id fallback)")
end

-- N6a/N6b — a friendly NPC is selected by the same 50yd search, but the real
-- interact call is only dispatched inside the fixed 5yd gate. These are NAV
-- ticks, not helper-level distance tests.
do
    local function friendly_pretag_at(distance)
        mock.reset()
        local npc_obj = mock.create_object({
            pos = { x = distance, y = 0, z = 0 }, name = "Marshal Dughan",
            unit = true, valid = true, attackable = false, guid = "friendly_pretag_" .. tostring(distance),
        })
        local c = nav_ctx({
            utils = { squared_distance = utils.squared_distance,
                throttle = function() return true end },
            zygor = {
                has_current_step = function() return true end,
                get_current_step_info = function()
                    return { goals = { { is_complete = false, npc_id = 222 } } }
                end,
            },
            npc_manager = {
                find_nearest_npc = function() return npc_obj end,
            },
            object_scanner = { get_visible_objects = function() return { npc_obj } end },
        })
        local s = { _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }
        local next_state = nav_state.run(s, c)
        local tagged, interacted = false, false
        for _, call in ipairs(mock._input_calls) do
            if call[1] == "set_target" and call[2] == npc_obj then tagged = true end
            if call[1] == "interact_with_object" and call[2] == npc_obj then interacted = true end
        end
        return next_state, tagged, interacted
    end

    local near_state, near_tagged, near_interacted = friendly_pretag_at(4)
    assert(near_state == "NAV" and near_tagged and near_interacted,
        "N6a FAIL: a friendly NPC inside 5yd must keep the real en-route interaction")

    local inside_state, inside_tagged, inside_interacted = friendly_pretag_at(4.1)
    assert(inside_state == "NAV" and inside_tagged and inside_interacted,
        "N6b FAIL: a friendly NPC at 4.1yd is still inside the 5yd interaction gate")

    local outside_state, outside_tagged, outside_interacted = friendly_pretag_at(5.1)
    assert(outside_state == "NAV" and outside_tagged and not outside_interacted,
        "N6c FAIL: a friendly NPC at 5.1yd must not receive a remote interaction")
    print("  N6a-N6c PASS: friendly en-route interaction is limited to 5yd; targeting remains")
end

-- N4a/N4b — STUCK escalation: first retry jumps, second also taps a random turn
do
    local function stuck_ctx()
        return nav_ctx({ nav = { get_state = function() return "STUCK" end,
            stop = function() end, update = function() end } })
    end

    _jump_calls, _turn_calls = 0, 0
    local s1 = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = { x = 1, y = 1, z = 1 } }
    assert(nav_state.run(s1, stuck_ctx()) == "NAV", "N4a: stuck retry stays in NAV")
    assert(s1._nav_retries == 1, "N4a FAIL: retry counter should reach 1")
    assert(_jump_calls == 1, "N4a FAIL: first stuck retry should jump")
    assert(_turn_calls == 0, "N4a FAIL: first stuck retry should not turn")
    assert(s1._nav_retry_timer == 2.0, "N4a FAIL: stuck retry should keep the 2s backoff")

    _jump_calls, _turn_calls = 0, 0
    local s2 = { _nav_retry_timer = 0, _nav_retries = 1, _nav_destination = { x = 1, y = 1, z = 1 } }
    assert(nav_state.run(s2, stuck_ctx()) == "NAV", "N4b: stuck retry stays in NAV")
    assert(s2._nav_retries == 2, "N4b FAIL: retry counter should reach 2")
    assert(_jump_calls == 1, "N4b FAIL: second stuck retry should jump")
    -- The turn tap retry 2 used to add is gone: start+stop in one tick turns for zero frames, so
    -- it never unwedged anything, and it left an arrow key one forgotten stop away from being held
    -- down (combat_helper did exactly that, and the player spun). The quester drives no turn keys.
    assert(_turn_calls == 0,
        "N4b FAIL: the quester must never drive the turn keys (got " .. tostring(_turn_calls) .. ")")
    print("  N4 PASS: stuck escalation — jump only, no turn keys")
end

-- N5 — arrival settles for 1.5s before IDLE re-evaluates
do
    local c = nav_ctx({ nav = { get_state = function() return "ARRIVED" end,
        stop = function() end, update = function() end } })
    local s = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = { x = 1, y = 1, z = 1 } }
    assert(nav_state.run(s, c) == "IDLE", "N5: arrival returns to IDLE")
    assert(s._action_pause_timer == 1.5,
        "N5 FAIL: arrival should hold IDLE for 1.5s so the NPC can render (got " ..
        tostring(s._action_pause_timer) .. ")")
    assert(s._just_arrived == true, "N5 FAIL: arrival should set _just_arrived")
    print("  N5 PASS: arrival settle pause set for IDLE")
end

-- =============================================================================
-- N8 — a live unit's destination is followed, and the client is RE-ISSUED the
-- refreshed point. The client walks to the coordinates it was handed, not to the
-- table our handler keeps: refreshing only the table leaves the walk ending where
-- the mob stood (live: the priest kept walking while the mob moved — a 31yd
-- approach took six minutes, the client reported "Stuck detected" against a point
-- the mob had long left, and the bot ended up in melee range of a ranged fight).
-- =============================================================================
-- The handler calls every nav method with a dot (nav.get_state()), so these are closures over the
-- table rather than `function n:method()` — a colon definition would receive a nil self.
local function make_nav(state)
    local n = { calls = {}, stops = 0, state = state }
    n.get_state = function() return n.state end
    n.navigate_to = function(dest)
        n.calls[#n.calls + 1] = { x = dest.x, y = dest.y, z = dest.z }
    end
    n.stop = function() n.stops = n.stops + 1 end
    n.update = function() end
    return n
end

do
    mock.reset()
    local mob = mock.create_object({ pos = { x = 100, y = 100, z = 0 }, name = "Stonelurk",
        unit = true, enemy = true, attackable = true, guid = "follow_mob" })
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("IDLE")
    local c = nav_ctx({ me = watcher, nav = nav })
    local dest = mob:get_position()
    local s = {
        _nav_retry_timer = 0,
        _nav_destination = dest,
        _nav_unit_dest = mob,
        _nav_unit_dest_key = dest,
    }

    -- 1. The client is idle, so this tick starts the walk and records what it was told.
    assert(nav_state.run(s, c) == "NAV", "N8: following stays in NAV")
    assert(#nav.calls == 1, "N8 FAIL: starting the walk should issue it exactly once (got " .. #nav.calls .. ")")
    assert(s._nav_issued_x == 100 and s._nav_issued_y == 100,
        "N8 FAIL: the coordinates handed to the client must be recorded (got " ..
        tostring(s._nav_issued_x) .. "," .. tostring(s._nav_issued_y) .. ")")

    -- 2. The mob walks 5yd while the client follows the path it was given.
    nav.state = "NAVIGATING"
    mob._pos.x = 105
    assert(nav_state.run(s, c) == "NAV", "N8: following stays in NAV")
    assert(s._nav_destination.x == 105,
        "N8 FAIL: the destination must track the unit's live position (got " ..
        tostring(s._nav_destination.x) .. ")")
    assert(#nav.calls == 2,
        "N8 FAIL: the moved target must be handed to the client again (got " .. #nav.calls .. " calls)")
    assert(nav.calls[2].x == 105, "N8 FAIL: the re-issued point must be the unit's new position")
    assert(s._nav_issued_x == 105, "N8 FAIL: issued coordinates must be updated by the re-issue")

    -- 3. Standing still: no re-issue, so a nudging target cannot restart the path each tick.
    assert(nav_state.run(s, c) == "NAV", "N8: following stays in NAV")
    assert(#nav.calls == 2, "N8 FAIL: an unmoved target must not be re-issued (got " .. #nav.calls .. " calls)")

    -- 4. Moved again, but inside the cooldown: the destination still tracks it, the client is not
    --    re-issued yet, and the next allowed tick does re-issue.
    mob._pos.x = 110
    assert(nav_state.run(s, c) == "NAV", "N8: following stays in NAV")
    assert(s._nav_destination.x == 110, "N8 FAIL: tracking must not depend on the re-issue cooldown")
    assert(#nav.calls == 2, "N8 FAIL: the re-issue cooldown should hold the path steady (got " .. #nav.calls .. " calls)")
    c.now = 0.6
    assert(nav_state.run(s, c) == "NAV", "N8: following stays in NAV")
    assert(#nav.calls == 3, "N8 FAIL: after the cooldown the moved target must be re-issued (got " .. #nav.calls .. " calls)")
    print("  N8 PASS: live-unit destination followed and re-issued to the client")
end

-- =============================================================================
-- N9 — the followed unit dies or despawns: there is nothing left to walk to, and
-- NAV must say so instead of retrying the ladder against a corpse forever.
-- =============================================================================
do
    mock.reset()
    local mob = mock.create_object({ pos = { x = 100, y = 100, z = 0 }, name = "Stonelurk",
        unit = true, enemy = true, attackable = true, guid = "dying_mob" })
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("NAVIGATING")
    local c = nav_ctx({ me = watcher, nav = nav })
    local dest = mob:get_position()
    local s = {
        _nav_retry_timer = 0,
        _nav_retries = 2,
        _nav_destination = dest,
        _nav_engage_dest = dest,
        _nav_engage_sq = 784,
        _nav_unit_dest = mob,
        _nav_unit_dest_key = dest,
    }

    mob._dead = true
    assert(nav_state.run(s, c) == "IDLE", "N9 FAIL: a dead destination unit must end the walk")
    assert(nav.stops == 1, "N9 FAIL: the client must be told to stop (got " .. tostring(nav.stops) .. ")")
    assert(s._nav_destination == nil and s._nav_unit_dest == nil and s._nav_unit_dest_key == nil,
        "N9 FAIL: a gone unit must clear the destination and its link")
    assert(s._nav_retries == 0, "N9 FAIL: retry state must not survive a destination that is gone")
    assert(#nav.calls == 0, "N9 FAIL: nothing should be issued for a dead destination unit")
    print("  N9 PASS: destination unit gone → walk ends, no issue")
end

-- =============================================================================
-- N10 — a destination the client cannot reach is left alone for a bounded time.
-- Live: 40 minutes of "nav failed (max_stuck_exceeded) — asking the client to
-- replan" at the same coordinates, with "Stuck detected" on it in between.
-- =============================================================================
do
    mock.reset()
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("FAILED")
    local c = nav_ctx({ me = watcher, nav = nav })
    local unreachable = { x = -7043.1, y = -3314.2, z = 238.1 }

    -- First encounter: the full ladder runs (3rd failure gives up) and the point is remembered.
    local s = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = unreachable }
    assert(nav_state.run(s, c) == "IDLE", "N10: a 3rd failure gives up")
    assert(s._nav_unreachable ~= nil, "N10 FAIL: the unreachable point must be remembered")
    assert(s._nav_unreachable.expires == 60.0,
        "N10 FAIL: the memory must expire (got " .. tostring(s._nav_unreachable.expires) .. ")")

    -- The same point handed back inside the window: skipped, not retried.
    local s2 = {
        _nav_retry_timer = 0, _nav_retries = 0,
        _nav_destination = { x = -7043.1, y = -3314.2, z = 238.1 },
        _nav_unreachable = s._nav_unreachable,
    }
    assert(nav_state.run(s2, c) == "IDLE", "N10 FAIL: a recently unreachable point must be skipped")
    assert(s2._nav_destination == nil, "N10 FAIL: the skipped point must be dropped")
    assert(s2._nav_retries == 0, "N10 FAIL: skipping must not consume retries")
    assert(#nav.calls == 0, "N10 FAIL: nothing should be issued for a skipped point")

    -- A different destination is still attempted.
    local s3 = {
        _nav_retry_timer = 0, _nav_retries = 0,
        _nav_destination = { x = 100, y = 100, z = 0 },
        _nav_unreachable = s._nav_unreachable,
    }
    assert(nav_state.run(s3, c) == "NAV", "N10 FAIL: a different destination must still be attempted")

    -- Expired: the original point is attempted again.
    local s4 = {
        _nav_retry_timer = 0, _nav_retries = 0,
        _nav_destination = { x = -7043.1, y = -3314.2, z = 238.1 },
        _nav_unreachable = s._nav_unreachable,
    }
    c.now = 61.0
    assert(nav_state.run(s4, c) == "NAV", "N10 FAIL: the memory must expire, not latch")
    print("  N10 PASS: unreachable destination skipped for 60s, then retried")
end

-- =============================================================================
-- N11 — the stand-off survives the Z-adjust retry. That retry REPLACES the
-- destination table, and the stand-off is bound to the table, so without the
-- relink the client walks onto the mob it was supposed to stop 28yd short of.
-- =============================================================================
do
    mock.reset()
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("IDLE")
    local c = nav_ctx({ me = watcher, nav = nav })

    -- Destination whose Z is 100yd below the player: the retry that adjusts Z runs on the 2nd+
    -- failure, which is what replaces the table.
    local dest = { x = 0, y = 100, z = -100 }
    local s = {
        _nav_retry_timer = 5.0, _nav_retries = 2,
        _nav_destination = dest,
        _nav_engage_dest = dest,
        _nav_engage_sq = 784,
    }
    c.now = 6.0
    assert(nav_state.run(s, c) == "NAV", "N11: the retry stays in NAV")
    assert(s._nav_destination.z == 0,
        "N11 FAIL: the Z-adjust should have replaced the destination (z=" .. tostring(s._nav_destination.z) .. ")")
    assert(s._nav_engage_dest == s._nav_destination,
        "N11 FAIL: the stand-off must follow the replaced destination table")

    -- The client now reports arrival while the player is inside the stand-off but far outside the
    -- default 3yd arrival radius: the stand-off decides, so this is an arrival.
    nav.state = "ARRIVED"
    watcher._pos = { x = 0, y = 75, z = 0 }
    assert(nav_state.run(s, c) == "IDLE",
        "N11 FAIL: inside the stand-off the walk is over (destination not honoured → retry)")
    assert(nav.stops >= 1, "N11 FAIL: arriving at the stand-off must stop the client")
    print("  N11 PASS: stand-off survives the Z-adjust table replacement")
end

-- =============================================================================
-- N12 — the mount gate: a mount is a CAST and movement cancels it, so it is cast
-- BEFORE the walk is issued and the walk is held for it. Attempting it on a tick
-- where the client is already walking the player could never complete (live: "I
-- would like it to auto mount" — the bag scan ran, the cast was issued, and the
-- player still travelled on foot).
-- =============================================================================
do
    mock.reset()
    mount_manager.reset()
    core.spell_book.get_mount_count = function() return 1 end
    core.spell_book.get_mount_info = function(idx)
        if idx == 1 then return { is_usable = true, mount_name = "Horse" } end
        return nil
    end

    local rider = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })  -- on foot
    local nav = make_nav("IDLE")
    local c = nav_ctx({ me = rider, nav = nav })
    c.now = 100.0
    local s = { _nav_retry_timer = 0, _nav_destination = { x = 0, y = 200, z = 0 } }

    _mount_casts = 0
    assert(nav_state.run(s, c) == "NAV", "N12: mounting keeps the bot in NAV")
    assert(_mount_casts == 1,
        "N12a FAIL: the mount must be cast before the walk (got " .. tostring(_mount_casts) .. ")")
    assert(#nav.calls == 0,
        "N12b FAIL: the walk must be held while the cast is in flight (got " ..
        tostring(#nav.calls) .. " walk(s) issued)")

    -- The cast lands: the hold is released and the walk starts.
    rider._mounted = true
    assert(nav_state.run(s, c) == "NAV", "N12: still NAV once mounted")
    assert(#nav.calls == 1, "N12c FAIL: the walk starts once the player is mounted")
    assert(_mount_casts == 1, "N12d FAIL: no second cast once mounted")
    print("  N12 PASS: mount cast precedes the walk, which is held for it")
end

-- =============================================================================
-- N15 — the walk-issued-anyway case names its cause in the log. "It didn't mount for a
-- 300yd run" has no diagnosis on its own, so the gate's refusal reason is published on the
-- tick that issues the walk, and withheld when the player is riding.
-- =============================================================================
do
    mock.reset()
    mount_manager.reset()
    core.spell_book.get_mount_count = function() return 1 end
    core.spell_book.get_mount_info = function(idx)
        if idx == 1 then return { is_usable = true, mount_name = "Horse" } end
        return nil
    end

    local logged = {}
    local walker = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("IDLE")
    local c = nav_ctx({ me = walker, nav = nav,
        debug_log = function(msg) logged[#logged + 1] = tostring(msg) end })
    c.now = 200.0
    -- 20yd: under the mount floor, so the gate says why and the walk goes out on foot.
    local s = { _nav_retry_timer = 0, _nav_destination = { x = 0, y = 20, z = 0 } }

    nav_state.run(s, c)
    assert(nav.calls[#nav.calls] ~= nil, "N15a FAIL: a short walk must still be issued")
    local found = nil
    for i = 1, #logged do
        if logged[i]:find("travelling on foot", 1, true) then found = logged[i] end
    end
    assert(found ~= nil, "N15b FAIL: the on-foot walk must say why")
    assert(found:find("too close", 1, true) ~= nil,
        "N15c FAIL: the reason must be the gate's own, got: " .. tostring(found))

    -- Control: mounted means no "on foot" line at all, so the log cannot cry wolf while riding.
    mount_manager.reset()
    local rider2 = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    rider2._mounted = true
    local nav2 = make_nav("IDLE")
    local logged2 = {}
    local c2 = nav_ctx({ me = rider2, nav = nav2,
        debug_log = function(msg) logged2[#logged2 + 1] = tostring(msg) end })
    c2.now = 300.0
    nav_state.run({ _nav_retry_timer = 0, _nav_destination = { x = 0, y = 20, z = 0 } }, c2)
    for i = 1, #logged2 do
        assert(not logged2[i]:find("travelling on foot", 1, true),
            "N15d FAIL: a mounted player must not be reported as walking on foot: " .. logged2[i])
    end
    print("  N15 PASS: an on-foot walk names the gate's reason; a mounted one logs none")
end

-- =============================================================================
-- N13 — the end of a mounted walk leaves the player OFF the mount. A mounted
-- player cannot cast, so every walk that ends with a fight or an interaction has
-- to dismount. Two ends, two sites: the stand-off stop (ranged engagement, 28yd —
-- far outside the 15yd travelling-tick dismount, so only this path can do it) and
-- a plain arrival (the travelling-tick dismount normally gets there first; the
-- arrival site is the backstop).
-- =============================================================================
do
    mock.reset()
    mount_manager.reset()
    core.spell_book.get_mount_count = function() return 0 end
    core.spell_book.get_mount_info = function() return nil end

    -- (a) stand-off: mounted, 25yd from an engagement destination (inside the 28yd stand-off, so
    -- this path and not the 15yd travelling-tick dismount has to do it).
    local rider = mock.create_player({ pos = { x = 0, y = 5, z = 0 } })
    rider._mounted = true
    local nav = make_nav("NAVIGATING")
    local c = nav_ctx({ me = rider, nav = nav })
    c.now = 50.0
    local dest = { x = 0, y = 30, z = 0 }
    local s = {
        _nav_retry_timer = 0, _nav_retries = 0,
        _nav_destination = dest, _nav_engage_dest = dest, _nav_engage_sq = 784,  -- 28yd
    }
    _dismount_calls = 0
    assert(nav_state.run(s, c) == "IDLE", "N13a: inside the stand-off the walk ends")
    assert(_dismount_calls == 1,
        "N13a FAIL: the stand-off stop must dismount for the fight (got " ..
        tostring(_dismount_calls) .. ")")

    -- (b) plain arrival on the destination.
    mount_manager.reset()
    local rider2 = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    rider2._mounted = true
    local nav2 = make_nav("ARRIVED")
    local c2 = nav_ctx({ me = rider2, nav = nav2 })
    c2.now = 60.0
    local s2 = { _nav_retry_timer = 0, _nav_retries = 0, _nav_destination = { x = 0, y = 0, z = 0 } }
    _dismount_calls = 0
    assert(nav_state.run(s2, c2) == "IDLE", "N13b: arrival returns to IDLE")
    assert(_dismount_calls >= 1, "N13b FAIL: arriving mounted must leave the player on foot")

    -- (c) travelling far does NOT dismount — the mount is the point of the walk.
    mount_manager.reset()
    local rider3 = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    rider3._mounted = true
    local nav3 = make_nav("NAVIGATING")
    local c3 = nav_ctx({ me = rider3, nav = nav3 })
    c3.now = 70.0
    local dest3 = { x = 0, y = 200, z = 0 }
    local s3 = { _nav_retry_timer = 0, _nav_destination = dest3 }
    _dismount_calls = 0
    nav_state.run(s3, c3)
    assert(_dismount_calls == 0, "N13c FAIL: a long walk must not dismount")
    print("  N13 PASS: the stand-off stop and the arrival both leave the player on foot")
end

-- =============================================================================
-- N14 — the pull gate's retreat outranks a destination written after it
-- =============================================================================
-- The destination fields had four writers, so a retreat the gate armed could be silently replaced
-- in the same tick by whoever wrote last — and the walk would go back into the group the bot had
-- just backed away from. The gate now publishes the point it wants (it writes no navigation field:
-- test_pull_safety R1) and this handler asserts that claim at the top of its tick, which is the
-- moment the destination is actually consumed.

do
    local pull_safety = require("shared/pull_safety")

    pull_safety.reset()
    local buzzard = mock.create_object({
        pos = { x = 40, y = 0, z = 0 }, name = "Buzzard",
        unit = true, valid = true, attackable = true, enemy = true, guid = "buzzard_nav",
    })
    mock._objects = { buzzard }
    local mob_dest = { x = 40, y = 0, z = 0 }

    local caster = mock.create_player({ pos = { x = 0, y = 0, z = 0 }, mana = 0, max_mana = 100 })
    local c = nav_ctx({
        me = caster,
        nav = { get_state = function() return "NAVIGATING" end, stop = function() end,
            update = function() end, navigate_to = function() end },
    })
    c.now = 5000.0

    local s = { _nav_retry_timer = 0, _nav_destination = mob_dest }
    assert(pull_safety.gate(c, s, buzzard) == true,
        "N14a FAIL: an empty mana bar must refuse this pull")
    local retreat = pull_safety.destination(c)
    assert(retreat, "N14b FAIL: the gate must publish the retreat it wants")
    assert(s._nav_destination == mob_dest,
        "N14c FAIL: the gate must not have written the destination itself (found " ..
        tostring(s._nav_destination and s._nav_destination.x) .. ")")

    -- A destination writer runs AFTER the retreat, in the same tick, and it is the shape this
    -- handler follows and re-issues: a live unit to close on, with a stand-off.
    s._nav_destination = mob_dest
    s._nav_unit_dest = buzzard
    s._nav_unit_dest_key = mob_dest
    s._nav_engage_dest = mob_dest
    s._nav_engage_sq = 784

    local next_state = nav_state.run(s, c)
    assert(next_state == "NAV" or next_state == "IDLE",
        "N14d FAIL: run must always return a state name (got " .. tostring(next_state) .. ")")
    assert(s._nav_destination == retreat,
        "N14e FAIL: the retreat must win over a destination written after it (got x=" ..
        tostring(s._nav_destination and s._nav_destination.x) .. ", expected x=" ..
        tostring(retreat.x) .. ")")
    assert(s._nav_unit_dest == nil,
        "N14f FAIL: the live-unit link must be dropped — while it stands, the follow block re-issues " ..
        "walks toward the mob the retreat is leaving")
    assert(s._nav_engage_dest == nil and s._nav_engage_sq == nil,
        "N14g FAIL: the stand-off must go too, or the walk stops early at the mob")

    -- Control: with no hold the later write stands, so the claim is demonstrably what beat it.
    pull_safety.reset()
    local s2 = { _nav_retry_timer = 0, _nav_destination = mob_dest,
        _nav_unit_dest = buzzard, _nav_unit_dest_key = mob_dest }
    local c2 = nav_ctx({
        me = caster,
        nav = { get_state = function() return "NAVIGATING" end, stop = function() end,
            update = function() end, navigate_to = function() end },
    })
    c2.now = 5100.0
    nav_state.run(s2, c2)
    assert(s2._nav_destination == mob_dest,
        "N14h FAIL: without a hold the ordinary unit destination must stand untouched")
    print("  N14 PASS: nav_state applies the gate's retreat over a later write, and leaves it alone " ..
        "without a hold")
end

-- =============================================================================
-- N16 — the en-route pre-tag does not START a fight the gate would refuse, and still tags a
-- quest GIVER. Live: "it still tries to engage mobs on low health/mana" — this scan runs every
-- 1.5s while walking and tags the goal's mob at 50yd, which is a fight begun mid-walk with the
-- rotation already able to cast on the target before the bot has arrived.
-- =============================================================================
local function pretag_scene(mob_opts, player_opts)
    mock.reset()
    local mob = mock.create_object(mob_opts)
    local player = mock.create_player(player_opts or { pos = { x = 0, y = 0, z = 0 } })
    local c = nav_ctx({
        me = player,
        -- Deterministic throttle: the interval is not what is under test.
        utils = { squared_distance = utils.squared_distance,
            throttle = function() return true end },
        zygor = {
            has_current_step = function() return true end,
            get_current_step_info = function()
                return { goals = { { is_complete = false, npc_id = 222 } } }
            end,
        },
        npc_manager = {
            find_nearest_npc = function() return mob end,
        },
        object_scanner = { get_visible_objects = function() return { mob } end },
    })
    c.now = 400.0
    return c, mob
end

do
    -- A HOSTILE goal mob at 20yd, 5% mana: the pre-tag must not touch it.
    local c, mob = pretag_scene({ pos = { x = 20, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, enemy = true, attackable = true, guid = "pretag_mob" },
        { pos = { x = 0, y = 0, z = 0 }, mana = 5, max_mana = 100 })
    local s = { _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }
    nav_state.run(s, c)
    for _, call in ipairs(mock._input_calls) do
        assert(not (call[1] == "set_target" and call[2] == mob),
            "N16a FAIL: the en-route scan tagged a hostile on 5% mana — tagging it IS the pull")
        assert(not (call[1] == "interact_with_object" and call[2] == mob),
            "N16b FAIL: the en-route scan interacted with a hostile on 5% mana")
    end

    -- Control A: same scene, mana restored → tagged. Without this, a scan that never fires for any
    -- reason would pass.
    local c2, mob2 = pretag_scene({ pos = { x = 20, y = 0, z = 0 }, name = "Stonevault Shaman",
        unit = true, valid = true, enemy = true, attackable = true, guid = "pretag_mob2" },
        { pos = { x = 0, y = 0, z = 0 }, mana = 100, max_mana = 100 })
    mock._input_calls = {}
    nav_state.run({ _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }, c2)
    local tagged = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == mob2 then tagged = true end
    end
    assert(tagged, "N16c FAIL: with mana back the same pre-tag must tag the mob")

    -- Control B: a quest GIVER (not attackable) on the same empty bar is still tagged — the gate
    -- only ever refuses fights, and blocking a giver would be the worse bug.
    local c3, giver = pretag_scene({ pos = { x = 20, y = 0, z = 0 }, name = "Marshal Dughan",
        unit = true, valid = true, attackable = false, guid = "pretag_giver" },
        { pos = { x = 0, y = 0, z = 0 }, mana = 5, max_mana = 100 })
    mock._input_calls = {}
    nav_state.run({ _nav_retry_timer = 0, _nav_destination = { x = 500, y = 0, z = 0 } }, c3)
    local tagged_giver = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "set_target" and call[2] == giver then tagged_giver = true end
    end
    local interacted_giver = false
    for _, call in ipairs(mock._input_calls) do
        if call[1] == "interact_with_object" and call[2] == giver then interacted_giver = true end
    end
    assert(tagged_giver and not interacted_giver,
        "N16d FAIL: a friendly giver should be tagged but not interacted with at 20yd")
    print("  N16 PASS: en-route pre-tag skips a hostile it would refuse, keeps givers un-interacted at range")
end

-- =============================================================================
-- N17 — the retry counter belongs to the destination it counted, not to the handler.
-- Live: after one walk was given up on, every later walk through the same shared table
-- carried the old count forward — "retry 4/3", "retry 5/3", ... climbing forever, and
-- each fresh destination was abandoned on its FIRST "arrived" callback whatever it was.
-- =============================================================================
do
    mock.reset()
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("ARRIVED")
    local c = nav_ctx({ me = watcher, nav = nav })

    -- A walk that ends "arrived" 13yd short three times gives up (N10 covers that ladder).
    local s = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = { x = 13, y = 0, z = 5 } }
    assert(nav_state.run(s, c) == "IDLE", "N17a FAIL: a 3rd short arrival must give up")
    assert(s._nav_destination == nil, "N17a FAIL: the given-up destination must be dropped")
    assert(s._nav_retries == 0,
        "N17b FAIL: the retry count must not survive the destination it counted (got " ..
        tostring(s._nav_retries) .. ")")

    -- The next walk through the same shared table starts from zero, so its own short arrival
    -- retries instead of being abandoned: this is the assertion the stale counter breaks.
    s._nav_destination = { x = 40, y = 0, z = 5 }
    assert(nav_state.run(s, c) == "NAV",
        "N17c FAIL: a fresh destination must get its own retries, not the last one's")
    assert(s._nav_retries == 1,
        "N17c FAIL: the first short arrival of a fresh destination is retry 1 (got " ..
        tostring(s._nav_retries) .. ")")
    assert(#nav.calls == 1, "N17c FAIL: the retry must be issued to the client")
    print("  N17 PASS: the retry counter belongs to its destination, not to the handler")
end

-- =============================================================================
-- N18 — the unreachable memory is keyed on the PLACE, not on how the destination was
-- classified. A destination that failed while nav_state was walking its waypoint
-- fallback was remembered under a name the producer could not reproduce, so the
-- producer handed the same coordinates straight back and the bot re-walked them.
-- =============================================================================
do
    mock.reset()
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local nav = make_nav("FAILED")
    local c = nav_ctx({ me = watcher, nav = nav })
    local place = { x = 700, y = -300, z = 40 }

    -- Both fallbacks already spent (the waypoint flag is what the old key's kind came from), so
    -- the 3rd failure is terminal and the place is remembered.
    local s = {
        _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = place,
        _nav_wp_fallback = true, _nav_mesh_fallback = true,
    }
    assert(nav_state.run(s, c) == "IDLE", "N18a FAIL: exhausted fallbacks must give up")
    assert(s._nav_unreachable ~= nil, "N18a FAIL: the unreachable place must be remembered")

    -- The producer offers the same place as an ordinary point: no fallback flag, and a Z from a
    -- freshly built waypoint table. Same place, so still skipped — nothing new is walked.
    nav.calls, nav.stops = {}, 0
    local s2 = {
        _nav_retry_timer = 0, _nav_retries = 0,
        _nav_destination = { x = place.x, y = place.y, z = place.z + 1 },
        _nav_unreachable = s._nav_unreachable,
    }
    assert(nav_state.run(s2, c) == "IDLE",
        "N18b FAIL: the same place must be skipped however it was classified")
    assert(#nav.calls == 0, "N18b FAIL: nothing may be issued for a skipped place")
    assert(s2._nav_destination == nil, "N18b FAIL: the skipped place must be dropped")

    -- Control: a different place on the same map is still walked, so the skip is about the
    -- coordinates and not about the memory existing at all.
    s2._nav_destination = { x = place.x + 1, y = place.y, z = place.z + 1 }
    assert(nav_state.run(s2, c) == "NAV", "N18c FAIL: a different place must still be attempted")
    -- Accepted, not skipped: the skip is the branch that stops the client, and it does not schedule
    -- a retry. Both observables separate the two branches without depending on the client's own
    -- walk being issued (the retry path only schedules; the next tick issues).
    assert(s2._nav_retry_timer == 0.1,
        "N18c FAIL: an accepted destination must schedule its retry (got " ..
        tostring(s2._nav_retry_timer) .. ")")
    assert(nav.stops == 1,
        "N18c FAIL: only the skipped place may have stopped the client (got " ..
        tostring(nav.stops) .. " stops)")
    print("  N18 PASS: unreachable places are remembered by place, not by classification")
end

-- =============================================================================
-- N19 — the direct-movement escalation is reachable. The handler's guard asks the
-- navigation module for `move_direct`, so the branch lives or dies on the module
-- answering it; when it does, the walk must be handed over instead of given up on.
-- =============================================================================
do
    mock.reset()
    local watcher = mock.create_player({ pos = { x = 0, y = 0, z = 0 } })
    local place = { x = 900, y = -200, z = 30 }

    -- Waypoint fallback already spent and the member present: the rescue takes the destination.
    local nav = make_nav("FAILED")
    nav.direct = {}
    nav.move_direct = function(dest)
        nav.direct[#nav.direct + 1] = { x = dest.x, y = dest.y, z = dest.z }
    end
    local s = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = place,
        _nav_wp_fallback = true }
    assert(nav_state.run(s, nav_ctx({ me = watcher, nav = nav })) == "NAV",
        "N19a FAIL: the direct-movement escalation must hand the walk over")
    assert(#nav.direct == 1 and nav.direct[1].x == place.x,
        "N19a FAIL: the destination must reach move_direct")
    assert(s._nav_mesh_fallback == true, "N19a FAIL: the escalation is one-shot")
    assert(s._nav_unreachable == nil,
        "N19a FAIL: a place being re-walked directly must not be remembered as unreachable")

    -- The member absent — the shape the module had while it exported nothing: same inputs give
    -- up, so the scenario is about the member existing, not about the retry counters.
    local bare = make_nav("FAILED")
    local s2 = { _nav_retry_timer = 0, _nav_retries = 3, _nav_destination = place,
        _nav_wp_fallback = true }
    assert(nav_state.run(s2, nav_ctx({ me = watcher, nav = bare })) == "IDLE",
        "N19b FAIL: without the member the handler must give up as before")
    assert(s2._nav_unreachable ~= nil,
        "N19b FAIL: the give-up path is the one that remembers the place")
    print("  N19 PASS: the direct-movement escalation fires when the module can serve it")
end

print("PASS test_nav_state")
os.exit(0)
