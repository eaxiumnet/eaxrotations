-- What: Parity between the game-event drive path and the polling path (plan item 12).
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: Item 12 makes the quest pick-up/turn-in sequence event-driven, with an automatic
--      fallback to the polling path on a build that will not deliver or accept the events.
--      The one claim that must hold is that the two paths are indistinguishable: the same
--      scripted gossip/detail/progress/complete sequence, driven through both, must produce
--      the same state transitions and the same client calls, tick for tick. This suite
--      drives the sequence four ways — events delivered, events registered but never
--      delivered, registration refused, API absent — and compares the per-tick logs line by
--      line. It then proves the event path is load-bearing: with the polling probe stubbed
--      blind, the events alone must still drive the sequence into INTERACT, and without
--      them INTERACT must be unreachable.
-- Safety: mock-only; no io.popen/os.execute/ffi.C/debug.*/math.sqrt

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()

local coordinator = require("quest_state/coordinator")
local idle_state = require("quest_state/idle_state")
local interact_state = require("quest_state/interact_state")
local utils = require("utils_sylvanas")

-- ============================================================================
-- The scripted sequence — one pick-up and one turn-in, seen by both paths
-- ============================================================================
-- Each entry is the CLIENT's state for that tick: the frame it is showing (which the
-- polling accessors see) and the frame event it fires for that frame (which the event
-- bridge sees). The two views are set independently on purpose — the parity claim is
-- about the sequence, not about the mock agreeing with itself.

local function client_nothing()
    mock._frames = {}
    mock._gossip_available = {}
    mock._gossip_active = {}
    mock._quest_rewards = {}
    mock._quest_money = 0
end

--- Gossip frame offering quest 115 — the pick-up entry point.
local function client_gossip_available(id, title)
    client_nothing()
    mock._frames.gossip = { npc = "Marshal McBride" }
    mock._gossip_available = { { quest_id = id, title = title } }
end

--- Gossip frame with a complete quest — the turn-in entry point.
local function client_gossip_turnin(id, title)
    client_nothing()
    mock._frames.gossip = { npc = "Marshal McBride" }
    mock._gossip_active = { { quest_id = id, title = title, is_complete = true } }
end

--- Quest detail frame with a reward choice.
local function client_detail_reward()
    client_nothing()
    mock._quest_rewards = { { link = "|cff1eff00|Hitem:1234|h[Reward]|h|r", name = "Reward" } }
end

--- Quest progress frame with a money-only reward.
local function client_progress_money()
    client_nothing()
    mock._quest_money = 1200
end

-- Each frame is held for two ticks, as the client holds it: the tick that enters INTERACT
-- and the tick that handles it. A frame that lasted one tick would never be reached.
local SCRIPT = {
    { client = client_nothing },
    { client = function() client_gossip_available(115, "Quest A") end, event = "GOSSIP_SHOW" },
    { client = function() client_gossip_available(115, "Quest A") end, event = "GOSSIP_SHOW" },
    { client = function() client_gossip_available(115, "Quest A") end },
    { client = client_detail_reward, event = "QUEST_DETAIL" },
    { client = client_detail_reward },
    { client = client_detail_reward },
    { client = client_progress_money, event = "QUEST_PROGRESS" },
    { client = client_progress_money },
    { client = function() client_gossip_turnin(207, "Done A") end, event = "GOSSIP_SHOW" },
    { client = function() client_gossip_turnin(207, "Done A") end, event = "GOSSIP_SHOW" },
    { client = client_nothing, event = "QUEST_COMPLETE" },
    -- A bind-confirm prompt may arrive mid-sequence. It is recorded and must change
    -- nothing: the plugin does not answer these, so they must not pulse.
    { client = client_nothing, event = "LOOT_BIND_CONFIRM" },
    { client = function() client_gossip_available(309, "Quest B") end, event = "GOSSIP_SHOW" },
    { client = function() client_gossip_available(309, "Quest B") end, event = "QUEST_GREETING" },
    { client = client_nothing, event = "GOSSIP_CLOSED" },
}

local ZYGOR_STUB = {
    has_current_step = function() return true end,
    get_current_step_info = function()
        return { is_complete = false,
            goals = { { type = "area", npc_id = 0, target = "McBride" } }, step_num = 1 }
    end,
    get_current_waypoint_world = function() return nil end,
}

-- ============================================================================
-- Setup — one run of the sequence under a chosen event-path mode
-- ============================================================================

--- Load a fresh bridge for this run and put it where the plugin publishes it.
--- @param mode string "delivering" | "silent" | "refused" | "absent"
--- @return table bridge
--- @return boolean installed
local function setup_events(mode)
    package.loaded["quest_frame_events_sylvanas"] = nil
    local ns = _G.EaxAutoQuester
    if ns then ns.quest_frame_events = nil end

    local saved_registrar = mock.register_on_game_event_callback
    if mode == "absent" then mock.register_on_game_event_callback = nil end
    mock._game_event_raises = (mode == "refused")
    mock._game_event_registrations = 0
    mock._game_event_callback = nil

    local bridge = require("quest_frame_events_sylvanas")
    local installed = false
    if mode ~= "absent" then installed = bridge.install() end

    mock.register_on_game_event_callback = saved_registrar
    if ns then ns.quest_frame_events = bridge end
    return bridge, installed
end

--- Drive the scripted sequence once.
--- @param mode string Event-path mode (see setup_events).
--- @param opts table|nil { blind_poll = true } to stub the polling probe so the pulse is
---        the only signal left; used for the load-bearing proof, never for parity runs.
--- @return table lines Per-tick log, one string per tick.
--- @return table bridge The bridge used for this run.
--- @return boolean installed
local function drive(mode, opts)
    opts = opts or {}

    mock.reset()
    mock.create_player({ pos = { x = 0, y = 0, z = 0 }, hp = 10000, max_hp = 10000,
        mana = 10000, max_mana = 10000 })

    -- Fresh quest handlers for every run: they carry per-frame state (throttle
    -- timestamps, retry counts) that must not leak from one run into the next.
    package.loaded["quest_interaction_sylvanas"] = nil
    local quest_interaction = require("quest_interaction_sylvanas")

    local bridge, installed = setup_events(mode)

    -- The gate is the state machine's own polling probe — item 12 does not replace it.
    -- What the event path adds is the per-tick pulse, consumed below through the
    -- coordinator's own accessor, so the wired path is what is driven here.
    local gate = idle_state.detect_open_frame
    if opts.blind_poll then
        -- Same probe, stubbed blind: the pulse is the only signal left, which is how the
        -- load-bearing proof below isolates it.
        gate = function() return false end
    end

    local tokens = {}
    local proxy = {}
    for k, v in pairs(quest_interaction) do proxy[k] = v end
    proxy.handle_any_frame = function(step_text)
        local result = quest_interaction.handle_any_frame(step_text)
        if result then tokens[#tokens + 1] = "token=" .. tostring(result) end
        return result
    end

    local shared = {
        _state = "IDLE",
        _interact_start_time = 0,
        _interact_cooldown = 0,
        _loot_cooldown = 0,
        _last_cooldown_log = 0,
        _nav_destination = nil,
        _area_wait_timer = 0,
        _post_interact_timer = 0,
        _at_quest_object_timer = 0,
        _action_pause_timer = 0,
        _area_fail_count = 0,
        _visited_waypoints = {},
    }

    local ctx = {
        zygor = ZYGOR_STUB,
        nav = { is_navigating = function() return false end, stop = function() end },
        quest_interaction = proxy,
        npc_manager = { find_interactable_objects = function() return {} end },
        utils = utils,
        me = mock._player,
        now = 0,
        debug_log = function() end,
        log = function() end,
        safe = function(v, fallback) if v == nil then return fallback end return v end,
        detect_open_frame = gate,
        frame_signalled = false,
        object_scanner = { get_visible_objects = function() return {} end },
    }

    local lines = {}
    for tick, step in ipairs(SCRIPT) do
        step.client()
        if step.event and mode == "delivering" then
            mock.fire_game_event(step.event)   -- through the callback the bridge registered
        end

        local now = tick * 0.5
        mock.set_time(now)
        ctx.now = now

        -- Consume the frame-event pulse for this tick, exactly as the coordinator's
        -- per-tick context does, before dispatching the handlers.
        ctx.frame_signalled = coordinator._test_take_frame_pulse(true)

        tokens = {}
        local calls_before = #mock._input_calls
        local selected_before = mock._frames.gossip_selected

        -- Dispatch exactly as the coordinator does: one handler per tick, state carried.
        local from = shared._state
        if from == "IDLE" then
            shared._state = idle_state.run(shared, ctx)
        elseif from == "INTERACT" then
            shared._state = interact_state.run(shared, ctx)
        else
            -- Not part of the frame sequence under test (e.g. a quest goal at range).
            -- Every run reaches these the same way, and parity is asserted over the whole
            -- log, so this normalization is applied identically to every path.
            shared._state = "IDLE"
        end

        local calls = {}
        for i = calls_before + 1, #mock._input_calls do
            local c = mock._input_calls[i]
            calls[#calls + 1] = c[1] .. "(" .. tostring(c[2] or "") .. ")"
        end
        if mock._frames.gossip_selected ~= selected_before then
            calls[#calls + 1] = "gossip_selected=" .. tostring(mock._frames.gossip_selected)
        end

        lines[#lines + 1] = string.format("%02d %-8s -> %-8s %s | %s", tick, from,
            shared._state, table.concat(tokens, ","), table.concat(calls, ","))
    end

    return lines, bridge, installed
end

local function assert_same_sequence(label, a, b)
    assert(#a == #b, label .. " FAIL: tick counts differ (" .. #a .. " vs " .. #b .. ")")
    for i = 1, #a do
        assert(a[i] == b[i], label .. " FAIL: tick " .. i .. " differs\n  events: " ..
            a[i] .. "\n  poll:   " .. b[i])
    end
end

local function count_in(lines, needle)
    local n = 0
    for _, line in ipairs(lines) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- ============================================================================
-- P1: events delivered  vs  events registered but never delivered
-- ============================================================================
local events_log, events_bridge, events_installed = drive("delivering")
local silent_log, silent_bridge = drive("silent")
assert(events_installed == true, "P1: the delivering run must install the bridge")
assert_same_sequence("P1", events_log, silent_log)
print("P1 PASS: delivering and silent builds produce the same " .. #events_log ..
    " tick sequence")

-- The delivering run must really have used the event path, or the parity above is a
-- comparison of two polling runs.
local delivered_status = events_bridge.status()
assert(delivered_status.delivered == true,
    "P1: the delivering run must have received events")
assert(delivered_status.events >= 8,
    "P1: expected the scripted events, got " .. tostring(delivered_status.events))
assert(delivered_status.pulse == false,
    "P1: the consumed pulse must not be left pending")

-- The silent run must really have been silent: no event ever arrived, so its pulse was
-- never true and the run above was the polling path untouched. That is the fallback.
local silent_status = silent_bridge.status()
assert(silent_status.delivered == false and silent_status.events == 0,
    "P1: the silent build must not have received events (delivered=" ..
    tostring(silent_status.delivered) .. ", events=" .. tostring(silent_status.events) .. ")")

-- ============================================================================
-- P2/P3: registration refused, and API absent — both leave the poll in charge
-- ============================================================================
local refused_log, _, refused_installed = drive("refused")
assert(refused_installed == false, "P2: a refused registration must not install")
assert_same_sequence("P2", events_log, refused_log)
print("P2 PASS: registration refused → same " .. #refused_log .. " tick sequence")

local absent_log, _, absent_installed = drive("absent")
assert(absent_installed == false, "P3: a missing API must not install")
assert_same_sequence("P3", events_log, absent_log)
print("P3 PASS: API absent → same " .. #absent_log .. " tick sequence")

-- ============================================================================
-- P4: the sequence is non-vacuous — it really drove the quest frames
-- ============================================================================
local function log_contains(needle)
    for _, line in ipairs(events_log) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

assert(log_contains("gossip_selected=115"),
    "P4 FAIL: the scripted gossip must have selected quest 115\n" ..
    table.concat(events_log, "\n"))
assert(log_contains("gossip_selected=207"),
    "P4 FAIL: the scripted turn-in must have selected quest 207\n" ..
    table.concat(events_log, "\n"))
assert(log_contains("-> INTERACT"),
    "P4 FAIL: the sequence must have entered INTERACT\n" .. table.concat(events_log, "\n"))
assert(log_contains("token="),
    "P4 FAIL: the frame handlers must have produced action tokens\n" ..
    table.concat(events_log, "\n"))
local entered = count_in(events_log, "-> INTERACT")
local exited = count_in(events_log, "INTERACT -> IDLE")
assert(entered >= 2 and exited >= 2,
    "P4 FAIL: expected the IDLE→INTERACT→IDLE cycle at least twice, got " ..
    tostring(entered) .. " in and " .. tostring(exited) .. " out\n" ..
    table.concat(events_log, "\n"))
print("P4 PASS: non-vacuous — " .. entered .. " INTERACT entries, " .. exited ..
    " clean exits, both gossips and the turn-in selected")

-- ============================================================================
-- P5: the pulse is load-bearing — with the polling probe blind, the events alone
--     drive the sequence into INTERACT, and without them it never happens
-- ============================================================================
local blind_events_log = drive("delivering", { blind_poll = true })
local blind_poll_log = drive("silent", { blind_poll = true })

local blind_entries = count_in(blind_events_log, "-> INTERACT")
assert(blind_entries > 0,
    "P5 FAIL: with the polling probe blind, the events alone must still enter INTERACT\n" ..
    table.concat(blind_events_log, "\n"))
assert(count_in(blind_poll_log, "-> INTERACT") == 0,
    "P5 FAIL: with the polling probe blind and no events, INTERACT must be unreachable — " ..
    "otherwise the parity above compares two polling runs\n" ..
    table.concat(blind_poll_log, "\n"))
print("P5 PASS: probe-blind — " .. blind_entries ..
    " INTERACT entries from the events, 0 without them (the pulse is load-bearing)")

print("PASS test_frame_event_parity")
os.exit(0)
