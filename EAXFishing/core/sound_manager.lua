-- sound_manager.lua — Configurable sound alerts for fishing events.
-- WHAT:  plays distinct sounds for user-configurable events (bags full, pool
--        depleted, lure expiring, whisper, disconnect, level up).
-- WHEN:  called by the engine when specific events occur.
-- WHY:   users want audio feedback without watching the screen — different
--        sounds for different events so they know what happened.
-- SAFETY: pcall on all sound plays; menu-guarded per event.

local APISurface = require("core/api_surface")

local M = {}

-- Sound IDs (WoW sound effect IDs)
M.SOUND_RARE_CATCH     = 6294  -- Quest Complete fanfare
M.SOUND_BAGS_FULL      = 6193  -- PvP warning (attention-grabbing)
M.SOUND_POOL_DEPLETED  = 4157  -- Trade window close (subtle "done")
M.SOUND_LURE_EXPIRING  = 11742 -- Soft chime
M.SOUND_WHISPER        = 1031  -- Whisper notification
M.SOUND_DISCONNECT     = 8192  -- Error buzzer
M.SOUND_LEVEL_UP       = 6194  -- Level up fanfare
M.SOUND_CATCH          = 3674  -- Soft splash (subtle catch confirmation)

--- Play a sound for a specific event if the user has it enabled
-- @param ctx table
-- @param event_name string one of: "rare", "bags_full", "pool_depleted",
--        "lure_expiring", "whisper", "disconnect", "level_up", "catch"
function M.play_for_event(ctx, event_name)
    local config = ctx.deps.config
    if not config.menu then return end

    -- Master sound toggle
    if config.menu.sound_alerts_enabled
       and config.menu.sound_alerts_enabled.get_state
       and not config.menu.sound_alerts_enabled:get_state() then
        return
    end

    -- Per-event sound IDs
    local sound_map = {
        rare           = M.SOUND_RARE_CATCH,
        bags_full      = M.SOUND_BAGS_FULL,
        pool_depleted  = M.SOUND_POOL_DEPLETED,
        lure_expiring  = M.SOUND_LURE_EXPIRING,
        whisper        = M.SOUND_WHISPER,
        disconnect     = M.SOUND_DISCONNECT,
        level_up       = M.SOUND_LEVEL_UP,
        catch          = M.SOUND_CATCH,
    }

    local sound_id = sound_map[event_name]
    if not sound_id then return end

    -- Check per-event toggle
    local toggle_key = "sound_" .. event_name
    local toggle = config.menu[toggle_key]
    if toggle and toggle.get_state and not toggle:get_state() then
        return
    end

    APISurface.play_sound_by_id(sound_id)
end

return M
