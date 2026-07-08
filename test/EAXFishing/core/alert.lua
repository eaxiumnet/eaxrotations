-- =============================================================================
-- Core/Alert Module - Rare catch notifications with sound + text overlay
-- WHAT:  Plays a sound and draws a temporary on-screen alert when a rare/
--        valuable item is caught.
-- WHEN:  immediately after looting a notable item.
-- WHY:   users want to know when they hit the jackpot without staring at the
--        loot window.
-- SAFETY: pcall on sound play; no crash if sound API is missing.
-- =============================================================================

local APISurface = require("core/api_surface")

local M = {}

-- Alert display duration (seconds)
local ALERT_DURATION = 4.0
-- Quest Complete fanfare — universally recognized "rare drop" sound
local SOUND_QUEST_COMPLETE = 6294

--- Trigger a rare-catch alert.
-- @param ctx table context
-- @param item_name string
-- @param quality number 1=gray 2=white 3=green 4=blue
-- @param vendor_copper number? notable vendor value
function M.fire(ctx, item_name, quality, vendor_copper)
    local state = ctx.state
    local config = ctx.deps.config

    local alerts_on = false
    if config.menu.rare_alert_enabled and config.menu.rare_alert_enabled.get_state then
        alerts_on = config.menu.rare_alert_enabled:get_state()
    end
    if not alerts_on then return end

    local now = APISurface.now()

    -- Set alert state for the renderer
    state.alert.active = true
    state.alert.text = "★ Rare catch: " .. tostring(item_name) .. "!"
    state.alert.fade_start = now
    state.alert.fade_end = now + ALERT_DURATION
    state.alert.quality = quality or 2

    -- Play sound (pcall-guarded in api_surface)
    APISurface.play_sound_by_id(SOUND_QUEST_COMPLETE)
end

--- Get current alert color based on item quality.
-- @param quality number
-- @return table color {r,g,b,a}
function M.color_for_quality(quality)
    -- WoW item quality colors
    if quality == 4 then
        return {r = 0,   g = 112, b = 221, a = 255}   -- Blue (rare)
    elseif quality == 3 then
        return {r = 30,  g = 255, b = 0,   a = 255}   -- Green (uncommon)
    elseif quality == 5 then
        return {r = 163, g = 53,  b = 238, a = 255}   -- Purple (epic)
    else
        return {r = 255, g = 215, b = 0,   a = 255}   -- Gold fallback
    end
end

--- Draw the alert overlay (called from ui/render each frame).
-- @param ctx table context
-- @param now number current time
-- @param screen_cx number screen center X
-- @param screen_cy number screen center Y
function M.render(ctx, now, screen_cx, screen_cy)
    local state = ctx.state
    if not state.alert.active then return end

    -- Fade out
    if now >= state.alert.fade_end then
        state.alert.active = false
        return
    end

    local elapsed = now - state.alert.fade_start
    local progress = elapsed / (state.alert.fade_end - state.alert.fade_start)
    local alpha = math.floor(255 * (1.0 - progress))

    local color = M.color_for_quality(state.alert.quality)
    color.a = alpha

    -- Draw large centered text
    APISurface.draw_text_2d(
        state.alert.text,
        {x = screen_cx - 140, y = screen_cy - 60},
        22,
        color,
        false
    )
end

return M
