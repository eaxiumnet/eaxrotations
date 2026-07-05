-- responder.lua — Whisper detection and AFK response logging.
-- WHAT:  detects incoming whisper events (when API supports them) and logs them.
--        Since Sylvanas does not currently expose CHAT_MSG_WHISPER or SendChatMessage,
--        this module is detection-only — it alerts the user that a whisper arrived.
-- WHEN:  on game event callback.
-- WHY:   users want to know when someone whispers them while fishing (possible GM
--        or player interaction) so they can respond manually.
-- SAFETY: pcall on all API; no chat sending (API not available).

local APISurface = require("core/api_surface")

local M = {}

--- Handle a game event (called from game event dispatcher)
-- @param ctx table
-- @param event_name string
-- @param args table
function M.on_game_event(ctx, event_name, args)
    if not event_name then return end

    -- CHAT_MSG_WHISPER is not in Sylvanas' registered events yet,
    -- but we handle it in case it's added in the future.
    if event_name == "CHAT_MSG_WHISPER" then
        local sender = args and args[2] or "Unknown"
        local message = args and args[1] or ""
        local state = ctx.state
        local now = APISurface.now()

        -- Throttle responses (don't spam alerts for same sender)
        if sender == state.responder.last_sender
           and now - state.responder.last_response_time < 30.0 then
            return
        end

        state.responder.last_sender = sender
        state.responder.last_response_time = now
        state.responder.responses_total = state.responder.responses_total + 1

        APISurface.print("[EaxFishing] ⚠ Whisper from " .. tostring(sender) .. ": " .. tostring(message))

        -- Trigger alert overlay
        if state.alert then
            state.alert.active = true
            state.alert.text = "⚠ Whisper from " .. tostring(sender) .. "!"
            state.alert.fade_start = now
            state.alert.fade_end = now + 5.0
            state.alert.quality = 3 -- green (attention)
        end

        -- Play attention sound
        APISurface.play_sound_by_id(6193) -- PvP warning sound
    end
end

--- Reset responder state
function M.reset(state)
    if not state.responder then return end
    state.responder.last_response_time = 0.0
    state.responder.responses_total = 0
    state.responder.last_sender = ""
end

return M
