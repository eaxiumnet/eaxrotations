-- shot_timer_sylvanas.lua — Swing-timer-aware casting for Hunters (TBC 2.5.5).
-- WHAT:  Prevent shot clipping by checking ranged swing timer before casts.
-- WHEN:  All Hunter specs before Steady Shot / instant shots.
-- WHY:   Clipping auto-shots is the #1 Hunter DPS mistake.
-- SAFETY: delegates to HunterCore; nil-guarded fallbacks.
-- DECISION: pre-cast delay gate for Hunter cast-time spells vs auto-shot.

local NS = _G.EaxRotations
if not NS then return {} end

local hunter_core = require("shared/hunter_core_sylvanas")

local M = {}

--- Should we delay a cast because an auto-shot is about to fire?
-- Returns true if the cast should be postponed until after the next auto.
--
-- @param context   table   Rotation context (unused, reserved for future state)
-- @param buffer_ms number  Safety buffer in milliseconds (default 150)
-- @return boolean  true = delay the cast, false = safe to proceed
function M.should_delay_cast(context, buffer_ms)
    buffer_ms = buffer_ms or 150
    local remain_ms = hunter_core.ms_until_auto and hunter_core.ms_until_auto() or 0
    if remain_ms == 0 then return false end
    -- Steady Shot cast time + buffer + 500ms auto-shot wind-up safety
    local steady_cast_ms = (hunter_core.get_steady_cast_ms and hunter_core.get_steady_cast_ms()) or 1500
    local needed = steady_cast_ms + buffer_ms + 500
    return remain_ms <= needed
end

--- Should we delay an INSTANT shot (Arcane, Multi) because auto is imminent?
-- Instant shots only block the 500ms auto wind-up + buffer.
--
-- @param context   table   Rotation context
-- @param buffer_ms number  Safety buffer in milliseconds (default 150)
-- @return boolean  true = delay the cast
function M.should_delay_instant(context, buffer_ms)
    buffer_ms = buffer_ms or 150
    local remain_ms = hunter_core.ms_until_auto and hunter_core.ms_until_auto() or 0
    if remain_ms == 0 then return false end
    return remain_ms <= (buffer_ms + 500)
end

--- Re-export HunterCore steady-shot check with configurable buffer.
-- @param buffer_ms number|nil
-- @return boolean  true = safe to cast Steady Shot
function M.can_cast_steady(buffer_ms)
    if hunter_core.can_cast_steady then
        return hunter_core.can_cast_steady(buffer_ms)
    end
    return true
end

--- Re-export HunterCore instant-shot check with configurable buffer.
-- @param cast_ms   number|nil  Cast time in ms (default 500)
-- @param buffer_ms number|nil  Buffer in ms (default 100)
-- @return boolean  true = safe to cast instant
function M.can_cast_instant(cast_ms, buffer_ms)
    if hunter_core.can_cast_instant then
        return hunter_core.can_cast_instant(cast_ms, buffer_ms)
    end
    return true
end

if NS then
    NS.ShotTimer = M
end

return M
