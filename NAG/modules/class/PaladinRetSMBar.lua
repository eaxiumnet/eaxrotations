--- @module "NAG.PaladinRetSMBar"
--- Guitar-hero style action bar driven by PaladinRetStateMachine timeline.
---
--- Shows predicted action icons (SoC/Twist/CS/Judge/Filler) scrolling right-to-left
--- toward a hit zone at the left edge.  Displays state0 (NOW) plus the next 2
--- predicted swing cycles — giving the player a 2-swing lookahead.
---
--- Mirrors the HunterStateMachineBar pattern exactly for consistency.
---
--- License: CC BY-NC 4.0
--- Authors: Rakizi, Fonsas

-- ============================ LOCALIZE ============================
local _, ns = ...

local GetTime = _G.GetTime
local UnitClassBase = _G.UnitClassBase
local UnitAffectingCombat = _G.UnitAffectingCombat
local CreateFrame = _G.CreateFrame
local GetSpellTexture = _G.GetSpellTexture
local abs = math.abs

--- @type NAG|AceAddon
local NAG = LibStub("AceAddon-3.0"):GetAddon("NAG")
local Version = ns.Version

-- ============================ CONSTANTS ============================
local UPDATE_INTERVAL = 0.016
local DEFAULT_HORIZON_SECONDS = 6.0
local DEFAULT_SNAPSHOT_INTERVAL_SECONDS = 0.08
local PAST_TOLERANCE_SECONDS = 0.2
local MAX_ACTION_ICONS = 48
local SECONDS_EPSILON = 0.0001
local HOLD_SMOOTH_REFRESH_INTERVAL = 0.10
local HOLD_SMOOTH_SNAP_THRESHOLD = 0.20
local ICON_GCD_SUPPRESS_SECONDS = 0.12
local ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS = 0.35
local ICON_NEAR_ZERO_WINDOW_SECONDS = 0.30
local PREDICTION_FADE_TOTAL_SECONDS = 0.30
local PREDICTION_FADE_HOLD_TRANSPARENT_SECONDS = 0.10
local ZERO_STICK_REFRESH_MAX_SECONDS = 1.0

-- ============================ DEFAULTS ============================
local defaults = {
    class = {
        enabled = false,
        hideOutOfCombat = false,

        autoAnchor = true,
        lockToRetBar = true,
        point = "CENTER",
        x = 0,
        y = -30,

        width = 220,
        height = 20,
        alpha = 0.90,
        horizonSeconds = DEFAULT_HORIZON_SECONDS,
        snapshotIntervalSeconds = DEFAULT_SNAPSHOT_INTERVAL_SECONDS,
        iconSize = 16,
        sparkSmoothing = 0.28,

        showBackground = true,
        showHitZone = true,
        showSwingMarkers = true,
        showStateLabels = false,
        backgroundColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.40 },
        hitZoneColor = { r = 1.0, g = 1.0, b = 1.0, a = 0.80 },
        swingMarkerColor = { r = 0.5, g = 0.5, b = 0.5, a = 0.35 },
    }
}

--- @class PaladinRetSMBar:CoreModule
local PaladinRetSMBar = NAG:CreateModule("PaladinRetSMBar", defaults, {
    moduleType = ns.MODULE_TYPES.CLASS,
    className = "PALADIN",
    optionsCategory = ns.MODULE_CATEGORIES.CLASS,
    messageHandlers = {
        NAG_FRAME_UPDATED = true,
        NAG_PALADIN_BAR_SCALE_UPDATED = true,
    },
    hidden = function()
        return UnitClassBase("player") ~= "PALADIN"
    end,
})

ns.PaladinRetSMBar = PaladinRetSMBar
local module = PaladinRetSMBar

-- ============================ LOCALS ============================
local frame
local background
local hitZone
local swingMarkers = {}
local lastUpdate = 0
local lastSnapshotAt = 0
local cachedActions = {}
local cachedSwingTimes = {}
local holdSmoothState = {}
local visibleActionKeys = {}

-- ============================ HELPERS ============================
local function Clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function SetSizeIfChanged(target, width, height)
    if not target then return end
    if target._nagWidth ~= width or target._nagHeight ~= height then
        target:SetSize(width, height)
        target._nagWidth = width
        target._nagHeight = height
    end
end

local function SetAlphaIfChanged(target, alpha)
    if not target then return end
    if target._nagAlpha ~= alpha then
        target:SetAlpha(alpha)
        target._nagAlpha = alpha
    end
end

local function SetShownIfChanged(target, shouldShow)
    if not target then return end
    if shouldShow then
        if not target:IsShown() then
            target:Show()
        end
    elseif target:IsShown() then
        target:Hide()
    end
end

local function SetTextureIfChanged(textureRegion, texturePath)
    if not textureRegion then return end
    if textureRegion._nagTexture ~= texturePath then
        textureRegion:SetTexture(texturePath)
        textureRegion._nagTexture = texturePath
    end
end

local function SetColorTextureIfChanged(textureRegion, r, g, b, a)
    if not textureRegion then return end
    if textureRegion._nagR ~= r
        or textureRegion._nagG ~= g
        or textureRegion._nagB ~= b
        or textureRegion._nagA ~= a then
        textureRegion:SetColorTexture(r, g, b, a)
        textureRegion._nagR = r
        textureRegion._nagG = g
        textureRegion._nagB = b
        textureRegion._nagA = a
    end
end

local function SetCenterPointIfChanged(target, relativeTo, x, y)
    if not target then return end
    if target._nagPointRelative ~= relativeTo
        or target._nagPointX ~= x
        or target._nagPointY ~= y then
        target:ClearAllPoints()
        target:SetPoint("CENTER", relativeTo, "LEFT", x, y)
        target._nagPointRelative = relativeTo
        target._nagPointX = x
        target._nagPointY = y
    end
end

--- @param spellId number
--- @return string
local function GetSpellIcon(spellId)
    if spellId and spellId > 0 then
        if NAG and NAG.Spell and NAG.Spell[spellId] and NAG.Spell[spellId].icon then
            return NAG.Spell[spellId].icon
        end
        local tex = GetSpellTexture(spellId)
        if tex then return tex end

        if NAG and NAG.ResolveEffectiveSpellId then
            local resolved = NAG:ResolveEffectiveSpellId(spellId)
            if resolved and resolved ~= spellId then
                if NAG.Spell and NAG.Spell[resolved] and NAG.Spell[resolved].icon then
                    return NAG.Spell[resolved].icon
                end
                local tex2 = GetSpellTexture(resolved)
                if tex2 then return tex2 end
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ResolveHorizonSeconds(db)
    local horizon = tonumber(db and db.horizonSeconds or DEFAULT_HORIZON_SECONDS) or DEFAULT_HORIZON_SECONDS
    if horizon <= 0 then horizon = DEFAULT_HORIZON_SECONDS end
    return horizon
end

local function ResolveSnapshotInterval(db)
    local interval = tonumber(db and db.snapshotIntervalSeconds or DEFAULT_SNAPSHOT_INTERVAL_SECONDS)
        or DEFAULT_SNAPSHOT_INTERVAL_SECONDS
    if interval < 0 then interval = 0 end
    return interval
end

local function BuildActionVisualKey(entry)
    if not entry then
        return "missing"
    end
    return table.concat({
        tostring(entry.stateIndex or 0),
        tostring(entry.slot or 0),
        tostring(entry.spellId or 0),
        tostring(entry.label or ""),
    }, ":")
end

local function ClearActionVisualState(self, stateKey)
    if not stateKey then
        return
    end
    holdSmoothState[stateKey] = nil
    self._zeroStickState = self._zeroStickState or {}
    self._predictionIconFadeState = self._predictionIconFadeState or {}
    self._iconSuppressState = self._iconSuppressState or {}
    self._zeroStickState[stateKey] = nil
    self._predictionIconFadeState[stateKey] = nil
    self._iconSuppressState[stateKey] = nil
end

local function GetZeroStickStableDelay(self, stateKey, delay, isDisplayed)
    self._zeroStickState = self._zeroStickState or {}

    if not isDisplayed or delay == nil then
        self._zeroStickState[stateKey] = nil
        return delay
    end

    local normalized = delay
    if normalized < 0 then
        normalized = 0
    end

    if normalized <= SECONDS_EPSILON then
        self._zeroStickState[stateKey] = true
        return 0
    end

    if self._zeroStickState[stateKey] and normalized < ZERO_STICK_REFRESH_MAX_SECONDS then
        return 0
    end

    if normalized >= ZERO_STICK_REFRESH_MAX_SECONDS then
        self._zeroStickState[stateKey] = nil
    end

    return normalized
end

local function GetPredictionIconFadeAlpha(self, stateKey, shouldBeVisible, now)
    self._predictionIconFadeState = self._predictionIconFadeState or {}

    if not shouldBeVisible then
        self._predictionIconFadeState[stateKey] = nil
        return 1
    end

    local state = self._predictionIconFadeState[stateKey]
    if not state then
        state = { shownAt = now }
        self._predictionIconFadeState[stateKey] = state
    end

    local elapsed = now - (state.shownAt or now)
    if elapsed < 0 then
        elapsed = 0
    end
    if elapsed <= PREDICTION_FADE_HOLD_TRANSPARENT_SECONDS then
        return 0
    end
    if elapsed >= PREDICTION_FADE_TOTAL_SECONDS then
        return 1
    end

    local fadeWindow = PREDICTION_FADE_TOTAL_SECONDS - PREDICTION_FADE_HOLD_TRANSPARENT_SECONDS
    if fadeWindow <= 0 then
        return 1
    end

    local t = (elapsed - PREDICTION_FADE_HOLD_TRANSPARENT_SECONDS) / fadeWindow
    return Clamp(t, 0, 1)
end

local function GetSmoothedHoldDelay(stateKey, rawDelay, now)
    local currentTime = now or GetTime() or 0
    local raw = rawDelay or 0
    if raw < 0 then
        raw = 0
    end

    local state = holdSmoothState[stateKey]
    if not state then
        holdSmoothState[stateKey] = {
            sampledDelay = raw,
            sampledAt = currentTime,
            nextRefreshAt = currentTime + HOLD_SMOOTH_REFRESH_INTERVAL,
        }
        return raw
    end

    local predicted = state.sampledDelay - (currentTime - state.sampledAt)
    if predicted < 0 then
        predicted = 0
    end

    local shouldRefresh = false
    if currentTime >= (state.nextRefreshAt or 0) then
        shouldRefresh = true
    end
    if abs(raw - predicted) > HOLD_SMOOTH_SNAP_THRESHOLD then
        shouldRefresh = true
    end
    if predicted <= 0 and raw > 0 then
        shouldRefresh = true
    end

    if shouldRefresh then
        state.sampledDelay = raw
        state.sampledAt = currentTime
        state.nextRefreshAt = currentTime + HOLD_SMOOTH_REFRESH_INTERVAL
        if raw > predicted then
            return predicted + ((raw - predicted) * 0.25)
        end
        return raw
    end

    return predicted
end

local function GetJumpSuppressAlpha(self, stateKey, displayDelay, shouldBeVisible, now)
    self._iconSuppressState = self._iconSuppressState or {}

    if not shouldBeVisible then
        self._iconSuppressState[stateKey] = nil
        return 1
    end

    local normalized = displayDelay or 0
    if normalized < 0 then
        normalized = 0
    end

    local state = self._iconSuppressState[stateKey]
    if not state then
        state = { lastDelay = normalized, suppressUntil = 0 }
        self._iconSuppressState[stateKey] = state
    else
        local previous = tonumber(state.lastDelay or 0) or 0
        if previous <= ICON_NEAR_ZERO_WINDOW_SECONDS
            and (normalized - previous) >= ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS
        then
            state.suppressUntil = now + ICON_GCD_SUPPRESS_SECONDS
        end
        state.lastDelay = normalized
    end

    if (tonumber(state.suppressUntil or 0) or 0) > now then
        return 0
    end
    return 1
end

-- ============================ ACTION COLLECTION ============================

--- Push a single action moment into the actions array.
--- @param actions table
--- @param at number|nil Absolute time
--- @param spellId number
--- @param slot number 1=primary, 2=secondary (filler/judge)
--- @param stateIndex number
--- @param label string|nil Short label for debug
local function PushAction(actions, at, spellId, slot, stateIndex, label)
    local ts = tonumber(at or 0) or 0
    if ts <= 0 then return end
    local sid = tonumber(spellId or 0) or 0
    if sid <= 0 then return end
    actions[#actions + 1] = {
        at = ts,
        spellId = sid,
        slot = slot or 1,
        stateIndex = tonumber(stateIndex) or 0,
        label = label,
    }
end

--- Extract displayable actions from one state record.
--- @param state table|nil
--- @param actions table
--- @param stateIndex number
local function CollectStateActions(state, actions, stateIndex)
    if not state then return end
    local sidx = tonumber(stateIndex) or 0
    local actionAt = tonumber(state.actionAt or 0) or 0
    local actionSpellId = tonumber(state.actionSpellId or 0) or 0

    -- Primary action
    if actionAt > 0 and actionSpellId > 0 then
        PushAction(actions, actionAt, actionSpellId, 1, sidx, state.action)
    end

    -- Filler (secondary slot): only when state machine flagged filler fits.
    if state.fillerFlag then
        local fillerAt = tonumber(state.fillerAt or 0) or 0
        local fillerSpellId = tonumber(state.fillerSpellId or 0) or 0
        if fillerAt > 0 and fillerSpellId > 0 then
            PushAction(actions, fillerAt, fillerSpellId, 2, sidx, state.fillerAction)
        end
    end

    -- Judge+SoC sequence: when action is judge_soc, primary shows Judge,
    -- secondary shows the SoC seal that immediately follows.
    if state.action == "judge_soc" then
        local socSpellId = tonumber(state.socFollowUpSpellId or 0) or 0
        if socSpellId > 0 and actionAt > 0 then
            PushAction(actions, actionAt, socSpellId, 2, sidx, "soc_followup")
        end
    else
        -- Standalone judge (secondary slot) — for non-judge_soc states that still flag judge
        local judgeAt = tonumber(state.judgeAt or 0) or 0
        local judgeSpellId = tonumber(state.judgeSpellId or 0) or 0
        if judgeAt > 0 and judgeSpellId > 0 and judgeSpellId ~= actionSpellId then
            PushAction(actions, judgeAt, judgeSpellId, 2, sidx, "judge")
        end
    end
end

--- Collect swing end times for vertical markers.
--- @param timeline table
--- @param now number
--- @param horizonSeconds number
--- @return table swingTimes Array of absolute swing-end times
local function CollectSwingTimes(timeline, now, horizonSeconds)
    local times = {}
    if not timeline or timeline.ok ~= true then return times end
    local horizonAt = now + horizonSeconds

    if timeline.state0 then
        local t = tonumber(timeline.state0.swingEndAt or 0) or 0
        if t > now and t <= horizonAt then
            times[#times + 1] = t
        end
    end

    -- No future states in next-action-only mode.
    return times
end

--- Build the full action list from a timeline prediction.
--- @param timeline table|nil
--- @param now number
--- @param horizonSeconds number
--- @return table actions Sorted array of { at, spellId, slot, stateIndex }
local function CollectActionMoments(timeline, now, horizonSeconds)
    if not timeline or timeline.ok ~= true then
        return {}
    end
    if NAG and NAG.RetSMCollectActionMoments then
        -- Consume state0 + one future state so the next action-in-line can render ahead.
        return NAG:RetSMCollectActionMoments(timeline, now, horizonSeconds, 2)
    end
    return {}
end

-- ============================ PREDICTION BRIDGE ============================

--- Get the state machine timeline prediction.
--- Uses cached prediction when available (respects event-driven invalidation).
--- Falls back to direct PredictLive if the cached path isn't available.
--- @param horizonSeconds number
--- @return table|nil
local function PredictTimeline(horizonSeconds)
    local sm = NAG:GetModule("PaladinRetStateMachine", true)
    if sm then
        if sm.GetCachedPrediction then
            return sm:GetCachedPrediction(horizonSeconds)
        end
        if sm.PredictLive then
            return sm:PredictLive(horizonSeconds, true)
        end
    end
    return nil
end

-- ============================ FRAME/ICONS ============================
local MAX_SWING_MARKERS = 4

local function HideAllIcons()
    if not frame or not frame.actionIcons then return end
    for i = 1, #frame.actionIcons do
        local iconFrame = frame.actionIcons[i]
        if iconFrame then
            iconFrame.currentX = nil
            iconFrame.visualKey = nil
            SetAlphaIfChanged(iconFrame, 1)
            SetShownIfChanged(iconFrame, false)
        end
    end
end

local function HideSwingMarkers()
    for i = 1, #swingMarkers do
        if swingMarkers[i] then
            SetShownIfChanged(swingMarkers[i], false)
        end
    end
end

function module:UpdateFrameAnchor()
    if not frame then return end
    local db = self.db and self.db.class
    if not db then return end

    -- Try anchoring below the existing Ret Twist Bar
    if db.lockToRetBar then
        local retBar = ns.PaladinRetTwistBar
        local retBarFrame = retBar and retBar._frame
        if not retBarFrame then
            retBarFrame = _G["NAGPaladinRetTwistBar"]
        end
        if retBarFrame and retBarFrame:IsShown() then
            frame:SetParent(_G.UIParent)
            frame:ClearAllPoints()
            frame:SetPoint("TOP", retBarFrame, "BOTTOM", db.x, db.y)
            return
        end
    end

    if db.autoAnchor then
        local anchor = NAG.GetDisplayAnchor and NAG:GetDisplayAnchor() or nil
        if anchor and anchor ~= _G.UIParent then
            frame:SetParent(_G.UIParent)
            frame:ClearAllPoints()
            frame:SetPoint("TOP", anchor, "BOTTOM", db.x, db.y)
            return
        end
    end

    frame:SetParent(_G.UIParent)
    frame:ClearAllPoints()
    frame:SetPoint(db.point, db.x, db.y)
end

function module:CreateFrameUI()
    if frame then return end

    local db = self.db.class
    frame = CreateFrame("Frame", "NAGPaladinRetSMBar", _G.UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.height)
    frame:SetPoint(db.point, db.x, db.y)
    frame:SetAlpha(db.alpha or 1.0)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(NAG.IsAnyEditMode and NAG:IsAnyEditMode())
    frame:SetScript("OnDragStart", function()
        if not (NAG.IsAnyEditMode and NAG:IsAnyEditMode()) then return end
        if UnitAffectingCombat and UnitAffectingCombat("player") then return end
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint(1)
        db.point = point
        db.x = x
        db.y = y
    end)
    frame:Hide()

    -- Background
    background = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    -- Hit zone (left edge = "now" marker)
    hitZone = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    hitZone:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    hitZone:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    hitZone:SetWidth(3)

    -- Swing markers (vertical lines showing where each swing lands)
    for i = 1, MAX_SWING_MARKERS do
        local marker = frame:CreateTexture(nil, "ARTWORK", nil, -2)
        marker:SetSize(1, db.height)
        marker:Hide()
        swingMarkers[i] = marker
    end

    -- Action icon pool
    frame.actionIcons = {}
    for i = 1, MAX_ACTION_ICONS do
        local iconFrame = CreateFrame("Frame", nil, frame)
        iconFrame:SetSize(db.iconSize, db.iconSize)
        iconFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
        iconFrame.icon = iconFrame:CreateTexture(nil, "ARTWORK", nil, 0)
        iconFrame.icon:SetAllPoints()
        iconFrame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        iconFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        iconFrame.stateText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        iconFrame.stateText:SetPoint("BOTTOM", iconFrame, "TOP", 0, 1)
        iconFrame.stateText:SetJustifyH("CENTER")
        iconFrame.stateText:SetText("")
        iconFrame.currentX = nil
        iconFrame:Hide()
        frame.actionIcons[i] = iconFrame
    end

    -- Apply scale from shared Paladin bar scale
    local retTwistModule = ns.PaladinRetTwistModule
    if retTwistModule and retTwistModule.GetPaladinBarScale then
        local scale = retTwistModule:GetPaladinBarScale()
        if scale and scale > 0 then
            frame:SetScale(scale)
        end
    end
end

-- ============================ RENDERING ============================

function module:RefreshSnapshot(now)
    if not frame then return end
    local db = self.db.class
    local horizonSeconds = ResolveHorizonSeconds(db)
    local snapshotInterval = ResolveSnapshotInterval(db)

    if lastSnapshotAt > 0 and (now - lastSnapshotAt) < snapshotInterval then
        return
    end

    local timeline = PredictTimeline(horizonSeconds)
    -- Only replace the displayed timeline when we have a valid prediction.
    -- After InvalidatePrediction() or a failed snapshot (snap.ok=false), the SM may
    -- briefly return ok=false — keep the last good icons until the next successful compute.
    if timeline and timeline.ok == true then
        cachedActions = CollectActionMoments(timeline, now, horizonSeconds)
        cachedSwingTimes = CollectSwingTimes(timeline, now, horizonSeconds)
    end
    lastSnapshotAt = now
end

function module:RenderActions(now)
    if not frame then return end

    local db = self.db.class
    local width = tonumber(db.width or frame:GetWidth() or 0) or 0
    local height = tonumber(db.height or frame:GetHeight() or 0) or 0
    local horizonSeconds = ResolveHorizonSeconds(db)
    local iconSize = tonumber(db.iconSize or 16) or 16
    local smoothing = Clamp(tonumber(db.sparkSmoothing or 0.28) or 0.28, 0, 1)
    local actions = cachedActions or {}
    local iconCount = #frame.actionIcons
    local drawCount = math.min(#actions, iconCount)

    -- Hide all actions when not in combat or not attacking
    local inCombat = UnitAffectingCombat("player") and true or false
    local isAttacking = (NAG.IsAttacking and NAG:IsAttacking()) or false
    if not inCombat or not isAttacking then
        drawCount = 0
    end
    local nextVisibleActionKeys = {}

    -- Render swing time vertical markers
    if db.showSwingMarkers then
        local mc = db.swingMarkerColor or { r = 0.5, g = 0.5, b = 0.5, a = 0.35 }
        for i = 1, MAX_SWING_MARKERS do
            local marker = swingMarkers[i]
            if marker then
                local swingAt = cachedSwingTimes[i]
                if swingAt then
                    local secFromNow = swingAt - now
                    local markerX = (secFromNow / horizonSeconds) * width
                    if markerX > 0 and markerX < width then
                        SetSizeIfChanged(marker, 1, height)
                        SetColorTextureIfChanged(marker, mc.r, mc.g, mc.b, mc.a)
                        SetCenterPointIfChanged(marker, frame, markerX, 0)
                        SetShownIfChanged(marker, true)
                    else
                        SetShownIfChanged(marker, false)
                    end
                else
                    SetShownIfChanged(marker, false)
                end
            end
        end
    else
        HideSwingMarkers()
    end

    -- Render action icons
    for i = 1, drawCount do
        local entry = actions[i]
        local iconFrame = frame.actionIcons[i]
        local rawDelay = (tonumber(entry.at or 0) or 0) - now
        local stateKey = BuildActionVisualKey(entry)
        local smoothedDelay = GetSmoothedHoldDelay(stateKey, rawDelay, now)
        local displayDelay = GetZeroStickStableDelay(self, stateKey, smoothedDelay, true)
        local targetX = (displayDelay / horizonSeconds) * width
        nextVisibleActionKeys[stateKey] = true

        if targetX < -iconSize then
            GetPredictionIconFadeAlpha(self, stateKey, false, now)
            GetJumpSuppressAlpha(self, stateKey, 0, false, now)
            ClearActionVisualState(self, stateKey)
            iconFrame.visualKey = nil
            iconFrame.currentX = nil
            if iconFrame.stateText then
                SetShownIfChanged(iconFrame.stateText, false)
            end
            SetAlphaIfChanged(iconFrame, 1)
            SetShownIfChanged(iconFrame, false)
        else
            -- Smoothing: only smooth leftward movement (icons approach the hit zone)
            if iconFrame.currentX == nil or targetX >= iconFrame.currentX then
                iconFrame.currentX = targetX
            else
                iconFrame.currentX = iconFrame.currentX + ((targetX - iconFrame.currentX) * smoothing)
            end

            SetSizeIfChanged(iconFrame, iconSize, iconSize)
            SetTextureIfChanged(iconFrame.icon, GetSpellIcon(tonumber(entry.spellId or 0) or 0))
            -- Slot 2 (fillers/judge) offset downward; slot 1 (primary) centered
            local yOffset = (entry.slot == 2) and -(iconSize * 0.55) or (iconSize * 0.15)
            SetCenterPointIfChanged(iconFrame, frame, iconFrame.currentX, yOffset)
            iconFrame.visualKey = stateKey

            local fadeAlpha = GetPredictionIconFadeAlpha(self, stateKey, true, now)
            local suppressAlpha = GetJumpSuppressAlpha(self, stateKey, displayDelay, true, now)
            SetAlphaIfChanged(iconFrame, fadeAlpha * suppressAlpha)

            if iconFrame.stateText then
                if db.showStateLabels then
                    local label = string.format("%s +%.2f",
                        tostring(entry.label or entry.stateIndex or 0),
                        max(0, displayDelay or 0)
                    )
                    if iconFrame.stateText._nagText ~= label then
                        iconFrame.stateText:SetText(label)
                        iconFrame.stateText._nagText = label
                    end
                    SetShownIfChanged(iconFrame.stateText, true)
                else
                    SetShownIfChanged(iconFrame.stateText, false)
                end
            end
            SetShownIfChanged(iconFrame, true)
        end
    end

    -- Hide unused icons
    for i = drawCount + 1, iconCount do
        local iconFrame = frame.actionIcons[i]
        local priorKey = iconFrame.visualKey
        if priorKey then
            GetPredictionIconFadeAlpha(self, priorKey, false, now)
            GetJumpSuppressAlpha(self, priorKey, 0, false, now)
        end
        iconFrame.currentX = nil
        iconFrame.visualKey = nil
        if iconFrame.stateText then
            SetShownIfChanged(iconFrame.stateText, false)
        end
        SetAlphaIfChanged(iconFrame, 1)
        SetShownIfChanged(iconFrame, false)
    end

    for stateKey, _ in pairs(visibleActionKeys) do
        if not nextVisibleActionKeys[stateKey] then
            GetPredictionIconFadeAlpha(self, stateKey, false, now)
            GetJumpSuppressAlpha(self, stateKey, 0, false, now)
            ClearActionVisualState(self, stateKey)
        end
    end
    visibleActionKeys = nextVisibleActionKeys
end

function module:UpdateDisplay()
    if not frame then
        self:CreateFrameUI()
        if not frame then return end
    end

    -- In edit mode, let UpdateVisibility handle things
    if NAG.IsAnyEditMode and NAG:IsAnyEditMode() then
        return
    end

    local db = self.db.class

    -- Gate: only show when TBC Ret bars are enabled (same gate as RetTwistBar)
    if NAG.IsTBCRetBarsEnabled and not NAG:IsTBCRetBarsEnabled() then
        frame:Hide()
        return
    end

    if db.hideOutOfCombat and not UnitAffectingCombat("player") then
        return
    end

    SetSizeIfChanged(frame, db.width, db.height)
    SetAlphaIfChanged(frame, db.alpha or 1.0)

    if background then
        if db.showBackground then
            local c = db.backgroundColor
            SetColorTextureIfChanged(background, c.r, c.g, c.b, c.a)
            SetShownIfChanged(background, true)
        else
            SetShownIfChanged(background, false)
        end
    end

    if hitZone then
        if db.showHitZone then
            local c = db.hitZoneColor
            SetColorTextureIfChanged(hitZone, c.r, c.g, c.b, c.a)
            SetShownIfChanged(hitZone, true)
        else
            SetShownIfChanged(hitZone, false)
        end
    end

    local now = GetTime()
    self:RefreshSnapshot(now)
    self:RenderActions(now)
end

-- ============================ VISIBILITY ============================
function module:NAG_FRAME_UPDATED()
    local db = self.db and self.db.class
    if not db or not db.enabled then
        return
    end
    self:UpdateVisibility()
end

function module:NAG_PALADIN_BAR_SCALE_UPDATED()
    local db = self.db and self.db.class
    if not db or not db.enabled or not frame then return end
    local retTwistModule = ns.PaladinRetTwistModule
    if retTwistModule and retTwistModule.GetPaladinBarScale then
        local scale = retTwistModule:GetPaladinBarScale()
        if scale and scale > 0 then
            frame:SetScale(scale)
        end
    end
end

function module:UpdateVisibility()
    local db = self.db.class
    if not db.enabled then
        if frame then
            frame:Hide()
            frame:SetScript("OnUpdate", nil)
        end
        lastUpdate = 0
        lastSnapshotAt = 0
        return
    end

    if not frame then
        self:CreateFrameUI()
        if not frame then return end
    end

    -- Check if the state machine itself is enabled
    local sm = NAG:GetModule("PaladinRetStateMachine", true)
    if not sm or not sm.db or not sm.db.class.enabled then
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        return
    end

    if NAG.IsAnyEditMode and NAG:IsAnyEditMode() then
        frame:Show()
        frame:EnableMouse(true)
        self:UpdateFrameAnchor()
        frame:SetScript("OnUpdate", function(_, elapsed)
            lastUpdate = lastUpdate + elapsed
            if lastUpdate >= UPDATE_INTERVAL then
                module:UpdateDisplay()
                lastUpdate = 0
            end
        end)
        return
    end

    if db.hideOutOfCombat and not UnitAffectingCombat("player") then
        frame:Hide()
        frame:SetScript("OnUpdate", nil)
        return
    end

    frame:Show()
    frame:EnableMouse(false)
    self:UpdateFrameAnchor()
    frame:SetScript("OnUpdate", function(_, elapsed)
        lastUpdate = lastUpdate + elapsed
        if lastUpdate >= UPDATE_INTERVAL then
            module:UpdateDisplay()
            lastUpdate = 0
        end
    end)
end

-- ============================ LIFECYCLE ============================
function module:ModuleInitialize()
end

function module:ModuleEnable()
    lastUpdate = 0
    lastSnapshotAt = 0
    cachedActions = {}
    cachedSwingTimes = {}
    holdSmoothState = {}
    visibleActionKeys = {}
    self._zeroStickState = {}
    self._predictionIconFadeState = {}
    self._iconSuppressState = {}
    if self.db and self.db.class and self.db.class.enabled then
        self:UpdateVisibility()
    end
end

function module:ModuleDisable()
    if frame then
        frame:SetScript("OnUpdate", nil)
        frame:Hide()
    end
    HideAllIcons()
    HideSwingMarkers()
    holdSmoothState = {}
    visibleActionKeys = {}
    self._zeroStickState = {}
    self._predictionIconFadeState = {}
    self._iconSuppressState = {}
end

-- ============================ OPTIONS ============================
function module:GetOptions()
    local OptionsFactory = NAG:GetModule("OptionsFactory", true)
    if not OptionsFactory then return nil end

    return {
        type = "group",
        name = "Ret SM Timeline Bar",
        order = 29,
        args = {
            description = {
                type = "description",
                name = "|cffaaaaaa(Experimental) Guitar-hero style prediction bar showing state machine actions scrolling toward the present. Shows 2 swing cycles of lookahead.|r",
                order = 0,
            },
            enabled = OptionsFactory:CreateToggle(
                "Enable SM Bar",
                "Show the state machine prediction timeline bar.",
                function() return self:GetSetting("class", "enabled") end,
                function(_, value)
                    self:SetSetting("class", "enabled", value)
                    self:UpdateVisibility()
                end,
                { order = 1 }
            ),
            hideOutOfCombat = OptionsFactory:CreateToggle(
                "Hide Out of Combat",
                "Only show the bar while in combat.",
                function() return self:GetSetting("class", "hideOutOfCombat") end,
                function(_, value) self:SetSetting("class", "hideOutOfCombat", value) end,
                { order = 2 }
            ),
            showSwingMarkers = OptionsFactory:CreateToggle(
                "Show Swing Markers",
                "Show vertical lines at each predicted swing time.",
                function() return self:GetSetting("class", "showSwingMarkers") end,
                function(_, value) self:SetSetting("class", "showSwingMarkers", value) end,
                { order = 3 }
            ),
            showStateLabels = OptionsFactory:CreateToggle(
                "Show Action Labels",
                "Show action names above each icon (debug).",
                function() return self:GetSetting("class", "showStateLabels") end,
                function(_, value) self:SetSetting("class", "showStateLabels", value) end,
                { order = 4 }
            ),
            lockToRetBar = OptionsFactory:CreateToggle(
                "Anchor to Ret Twist Bar",
                "Anchor this bar below the Ret Twist Bar when visible.",
                function() return self:GetSetting("class", "lockToRetBar") end,
                function(_, value)
                    self:SetSetting("class", "lockToRetBar", value)
                    self:UpdateFrameAnchor()
                end,
                { order = 5 }
            ),
            width = OptionsFactory:CreateRange(
                "Bar Width",
                "Width of the prediction bar.",
                function() return self:GetSetting("class", "width") end,
                function(_, value) self:SetSetting("class", "width", value) end,
                { order = 10, min = 100, max = 500, step = 5 }
            ),
            height = OptionsFactory:CreateRange(
                "Bar Height",
                "Height of the prediction bar.",
                function() return self:GetSetting("class", "height") end,
                function(_, value) self:SetSetting("class", "height", value) end,
                { order = 11, min = 8, max = 60, step = 1 }
            ),
            iconSize = OptionsFactory:CreateRange(
                "Icon Size",
                "Size of the action icons on the bar.",
                function() return self:GetSetting("class", "iconSize") end,
                function(_, value) self:SetSetting("class", "iconSize", value) end,
                { order = 12, min = 8, max = 32, step = 1 }
            ),
            horizonSeconds = OptionsFactory:CreateRange(
                "Horizon (seconds)",
                "How far into the future the bar shows.",
                function() return self:GetSetting("class", "horizonSeconds") end,
                function(_, value) self:SetSetting("class", "horizonSeconds", value) end,
                { order = 13, min = 3, max = 20, step = 0.5 }
            ),
        },
    }
end
