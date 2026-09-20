-- quest_frame_events_sylvanas.lua — game-event bridge for the quest pick-up/turn-in sequence.
-- WHAT:  registers ONE core.register_on_game_event_callback and turns the quest/gossip frame
--        events into a one-tick pulse the coordinator consumes each tick, so the sequence is
--        driven by the client's own frame events instead of being discovered by polling.
-- WHEN:  installed once at plugin load (main.lua); consumed once per tick by the coordinator.
-- WHY:   the client's docs say the gossip/quest names were added 2026-08-30 "because the
--        whole pick-up/turn-in sequence had to be polled" — GOSSIP_SHOW/GOSSIP_CLOSED bracket
--        the gossip frame, QUEST_DETAIL / QUEST_PROGRESS / QUEST_COMPLETE are the three panel
--        states, QUEST_GREETING is the classic multi-quest picker. A quest frame the polling
--        probe cannot see (QUEST_GREETING with available quests but no gossip frame and no
--        reward link) is exactly what a frame event catches.
-- SAFETY: the polling path is never displaced, so there is nothing to "switch back" from:
--         * detect_open_frame() stays the only gate and the only INTERACT exit check — the
--           pulse only ADDS a reason for IDLE to enter INTERACT, in the tick it arrives.
--         * a build that refuses the registration or never delivers an event simply has a
--           pulse that is never true, which is byte-for-byte the polling behavior.
--         * a pulse that is never consumed is dropped rather than latched: it cannot leak
--           into a later tick and pull INTERACT open for a frame that is long gone.
--         * it never handles a frame itself. The frame-handling rules stay in
--           quest_interaction_sylvanas, and the four bind confirms are deliberately NOT
--           allowed to raise the pulse (the plugin does not answer them, so entering
--           INTERACT for one would be a behavior change this bridge must not make).
-- Decision: one firehose callback (the API takes one function for every event) that
--         classifies by name into open/close/confirm; a read-and-clear pulse rather than a
--         latched flag; no clock, no closure and no per-tick work of any kind.

local _core_log = core.log

local M = {}

-- ============================================================================
-- Event classification
-- ============================================================================

--- Events that mean a quest/gossip frame the interaction rules handle is now up.
M.QUEST_OPEN_EVENTS = {
    GOSSIP_SHOW = true,
    QUEST_DETAIL = true,
    QUEST_PROGRESS = true,
    QUEST_COMPLETE = true,
    QUEST_GREETING = true,
}

--- The event that means the gossip frame is gone.
M.QUEST_CLOSE_EVENTS = {
    GOSSIP_CLOSED = true,
}

--- Prompts where the engine is withholding an action. Recorded, never a pulse.
M.CONFIRM_EVENTS = {
    AUTOEQUIP_BIND_CONFIRM = true,
    EQUIP_BIND_CONFIRM = true,
    CONFIRM_BINDER = true,
    LOOT_BIND_CONFIRM = true,
}

--- Every event name this module acts on, in one place for docs and tests.
M.EVENT_NAMES = {
    "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
    "AUTOEQUIP_BIND_CONFIRM", "EQUIP_BIND_CONFIRM", "CONFIRM_BINDER", "LOOT_BIND_CONFIRM",
}

-- ============================================================================
-- State
-- ============================================================================

local _installed = false      -- registration accepted by this build
local _reason = "not_attempted"  -- why the event path is or is not in use
local _delivered = false      -- a frame event has actually arrived
local _pulse = false          -- unread: a quest frame opened and has not been acted on
local _frame = nil            -- name of the last open event seen
local _last_confirm = nil     -- { name =, args = } of the last bind-confirm prompt
local _events = 0             -- events classified, for the debug surface

-- ============================================================================
-- Install — the startup probe
-- ============================================================================

--- Register the firehose callback once. Idempotent on purpose: the API allows only a
--- limited number of callbacks per plugin and raises when exceeded, so a second call
--- would be a bug, not a retry.
--- @return boolean installed
function M.install()
    if _installed then return true end

    local api = core and core.register_on_game_event_callback
    if type(api) ~= "function" then
        _reason = "no_api"
        return false
    end

    local ok = pcall(api, M.on_game_event)
    if not ok then
        -- The API is present but refused the registration (the documented callback limit).
        _reason = "registration_refused"
        if _core_log then
            _core_log("[EaxAutoQuester] quest frame events unavailable (registration refused) - polling only")
        end
        return false
    end

    _installed = true
    _reason = "registered"
    return true
end

--- Is the event path live? When false the pulse is never true and the polling path is
--- what runs — which is all this module can ever add to.
--- @return boolean
function M.available()
    return _installed
end

--- Why the event path is or is not in use, for the debug log and the tests.
--- @return table
function M.status()
    return {
        installed = _installed,
        available = M.available(),
        reason = _reason,
        delivered = _delivered,
        events = _events,
        frame = _frame,
        pulse = _pulse,
        confirm = _last_confirm and _last_confirm.name or nil,
    }
end

-- ============================================================================
-- Delivery
-- ============================================================================

--- Dispatch one game event. This is what the registered callback calls, and it is the
--- seam every test drives directly.
--- @param name string|nil Event name.
--- @param args table|nil Positional arguments (1-based), as the API delivers them.
function M.on_game_event(name, args)
    if type(name) ~= "string" then return end

    if M.QUEST_OPEN_EVENTS[name] then
        _events = _events + 1
        _delivered = true         -- an event arrived: the pump is delivering
        _pulse = true             -- IDLE may enter INTERACT on this tick
        _frame = name
        return
    end

    if M.QUEST_CLOSE_EVENTS[name] then
        _events = _events + 1
        _delivered = true
        -- A frame that closed before it was handled must not pull INTERACT open.
        _pulse = false
        _frame = nil
        return
    end

    if M.CONFIRM_EVENTS[name] then
        _events = _events + 1
        _delivered = true
        _last_confirm = { name = name, args = args }
        -- Deliberately no pulse: these do not raise the gate (see the header).
    end
end

--- Read and clear the pulse. The coordinator calls this once per tick, before dispatching,
--- so a pulse is worth exactly one tick: it can never be acted on after the frame that
--- raised it has gone, and an unread pulse cannot accumulate.
--- @return boolean pulsing
function M.take_pulse()
    if not _pulse then return false end
    _pulse = false
    return true
end

--- Drop an unread pulse without acting on it. Called when the state machine stops, so a
--- frame event that arrived while the plugin was parked cannot be acted on at resume.
function M.drop_pulse()
    _pulse = false
end

-- ============================================================================
-- Exports
-- ============================================================================

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.quest_frame_events = M

return M
