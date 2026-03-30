--- @module "NAG.SessionDebugLog"
--- In-memory NDJSON session log for debugging (WoW has no file I/O).
--- Any code can append via ns.SessionDebugLog.Append; use /nag debuglog for a scrollable copy UI.
--- Rotation timing/errors: Common.lua writes lines with meta.subsystem == "rotation" (filter in viewer).
---
--- Envelope (one JSON object per line): location, message, timestamp (ms), data (object).
--- Optional `meta`: nil, or a flat table encoded as JSON `"meta":{...}` (omit key when nil or empty).
---
--- License: CC BY-NC 4.0
--- Authors: Rakizi, Fonsas

-- ============================ LOCALIZE ============================
local _, ns = ...
--- @type NAG|AceAddon
local NAG = LibStub("AceAddon-3.0"):GetAddon("NAG")

local GetTime = _G.GetTime
local CreateFrame = _G.CreateFrame
local UIDropDownMenu_CreateInfo = _G.UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_SetText = _G.UIDropDownMenu_SetText
local UIDropDownMenu_SetWidth = _G.UIDropDownMenu_SetWidth
local max = math.max
local lower = string.lower
local sort = table.sort

-- ============================ JSON HELPERS (flat data only) ============================

local function escapeJsonString(s)
    return tostring(s or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n")
end

local function jsonEncodeValue(v)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        if v ~= v then
            return "null"
        end
        return tostring(v)
    elseif t == "string" then
        return '"' .. escapeJsonString(v) .. '"'
    end
    return '"' .. escapeJsonString(tostring(v)) .. '"'
end

--- Encode a flat table as JSON object (string keys; non-scalars become string placeholders).
--- @param d table|nil
--- @return string
local function jsonEncodeDataTable(d)
    if type(d) ~= "table" then
        return "{}"
    end
    local parts = {}
    for k, v in pairs(d) do
        if type(k) == "string" then
            if type(v) == "table" then
                parts[#parts + 1] = string.format('"%s":"%s"', escapeJsonString(k), escapeJsonString("<table>"))
            else
                parts[#parts + 1] = string.format('"%s":%s', escapeJsonString(k), jsonEncodeValue(v))
            end
        end
    end
    if #parts == 0 then
        return "{}"
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- ============================ NAMESPACE API ============================

--- Append one NDJSON line to NAG._debugSessionLog (safe before SessionDebugLog module exists).
--- @param location string e.g. "Module.lua:FunctionName"
--- @param message string short event name
--- @param data table|nil flat key-value for JSON "data"
--- @param meta table|nil optional flat table → JSON `"meta":{...}`; reuse one table per kind at call site to avoid allocs
function ns.SessionDebugLogAppend(location, message, data, meta)
    if meta ~= nil then
        assert(type(meta) == "table", "SessionDebugLogAppend: meta must be nil or a table")
    end
    local t = (GetTime() and (GetTime() * 1000)) or 0
    local dataStr = jsonEncodeDataTable(data)
    local metaEncoded = meta and jsonEncodeDataTable(meta) or "{}"
    local metaSuffix = ""
    if metaEncoded ~= "{}" then
        metaSuffix = ',"meta":' .. metaEncoded
    end
    local line = string.format(
        '{"location":"%s","message":"%s","timestamp":%.0f,"data":%s%s}',
        escapeJsonString(location or ""),
        escapeJsonString(message or ""),
        t,
        dataStr,
        metaSuffix
    )
    if not NAG._debugSessionLog then
        NAG._debugSessionLog = {}
    end
    table.insert(NAG._debugSessionLog, line)
end

function ns.SessionDebugLogClear()
    NAG._debugSessionLog = {}
end

ns.SessionDebugLog = ns.SessionDebugLog or {}
ns.SessionDebugLog.Append = ns.SessionDebugLogAppend
ns.SessionDebugLog.Clear = ns.SessionDebugLogClear

-- ============================ MODULE (viewer + slash) ============================

--- @class SessionDebugLog: CoreModule
local SessionDebugLog = NAG:CreateModule("SessionDebugLog", nil, {
    moduleType = ns.MODULE_TYPES.DEBUG,
    optionsCategory = ns.MODULE_CATEGORIES.DEBUG,
    optionsOrder = 108,
    hidden = function()
        return not NAG:IsDevModeEnabled()
    end,
    slashCommands = {
        ["debuglog"] = {
            handler = true,
            help = "Open debug session log viewer (scrollable, select-all to copy). Usage: /nag debuglog",
            root = "nag",
        },
    },
})

local MAX_LOG_LINES_IN_VIEWER = 10000
local LINE_HEIGHT = 14
local VIEWER_WIDTH = 600
local VIEWER_HEIGHT = 500
local VIEWER_MIN_WIDTH = 520
local VIEWER_MIN_HEIGHT = 360
local MODULE_FILTER_ALL = "All"

local function trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function extractModuleNameFromLogLine(line)
    if type(line) ~= "string" or line == "" then
        return nil
    end

    local subsystem = line:match('"subsystem":"([^"]+)"')
    if subsystem and subsystem ~= "" then
        return subsystem
    end

    local location = line:match('"location":"([^"]+)"')
    if not location or location == "" then
        return nil
    end

    local moduleName = location:match("^([^:]+)")
    if moduleName and moduleName ~= "" then
        return moduleName
    end

    return location
end

local function tokenizeFilterExpression(filterText)
    local tokens = {}
    local i = 1
    local n = #filterText

    while i <= n do
        local c = filterText:sub(i, i)
        if c:match("%s") then
            i = i + 1
        elseif c == "&" or c == "|" or c == "!" or c == "(" or c == ")" then
            tokens[#tokens + 1] = { kind = "op", value = c }
            i = i + 1
        else
            local startPos = i
            while i <= n do
                local ch = filterText:sub(i, i)
                if ch:match("%s") or ch == "&" or ch == "|" or ch == "!" or ch == "(" or ch == ")" then
                    break
                end
                i = i + 1
            end
            local term = filterText:sub(startPos, i - 1)
            if term ~= "" then
                tokens[#tokens + 1] = { kind = "term", value = lower(term) }
            end
        end
    end

    return tokens
end

local function opPrecedence(op)
    if op == "!" then return 3 end
    if op == "&" then return 2 end
    if op == "|" then return 1 end
    return 0
end

local function opIsRightAssociative(op)
    return op == "!"
end

local function compileFilterExpression(filterText)
    local expr = lower(trim(filterText or ""))
    if expr == "" then
        return { mode = "all" }
    end

    -- WoW text fields treat pipe specially; normalize textual operators so users
    -- can reliably express boolean filters without relying on "|".
    expr = expr:gsub("%f[%a]not%f[%A]", " ! ")
    expr = expr:gsub("%f[%a]and%f[%A]", " & ")
    expr = expr:gsub("%f[%a]or%f[%A]", " | ")
    expr = expr:gsub(",", " | ")
    expr = trim(expr)

    local hasBoolOps = expr:find("[&|!()]", 1) ~= nil
    if not hasBoolOps then
        return { mode = "plain", text = expr }
    end

    local tokens = tokenizeFilterExpression(expr)
    if #tokens == 0 then
        return { mode = "all" }
    end

    local output = {}
    local opStack = {}

    for i = 1, #tokens do
        local token = tokens[i]
        if token.kind == "term" then
            output[#output + 1] = token
        else
            local op = token.value
            if op == "(" then
                opStack[#opStack + 1] = op
            elseif op == ")" then
                local foundOpen = false
                while #opStack > 0 do
                    local top = opStack[#opStack]
                    opStack[#opStack] = nil
                    if top == "(" then
                        foundOpen = true
                        break
                    end
                    output[#output + 1] = { kind = "op", value = top }
                end
                if not foundOpen then
                    return { mode = "plain", text = expr }
                end
            else
                while #opStack > 0 do
                    local top = opStack[#opStack]
                    if top == "(" then
                        break
                    end
                    local topPrec = opPrecedence(top)
                    local curPrec = opPrecedence(op)
                    local shouldPop = (not opIsRightAssociative(op) and curPrec <= topPrec)
                        or (opIsRightAssociative(op) and curPrec < topPrec)
                    if not shouldPop then
                        break
                    end
                    opStack[#opStack] = nil
                    output[#output + 1] = { kind = "op", value = top }
                end
                opStack[#opStack + 1] = op
            end
        end
    end

    while #opStack > 0 do
        local top = opStack[#opStack]
        opStack[#opStack] = nil
        if top == "(" or top == ")" then
            return { mode = "plain", text = expr }
        end
        output[#output + 1] = { kind = "op", value = top }
    end

    return { mode = "expr", rpn = output, raw = expr }
end

local function matchesCompiledFilter(compiled, lowerLine)
    if compiled.mode == "all" then
        return true
    end
    if compiled.mode == "plain" then
        return lowerLine:find(compiled.text, 1, true) ~= nil
    end

    local stack = {}
    local rpn = compiled.rpn or {}
    for i = 1, #rpn do
        local token = rpn[i]
        if token.kind == "term" then
            stack[#stack + 1] = (lowerLine:find(token.value, 1, true) ~= nil)
        else
            local op = token.value
            if op == "!" then
                local a = stack[#stack]
                if a == nil then
                    return lowerLine:find(compiled.raw or "", 1, true) ~= nil
                end
                stack[#stack] = nil
                stack[#stack + 1] = not a
            elseif op == "&" or op == "|" then
                local b = stack[#stack]
                stack[#stack] = nil
                local a = stack[#stack]
                stack[#stack] = nil
                if a == nil or b == nil then
                    return lowerLine:find(compiled.raw or "", 1, true) ~= nil
                end
                if op == "&" then
                    stack[#stack + 1] = (a and b)
                else
                    stack[#stack + 1] = (a or b)
                end
            end
        end
    end

    if #stack ~= 1 then
        return lowerLine:find(compiled.raw or "", 1, true) ~= nil
    end
    return stack[1] == true
end

function SessionDebugLog:BuildModuleFilterOptions(log)
    local seen = {}
    local modules = { MODULE_FILTER_ALL }
    local total = #log

    for i = 1, total do
        local moduleName = extractModuleNameFromLogLine(log[i])
        if moduleName and not seen[moduleName] then
            seen[moduleName] = true
            modules[#modules + 1] = moduleName
        end
    end

    if #modules > 2 then
        local sortedModules = {}
        for i = 2, #modules do
            sortedModules[#sortedModules + 1] = modules[i]
        end
        sort(sortedModules)
        for i = 1, #sortedModules do
            modules[i + 1] = sortedModules[i]
        end
    end

    return modules
end

function SessionDebugLog:RefreshModuleDropdown()
    if not self._debugLogModuleDropdown then
        return
    end

    local selected = self._debugLogModuleFilter or MODULE_FILTER_ALL
    UIDropDownMenu_SetText(self._debugLogModuleDropdown, selected)
end

function SessionDebugLog:RefreshDebugLogViewer()
    if not self._debugLogEditBox or not self._debugLogScrollFrame then
        return
    end

    local log = NAG._debugSessionLog or {}
    local total = #log
    local compiledFilter = compileFilterExpression(self._debugLogTextFilter or "")
    local selectedModule = self._debugLogModuleFilter or MODULE_FILTER_ALL

    local filtered = {}
    for i = 1, total do
        local line = log[i] or ""
        local lowerLine = lower(line)
        local lineModule = extractModuleNameFromLogLine(line) or MODULE_FILTER_ALL
        local moduleMatches = (selectedModule == MODULE_FILTER_ALL) or (lineModule == selectedModule)
        if moduleMatches then
            if matchesCompiledFilter(compiledFilter, lowerLine) then
                filtered[#filtered + 1] = line
            end
        end
    end

    local lineCountFiltered = #filtered
    local startIdx = 1
    local capNote = ""
    if lineCountFiltered > MAX_LOG_LINES_IN_VIEWER then
        startIdx = lineCountFiltered - MAX_LOG_LINES_IN_VIEWER + 1
        capNote = "# Showing last " .. tostring(MAX_LOG_LINES_IN_VIEWER) .. " filtered lines of " .. tostring(lineCountFiltered) .. " matches.\n\n"
    end

    local lines = {}
    if capNote ~= "" then
        lines[1] = capNote
    end
    for i = startIdx, lineCountFiltered do
        lines[#lines + 1] = filtered[i] or ""
    end

    local text = table.concat(lines, "\n")
    if text == "" then
        text = "# Log is empty for current filters. Instrumentation calls ns.SessionDebugLog.Append(...) to capture entries."
    end

    local scrollWidth = self._debugLogScrollFrame:GetWidth() or VIEWER_WIDTH
    self._debugLogEditBox:SetWidth(max(220, scrollWidth - 8))
    self._debugLogEditBox:SetText(text)
    self._debugLogEditBox:SetCursorPosition(0)
    self._debugLogEditBox:ClearFocus()

    local renderedLineCount = lineCountFiltered
    if renderedLineCount > MAX_LOG_LINES_IN_VIEWER then
        renderedLineCount = MAX_LOG_LINES_IN_VIEWER
    end
    if renderedLineCount < 1 then
        renderedLineCount = 1
    end

    self._debugLogEditBox:SetHeight(max(VIEWER_HEIGHT, renderedLineCount * LINE_HEIGHT))
    self._debugLogScrollFrame:SetVerticalScroll(0)
    if self._debugLogStatusText then
        local shownCount = lineCountFiltered
        if shownCount > MAX_LOG_LINES_IN_VIEWER then
            shownCount = MAX_LOG_LINES_IN_VIEWER
        end
        self._debugLogStatusText:SetText(
            string.format("Lines shown: %d | Matches: %d | Total: %d", shownCount, lineCountFiltered, total)
        )
    end
    self:RefreshModuleDropdown()
end

--- Delete log lines that match the current module dropdown and text filter (same rules as the viewer).
--- With module "All" and an empty filter, every line matches — same effect as Clear all.
function SessionDebugLog:RemoveMatchingLinesFromStorage()
    local log = NAG._debugSessionLog or {}
    local compiledFilter = compileFilterExpression(self._debugLogTextFilter or "")
    local selectedModule = self._debugLogModuleFilter or MODULE_FILTER_ALL
    local newLog = {}
    for i = 1, #log do
        local line = log[i] or ""
        local lowerLine = lower(line)
        local lineModule = extractModuleNameFromLogLine(line) or MODULE_FILTER_ALL
        local moduleMatches = (selectedModule == MODULE_FILTER_ALL) or (lineModule == selectedModule)
        local wouldShow = moduleMatches and matchesCompiledFilter(compiledFilter, lowerLine)
        if not wouldShow then
            newLog[#newLog + 1] = line
        end
    end
    NAG._debugSessionLog = newLog
    self:RefreshDebugLogViewer()
end

function SessionDebugLog:UpdateViewerLayout()
    local f = self._debugLogFrame
    if not f or not self._debugLogSearchBox or not self._debugLogModuleDropdown then
        return
    end

    local frameWidth = f:GetWidth() or (VIEWER_WIDTH + 40)
    local controlsWidth = max(160, (frameWidth - 94) / 2)
    self._debugLogSearchBox:SetWidth(controlsWidth)
    UIDropDownMenu_SetWidth(self._debugLogModuleDropdown, controlsWidth)
end

--- Open or toggle the debug session log viewer (scrollable EditBox; select-all to copy).
function SessionDebugLog:debuglog()
    local log = NAG._debugSessionLog
    if not log then
        NAG._debugSessionLog = {}
        log = NAG._debugSessionLog
    end

    if self._debugLogFrame and self._debugLogFrame:IsShown() then
        self._debugLogFrame:Hide()
        return
    end

    if not self._debugLogFrame then
        local f = CreateFrame("Frame", "NAGDebugLogViewer", UIParent)
        f:SetFrameStrata("DIALOG")
        f:SetSize(VIEWER_WIDTH + 40, VIEWER_HEIGHT + 80)
        f:SetPoint("CENTER", 0, 0)
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
        else
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(f)
            if bg.SetColorTexture then
                bg:SetColorTexture(0, 0, 0, 0.85)
            else
                bg:SetTexture("Interface\\Buttons\\WHITE8x8")
                bg:SetVertexColor(0, 0, 0, 0.85)
            end
        end
        f:SetMovable(true)
        f:SetResizable(true)
        f:EnableMouse(true)
        if f.SetResizeBounds then
            f:SetResizeBounds(VIEWER_MIN_WIDTH, VIEWER_MIN_HEIGHT)
        elseif f.SetMinResize then
            f:SetMinResize(VIEWER_MIN_WIDTH, VIEWER_MIN_HEIGHT)
        end
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetScript("OnSizeChanged", function()
            self:UpdateViewerLayout()
            self:RefreshDebugLogViewer()
        end)
        f:Hide()

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -16)
        title:SetText("NAG Debug Session Log (select-all then Ctrl+C to copy)")

        local dragRegion = CreateFrame("Frame", nil, f)
        dragRegion:SetPoint("TOPLEFT", 16, -12)
        dragRegion:SetPoint("TOPRIGHT", -16, -12)
        dragRegion:SetHeight(24)
        dragRegion:EnableMouse(true)
        dragRegion:RegisterForDrag("LeftButton")
        dragRegion:SetScript("OnDragStart", function()
            f:StartMoving()
        end)
        dragRegion:SetScript("OnDragStop", function()
            f:StopMovingOrSizing()
        end)

        local searchBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        searchBox:SetSize(180, 22)
        searchBox:SetPoint("TOPLEFT", 24, -40)
        searchBox:SetAutoFocus(false)
        searchBox:SetScript("OnEscapePressed", function(box)
            box:ClearFocus()
        end)
        searchBox:SetScript("OnTextChanged", function(box)
            self._debugLogTextFilter = box:GetText() or ""
            self:RefreshDebugLogViewer()
        end)

        local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        searchLabel:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 2, 4)
        searchLabel:SetText("Filter text (!, &, |, (), or/and/not)")

        local moduleDropdown = CreateFrame("Frame", "NAGDebugLogModuleDropdown", f, "UIDropDownMenuTemplate")
        moduleDropdown:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 6, 8)
        UIDropDownMenu_SetWidth(moduleDropdown, 180)

        local scroll = CreateFrame("ScrollFrame", "NAGDebugLogScroll", f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 20, -72)
        scroll:SetPoint("BOTTOMRIGHT", -36, 44)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontHighlightSmall")
        edit:SetWidth(VIEWER_WIDTH)
        edit:SetScript("OnEscapePressed", function()
            f:Hide()
        end)
        scroll:SetScrollChild(edit)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(72, 22)
        closeBtn:SetPoint("BOTTOM", f, "BOTTOM", -102, 10)
        closeBtn:SetText("Close")
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        local removeShownBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        removeShownBtn:SetSize(102, 22)
        removeShownBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
        removeShownBtn:SetText("Remove shown")
        removeShownBtn:SetScript("OnClick", function()
            self:RemoveMatchingLinesFromStorage()
        end)

        local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        clearBtn:SetSize(78, 22)
        clearBtn:SetPoint("BOTTOM", f, "BOTTOM", 102, 10)
        clearBtn:SetText("Clear all")
        clearBtn:SetScript("OnClick", function()
            NAG._debugSessionLog = {}
            self:RefreshDebugLogViewer()
        end)

        local statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("BOTTOMLEFT", 22, 34)
        statusText:SetJustifyH("LEFT")
        statusText:SetText("Lines shown: 0 | Matches: 0 | Total: 0")

        local resizeHandle = CreateFrame("Button", nil, f)
        resizeHandle:SetSize(18, 18)
        resizeHandle:SetPoint("BOTTOMRIGHT", -8, 8)
        resizeHandle:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
        resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        resizeHandle:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" then
                return
            end
            f:StartSizing("BOTTOMRIGHT")
        end)
        resizeHandle:SetScript("OnMouseUp", function()
            f:StopMovingOrSizing()
        end)

        self._debugLogTextFilter = self._debugLogTextFilter or ""
        self._debugLogModuleFilter = self._debugLogModuleFilter or MODULE_FILTER_ALL

        searchBox:SetText(self._debugLogTextFilter)
        UIDropDownMenu_Initialize(moduleDropdown, function(_, _, _)
            local options = self:BuildModuleFilterOptions(NAG._debugSessionLog or {})
            local selected = self._debugLogModuleFilter or MODULE_FILTER_ALL
            local hasSelection = false
            for i = 1, #options do
                local moduleName = options[i]
                if moduleName == selected then
                    hasSelection = true
                end
                local info = UIDropDownMenu_CreateInfo()
                info.text = moduleName
                info.func = function()
                    self._debugLogModuleFilter = moduleName
                    self:RefreshDebugLogViewer()
                end
                info.checked = (moduleName == selected)
                _G.UIDropDownMenu_AddButton(info)
            end
            if not hasSelection then
                self._debugLogModuleFilter = MODULE_FILTER_ALL
            end
        end)

        self._debugLogFrame = f
        self._debugLogEditBox = edit
        self._debugLogScrollFrame = scroll
        self._debugLogSearchBox = searchBox
        self._debugLogModuleDropdown = moduleDropdown
        self._debugLogResizeHandle = resizeHandle
        self._debugLogDragRegion = dragRegion
        self._debugLogStatusText = statusText
    end

    self._debugLogTextFilter = self._debugLogTextFilter or ""
    self._debugLogModuleFilter = self._debugLogModuleFilter or MODULE_FILTER_ALL
    self:UpdateViewerLayout()
    if self._debugLogSearchBox then
        self._debugLogSearchBox:SetText(self._debugLogTextFilter)
    end
    self:RefreshDebugLogViewer()

    self._debugLogFrame:Show()
end
