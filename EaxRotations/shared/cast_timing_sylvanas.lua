-- cast_timing_sylvanas.lua — Cast/channel end-time gate (engine timing signal).
-- WHAT:  answers "how long is this unit's current cast/channel still running?" and
--        "is it too late for an interrupt to matter?".
-- WHEN:  read by interrupt lanes (before spending an interrupt cooldown) and by
--        channel lanes (before re-issuing a channel already in progress).
-- WHY:   the engine exposes real end times via
--        unit:get_channeling_or_casting_remaining_sec() / get_cast_remaining_sec()
--        / get_channel_remaining_sec() (plus the _ms variants). Before this
--        module NO rotation read any of them — the only timing proxy in the tree
--        was cast *percent* (shared/interrupt_manager_sylvanas.lua
--        cast_has_interrupt_window), which is duration-relative: 50% of a 0.8s
--        cast (0.4s left — already landing) and 50% of a 6s cast (3s left —
--        plenty) look identical, so a short cast about to finish could still
--        claim an interrupt and burn the cooldown for nothing.
-- SAFETY: pure module — it takes units/contexts as data and captures no NS at
--         require time (behavioral_audit's shared-virgin guard), allocates
--         nothing, and FAILS OPEN: when the engine reports no end time the
--         gates behave exactly as they did before this module existed.

local M = {}

-- How much of a cast must remain for an interrupt to be worth spending.
-- Below this the cast lands first (server-side interrupt resolution + the
-- interrupter's own reaction/GCD), so the cooldown is wasted. Overridable per
-- spec through settings.interrupt_lead_sec.
M.DEFAULT_LEAD_SEC = 0.30

-- Clamp for the settings-provided lead so a bad setting cannot disable the gate
-- or move it absurdly far up the cast bar.
M.MIN_LEAD_SEC = 0.10
M.MAX_LEAD_SEC = 1.50

-- Engine accessors that report a cast-or-channel end time, best first. The
-- combined accessor covers both channels and casts; the specific ones are the
-- fallback for builds that only publish one of them.
local END_TIME_ACCESSORS = {
    "get_channeling_or_casting_remaining_sec",
    "get_cast_remaining_sec",
    "get_channel_remaining_sec",
}

-- Single-owner safe reads (2026-09-12): shared/safe_helpers_sylvanas owns
-- safe()/safe_field()/safe_method() for the whole tree. Its safe_field is now
-- closure-free (pcall over a hoisted raw reader), which is the property that
-- previously forced this module to keep a private copy -- so the private
-- read_field/safe_method pair is gone and the hot path keeps its
-- zero-allocation guarantee.
local safe_helpers = require("shared/safe_helpers_sylvanas")
local safe_method = safe_helpers.safe_field

--- Read the first accessor in a list that returns a number.
-- @param unit  engine game_object or nil
-- @param names accessor name list, best first
-- @return number|nil
local function first_number(unit, names)
    if not unit then return nil end
    for i = 1, #names do
        local fn = safe_method(unit, names[i])
        if type(fn) == "function" then
            local ok, value = pcall(fn, unit)
            if ok and type(value) == "number" and value >= 0 then return value end
        end
    end
    return nil
end

-- Engine accessors that report a channel's own identity and clock. The
-- channel-specific accessors are authoritative; the combined id accessor is the
-- fallback for builds that only publish one of them.
local CHANNEL_ID_ACCESSORS = {
    "get_active_channel_spell_id",
    "get_active_cast_or_channel_id",
}

local CHANNEL_ELAPSED_ACCESSORS = {
    "get_channel_elapsed_ms",
}

local CHANNEL_DURATION_ACCESSORS = {
    "get_channel_duration_ms",
}

-- Hoisted so channel_remaining_ms (called per frame by mf_tick) allocates
-- nothing: a table literal in the body would be one new table per call.
local CHANNEL_REMAINING_MS_ACCESSORS = { "get_channel_remaining_ms" }
local CHANNEL_REMAINING_SEC_ACCESSORS = { "get_channel_remaining_sec" }

--- Remaining seconds of a unit's current cast or channel (target-side gate).
-- @param unit  engine game_object (player or target) or nil
-- @return number seconds remaining, or nil when the engine reports nothing
--         (no cast/channel, or a harness without the accessors)
function M.remaining(unit)
    return first_number(unit, END_TIME_ACCESSORS)
end

--- Spell id of the unit's active channel, or nil when not channeling.
-- Used by the dispatcher's channel-clip opt-in: only a channel a spec has
-- declared clip-managed may re-enter the decision loop mid-channel.
-- @param unit  engine game_object or nil
-- @return number|nil
function M.channel_id(unit)
    local id = first_number(unit, CHANNEL_ID_ACCESSORS)
    if type(id) ~= "number" or id <= 0 then return nil end
    return id
end

--- Milliseconds already elapsed in the unit's current channel, or nil.
-- This is the authoritative elapsed clock; before it existed the repo computed
-- `now - channel_start` by hand, which is off by the poll gap and blind to a
-- duration the engine scaled with haste.
-- @param unit  engine game_object or nil
-- @return number|nil milliseconds
function M.channel_elapsed_ms(unit)
    return first_number(unit, CHANNEL_ELAPSED_ACCESSORS)
end

--- Milliseconds remaining in the unit's current channel, or nil.
-- Prefers the millisecond accessor; falls back to seconds and rescales.
-- Fail-open: nil means "unknown" and callers must keep their pre-signal path.
-- @param unit  engine game_object or nil
-- @return number|nil milliseconds
function M.channel_remaining_ms(unit)
    local ms = first_number(unit, CHANNEL_REMAINING_MS_ACCESSORS)
    if type(ms) == "number" then return ms end
    local sec = first_number(unit, CHANNEL_REMAINING_SEC_ACCESSORS)
    if type(sec) == "number" then return sec * 1000 end
    return nil
end

--- Total duration of the unit's current channel in milliseconds, or nil.
-- Haste-scaled by the engine, which is what makes a tick-interval derivation
-- correct where a hardcoded 1000ms tick is not.
-- @param unit  engine game_object or nil
-- @return number|nil milliseconds
function M.channel_duration_ms(unit)
    return first_number(unit, CHANNEL_DURATION_ACCESSORS)
end

--- Is there enough cast left for an interrupt to land in time?
-- Fail-open: an unknown remaining time (nil) reports true — the pre-module
-- behavior, where every cast the engine flagged was interruptible.
-- @param remaining  seconds left, or nil when unknown
-- @param lead       minimum worthwhile remaining seconds (defaults to DEFAULT_LEAD_SEC)
function M.lead_open(remaining, lead)
    if type(remaining) ~= "number" then return true end
    local threshold = lead
    if type(threshold) ~= "number" then threshold = M.DEFAULT_LEAD_SEC end
    if threshold < M.MIN_LEAD_SEC then threshold = M.MIN_LEAD_SEC end
    if threshold > M.MAX_LEAD_SEC then threshold = M.MAX_LEAD_SEC end
    return remaining > threshold
end

--- Read the lead threshold from a spec settings table (settings.interrupt_lead_sec).
function M.lead_from_settings(settings)
    local value = settings and settings.interrupt_lead_sec
    if type(value) ~= "number" then return M.DEFAULT_LEAD_SEC end
    return value
end

--- Interrupt gate reading the dispatcher-published context (spec DSL lanes).
-- context.target_cast_remaining is produced by main_sylvanas from the engine's
-- end-time accessors; 0/absent means "unknown" and keeps the lane open.
-- @param context  dispatcher context
-- @param settings optional settings table carrying interrupt_lead_sec
function M.context_interrupt_open(context, settings)
    if not context then return true end
    local remaining = context.target_cast_remaining
    if type(remaining) ~= "number" or remaining <= 0 then return true end
    return M.lead_open(remaining, M.lead_from_settings(settings))
end

return M
