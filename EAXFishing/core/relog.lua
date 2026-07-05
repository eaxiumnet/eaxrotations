-- relog.lua — Disconnect detection and auto-relog alerting.
-- WHAT:  detects when the server connection drops and alerts the user.
--        Since Sylvanas does not expose a relog/login API from Lua scripts,
--        this module is detection-only — it alerts and logs the disconnect.
-- WHEN:  every tick (throttled), checks nav client server availability.
-- WHY:   overnight fishers need to know when they disconnect so they can
--        relog manually (or via external launcher script).
-- SAFETY: pcall on all API; detection-only (no relog action possible).

local APISurface = require("core/api_surface")

local M = {}

--- Check if the game server connection is still up
-- Uses nav client's is_server_available() as a proxy for server connection.
-- @param ctx table
-- @return boolean true if connected, false if disconnected
function M.is_connected(ctx)
    local Client = require("navigation/client")
    if not Client.has_client(ctx) then
        -- No nav client — can't detect disconnect this way.
        -- Assume connected (the player object existing is a good sign).
        return true
    end
    local client = Client.get_client(ctx)
    if client and type(client.is_server_available) == "function" then
        local ok, result = pcall(client.is_server_available, client)
        if ok then return result end
    end
    return true
end

--- Check for disconnect and alert
-- @param ctx table
-- @param now number
-- @return boolean true if disconnect was detected this tick
function M.check_disconnect(ctx, now)
    local state = ctx.state
    if not state.relog then return false end

    -- Throttle check (every 5s)
    if now - state.relog.last_check_time < 5.0 then return false end
    state.relog.last_check_time = now

    if not M.is_connected(ctx) then
        -- Only alert once per disconnect
        if state.relog.disconnected_at == 0.0 then
            state.relog.disconnected_at = now
            state.relog.relog_attempts = state.relog.relog_attempts + 1
            APISurface.print("[EaxFishing] ⚠⚠ Server connection lost! Relog required.")
            -- Trigger alert overlay
            if state.alert then
                state.alert.active = true
                state.alert.text = "⚠⚠ Disconnected! Relog required!"
                state.alert.fade_start = now
                state.alert.fade_end = now + 10.0
                state.alert.quality = 4 -- blue (urgent)
            end
            -- Play urgent sound
            APISurface.play_sound_by_id(6193)
            return true
        end
    else
        -- Connection restored — clear disconnect state
        if state.relog.disconnected_at > 0.0 then
            APISurface.print("[EaxFishing] ✓ Server connection restored.")
            state.relog.disconnected_at = 0.0
        end
    end

    return false
end

--- Reset relog state
function M.reset(state)
    if not state.relog then return end
    state.relog.disconnected_at = 0.0
    state.relog.relog_attempts = 0
    state.relog.last_relog_time = 0.0
    state.relog.last_check_time = 0.0
end

return M
