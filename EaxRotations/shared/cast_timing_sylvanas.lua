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

-- Raw field read hoisted so the pcall below needs no per-call closure (the
-- repo's no-per-frame-allocation rule). pcall(read_field, obj, name) is the
-- established closure-free form; the interrupt_manager idiom reads the field
-- directly, but keeping the pcall here guards a throwing __index metamethod
-- without allocating.
local function read_field(obj, name)
    return obj[name]
end

local function safe_method(obj, name)
    if not obj then return nil end
    local ok, value = pcall(read_field, obj, name)
    return ok and value or nil
end

--- Remaining seconds of a unit's current cast or channel (target-side gate).
-- @param unit  engine game_object (player or target) or nil
-- @return number seconds remaining, or nil when the engine reports nothing
--         (no cast/channel, or a harness without the accessors)
function M.remaining(unit)
    if not unit then return nil end
    for i = 1, #END_TIME_ACCESSORS do
        local fn = safe_method(unit, END_TIME_ACCESSORS[i])
        if type(fn) == "function" then
            local ok, value = pcall(fn, unit)
            if ok and type(value) == "number" and value >= 0 then return value end
        end
    end
    return nil
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
