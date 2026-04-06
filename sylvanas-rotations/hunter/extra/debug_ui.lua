-- =============================================================================
-- DEBUG LOG FRAME - Scrollable debug output window
-- Converted from flux/rotation/source/aio/core.lua lines 217-570
-- =============================================================================

local core = _G.core
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local C_Timer = _G.C_Timer

-- =============================================================================
-- CONSTANTS
-- =============================================================================
local MAX_LOG_LINES = 500
local DBG_THEME = {
    bg = { 0.05, 0.05, 0.05, 0.95 },
    border = { 0.2, 0.2, 0.2, 1 },
    text = { 0.8, 0.8, 0.8, 1 },
    text_dim = { 0.5, 0.5, 0.5, 1 },
    accent = { 0.2, 0.6, 1, 1 },
}

-- =============================================================================
-- STATE
-- =============================================================================
local debug_log_lines = {}
local DebugLogFrame = nil
local last_log_text = ""

-- =============================================================================
-- FRAME CREATION
-- =============================================================================

local function CreateDebugLogFrame()
    if DebugLogFrame then return DebugLogFrame end

    local f = CreateFrame("Frame", "FluxAIODebugLog", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(450, 300)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    -- Title
    f.TitleBg:SetHeight(24)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.title:SetPoint("TOP", f.TitleBg, "TOP", 0, -6)
    f.title:SetText("Flux AIO Debug Log")

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -32)
    scrollFrame:SetPoint("BOTTOMRIGHT", -32, 44)
    scrollFrame:EnableMouseWheel(true)
    f.scrollFrame = scrollFrame

    -- Content frame
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetWidth(400)
    contentFrame:SetHeight(1)
    scrollFrame:SetScrollChild(contentFrame)
    f.contentFrame = contentFrame

    -- Text display
    local textDisplay = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textDisplay:SetPoint("TOPLEFT", 5, -5)
    textDisplay:SetWidth(400)
    textDisplay:SetJustifyH("LEFT")
    textDisplay:SetJustifyV("TOP")
    textDisplay:SetTextColor(DBG_THEME.text[1], DBG_THEME.text[2], DBG_THEME.text[3])
    f.textDisplay = textDisplay

    -- Copy button
    local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    copyBtn:SetSize(60, 20)
    copyBtn:SetPoint("BOTTOMLEFT", 12, 12)
    copyBtn:SetText("Copy")
    f.copyBtn = copyBtn

    -- Clear button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("BOTTOMLEFT", copyBtn, "BOTTOMRIGHT", 8, 0)
    clearBtn:SetText("Clear")
    f.clearBtn = clearBtn

    -- Copy popup
    local copyPopup = CreateFrame("Frame", nil, f, "BasicFrameTemplateWithInset")
    copyPopup:SetSize(440, 300)
    copyPopup:SetPoint("CENTER", f, "CENTER", 0, 0)
    copyPopup:SetFrameStrata("FULLSCREEN_DIALOG")
    copyPopup:Hide()
    f.copyPopup = copyPopup

    local copyTitle = copyPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    copyTitle:SetPoint("TOP", copyPopup.TitleBg, "TOP", 0, -6)
    copyTitle:SetText("Copy Log")

    local copyScroll = CreateFrame("ScrollFrame", nil, copyPopup, "UIPanelScrollFrameTemplate")
    copyScroll:SetPoint("TOPLEFT", 12, -32)
    copyScroll:SetPoint("BOTTOMRIGHT", -32, 12)

    local copyEdit = CreateFrame("EditBox", nil, copyScroll)
    copyEdit:SetMultiLine(true)
    copyEdit:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    copyEdit:SetWidth(380)
    copyEdit:SetAutoFocus(false)
    copyEdit:EnableMouse(true)
    copyEdit:SetScript("OnEscapePressed", function() copyPopup:Hide() end)
    copyScroll:SetScrollChild(copyEdit)
    f.copyEditBox = copyEdit

    -- Button handlers
    copyBtn:SetScript("OnClick", function()
        local logText = table.concat(debug_log_lines, "\n")
        f.copyEditBox:SetText(logText)
        copyPopup:Show()
        f.copyEditBox:SetFocus()
        f.copyEditBox:HighlightText()
    end)

    clearBtn:SetScript("OnClick", function()
        debug_log_lines = {}
        textDisplay:SetText("")
        contentFrame:SetHeight(1)
    end)

    -- Resize grip
    local resizeBtn = CreateFrame("Button", nil, f)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetPoint("BOTTOMRIGHT", -2, 2)
    local resizeTex = resizeBtn:CreateTexture(nil, "OVERLAY")
    resizeTex:SetAllPoints()
    resizeTex:SetColorTexture(DBG_THEME.border[1], DBG_THEME.border[2], DBG_THEME.border[3], 0.6)
    resizeBtn:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    resizeBtn:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        contentFrame:SetWidth(scrollFrame:GetWidth() - 10)
        textDisplay:SetWidth(scrollFrame:GetWidth() - 10)
    end)

    -- Hint text
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 140, 16)
    hint:SetText("/fluxlog to toggle")
    hint:SetTextColor(DBG_THEME.text_dim[1], DBG_THEME.text_dim[2], DBG_THEME.text_dim[3])

    f:Hide()
    DebugLogFrame = f
    return f
end

-- =============================================================================
-- LOGGING API
-- =============================================================================

local function AddDebugLogLine(text)
    table.insert(debug_log_lines, text)
    while #debug_log_lines > MAX_LOG_LINES do
        table.remove(debug_log_lines, 1)
    end

    if DebugLogFrame and DebugLogFrame:IsShown() then
        local logText = table.concat(debug_log_lines, "\n")
        DebugLogFrame.textDisplay:SetText(logText)
        local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
        DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
        C_Timer.After(0.01, function()
            if DebugLogFrame and DebugLogFrame.scrollFrame then
                DebugLogFrame.scrollFrame:SetVerticalScroll(DebugLogFrame.scrollFrame:GetVerticalScrollRange())
            end
        end)
    end
end

local function RefreshDebugLogFrame()
    if DebugLogFrame and DebugLogFrame.textDisplay then
        local logText = table.concat(debug_log_lines, "\n")
        DebugLogFrame.textDisplay:SetText(logText)
        local textHeight = DebugLogFrame.textDisplay:GetStringHeight() or 1
        DebugLogFrame.contentFrame:SetHeight(textHeight + 10)
    end
end

local function ToggleDebugLogFrame()
    local f = CreateDebugLogFrame()
    if f:IsShown() then
        f:Hide()
    else
        RefreshDebugLogFrame()
        f:Show()
    end
end

-- =============================================================================
-- EXPORT
-- =============================================================================

return {
    AddDebugLogLine = AddDebugLogLine,
    RefreshDebugLogFrame = RefreshDebugLogFrame,
    ToggleDebugLogFrame = ToggleDebugLogFrame,
    CreateDebugLogFrame = CreateDebugLogFrame,
}


