-- What: Unit tests for EaxAutoQuester/quest_state/nav_state.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Verify NAV state transitions: IDLE (combat/arrived/failed/stuck), NAV

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

local nav_state = require("EaxAutoQuester/quest_state/nav_state")

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

local utils = require("EaxAutoQuester/utils_sylvanas")

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

-- N6 — en-route pre-tag: while walking, tag + interact the goal's quest NPC
do
    mock.reset()
    local npc_obj = mock.create_object({ pos = { x = 20, y = 0, z = 0 }, name = "Elder Tiger",
        unit = true, valid = true, guid = "npc_pretag" })
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
    print("  N6 PASS: en-route pre-tag — goal NPC tagged at 50yd (target_id fallback)")
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
    assert(_turn_calls == 1,
        "N4b FAIL: second stuck retry should tap exactly one turn (got " .. tostring(_turn_calls) .. ")")
    print("  N4 PASS: stuck escalation — jump, then jump + random turn tap")
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

print("PASS test_nav_state")
os.exit(0)
