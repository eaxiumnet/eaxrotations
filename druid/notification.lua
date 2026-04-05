-- =============================================================================
-- NOTIFICATION SYSTEM - Center-screen text notifications
-- Converted from flux/rotation/source/aio/core.lua lines 88-132
-- =============================================================================

local core = _G.core
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

-- Hot-path API caching (EAX pattern)
local _core_game_time = core.game_time

-- =============================================================================
-- NOTIFICATION FRAME
-- =============================================================================
local notif_frame = CreateFrame("Frame", "FluxAIONotification", UIParent)
notif_frame:SetSize(300, 40)
notif_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
notif_frame:SetFrameStrata("HIGH")
notif_frame:Hide()

local notif_text = notif_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
notif_text:SetPoint("CENTER")
notif_text:SetFont(notif_text:GetFont() or "Fonts\\FRIZQT__.TTF", 22, "OUTLINE")

local notif_fade_start = 0
local notif_fade_duration = 0.4
local notif_visible_until = 0

notif_frame:SetScript("OnUpdate", function(self, elapsed)
    local now = _core_game_time()
    if now < notif_visible_until then
        notif_text:SetAlpha(1)
    elseif now < notif_visible_until + notif_fade_duration then
        local progress = (now - notif_visible_until) / notif_fade_duration
        notif_text:SetAlpha(1 - progress)
    else
        notif_text:SetAlpha(0)
        self:Hide()
    end
end)

-- =============================================================================
-- NOTIFICATION API
-- =============================================================================

---Show a center-screen notification
---@param text string The text to display
---@param duration number|nil Duration in seconds (default: 1.5)
---@param color table|nil RGB color table {r, g, b} (default: white)
local function show_notification(text, duration, color)
    duration = duration or 1.5
    color = color or { 1, 1, 1 }
    notif_text:SetText(text)
    notif_text:SetTextColor(color[1], color[2], color[3], 1)
    notif_visible_until = _core_game_time() + duration
    notif_frame:Show()
end

-- =============================================================================
-- EXPORT
-- =============================================================================

return {
    show_notification = show_notification,
}


