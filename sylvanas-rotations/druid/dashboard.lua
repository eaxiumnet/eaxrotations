-- =============================================================================
-- COMBAT DASHBOARD - Simplified Flux AIO Dashboard
-- Converted from flux/rotation/source/aio/dashboard.lua (54KB → core features)
-- Features: Resource bar, cooldowns, buffs/debuffs, target info, toggle
-- =============================================================================

local core = _G.core
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local izi = require("izi_sdk")

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local FRAME_WIDTH = 170
local ICON_SIZE = 22
local MAX_COOLDOWNS = 8
local MAX_BUFFS = 6
local MAX_DEBUFFS = 6
local UPDATE_INTERVAL = 0.1  -- 10Hz update

local THEME = {
    bg = { 0.05, 0.05, 0.05, 0.95 },
    border = { 0.2, 0.2, 0.2, 1 },
    text = { 0.8, 0.8, 0.8, 1 },
    accent = { 0.2, 0.6, 1, 1 },
    rage = { 1.0, 0.2, 0.2 },
    energy = { 1.0, 0.8, 0.2 },
    mana = { 0.2, 0.4, 1.0 },
}

-- =============================================================================
-- STATE
-- =============================================================================
local dashboard_frame = nil
local is_visible = false
local cooldown_icons = {}
local buff_icons = {}
local debuff_icons = {}

-- =============================================================================
-- FRAME CREATION
-- =============================================================================

local function create_dashboard_frame()
    if dashboard_frame then return dashboard_frame end
    
    local f = CreateFrame("Frame", "FluxAIODashboard", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(FRAME_WIDTH, 250)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    
    -- Title
    f.TitleBg:SetHeight(20)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -5)
    f.title:SetText("Flux AIO")
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
        is_visible = false
    end)
    
    -- Resource bar
    local resourceBar = CreateFrame("StatusBar", nil, f)
    resourceBar:SetSize(FRAME_WIDTH - 20, 16)
    resourceBar:SetPoint("TOP", f, "TOP", 0, -28)
    resourceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    resourceBar:SetMinMaxValues(0, 100)
    resourceBar:SetValue(50)
    f.resourceBar = resourceBar
    
    local resourceText = resourceBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resourceText:SetPoint("CENTER", resourceBar, "CENTER", 0, 0)
    resourceText:SetText("Resource")
    f.resourceText = resourceText
    
    -- Target info
    local targetText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetText:SetPoint("TOP", resourceBar, "BOTTOM", 0, -8)
    targetText:SetWidth(FRAME_WIDTH - 20)
    targetText:SetJustifyH("LEFT")
    targetText:SetText("Target: None")
    targetText:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    f.targetText = targetText
    
    -- Cooldown icons section
    local cdLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cdLabel:SetPoint("TOP", targetText, "BOTTOM", 0, -10)
    cdLabel:SetText("Cooldowns")
    cdLabel:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    
    for i = 1, MAX_COOLDOWNS do
        local icon = CreateFrame("Frame", nil, f)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        icon:SetPoint("TOPLEFT", cdLabel, "BOTTOMLEFT", col * (ICON_SIZE + 2), -5 - row * (ICON_SIZE + 2))
        
        local tex = icon:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetColorTexture(0.2, 0.2, 0.2)
        icon.texture = tex
        
        local cdText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        cdText:SetPoint("CENTER", icon, "CENTER", 0, 0)
        cdText:SetText("")
        icon.cdText = cdText
        
        icon:Hide()
        cooldown_icons[i] = icon
    end
    
    -- Resize grip
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetColorTexture(THEME.border[1], THEME.border[2], THEME.border[3], 0.6)
    resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
    
    f:SetResizeBounds(150, 100, 300, 400)
    
    dashboard_frame = f
    return f
end

-- =============================================================================
-- UPDATE FUNCTION
-- =============================================================================

local function update_dashboard()
    if not dashboard_frame or not dashboard_frame:IsShown() then return end
    
    local me = izi.me()
    local target = izi.target()
    
    if not me then return end
    
    -- Update resource bar
    local powerType = me:power_type()
    local powerCurrent = me:power_current()
    local powerMax = me:power_max()
    local powerPct = (powerMax > 0) and (powerCurrent / powerMax * 100) or 0
    
    dashboard_frame.resourceBar:SetValue(powerPct)
    dashboard_frame.resourceBar:SetText(string.format("%d/%d", powerCurrent, powerMax))
    
    -- Color by power type
    if powerType == 1 then  -- Rage
        dashboard_frame.resourceBar:SetStatusBarColor(THEME.rage[1], THEME.rage[2], THEME.rage[3])
    elseif powerType == 3 then  -- Energy
        dashboard_frame.resourceBar:SetStatusBarColor(THEME.energy[1], THEME.energy[2], THEME.energy[3])
    else  -- Mana/Focus
        dashboard_frame.resourceBar:SetStatusBarColor(THEME.mana[1], THEME.mana[2], THEME.mana[3])
    end
    
    -- Update target info
    if target and target:is_valid() then
        local targetHp = target:get_health_percentage() or 0
        local ttd = target:time_to_die() or 999
        local targetName = target:name() or "Unknown"
        
        dashboard_frame.targetText:SetText(
            string.format("%s\nHP: %.0f%% | TTD: %.1fs", targetName, targetHp, ttd)
        )
    else
        dashboard_frame.targetText:SetText("Target: None")
    end
end

-- =============================================================================
-- TOGGLE API
-- =============================================================================

local function toggle_dashboard()
    local f = create_dashboard_frame()
    if f:IsShown() then
        f:Hide()
        is_visible = false
    else
        f:Show()
        is_visible = true
        update_dashboard()
    end
end

local function show_dashboard()
    local f = create_dashboard_frame()
    f:Show()
    is_visible = true
end

local function hide_dashboard()
    if dashboard_frame then
        dashboard_frame:Hide()
        is_visible = false
    end
end

local function is_dashboard_visible()
    return is_visible
end

-- =============================================================================
-- UPDATE TIMER
-- =============================================================================

local update_frame = CreateFrame("Frame")
update_frame.elapsed = 0
update_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= UPDATE_INTERVAL then
        self.elapsed = 0
        update_dashboard()
    end
end)

-- =============================================================================
-- SETTING WATCHER
-- =============================================================================

local SettingsBridge = require("settings_bridge")

local watch_frame = CreateFrame("Frame")
watch_frame.elapsed = 0
watch_frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.5 then
        self.elapsed = 0
        local show = SettingsBridge:get("dashboard.show", false)
        if show and not is_visible then
            show_dashboard()
        elseif not show and is_visible then
            hide_dashboard()
        end
    end
end)

-- =============================================================================
-- EXPORT
-- =============================================================================

return {
    toggle = toggle_dashboard,
    show = show_dashboard,
    hide = hide_dashboard,
    is_visible = is_dashboard_visible,
    update = update_dashboard,
    create = create_dashboard_frame,
}


