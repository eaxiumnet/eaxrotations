-- What: Tests for EaxAutoQuester/quest_frame_events_sylvanas.lua
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Item 12 drives the quest pick-up/turn-in sequence from the client's frame events
--      (GOSSIP_SHOW / GOSSIP_CLOSED / QUEST_DETAIL / QUEST_PROGRESS / QUEST_COMPLETE /
--      QUEST_GREETING plus the four bind-confirm prompts), registered through
--      core.register_on_game_event_callback, and falls back to the polling path on a build
--      that will not deliver or accept them. These scenarios pin the probe (exactly ONE
--      registration, through the documented entry point; refused; API absent), the pulse
--      (one-shot, only the open events, a close cancelling a frame that was never handled,
--      and a drop that stops an unread pulse outliving its frame), the four confirms being
--      recorded WITHOUT pulsing, and — structurally — that the bridge owns no gate of its
--      own, so it can never displace the polling probe.
-- Safety: mock-only; no io.popen/os.execute/ffi.C/debug.*/math.sqrt

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()

--- A fresh bridge, loaded exactly as the plugin loads it. Scenarios below swap the API
--- surface underneath, so each needs its own instance and its own registration.
local function fresh_events()
    package.loaded["quest_frame_events_sylvanas"] = nil
    local ns = _G.EaxAutoQuester
    if ns then ns.quest_frame_events = nil end
    return require("quest_frame_events_sylvanas")
end

local OPEN = { "GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING" }
local CONFIRMS = { "AUTOEQUIP_BIND_CONFIRM", "EQUIP_BIND_CONFIRM", "CONFIRM_BINDER", "LOOT_BIND_CONFIRM" }

-- ============================================================================
-- F1: the probe registers exactly once, through the documented entry point
-- ============================================================================
do
    mock.reset()
    local fe = fresh_events()

    assert(fe.install() == true, "F1: install must succeed when the API is present")
    assert(mock._game_event_registrations == 1,
        "F1: the bridge must register exactly one callback, got " ..
        tostring(mock._game_event_registrations))
    assert(type(mock._game_event_callback) == "function",
        "F1: a callback must be registered")
    assert(fe.available() == true, "F1: an accepted registration means the path is live")

    -- The real API allows only a limited number of callbacks per plugin and raises when
    -- exceeded, so a second install must be a no-op rather than a second registration.
    assert(fe.install() == true, "F1: install must stay idempotent")
    assert(mock._game_event_registrations == 1,
        "F1: a repeated install must not register a second callback, got " ..
        tostring(mock._game_event_registrations))
    print("F1 PASS: one registration, idempotent install")
end

-- ============================================================================
-- F2: the bridge owns no gate — the polling probe stays the only one
-- ============================================================================
do
    local fe = fresh_events()
    assert(fe.wrap_detect == nil,
        "F2: the bridge must not offer a replacement gate — the polling probe is the gate")
    assert(fe.detect_open_frame == nil,
        "F2: the bridge must not own a frame detector — decisions stay with the state machine")
    for _, name in ipairs({ "install", "available", "status", "on_game_event",
                            "take_pulse", "drop_pulse" }) do
        assert(type(fe[name]) == "function", "F2: missing public member " .. name)
    end
    print("F2 PASS: no gate of its own — it can only add a pulse for the caller to consume")
end

-- ============================================================================
-- F3: what each event means to the pulse
-- ============================================================================
do
    mock.reset()
    local fe = fresh_events()
    fe.install()

    for _, name in ipairs(OPEN) do
        mock.fire_game_event(name)
        assert(fe.take_pulse() == true, "F3: " .. name .. " must raise the pulse")
        assert(fe.take_pulse() == false,
            "F3: the pulse is read-and-clear — a second read must not re-raise it (" .. name .. ")")
    end

    -- All ten documented names must be classified; a dropped name would silently fall
    -- through and the sequence would depend on the poll again.
    local classified = { GOSSIP_CLOSED = true }
    for _, name in ipairs(OPEN) do classified[name] = true end
    for _, name in ipairs(CONFIRMS) do classified[name] = true end
    for _, name in ipairs(fe.EVENT_NAMES) do
        assert(classified[name] == true, "F3: unclassified event name " .. tostring(name))
    end
    assert(#fe.EVENT_NAMES == 10, "F3: expected 10 event names, got " .. tostring(#fe.EVENT_NAMES))

    -- A frame that closed before it was handled must not be acted on.
    mock.fire_game_event("GOSSIP_SHOW")
    mock.fire_game_event("GOSSIP_CLOSED")
    assert(fe.take_pulse() == false,
        "F3: a frame that closed unhandled must not leave a pulse")

    -- The four bind confirms are recorded (they prove delivery) but must NOT pulse: the
    -- plugin does not answer them, so entering INTERACT for one would be a behavior
    -- change this bridge is not allowed to make.
    for _, name in ipairs(CONFIRMS) do
        mock.fire_game_event(name, { 1 })
        assert(fe.take_pulse() == false, "F3: " .. name .. " must not raise a pulse")
    end
    local st = fe.status()
    assert(st.confirm == "LOOT_BIND_CONFIRM",
        "F3: the last bind confirm must be recorded, got " .. tostring(st.confirm))
    assert(st.delivered == true, "F3: a bind confirm proves the callback is delivering")

    -- Unrelated events change nothing and are not counted as frame events.
    local before = fe.status().events
    mock.fire_game_event("ENCOUNTER_START", { 1 })
    local after = fe.status()
    assert(after.events == before, "F3: an unrelated event must not be acted on")
    assert(after.pulse == false, "F3: an unrelated event must not pulse")
    print("F3 PASS: open/close/confirm classification, read-and-clear pulse")
end

-- ============================================================================
-- F4: a pulse is worth one read — it cannot accumulate or outlive its frame
-- ============================================================================
do
    mock.reset()
    local fe = fresh_events()
    fe.install()

    mock.fire_game_event("GOSSIP_SHOW")
    mock.fire_game_event("QUEST_COMPLETE")
    assert(fe.take_pulse() == true, "F4: a pulse must be readable once")
    assert(fe.take_pulse() == false,
        "F4: two events in one tick must not leave a pulse behind for the next tick")

    -- An unread pulse is dropped when the state machine stops, so an event that arrived
    -- while the plugin was parked cannot be acted on at resume.
    mock.fire_game_event("GOSSIP_SHOW")
    assert(fe.status().pulse == true, "F4: the pulse must be pending before the drop")
    fe.drop_pulse()
    assert(fe.take_pulse() == false, "F4: a dropped pulse must not be readable")
    print("F4 PASS: one read per pulse; an unread pulse can be dropped")
end

-- ============================================================================
-- F5: the API is absent → no registration, no pulse, nothing else changes
-- ============================================================================
do
    mock.reset()
    local saved = mock.register_on_game_event_callback
    mock.register_on_game_event_callback = nil

    local fe = fresh_events()
    local installed = fe.install()
    mock.register_on_game_event_callback = saved

    assert(installed == false, "F5: install must fail cleanly when the API is absent")
    assert(fe.available() == false, "F5: the event path must be unavailable")
    assert(fe.status().reason == "no_api",
        "F5: reason should record the missing API, got " .. tostring(fe.status().reason))
    assert(fe.take_pulse() == false, "F5: no API means no pulse, i.e. polling behavior")
    print("F5 PASS: API absent → install refused, pulse permanently false")
end

-- ============================================================================
-- F6: the API is present but refuses the registration → same as absent
-- ============================================================================
do
    mock.reset()
    local saved = mock.register_on_game_event_callback
    mock._game_event_raises = true

    local fe = fresh_events()
    local installed = fe.install()
    mock.register_on_game_event_callback = saved

    assert(installed == false, "F6: a refused registration must not report success")
    assert(fe.available() == false, "F6: a refused registration must not leave the path live")
    assert(fe.status().reason == "registration_refused",
        "F6: reason should record the refusal, got " .. tostring(fe.status().reason))
    assert(fe.take_pulse() == false, "F6: a refused registration means polling behavior")
    assert(mock._game_event_callback == nil, "F6: no callback may be left registered")
    print("F6 PASS: registration refused → install false, pulse permanently false")
end

-- ============================================================================
-- F7: the coordinator consumes the pulse once per tick and drops it on stop
--     (the wiring, driven through the coordinator's own accessor)
-- ============================================================================
do
    mock.reset()
    local fe = fresh_events()
    fe.install()

    local coordinator = require("quest_state/coordinator")

    mock.fire_game_event("QUEST_GREETING")
    assert(coordinator._test_take_frame_pulse(true) == true,
        "F7: the coordinator must consume the pulse the bridge raised")
    assert(coordinator._test_take_frame_pulse() == false,
        "F7: the next tick's read must be clear, so a stale pulse cannot enter INTERACT")

    mock.fire_game_event("GOSSIP_SHOW")
    coordinator.stop_navigation()
    assert(coordinator._test_take_frame_pulse() == false,
        "F7: stopping the machine must drop an unread pulse")
    print("F7 PASS: coordinator consumes the pulse per tick and drops it on stop")
end

-- ============================================================================
-- F8: the startup probe is wired — loading the plugin entry point installs the bridge
-- ============================================================================
do
    mock.reset()
    local ns = _G.EaxAutoQuester
    if ns then ns.quest_frame_events = nil end
    package.loaded["quest_frame_events_sylvanas"] = nil

    -- Load the real entry point, the way the plugin is loaded on startup. This is last:
    -- main.lua publishes its own namespace table, so anything that ran before it must
    -- not depend on the global afterwards.
    local ok, main_mod = pcall(require, "main")
    assert(ok and type(main_mod) == "table", "F8: main.lua must load under the mock")

    assert(mock._game_event_registrations == 1,
        "F8: loading the plugin must register exactly one game-event callback, got " ..
        tostring(mock._game_event_registrations))
    assert(type(mock._game_event_callback) == "function",
        "F8: the registered callback must be the bridge's dispatcher")

    local published = _G.EaxAutoQuester and _G.EaxAutoQuester.quest_frame_events
    assert(published ~= nil, "F8: the bridge must be published where the coordinator looks")
    local st = published.status()
    assert(st.installed == true and st.available == true,
        "F8: the startup probe must leave the event path installed (reason=" ..
        tostring(st.reason) .. ")")

    -- And the installed callback really is the dispatcher: an event raises the pulse.
    mock.fire_game_event("GOSSIP_SHOW")
    assert(published.take_pulse() == true,
        "F8: an event delivered to the plugin's own registration must raise the pulse")
    print("F8 PASS: loading main.lua installs the bridge and one callback")
end

print("PASS test_quest_frame_events")
os.exit(0)
