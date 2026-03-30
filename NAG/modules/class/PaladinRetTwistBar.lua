--- @module "NAG.PaladinRetTwistBar"
--- Visual swing + GCD timing bar for validating Ret seal twisting math against SwedgeTimer.
---
--- Phase 1 (current): show only
--- - Swing bar (time to next mainhand swing)
--- - GCD bar (time to GCD ready)
---
--- Phase 2 (later): add twist window overlays (last ~0.4s + delay buffers) and "can twist" highlight.
---
--- License: CC BY-NC 4.0 (https://creativecommons.org/licenses/by-nc/4.0/legalcode)
--- Authors: Rakizi, Fonsas
--- Discord: https://discord.gg/ebonhold

-- ============================ LOCALIZE ============================
local _, ns = ...

local GetTime = _G.GetTime
local UnitClassBase = _G.UnitClassBase
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local CreateFrame = _G.CreateFrame
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local EasyMenu = _G.EasyMenu
local CloseDropDownMenus = _G.CloseDropDownMenus
local ToggleDropDownMenu = _G.ToggleDropDownMenu
local UIDropDownMenu_Initialize = _G.UIDropDownMenu_Initialize
local UIDropDownMenu_AddButton = _G.UIDropDownMenu_AddButton
local StaticPopup_Show = _G.StaticPopup_Show
local StaticPopupDialogs = _G.StaticPopupDialogs
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI
local pi = math.pi

--- @type NAG|AceAddon
local NAG = LibStub("AceAddon-3.0"):GetAddon("NAG")

local swingTimerLib = ns.LibClassicSwingTimerAPI
local OptionsFactory
local PaladinTwistConstants = ns.PaladinTwistConstants or {}
local RET_TWIST_SOB_FAMILY_IDS = PaladinTwistConstants.RET_TWIST_SOB_FAMILY_IDS or { 31892, 31893 }
local RET_TWIST_SOM_FAMILY_IDS = PaladinTwistConstants.RET_TWIST_SOM_FAMILY_IDS or { 53720, 348700, 348701 }
local SPELL_SEAL_OF_WISDOM = 20357

local function containsSpellId(ids, spellId)
    if not spellId then
        return false
    end

    for i = 1, #ids do
        if ids[i] == spellId then
            return true
        end
    end

    return false
end

-- ============================ DEFAULTS ============================
local defaults = {
    class = {
        enabled = true,
        showBar = true,
        hideOutOfCombat = false,
        -- Debug prints are intentionally always-on (throttled) while we validate math vs SwedgeTimer.
        debugThrottleSeconds = 0.25,

        -- Positioning
        autoAnchor = true, -- Anchor relative to NAG primary frame when available
        anchorSide = "bottom", -- "bottom" = below NAG frame, "right" = to the right of NAG frame
        point = "CENTER",
        x = 140,
        y = 33,

        -- Dimensions
        width = 220,
        height = 6,
        alpha = 1.0,
        -- Bar fill direction: "rightToLeft" = countdown (current), "leftToRight" = classic swing-timer fill.
        barFillDirection = "rightToLeft",
        showGCDBar = true,
        showGCDSparks = true,
        gcdLaneHeight = 2,
        gcdLaneGap = 6,
        gcdSparkHeight = 5,
        showSwingIconSpark = true,
        userPositioned = false,
        predictionIconSize = 16,
        predictionTopLaneOffsetY = 12,
        predictionBottomLaneOffsetY = -12,
        predictionCSSplitExtraOffsetY = -14,
        showSocIcon = true,
        showJudgeIcon = true,
        showCSIcon = true,
        csLaneMode = "auto", -- auto (top in sideBySide, bottom in split), top, bottom
        fillerLaneMode = "bottom", -- bottom (reverted judge lane), top
        judgeBackgroundInverted = false,
        judgeSocLayoutMode = "sideBySide", -- "split" (SoC top, Judge bottom) or "sideBySide" (both top)
        socSideBySideOffsetX = 4,
        judgeSideBySideOffsetX = -4,
        judgeSocSideBySideOffsetY = 0,
        socBackgroundRotationSideBySideDeg = -15,
        judgeBackgroundRotationSideBySideDeg = 15,
        socBackgroundOffsetX = 0,
        socBackgroundOffsetY = 0,
        judgeBackgroundOffsetX = 0,
        judgeBackgroundOffsetY = 0,
        showFillerIconSpark = true,
        showNextNextIconSpark = true,
        nextNextLaneOffsetY = 22,
        showKeybindOnBar = false,
        fillerSourcePosition = "left1", -- left1/right1 source from secondary suggestions
        fillerOffsetX = 0,
        fillerOffsetY = 0,

        -- Twist window visualization
        showTwistWindow = true,
        twistWindowSeconds = 0.4,   -- The classic SoC twist window (~0.4s before swing)
        -- NOTE: We intentionally do not show a separate "GCD end marker" line for now.
        -- The GCD overlay bar already provides this information visually.
        --
        -- SwedgeTimer-style "div" boundary marker:
        -- A moving tick that sits left of the swing marker by (twistWindow + lastGcdDuration),
        -- showing the last point where a fresh GCD would still end before the twist window opens.
        showDivBoundaryMarker = false,

        -- Appearance
        -- Swing bar itself is intentionally invisible; we show only the spark line (ShamanWeaveBar-style).
        swingColor = { r = 0.30, g = 0.75, b = 0.30, a = 0.0 },
        -- Slightly brighter to be easy to see over the background (matches ShamanWeaveBar vibe).
        gcdColor = { r = 0.40, g = 0.40, b = 0.40, a = 0.95 },
        backgroundColor = { r = 0.0, g = 0.0, b = 0.0, a = 0.35 },
        sparkColor = { r = 0.9, g = 0.9, b = 0.9, a = 0.9 },

        -- Twist window colors
        twistWindowColor = { r = 0.90, g = 0.90, b = 0.90, a = 0.18 },     -- full 0.4s window
        divMarkerColor = { r = 0.95, g = 0.75, b = 0.10, a = 0.95 },       -- yellow/orange boundary tick
    }
}

--- @class PaladinRetTwistBar:CoreModule
local PaladinRetTwistBar = NAG:CreateModule("PaladinRetTwistBar", defaults, {
    moduleType = ns.MODULE_TYPES.CLASS,
    className = "PALADIN",
    optionsCategory = ns.MODULE_CATEGORIES.CLASS,
    hidden = function()
        return UnitClassBase("player") ~= "PALADIN"
    end,
    messageHandlers = {
        NAG_FRAME_UPDATED = true,
        NAG_PALADIN_BAR_SCALE_UPDATED = true,
    },
})

ns.PaladinRetTwistBar = PaladinRetTwistBar
local module = PaladinRetTwistBar

-- ============================ LOCALS ============================
-- Pack frame refs into one table to stay under Lua's 60-upvalue limit (UpdateDisplay).
local ui = {}

local UPDATE_INTERVAL = 0.016 -- ~60fps
local lastUpdate = 0
local SECONDS_EPSILON = 0.0001
local HOLD_SMOOTH_REFRESH_INTERVAL = 0.10
local HOLD_SMOOTH_SNAP_THRESHOLD = 0.20
local TIMELINE_SMOOTH_STALE_THRESHOLD = 0.002
local TIMELINE_SMOOTH_RESYNC_AHEAD_THRESHOLD = 0.08
local TIMELINE_SMOOTH_RESYNC_BEHIND_THRESHOLD = 0.18
local ICON_GCD_SUPPRESS_SECONDS = 0.12
local ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS = 0.35
local ICON_NEAR_ZERO_WINDOW_SECONDS = 0.30
local PREDICTION_FADE_TOTAL_SECONDS = 0.30
local PREDICTION_FADE_HOLD_TRANSPARENT_SECONDS = 0.10
local ZERO_STICK_REFRESH_MAX_SECONDS = 1.0
local CS_SMOOTH_STATE_GRACE_SECONDS = 0.35
local CS_TRANSIENT_ZERO_HOLD_SECONDS = 0.25
local CS_TRANSIENT_ZERO_MIN_READY = 0.50
-- CS-specific: trust predictive decay for fluid countdown; only resync when clearly off.
local CS_HOLD_REFRESH_INTERVAL = 0.35
local CS_HOLD_SNAP_THRESHOLD = 0.60
-- Soften the jump when we do resync: backdate sample so predicted is closer to raw.
local CS_HOLD_RESYNC_BLEND_SECONDS = 0.08
local holdSmoothState = {}
local timelineSmoothState = {}

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

--- S0 (upcoming) lanes: no fade-in so icons stay visible when transitioning from next-next.
local PREDICTION_FADE_SKIP_STATE_KEYS = { soc = true, judge = true, cs = true, filler = true }

local function GetPredictionIconFadeAlpha(self, stateKey, shouldBeVisible, now)
    self._predictionIconFadeState = self._predictionIconFadeState or {}

    if not shouldBeVisible then
        self._predictionIconFadeState[stateKey] = nil
        return 1
    end

    -- S0 lanes: no fade-in; show at full opacity immediately.
    if PREDICTION_FADE_SKIP_STATE_KEYS[stateKey] then
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
    if t < 0 then
        t = 0
    elseif t > 1 then
        t = 1
    end
    return t
end

-- Next-next fade-out: 0.2s hold + 0.2s fade to zero = 0.4s total persist when transitioning to S0.
local NEXTNEXT_FADEOUT_HOLD_SECONDS = 0.2
local NEXTNEXT_FADEOUT_FADE_SECONDS = 0.2
local NEXTNEXT_FADEOUT_TOTAL_SECONDS = NEXTNEXT_FADEOUT_HOLD_SECONDS + NEXTNEXT_FADEOUT_FADE_SECONDS

--- For next-next icons: when hiding, persist 0.4s (0.2s hold + 0.2s fade) so S0 can pick up without flash.
--- @param stateKey string e.g. "soc_nn", "judge_nn", "cs_nn", "filler_nn"
--- @param shouldBeVisible boolean Whether the icon has content to show
--- @param immediateHide boolean If true, hide immediately (e.g. iconsSuppressed)
--- @param now number GetTime()
--- @return boolean showFrame True to Show(), false to Hide()
--- @return number alpha Alpha for SetAlpha()
local function GetNextNextIconDisplayState(self, stateKey, shouldBeVisible, immediateHide, now)
    self._nextNextFadeOutState = self._nextNextFadeOutState or {}

    if immediateHide then
        self._nextNextFadeOutState[stateKey] = nil
        return false, 1
    end

    if shouldBeVisible then
        self._nextNextFadeOutState[stateKey] = { lastShownAt = now }
        local fadeInAlpha = GetPredictionIconFadeAlpha(self, stateKey, true, now)
        return true, fadeInAlpha
    end

    local state = self._nextNextFadeOutState[stateKey]
    if not state or not state.lastShownAt then
        GetPredictionIconFadeAlpha(self, stateKey, false, now)
        return false, 1
    end

    if not state.fadeOutStartedAt then
        state.fadeOutStartedAt = now
    end
    local elapsed = now - state.fadeOutStartedAt

    if elapsed >= NEXTNEXT_FADEOUT_TOTAL_SECONDS then
        self._nextNextFadeOutState[stateKey] = nil
        GetPredictionIconFadeAlpha(self, stateKey, false, now)
        return false, 1
    end

    local alpha
    if elapsed <= NEXTNEXT_FADEOUT_HOLD_SECONDS then
        alpha = 1
    else
        local t = (elapsed - NEXTNEXT_FADEOUT_HOLD_SECONDS) / NEXTNEXT_FADEOUT_FADE_SECONDS
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        alpha = 1 - t
    end
    return true, alpha
end

-- ============================ POPUPS ============================
-- Avoid re-registering popups on reloads.
if StaticPopupDialogs and not StaticPopupDialogs.NAG_RET_TWIST_BAR_DISABLE_CONFIRM then
    StaticPopupDialogs.NAG_RET_TWIST_BAR_DISABLE_CONFIRM = {
        text = "Disable Ret Twist Bar?",
        button1 = "Disable",
        button2 = "Cancel",
        OnAccept = function(dialog, data)
            local payload = data or (dialog and dialog.data) or nil
            if not payload or not payload.module then
                return
            end
            local m = payload.module
            if m.db and m.db.class then
                m.db.class.enabled = false
            end
            m:Disable()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

if StaticPopupDialogs and not StaticPopupDialogs.NAG_RET_TWIST_BAR_RESET_CONFIRM then
    StaticPopupDialogs.NAG_RET_TWIST_BAR_RESET_CONFIRM = {
        text = "Restore Ret Twist Bar defaults?",
        button1 = "Restore",
        button2 = "Cancel",
        OnAccept = function(dialog, data)
            local payload = data or (dialog and dialog.data) or nil
            if not payload or not payload.module then
                return
            end
            local m = payload.module
            if not (m.db and m.db.class) then
                return
            end

            -- Clear current settings and re-apply defaults (copy tables so we don't share refs).
            for k in pairs(m.db.class) do
                m.db.class[k] = nil
            end
            for k, v in pairs(defaults.class) do
                if type(v) == "table" and v.r ~= nil and v.g ~= nil and v.b ~= nil then
                    m.db.class[k] = { r = v.r, g = v.g, b = v.b, a = v.a or 1 }
                else
                    m.db.class[k] = v
                end
            end

            -- Ensure the bar comes back visible after reset (matches defaults).
            if m.UpdateVisibility then
                m:UpdateVisibility()
            end
            if m.UpdateDisplay then
                m:UpdateDisplay()
            end

            -- Auto reload to ensure all UI state reflects the restored defaults.
            if InCombatLockdown and InCombatLockdown() then
                m._pendingReloadUI = true
                if m.Print then
                    m:Print("Ret Twist Bar defaults restored. UI will reload after combat.")
                end
                return
            end
            if ReloadUI then
                ReloadUI()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- ============================ HELPERS ============================
local function Clamp01(x)
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

--- Timeline geometry: fixed 0.4s history + full swing future.
--- The left side reserves exactly 0.4 seconds worth of space before the twist-zero/swing boundary.
--- @param width number
--- @param swingSpeed number
--- @return number historyPx
--- @return number futurePx
local function GetTimelineGeometry(width, swingSpeed)
    if not width or width <= 0 or not swingSpeed or swingSpeed <= 0 then
        return 0, width or 0
    end

    local historySeconds = 0.4
    local totalSeconds = swingSpeed + historySeconds
    local historyPx = width * (historySeconds / totalSeconds)
    local futurePx = width - historyPx
    if futurePx < 0 then futurePx = 0 end
    return historyPx, futurePx
end

--- Convert seconds-before-swing to X offset within the bar.
--- 0 seconds maps to the swing boundary at x=historyPx.
--- Positive seconds map into the future region to the right.
--- Negative seconds map into the fixed 0.4s history region.
--- @param secondsBeforeSwing number
--- @param width number
--- @param swingSpeed number
--- @return number xPx
local function SecondsBeforeSwingToX(secondsBeforeSwing, width, swingSpeed)
    local historyPx, futurePx = GetTimelineGeometry(width, swingSpeed)
    if not swingSpeed or swingSpeed <= 0 or not width or width <= 0 or futurePx <= 0 then
        return historyPx
    end

    local s = secondsBeforeSwing or 0
    local minS = -0.4
    if s < minS then s = minS end
    if s > swingSpeed then s = swingSpeed end

    local x = historyPx + (s / swingSpeed) * futurePx
    if x < 0 then x = 0 end
    if x > width then x = width end
    return x
end

local function GetIconTintByActionRemaining(actionRemaining)
    local remaining = actionRemaining or 0
    if remaining < 0 then
        remaining = 0
    end
    if remaining <= 0.05 then
        return 0.08, 0.26, 0.10, 1.0 -- dark green
    end
    if remaining < 1.0 then
        return 0.55, 0.45, 0.05, 1.0 -- dark yellow
    end
    return 0.0, 0.0, 0.0, 1.0 -- black
end

local function ParseHoldSecondsFromOverlayText(text)
    if type(text) ~= "string" then
        return nil
    end
    local value = string.match(text, "([%d%.]+)s")
    if not value then
        return nil
    end
    local seconds = tonumber(value)
    if not seconds then
        return nil
    end
    if seconds < 0 then
        seconds = 0
    end
    return seconds
end

local function GetSpellTimeToReadyUnified(spellId)
    if not spellId then
        return nil
    end
    if NAG.SpellTimeToReadyResolved then
        return NAG:SpellTimeToReadyResolved(spellId)
    end
    if NAG.SpellTimeToReady then
        return NAG:SpellTimeToReady(spellId)
    end
    return nil
end

local function SetSparkKeybind(spark, showKeybind)
    if not spark or not spark.keybindText then return end
    if showKeybind and spark.spellId then
        local KeybindManager = NAG:GetModule("KeybindManager", true)
        local kb = ""
        if KeybindManager and KeybindManager.GetSpellKeybind then
            kb = KeybindManager:GetSpellKeybind(spark.spellId) or ""
        end
        spark.keybindText:SetText(kb)
        if kb ~= "" then
            spark.keybindText:Show()
        else
            spark.keybindText:Hide()
        end
    else
        spark.keybindText:SetText("")
        spark.keybindText:Hide()
    end
end

--- Return real usable time-to-ready for a spell on the timeline.
--- SpellTimeToReady is GCD-oriented in NAG timing, so we add current GCD left
--- to get the full remaining time until the spell is actually usable.
--- @param spellId number
--- @param gcdLeft number|nil
--- @return number
local function GetSpellTimelineReadySeconds(spellId, gcdLeft)
    local gcd = gcdLeft or 0
    if gcd < 0 then
        gcd = 0
    end

    local spellReady = GetSpellTimeToReadyUnified(spellId)
    if spellReady == nil then
        spellReady = 0
    end
    if spellReady < 0 then
        spellReady = 0
    end

    if spellReady <= SECONDS_EPSILON then
        return gcd
    end
    return gcd + spellReady
end

--- Return smoothed timeline seconds for cached timer sources.
--- Keeps scrolling down from last sampled value when raw reads are stale.
--- Resyncs when fresh raw data clearly diverges from prediction.
--- @param stateKey string
--- @param rawSeconds number|nil
--- @param now number|nil
--- @param maxSeconds number|nil
--- @return number
local function GetSmoothedTimelineSeconds(stateKey, rawSeconds, now, maxSeconds)
    local currentTime = now or (GetTime and GetTime()) or 0
    local raw = rawSeconds or 0
    if raw < 0 then
        raw = 0
    end
    if maxSeconds and maxSeconds > 0 and raw > maxSeconds then
        raw = maxSeconds
    end

    local state = timelineSmoothState[stateKey]
    if not state then
        timelineSmoothState[stateKey] = {
            sampledSeconds = raw,
            sampledAt = currentTime,
            lastRaw = raw,
        }
        return raw
    end

    local predicted = state.sampledSeconds - (currentTime - state.sampledAt)
    if predicted < 0 then
        predicted = 0
    end
    if maxSeconds and maxSeconds > 0 and predicted > maxSeconds then
        predicted = maxSeconds
    end

    local lastRaw = state.lastRaw or raw
    local staleRead = math.abs(raw - lastRaw) <= TIMELINE_SMOOTH_STALE_THRESHOLD
    local shouldResync = false

    if raw < (predicted - TIMELINE_SMOOTH_RESYNC_BEHIND_THRESHOLD) then
        shouldResync = true
    elseif raw > (predicted + TIMELINE_SMOOTH_RESYNC_AHEAD_THRESHOLD) and not staleRead then
        shouldResync = true
    elseif predicted <= SECONDS_EPSILON and raw > TIMELINE_SMOOTH_RESYNC_AHEAD_THRESHOLD and not staleRead then
        shouldResync = true
    end

    if shouldResync then
        state.sampledSeconds = raw
        state.sampledAt = currentTime
        predicted = raw
    end

    state.lastRaw = raw
    return predicted
end

local function DegreesToRadians(degrees)
    local deg = tonumber(degrees) or 0
    return deg * (pi / 180)
end

local function ClampActionSecondsForTimeline(secondsToCast, swingSpeed)
    local seconds = secondsToCast or 0
    if seconds < 0 then
        seconds = 0
    end
    if swingSpeed and swingSpeed > 0 and seconds > swingSpeed then
        seconds = swingSpeed
    end
    return seconds
end

local function ProjectActionSecondsBeforeSwing(rawSwingLeft, swingSpeed, holdRemaining)
    if not swingSpeed or swingSpeed <= 0 then
        return 0
    end
    local hold = holdRemaining or 0
    if hold < 0 then
        hold = 0
    end
    local swingLeft = rawSwingLeft or 0
    if hold <= swingLeft then
        return swingLeft - hold
    end
    local remainingAfterSwing = hold - swingLeft
    local projected = swingSpeed - remainingAfterSwing
    if projected < 0 then
        projected = 0
    end
    if projected > swingSpeed then
        projected = swingSpeed
    end
    return projected
end

local function IsSameSpellId(candidate, a, b)
    if not candidate then
        return false
    end
    return candidate == a or (b and candidate == b)
end

local function IsFillerSpellId(spellId)
    local id = tonumber(spellId)
    return id == 26573 or id == 879 -- Consecration / Exorcism
end

--- Cache for next-next icon lookups. Populated out of combat; read-only during combat.
--- spellId -> texture (string) or false (not known). Cleared on PLAYER_REGEN_ENABLED.
local nextNextIconCache = {}
local lastPrePopulateTime = 0

--- Get texture for next-next icon, or nil if spell unknown or no valid texture.
--- Uses ResolveEffectiveSpellId (player's known rank) and only returns when known.
--- Caches results out of combat; during combat uses cache only (no SpellIsKnown/GetSpellTexture).
--- @param spellId number
--- @param inCombat boolean
--- @return string|nil texture
local function GetNextNextSpellIcon(spellId, inCombat)
    if not spellId or spellId <= 0 then
        return nil
    end
    local cached = nextNextIconCache[spellId]
    if inCombat then
        return (cached and cached ~= false) and cached or nil
    end
    -- Out of combat: resolve, check known, get texture, cache
    local resolved = NAG.ResolveEffectiveSpellId and NAG:ResolveEffectiveSpellId(spellId) or spellId
    if not resolved then
        nextNextIconCache[spellId] = false
        return nil
    end
    local known = NAG.SpellIsKnown and NAG:SpellIsKnown(resolved)
    if not known then
        nextNextIconCache[spellId] = false
        return nil
    end
    local texture = (NAG.Spell and NAG.Spell[resolved] and NAG.Spell[resolved].icon)
        or (_G.GetSpellTexture and _G.GetSpellTexture(resolved))
    if not texture or texture == "Interface\\Icons\\INV_Misc_QuestionMark" then
        nextNextIconCache[spellId] = false
        return nil
    end
    nextNextIconCache[spellId] = texture
    return texture
end

--- Common Ret spell IDs to pre-populate when out of combat so cache is ready for combat.
local NEXTNEXT_PREPOPULATE_SPELL_IDS = {
    20271, -- Judgement
    35395, -- Crusader Strike
    26573, -- Consecration
    879,   -- Exorcism
    20293, -- Seal of Command (rank 2)
    20375, -- Seal of Command (rank 1)
}

--- Pre-populate next-next icon cache when out of combat so we have textures ready for combat.
local function PrePopulateNextNextIconCache()
    if UnitAffectingCombat and UnitAffectingCombat("player") then
        return
    end
    local ids = NEXTNEXT_PREPOPULATE_SPELL_IDS
    for i = 1, #ids do
        local sid = ids[i]
        if not nextNextIconCache[sid] then
            GetNextNextSpellIcon(sid, false)
        end
    end
    if NAG and NAG.RetTwistGetSoCSealId and NAG.RetTwistGetTwistSealId then
        local soCId = NAG:RetTwistGetSoCSealId()
        local twistId = NAG:RetTwistGetTwistSealId()
        if soCId and soCId > 0 and not nextNextIconCache[soCId] then
            GetNextNextSpellIcon(soCId, false)
        end
        if twistId and twistId > 0 and not nextNextIconCache[twistId] then
            GetNextNextSpellIcon(twistId, false)
        end
    end
end

local function IsPositionMatch(positionValue, expectedValue)
    if expectedValue == nil then
        return false
    end
    local positionText = string.lower(tostring(positionValue or ""))
    local expectedText = string.lower(tostring(expectedValue))
    if positionText == expectedText then
        return true
    end
    if expectedText == "left1" and positionValue == ns.SPELL_POSITIONS.LEFT then
        return true
    end
    if expectedText == "right1" and positionValue == ns.SPELL_POSITIONS.RIGHT then
        return true
    end
    return false
end

local function buildSuccessToast(twistSpellId)
    local label = "SoB/SoM"
    if containsSpellId(RET_TWIST_SOB_FAMILY_IDS, twistSpellId) then
        label = "SoB"
    elseif containsSpellId(RET_TWIST_SOM_FAMILY_IDS, twistSpellId) then
        label = "SoM"
    end

    return {
        text = string.format("Successful Twist"),
        r = 0.20,
        g = 0.85,
        b = 0.35,
    }
end

local function ClearParryHasteOverride()
    if not NAG then
        return
    end
    NAG._autoParryHasteNextSwingAt = nil
    NAG._autoParryHasteAppliedAt = nil
    NAG._autoParryHasteWeaponSpeed = nil
end

local function GetMainhandSwing()
    if swingTimerLib and swingTimerLib.UnitSwingTimerInfo then
        local speed, expiration = swingTimerLib:UnitSwingTimerInfo("player", "mainhand")
        if speed and expiration then
            local now = GetTime()
            local remaining = math.max(0, expiration - now)

            -- Local parry-haste override (no lib edits):
            -- Defensive parry haste shortens only the current swing deadline.
            -- Weapon speed is unchanged for future cycle projections.
            local overrideAt = NAG and NAG._autoParryHasteNextSwingAt or nil
            if overrideAt then
                local overrideRemaining = overrideAt - now
                if overrideRemaining <= 0 then
                    ClearParryHasteOverride()
                elseif overrideRemaining < remaining then
                    remaining = overrideRemaining
                end
            end

            return remaining, speed
        end
    end
    return 0, 0
end

local function To01(b)
    return b and 1 or 0
end

--- Effective scale for Paladin bar frames: NAG display scale * universal Paladin bar scale.
local function GetPaladinBarEffectiveScale()
    local anchor = NAG.GetDisplayAnchor and NAG:GetDisplayAnchor() or nil
    local nagScale = (anchor and anchor ~= _G.UIParent and anchor:GetScale()) or 1
    local pm = NAG:GetModule("PaladinRetTwistModule", true)
    local barScale = (pm and pm.GetPaladinBarScale and pm:GetPaladinBarScale()) or 1
    return nagScale * barScale
end

function PaladinRetTwistBar:UpdateFrameAnchor()
    if not ui.frame then
        return
    end

    local db = self.db.class
    local anchor = NAG.GetDisplayAnchor and NAG:GetDisplayAnchor() or nil
    local anchorValid = anchor and anchor ~= _G.UIParent

    -- When autoAnchor is true but anchor is temporarily invalid (e.g. during lock transition),
    -- db.x/db.y hold anchor-relative offsets, not UIParent coords. Do NOT apply the fallback
    -- or we would misplace the bar. Leave the frame where it is (position from last OnDragStop).
    if db.autoAnchor and not anchorValid then
        return
    end

    if not db.autoAnchor then
        ui.frame:SetParent(_G.UIParent)
        ui.frame:ClearAllPoints()
        ui.frame:SetPoint(db.point, _G.UIParent, db.point, db.x, db.y)
        ui.frame:SetScale(GetPaladinBarEffectiveScale())
        return
    end

    -- Keep on UIParent so we don't affect the main frame (e.g. floating selector position)
    ui.frame:SetParent(_G.UIParent)
    ui.frame:ClearAllPoints()
    if db.anchorSide == "right" then
        local dm = NAG:GetModule("DisplayManager", true)
        if dm and dm.AnchorFrameToRightOfDisplay then
            dm:AnchorFrameToRightOfDisplay(ui.frame, "BOTTOMLEFT", db.x or 8, db.y or 0)
        else
            ui.frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", db.x or 8, db.y or 0)
        end
    else
        ui.frame:SetPoint("TOP", anchor, "BOTTOM", db.x, db.y)
    end
    ui.frame:SetScale(GetPaladinBarEffectiveScale())
end

function PaladinRetTwistBar:UpdateVisibility()
    if not ui.frame then
        return
    end

    local db = self.db.class
    -- In edit mode: force visible for positioning - check FIRST so bars stay visible when unlocked
    if NAG.IsAnyEditMode and NAG:IsAnyEditMode() then
        ui.frame:SetFrameStrata("DIALOG")
        ui.frame:SetFrameLevel(200)
        ui.frame:EnableMouse(true)
        ui.frame:Show()
        ui.frame:SetScript("OnUpdate", function(_, elapsed)
            lastUpdate = lastUpdate + elapsed
            if lastUpdate >= UPDATE_INTERVAL then
                self:UpdateDisplay()
                lastUpdate = 0
            end
        end)
        if ui.clickCatcher then
            ui.clickCatcher:EnableMouse(true)
        end
        return
    end

    if not db.showBar then
        ui.frame:Hide()
        ui.frame:SetScript("OnUpdate", nil)
        return
    end

    if NAG.IsTBCRetBarsEnabled and not NAG:IsTBCRetBarsEnabled() then
        ui.frame:Hide()
        ui.frame:SetScript("OnUpdate", nil)
        return
    end

    if db.hideOutOfCombat and not UnitAffectingCombat("player") then
        ui.frame:Hide()
        ui.frame:SetScript("OnUpdate", nil)
        return
    end

    local dm = NAG:GetModule("DisplayManager", true)
    local level = dm and dm.GetRecommendedClassBarFrameLevel and dm:GetRecommendedClassBarFrameLevel() or 50
    ui.frame:SetFrameStrata("MEDIUM")
    ui.frame:SetFrameLevel(level)
    ui.frame:EnableMouse(false)
    ui.frame:Show()
    if ui.clickCatcher then
        ui.clickCatcher:EnableMouse(NAG.IsAnyEditMode and NAG:IsAnyEditMode())
    end
    -- Alpha will be dynamically adjusted in UpdateDisplay based on SoC + twist readiness
    self:UpdateFrameAnchor()
    ui.frame:SetScript("OnUpdate", function(_, elapsed)
        lastUpdate = lastUpdate + elapsed
        if lastUpdate >= UPDATE_INTERVAL then
            self:UpdateDisplay()
            lastUpdate = 0
        end
    end)
end

function PaladinRetTwistBar:ResolveSoCIds()
    local soCId = NAG.RetTwistGetSoCSealId and NAG:RetTwistGetSoCSealId() or nil
    local resolvedSoCId = soCId
    if soCId and NAG.ResolveEffectiveSpellId then
        resolvedSoCId = NAG:ResolveEffectiveSpellId(soCId) or soCId
    end
    return soCId, resolvedSoCId
end

function PaladinRetTwistBar:IsSoCRecommended(soCId, resolvedSoCId)
    local nextIdentity = NAG.NormalizePrimaryAction and NAG:NormalizePrimaryAction(NAG.nextSpell) or nil
    local nextSpell = nextIdentity and (NAG.GetActionResolveId and NAG:GetActionResolveId(nextIdentity)) or nil
    if IsSameSpellId(nextSpell, soCId, resolvedSoCId) then
        return true
    end

    local secondary = NAG.secondarySpells
    if type(secondary) ~= "table" then
        return false
    end
    for i = 1, #secondary do
        local entry = secondary[i]
        local norm = NAG.NormalizeSecondarySpellEntry and NAG:NormalizeSecondarySpellEntry(entry) or nil
        if norm then
            local entryId = norm.spellId or norm.itemId
            local position = norm.position
            local isAoe = (position == ns.SPELL_POSITIONS.AOE) or (type(position) == "string" and string.lower(position) == "aoe")
            if isAoe and entryId and IsSameSpellId(entryId, soCId, resolvedSoCId) then
                return true
            end
        end
    end
    return false
end

function PaladinRetTwistBar:GetHoldRemainingForSpell(spellId, resolvedSpellId, positions)
    local dm = NAG:GetModule("DisplayManager", true)
    if dm and dm.GetCustomHoldSwipe then
        for i = 1, #positions do
            local pos = positions[i]
            local state = dm:GetCustomHoldSwipe(spellId, pos)
            if (not state) and resolvedSpellId and resolvedSpellId ~= spellId then
                state = dm:GetCustomHoldSwipe(resolvedSpellId, pos)
            end
            if state and state.endAt then
                local remaining = state.endAt - GetTime()
                if remaining > 0 then
                    return remaining
                end
            end
        end
    end

    if NAG.castOverlayTexts then
        local text = NAG.castOverlayTexts[spellId]
        if (not text) and resolvedSpellId and resolvedSpellId ~= spellId then
            text = NAG.castOverlayTexts[resolvedSpellId]
        end
        local parsed = ParseHoldSecondsFromOverlayText(text)
        if parsed and parsed > 0 then
            return parsed
        end
    end
    return nil
end

--- Resolve action delay for an icon lane.
--- Modes:
--- - Default mode (legacy): hold -> cooldown readiness, gated by GCD.
--- - Hold-prediction mode (visual lane): hold only, fallback to 0 (fixed zero marker).
--- @param spellId number
--- @param resolvedSpellId number|nil
--- @param positions table
--- @param gcdLeft number
--- @param options table|nil
--- @return number
function PaladinRetTwistBar:GetActionDelayForSpell(spellId, resolvedSpellId, positions, gcdLeft, options)
    local holdPredictionOnly = options and options.holdPredictionOnly == true
    local gcd = gcdLeft or 0
    if gcd < 0 then
        gcd = 0
    end

    local holdRemaining = self:GetHoldRemainingForSpell(spellId, resolvedSpellId, positions)
    if holdRemaining and holdRemaining > SECONDS_EPSILON then
        if holdPredictionOnly then
            return holdRemaining
        end
        return math.max(gcd, holdRemaining)
    end

    if holdPredictionOnly then
        -- For visual HOLD prediction lanes, missing hold means "cast at swing moment".
        return 0
    end

    local queryId = resolvedSpellId or spellId
    local readyIn = GetSpellTimeToReadyUnified(queryId)
    if readyIn == nil then
        readyIn = 0
    end
    if readyIn < 0 then
        readyIn = 0
    end

    if readyIn < SECONDS_EPSILON then
        readyIn = 0
    end
    return math.max(gcd, readyIn)
end

function PaladinRetTwistBar:ClearSmoothedHoldState(stateKey)
    holdSmoothState[stateKey] = nil
end

--- Return smoothed hold delay for visual bar motion.
--- Uses sampled-refresh + predictive decay to avoid per-ui.frame jitter.
--- @param stateKey string
--- @param rawDelay number
--- @param now number
--- @return number
function PaladinRetTwistBar:GetSmoothedHoldDelay(stateKey, rawDelay, now)
    local currentTime = now or (GetTime and GetTime()) or 0
    local raw = rawDelay or 0
    if raw < 0 then
        raw = 0
    end

    local refreshInterval = HOLD_SMOOTH_REFRESH_INTERVAL
    local snapThreshold = HOLD_SMOOTH_SNAP_THRESHOLD
    if stateKey == "cs" then
        refreshInterval = CS_HOLD_REFRESH_INTERVAL
        snapThreshold = CS_HOLD_SNAP_THRESHOLD
    end

    local state = holdSmoothState[stateKey]
    if not state then
        holdSmoothState[stateKey] = {
            sampledDelay = raw,
            sampledAt = currentTime,
            nextRefreshAt = currentTime + refreshInterval,
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
    if math.abs(raw - predicted) > snapThreshold then
        shouldRefresh = true
    end
    if predicted <= 0 and raw > 0 then
        shouldRefresh = true
    end

    if shouldRefresh then
        state.sampledDelay = raw
        state.sampledAt = currentTime
        state.nextRefreshAt = currentTime + refreshInterval
        if stateKey == "cs" and CS_HOLD_RESYNC_BLEND_SECONDS > 0 then
            local blend = (raw - predicted) * 0.25
            if blend > 0 then
                return predicted + blend
            end
        end
        return raw
    end

    return predicted
end

--- Return visual hold-prediction delay for icon lanes (smoothed).
--- Missing hold resolves to 0 so icons pin to the static zero marker.
--- Final result is clamped to GCD floor for Weave-like minimum behavior.
--- @param stateKey string
--- @param spellId number
--- @param resolvedSpellId number|nil
--- @param positions table
--- @param now number
--- @param gcdFloor number|nil
--- @return number smoothedDelay
--- @return number rawDelay
function PaladinRetTwistBar:GetVisualHoldPredictionDelay(stateKey, spellId, resolvedSpellId, positions, now, gcdFloor)
    local holdRemaining = self:GetHoldRemainingForSpell(spellId, resolvedSpellId, positions)
    local rawDelay = 0
    if holdRemaining and holdRemaining > SECONDS_EPSILON then
        rawDelay = holdRemaining
    end
    local smoothed = self:GetSmoothedHoldDelay(stateKey, rawDelay, now)
    local floor = gcdFloor or 0
    if floor < 0 then
        floor = 0
    end
    if smoothed < floor then
        smoothed = floor
    end
    return smoothed, rawDelay
end

function PaladinRetTwistBar:GetJudgeSocLayoutMode()
    local mode = self.db and self.db.class and self.db.class.judgeSocLayoutMode or "sideBySide"
    if mode ~= "sideBySide" then
        mode = "split"
    end
    return mode
end

function PaladinRetTwistBar:ApplyJudgeSocBackgroundTransforms(judgeCalled)
    if not ui.frame or not self.db or not self.db.class then
        return
    end

    local db = self.db.class
    local mode = self:GetJudgeSocLayoutMode()
    local sideBySide = mode == "sideBySide"
    local sideBySideWithJudge = sideBySide and (judgeCalled == true)
    local judgeInverted = db.judgeBackgroundInverted == true

    if ui.socIconSparkBackground and ui.socIconSparkFrame then
        ui.socIconSparkBackground:ClearAllPoints()
        ui.socIconSparkBackground:SetPoint(
            "CENTER",
            ui.socIconSparkFrame,
            "CENTER",
            db.socBackgroundOffsetX or 0,
            db.socBackgroundOffsetY or 0
        )
        local socRotationDeg = sideBySideWithJudge and (db.socBackgroundRotationSideBySideDeg or 0) or 0
        ui.socIconSparkBackground:SetRotation(DegreesToRadians(socRotationDeg))
        ui.socIconSparkBackground:SetTexCoord(0, 1, 0, 1)
    end

    if ui.judgeIconSparkBackground and ui.judgeIconSparkFrame then
        ui.judgeIconSparkBackground:ClearAllPoints()
        ui.judgeIconSparkBackground:SetPoint(
            "CENTER",
            ui.judgeIconSparkFrame,
            "CENTER",
            db.judgeBackgroundOffsetX or 0,
            db.judgeBackgroundOffsetY or 0
        )
        local judgeRotationDeg = sideBySideWithJudge and (db.judgeBackgroundRotationSideBySideDeg or 0) or 0
        ui.judgeIconSparkBackground:SetRotation(DegreesToRadians(judgeRotationDeg))
        if judgeInverted then
            ui.judgeIconSparkBackground:SetTexCoord(0, 1, 1, 0)
        else
            ui.judgeIconSparkBackground:SetTexCoord(0, 1, 0, 1)
        end
    end

    -- Filler and next-next filler: same background orientation as filler lane (reverted when bottom, normal when top).
    local fillerLaneMode = db.fillerLaneMode or "bottom"
    local fillerReverted = (fillerLaneMode == "bottom")
    if ui.fillerIconSparkBackground then
        if fillerReverted then
            ui.fillerIconSparkBackground:SetTexCoord(0, 1, 1, 0)
        else
            ui.fillerIconSparkBackground:SetTexCoord(0, 1, 0, 1)
        end
    end
    if ui.nextFillerIconSparkBackground then
        if fillerReverted then
            ui.nextFillerIconSparkBackground:SetTexCoord(0, 1, 1, 0)
        else
            ui.nextFillerIconSparkBackground:SetTexCoord(0, 1, 0, 1)
        end
    end
end

--- Applies shared prediction icon sizing for all action icon lanes.
function PaladinRetTwistBar:ApplyPredictionIconSizing()
    if not self.db or not self.db.class then
        return
    end

    local db = self.db.class
    local iconSize = math.floor(db.predictionIconSize or 16)
    if iconSize < 8 then iconSize = 8 end
    if iconSize > 48 then iconSize = 48 end
    local ringSize = iconSize + 21

    if ui.socIconSparkFrame then ui.socIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.judgeIconSparkFrame then ui.judgeIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.csIconSparkFrame then ui.csIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.fillerIconSparkFrame then ui.fillerIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.nextSocIconSparkFrame then ui.nextSocIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.nextJudgeIconSparkFrame then ui.nextJudgeIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.nextCSIconSparkFrame then ui.nextCSIconSparkFrame:SetSize(iconSize, iconSize) end
    if ui.nextFillerIconSparkFrame then ui.nextFillerIconSparkFrame:SetSize(iconSize, iconSize) end

    if ui.socIconSparkBackground then ui.socIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.judgeIconSparkBackground then ui.judgeIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.csIconSparkBackground then ui.csIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.fillerIconSparkBackground then ui.fillerIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.nextSocIconSparkBackground then ui.nextSocIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.nextJudgeIconSparkBackground then ui.nextJudgeIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.nextCSIconSparkBackground then ui.nextCSIconSparkBackground:SetSize(ringSize, ringSize) end
    if ui.nextFillerIconSparkBackground then ui.nextFillerIconSparkBackground:SetSize(ringSize, ringSize) end
end

function PaladinRetTwistBar:IsJudgeParallelActive(soCRecommended)
    if not soCRecommended then
        return false
    end

    -- Only show Judgement lane when Judgement is explicitly recommended right now.
    -- Do not revive it from stale HOLD cache state alone.
    local nextIdentity = NAG.NormalizePrimaryAction and NAG:NormalizePrimaryAction(NAG.nextSpell) or nil
    local nextSpell = nextIdentity and (NAG.GetActionResolveId and NAG:GetActionResolveId(nextIdentity)) or nil
    if nextSpell == 20271 then
        return true
    end

    local secondary = NAG.secondarySpells
    if type(secondary) == "table" then
        for i = 1, #secondary do
            local entry = secondary[i]
            local norm = NAG.NormalizeSecondarySpellEntry and NAG:NormalizeSecondarySpellEntry(entry) or nil
            if norm then
                local entryId = norm.spellId or norm.itemId
                if entryId == 20271 then
                    return true
                end
            end
        end
    end

    return false
end

function PaladinRetTwistBar:IsCSRecommended()
    local nextIdentity = NAG.NormalizePrimaryAction and NAG:NormalizePrimaryAction(NAG.nextSpell) or nil
    local nextSpell = nextIdentity and (NAG.GetActionResolveId and NAG:GetActionResolveId(nextIdentity)) or nil
    if nextSpell == 35395 then
        return true
    end
    local secondary = NAG.secondarySpells
    if type(secondary) ~= "table" then
        return false
    end
    for i = 1, #secondary do
        local entry = secondary[i]
        local norm = NAG.NormalizeSecondarySpellEntry and NAG:NormalizeSecondarySpellEntry(entry) or nil
        if norm then
            local entryId = norm.spellId or norm.itemId
            if entryId == 35395 then
                return true
            end
        end
    end
    return false
end

--- Returns a recommended filler spell ID (Consecration/Exorcism) or nil.
--- Mirrors WeaveBar filler sourcing: uses configured secondary source slot.
--- @return number|nil
function PaladinRetTwistBar:GetRecommendedFillerSpellId()
    local nextIdentity = NAG.NormalizePrimaryAction and NAG:NormalizePrimaryAction(NAG.nextSpell) or nil
    local nextSpell = nextIdentity and (NAG.GetActionResolveId and NAG:GetActionResolveId(nextIdentity)) or nil
    if IsFillerSpellId(nextSpell) then
        return nextSpell
    end

    local db = self.db and self.db.class or nil
    local fillerSource = (db and db.fillerSourcePosition) or "left1"
    local secondary = NAG.secondarySpells
    if type(secondary) ~= "table" then
        return nil
    end

    for i = 1, #secondary do
        local entry = secondary[i]
        local norm = NAG.NormalizeSecondarySpellEntry and NAG:NormalizeSecondarySpellEntry(entry) or nil
        if norm then
            local entryId = norm.spellId or norm.itemId
            if IsPositionMatch(norm.position, fillerSource) and entryId and IsFillerSpellId(entryId) then
                return entryId
            end
        end
    end

    return nil
end

--- Return next-next prediction payload sourced directly from Ret state machine.
--- @return table|nil
function PaladinRetTwistBar:GetNextNextPredictionPayload()
    if not NAG or not NAG.RetSMGetTwistBarPrediction then
        return nil
    end
    return NAG:RetSMGetTwistBarPrediction()
end

function PaladinRetTwistBar:UpdateDisplay()
    if not ui.frame then return end

    -- In edit mode, visibility is managed by UpdateVisibility - never hide so user can position
    if NAG.IsAnyEditMode and NAG:IsAnyEditMode() then
        return
    end

    local db = self.db.class
    local judgeSocLayoutMode = self:GetJudgeSocLayoutMode()
    local sideBySideJudgeSoc = judgeSocLayoutMode == "sideBySide"
    local now = (GetTime and GetTime()) or 0
    local inCombat = UnitAffectingCombat("player") and true or false
    -- Pre-populate next-next icon cache when out of combat (throttled) so first combat has textures ready.
    if not inCombat and db.showBar and (now - lastPrePopulateTime) > 2 then
        lastPrePopulateTime = now
        PrePopulateNextNextIconCache()
    end
    if not db.showBar then return end
    if NAG.IsTBCRetBarsEnabled and not NAG:IsTBCRetBarsEnabled() then
        ui.frame:Hide()
        return
    end
    if db.hideOutOfCombat and not inCombat then return end

    -- Seal state (used for gating some visuals like the weapon spark / twist window overlay).
    local soCActive = inCombat and NAG.RetTwistIsSoCActive and NAG:RetTwistIsSoCActive() or false
    local soBActive = inCombat and NAG.RetTwistIsSoBActive and NAG:RetTwistIsSoBActive() or false
    local noSealActive = not soCActive and not soBActive
    local manaPercent = (NAG.CurrentManaPercent and NAG:CurrentManaPercent()) or 1.0
    local soWActive = (NAG.AuraIsActive and NAG:AuraIsActive(SPELL_SEAL_OF_WISDOM)) or false
    local manaCritical = manaPercent and manaPercent < 0.02
    -- When CS override is active, CS is the only action; block SoB/SoM and twist-related icons.
    local csOverrideActive = NAG.RetTwistShouldForceCrusaderStrike and NAG:RetTwistShouldForceCrusaderStrike(1.9, 0.1, 0.4) or false
    local isAttacking = (NAG.IsAttacking and NAG:IsAttacking()) or false
    local hasAttackableTarget = (NAG.UnitExists and NAG:UnitExists("target"))
        and (NAG.UnitCanAttack and NAG:UnitCanAttack("player", "target"))
        and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target"))
    local canShowPrimaryS0 = inCombat and isAttacking and hasAttackableTarget
    local twistGapGate = (not csOverrideActive) and (db.showTwistWindow and db.showSwingIconSpark and soCActive) or false

    -- Keep the entire module alpha stable (no shifting based on seals).
    local targetAlpha = (db.alpha or 1.0)
    ui.frame:SetAlpha(targetAlpha)

    local rawSwingLeft, swingSpeed = GetMainhandSwing()
    if not swingSpeed or swingSpeed <= 0 then
        -- Fallback to NAG helper if swingTimerLib isn't reporting yet.
        local _, raw = NAG:AutoTimeToNext()
        rawSwingLeft = raw or 0
        swingSpeed = NAG:AutoSwingTime() or 0
    end

    if not swingSpeed or swingSpeed <= 0 then
        ui.frame:Hide()
        return
    end

    if rawSwingLeft < 0 then
        rawSwingLeft = 0
    end
    local swingLeft = GetSmoothedTimelineSeconds("swing", rawSwingLeft, now, swingSpeed)

    local rawGcdLeft = NAG:GCDTimeToReady() or 0
    if rawGcdLeft < 0 then
        rawGcdLeft = 0
    end
    local gcdLeft = GetSmoothedTimelineSeconds("gcd", rawGcdLeft, now, nil)

    local width = db.width
    local baseHeight = db.height
    local swingHeight = baseHeight + 5
    local gcdHeight = db.gcdLaneHeight or 2
    local gcdGap = db.gcdLaneGap or 6
    local gcdSparkHeight = db.gcdSparkHeight or 5
    if gcdHeight < 1 then gcdHeight = 1 end
    if gcdGap < 0 then gcdGap = 0 end
    if gcdSparkHeight < 2 then gcdSparkHeight = 2 end
    local showGCDLane = db.showGCDBar ~= false

    -- Total frame height must fit swing lane + gap + gcd lane (including spark protrusion).
    local totalHeight = swingHeight
    if showGCDLane then
        totalHeight = totalHeight + gcdGap + gcdSparkHeight
    end
    ui.frame:SetSize(width, totalHeight)
    self:ApplyPredictionIconSizing()

    -- ============================ TIMELINE (0.4s HISTORY) ============================
    -- The "swing moment" (0s before swing) is at x=historyPx, with a fixed 0.4s history region on the left.
    local historyPx, futurePx = GetTimelineGeometry(width, swingSpeed)
    local swingCenterY = (totalHeight / 2) - (swingHeight / 2)
    local gcdCenterY = swingCenterY - (swingHeight / 2) - gcdGap - (gcdHeight / 2)

    local leftToRight = (db.barFillDirection == "leftToRight")
    local function toVisualX(x)
        if leftToRight then return width - x else return x end
    end

    -- Background should ONLY cover the swing lane (GCD lane intentionally sits outside the ui.background borders).
    if ui.background then
        ui.background:ClearAllPoints()
        ui.background:SetPoint("LEFT", ui.frame, "LEFT", 0, swingCenterY)
        ui.background:SetSize(width, swingHeight)
        ui.background:Show()
    end

    -- Swing bar: remaining time (shrinks right -> left) or left-to-right fill; anchored per barFillDirection.
    ui.swingBar:ClearAllPoints()
    local swingProgress = Clamp01((swingLeft or 0) / swingSpeed)
    if leftToRight then
        ui.swingBar:SetPoint("LEFT", ui.frame, "LEFT", toVisualX(historyPx + futurePx * (1 - swingProgress)), swingCenterY)
        ui.swingBar:SetWidth(futurePx * (1 - swingProgress))
    else
        ui.swingBar:SetPoint("LEFT", ui.frame, "LEFT", historyPx, swingCenterY)
        ui.swingBar:SetWidth(futurePx * swingProgress)
    end
    ui.swingBar:SetHeight(swingHeight)
    ui.swingBar:Show()

    -- Swing spark: vertical line at the swing moment (fixed when leftToRight, at bar end when rightToLeft).
    ui.swingSpark:SetSize(2, swingHeight)
    ui.swingSpark:ClearAllPoints()
    if leftToRight then
        ui.swingSpark:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(historyPx), swingCenterY)
    else
        ui.swingSpark:SetPoint("CENTER", ui.swingBar, "RIGHT", 0, 0)
    end
    if twistGapGate then
        ui.swingSpark:Show()
    else
        ui.swingSpark:Hide()
    end
    if twistGapGate then
        ui.swingSpark:Show()
    else
        ui.swingSpark:Hide()
    end

    -- Optional weapon icon spark (circular) positioned above the swing marker to avoid blocking the bar.
    local autoSparkVisible = false
    if ui.swingIconSparkFrame then
        -- Show only when SoC is active (twist setup) — the twist window icon matters only then.
        local twistSealIdForSpark = NAG.RetTwistGetTwistSealId and NAG:RetTwistGetTwistSealId() or nil
        -- Weapon spark (SoB/SoM icon flowing with swing) only matters during twist setup (SoC active).
        local weaponSparkShow = canShowPrimaryS0 and db.showSwingIconSpark and soCActive
        if weaponSparkShow then
            local soCIdForSpark = NAG.RetTwistGetSoCSealId and NAG:RetTwistGetSoCSealId() or nil
            -- When no seal active, show SoB/SoM first; else show twist seal (SoB/SoM) during SoC twist window
            local displaySpellId = noSealActive and twistSealIdForSpark or (twistSealIdForSpark or soCIdForSpark)
            if NAG.ResolveEffectiveSpellId and displaySpellId then
                displaySpellId = NAG:ResolveEffectiveSpellId(displaySpellId) or displaySpellId
            end

            local iconTexture = (displaySpellId and NAG.Spell and NAG.Spell[displaySpellId] and NAG.Spell[displaySpellId].icon)
                or (displaySpellId and _G.GetSpellTexture and _G.GetSpellTexture(displaySpellId))
                or "Interface\\Icons\\INV_Misc_QuestionMark"

            if iconTexture and iconTexture ~= ui.lastSwingIconTexture then
                ui.lastSwingIconTexture = iconTexture
                if ui.swingIconSparkIcon then
                    ui.swingIconSparkIcon:SetTexture(iconTexture)
                end
            end

            -- Position the icon at the middle of the moving twist gap, shifted left by ~0.2s.
            local window = db.twistWindowSeconds or 0.4
            if window < 0 then window = 0 end
            if window > swingSpeed then window = swingSpeed end

            local startSeconds = (swingLeft or 0) - window
            local endSeconds = (swingLeft or 0)
            local currentWindowOpenIn = startSeconds
            if currentWindowOpenIn < 0 then
                currentWindowOpenIn = 0
            end

            -- If GCD cannot reach this cycle's twist window-open timing, skip this cycle's icon.
            local currentSwingTwistUnreachable = gcdLeft > currentWindowOpenIn
            if currentSwingTwistUnreachable then
                SetSparkKeybind(ui.swingIconSparkFrame, false)
                ui.swingIconSparkFrame:Hide()
                if swingIconSparkBackground then
                    swingIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                    swingIconSparkBackground:Hide()
                end
            else
                local iconSeconds = (swingLeft or 0) - (window * 0.5) - 0.2
                -- Never allow the icon to go left of the fixed zero mark (0s before swing).
                -- If calculations would put it into negative time (history), pin it at 0.
                if iconSeconds < 0 then iconSeconds = 0 end
                if iconSeconds < startSeconds then iconSeconds = startSeconds end
                if iconSeconds > endSeconds then iconSeconds = endSeconds end

                local iconX = SecondsBeforeSwingToX(iconSeconds, width, swingSpeed)
                local iconSize = ui.swingIconSparkFrame:GetWidth() or 16
                local y = swingCenterY + (swingHeight / 2) + (iconSize / 2) + 1 + 12
                ui.swingIconSparkFrame:ClearAllPoints()
                ui.swingIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(iconX), y)
                if swingIconSparkBackground then
                    -- Tint the ui.background art when we're approaching the twist moment,
                    -- matching the moving twist gap bar thresholds.
                    local timeToZero = (swingLeft or 0) - window
                    if timeToZero < 0 then timeToZero = 0 end
                    if timeToZero <= 0.05 then
                        swingIconSparkBackground:SetVertexColor(0.08, 0.26, 0.10, 1.0) -- dark green
                    elseif timeToZero < 1.0 then
                        swingIconSparkBackground:SetVertexColor(0.55, 0.45, 0.05, 1.0) -- dark yellow
                    else
                        swingIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0) -- black
                    end
                    swingIconSparkBackground:Show()
                end
                ui.swingIconSparkFrame:Show()
                SetSparkKeybind(ui.swingIconSparkFrame, false)
                autoSparkVisible = true
            end
        else
            SetSparkKeybind(ui.swingIconSparkFrame, false)
            ui.swingIconSparkFrame:Hide()
            if swingIconSparkBackground then
                -- Reset tint when hidden so it doesn't carry across states.
                swingIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                swingIconSparkBackground:Hide()
            end
        end
    end

    local soCId, resolvedSoCId = self:ResolveSoCIds()
    local twistSealId = (NAG.RetTwistGetTwistSealId and NAG:RetTwistGetTwistSealId()) or nil -- SoB/SoM
    local resolvedTwistSealId = (twistSealId and NAG.ResolveEffectiveSpellId and NAG:ResolveEffectiveSpellId(twistSealId)) or twistSealId
    local soCRecommended = self:IsSoCRecommended(soCId, resolvedSoCId)
    local judgeParallelActive = self:IsJudgeParallelActive(soCRecommended)
    -- When mana < 2%, show Seal of Wisdom (emergency mana regen). When no seal, show SoB/SoM first.
    local socShouldShow = (manaCritical and not csOverrideActive)
        or soCRecommended or judgeParallelActive or (noSealActive and twistSealId and not csOverrideActive)

    local soCVisualDelay = nil
    local judgeVisualDelay = nil
    local csVisualDelay = nil
    local fillerVisualDelay = nil
    local soCRawDelay = nil
    local judgeRawDelay = nil
    local csRawReady = nil
    local fillerRawReady = nil

    if socShouldShow then
        if manaCritical then
            soCVisualDelay, soCRawDelay = self:GetVisualHoldPredictionDelay(
                "sow",
                SPELL_SEAL_OF_WISDOM,
                SPELL_SEAL_OF_WISDOM,
                { ns.SPELL_POSITIONS.PRIMARY, ns.SPELL_POSITIONS.AOE },
                now,
                gcdLeft
            )
            self:ClearSmoothedHoldState("soc")
            self:ClearSmoothedHoldState("twist")
        elseif noSealActive and twistSealId then
            soCVisualDelay, soCRawDelay = self:GetVisualHoldPredictionDelay(
                "twist",
                twistSealId,
                resolvedTwistSealId,
                { ns.SPELL_POSITIONS.PRIMARY, ns.SPELL_POSITIONS.AOE },
                now,
                gcdLeft
            )
            self:ClearSmoothedHoldState("soc")
        elseif soCId then
            soCVisualDelay, soCRawDelay = self:GetVisualHoldPredictionDelay(
                "soc",
                soCId,
                resolvedSoCId,
                { ns.SPELL_POSITIONS.PRIMARY, ns.SPELL_POSITIONS.AOE },
                now,
                gcdLeft
            )
            self:ClearSmoothedHoldState("twist")
        end
    else
        self:ClearSmoothedHoldState("soc")
        self:ClearSmoothedHoldState("twist")
        self:ClearSmoothedHoldState("sow")
    end

    if judgeParallelActive then
        judgeVisualDelay, judgeRawDelay = self:GetVisualHoldPredictionDelay(
            "judge",
            20271,
            20271,
            { ns.SPELL_POSITIONS.PRIMARY },
            now,
            gcdLeft
        )
    else
        self:ClearSmoothedHoldState("judge")
    end

    local csRecommended = self:IsCSRecommended()
    local csJustBecameRecommended = false
    local csRawReadyNow = GetSpellTimelineReadySeconds(35395, gcdLeft)

    -- Stabilize occasional transient zero reads while CS is clearly still cooling down.
    if csRawReadyNow <= SECONDS_EPSILON then
        local lastRaw = self._csLastRawReady
        local lastRawAt = self._csLastRawReadyAt or 0
        if lastRaw and lastRaw > CS_TRANSIENT_ZERO_MIN_READY and (now - lastRawAt) <= CS_TRANSIENT_ZERO_HOLD_SECONDS then
            csRawReadyNow = lastRaw
        end
    else
        self._csLastRawReady = csRawReadyNow
        self._csLastRawReadyAt = now
    end

    if csRecommended then
        -- On the exact ui.frame CS transitions from not-recommended to recommended,
        -- force-seed the smoother with real rawReady so there is no stale-low first ui.frame.
        csJustBecameRecommended = not self._csWasRecommended
        self._csWasRecommended = true
        self._csLastRecommendedAt = now
        csRawReady = csRawReadyNow

        if csJustBecameRecommended then
            self:ClearSmoothedHoldState("cs")
        end

        local csSmoothed = self:GetSmoothedHoldDelay("cs", csRawReadyNow, now)
        csVisualDelay = math.max(gcdLeft, csSmoothed)
    else
        self._csWasRecommended = false
        -- Keep CS smoothing warm briefly to avoid jumpy re-entry when recommendations flap.
        local keepCSWarm = self._csLastRecommendedAt and ((now - self._csLastRecommendedAt) <= CS_SMOOTH_STATE_GRACE_SECONDS)
        if keepCSWarm then
            self:GetSmoothedHoldDelay("cs", csRawReadyNow, now)
        else
            self:ClearSmoothedHoldState("cs")
        end
    end

    local fillerSpellId = nil
    local fillerRecommended = db.showFillerIconSpark and self:GetRecommendedFillerSpellId() or nil
    if fillerRecommended then
        fillerSpellId = fillerRecommended
        local rawReady = GetSpellTimeToReadyUnified(fillerSpellId) or 0
        if rawReady < 0 then
            rawReady = 0
        end
        -- Match Weave filler behavior: only display if filler is ready by GCD release.
        if rawReady > (gcdLeft + SECONDS_EPSILON) then
            fillerSpellId = nil
            if self._lastFillerSmoothKey then
                self:ClearSmoothedHoldState(self._lastFillerSmoothKey)
                self._lastFillerSmoothKey = nil
            end
        else
        fillerRawReady = rawReady
        local fillerKey = "filler_" .. tostring(fillerSpellId)
        if self._lastFillerSmoothKey and self._lastFillerSmoothKey ~= fillerKey then
            self:ClearSmoothedHoldState(self._lastFillerSmoothKey)
        end
        self._lastFillerSmoothKey = fillerKey
        local fillerSmoothed = self:GetSmoothedHoldDelay(fillerKey, rawReady, now)
        fillerVisualDelay = math.max(gcdLeft, fillerSmoothed)
        end
    else
        if self._lastFillerSmoothKey then
            self:ClearSmoothedHoldState(self._lastFillerSmoothKey)
            self._lastFillerSmoothKey = nil
        end
    end

    -- ============================ NEXT-NEXT (STATE1) PREDICTION ============================
    -- Do not show next-next when not in combat, no target, target not attackable, target dead,
    -- no active seal, Seal of Wisdom (mana regen) active, player not attacking, or target not in melee
    local targetInMelee = (NAG.TargetInMeleeRange and NAG:TargetInMeleeRange(5)) or false
    local canShowNextNext = canShowPrimaryS0 and not soWActive and targetInMelee

    -- No seal (SoB/SoC/SoM/SoR) for > 200ms: hide next-next (allow brief transition, then hide)
    local NO_SEAL_HIDE_AFTER_SECONDS = 0.2
    if noSealActive then
        local lastAt = tonumber(self._nextNextNoSealSince or 0) or 0
        if lastAt <= 0 then
            self._nextNextNoSealSince = now
        end
        if (now - (self._nextNextNoSealSince or now)) > NO_SEAL_HIDE_AFTER_SECONDS then
            canShowNextNext = false
        end
    else
        self._nextNextNoSealSince = nil
    end

    local nextNextPayload = canShowNextNext and self:GetNextNextPredictionPayload() or nil
    local nextNextCore = nextNextPayload and nextNextPayload.nextNext or nil
    local nextNextFiller = nextNextPayload and nextNextPayload.nextNextFiller or nil
    local nextNextSocFollow = nextNextPayload and nextNextPayload.nextNextSocFollow or nil

    local nextNextEnabled = db.showNextNextIconSpark ~= false
    local nextNextCoreActionKey = tostring(nextNextCore and nextNextCore.actionKey or "")
    local nextNextCoreSpellId = tonumber(nextNextCore and nextNextCore.spellId or 0) or 0
    local nextNextSoCRecommended = false
    local nextNextJudgeActive = false
    local nextNextCSRecommended = false
    local nextNextFillerSpellId = tonumber(nextNextFiller and nextNextFiller.spellId or 0) or 0
    local nextNextSoCDelay = nil
    local nextNextJudgeDelay = nil
    local nextNextCSDelay = nil
    local nextNextFillerDelay = nil

    if nextNextEnabled and nextNextCore then
        local coreDelay = tonumber(nextNextCore.waitFromNow or 0) or 0
        if coreDelay < 0 then coreDelay = 0 end

        if nextNextCoreActionKey == "judge_soc" then
            nextNextJudgeActive = true
            nextNextSoCRecommended = true
            nextNextJudgeDelay = coreDelay
            nextNextSoCDelay = tonumber(nextNextSocFollow and nextNextSocFollow.waitFromNow or coreDelay) or coreDelay
        elseif (nextNextCoreActionKey == "twist" or nextNextCoreActionKey == "hold") and nextNextCoreSpellId > 0 then
            -- Twist/hold applies a seal (SoC or SoB/SoM); show in seal lane.
            nextNextSoCRecommended = true
            nextNextSoCDelay = coreDelay
        elseif nextNextCoreSpellId > 0 and IsSameSpellId(nextNextCoreSpellId, soCId, resolvedSoCId) then
            nextNextSoCRecommended = true
            nextNextSoCDelay = coreDelay
        elseif nextNextCoreSpellId == 20271 then
            nextNextJudgeActive = true
            nextNextJudgeDelay = coreDelay
        elseif nextNextCoreSpellId == 35395 then
            nextNextCSRecommended = true
            nextNextCSDelay = coreDelay
        elseif IsFillerSpellId(nextNextCoreSpellId) then
            nextNextFillerSpellId = nextNextCoreSpellId
            nextNextFillerDelay = coreDelay
        end

        if not nextNextSoCRecommended and nextNextSocFollow then
            local socFollowSpellId = tonumber(nextNextSocFollow.spellId or 0) or 0
            if socFollowSpellId > 0 and IsSameSpellId(socFollowSpellId, soCId, resolvedSoCId) then
                nextNextSoCRecommended = true
                nextNextSoCDelay = tonumber(nextNextSocFollow.waitFromNow or coreDelay) or coreDelay
            end
        end

        if nextNextFillerSpellId > 0 and not nextNextFillerDelay then
            nextNextFillerDelay = tonumber(nextNextFiller and nextNextFiller.waitFromNow or coreDelay) or coreDelay
        end
    end

    -- Additional hide conditions: gap too small, or next-next too close to zero
    local gcdValue = (NAG.GCDTimeValue and NAG:GCDTimeValue()) or 1.5
    local nextNextCoreDelay = nextNextSoCDelay or nextNextJudgeDelay or nextNextCSDelay or nextNextFillerDelay or 999
    local primaryMinDelay = 999
    if socShouldShow and soCVisualDelay then primaryMinDelay = math.min(primaryMinDelay, soCVisualDelay) end
    if judgeParallelActive and judgeVisualDelay then primaryMinDelay = math.min(primaryMinDelay, judgeVisualDelay) end
    if csRecommended and csVisualDelay then primaryMinDelay = math.min(primaryMinDelay, csVisualDelay) end
    if fillerSpellId and fillerVisualDelay then primaryMinDelay = math.min(primaryMinDelay, fillerVisualDelay) end
    local gapToPrimary = nextNextCoreDelay - primaryMinDelay
    local NEXTNEXT_MIN_GAP_GCD_RATIO = 0.90
    local NEXTNEXT_MIN_DELAY_FROM_ZERO = 1.5
    if gapToPrimary < (NEXTNEXT_MIN_GAP_GCD_RATIO * gcdValue) or nextNextCoreDelay < NEXTNEXT_MIN_DELAY_FROM_ZERO then
        canShowNextNext = false
    end

    -- When hiding next-next, instantly hide - no fade-out
    local nextNextForceHide = not canShowNextNext

    -- Keep both icons grouped in side-by-side mode when Judgement is active:
    -- they share one HOLD-based base time, then only X offsets separate them.
    if sideBySideJudgeSoc and judgeParallelActive and socShouldShow then
        local sharedDelay = math.max(soCVisualDelay or 0, judgeVisualDelay or 0)
        soCVisualDelay = sharedDelay
        judgeVisualDelay = sharedDelay
    end

    local socDisplayed = canShowPrimaryS0 and (not csOverrideActive) and db.showSwingIconSpark and db.showSocIcon ~= false and socShouldShow and (soCId ~= nil or (noSealActive and twistSealId) or manaCritical)
    local judgeDisplayed = canShowPrimaryS0 and (not csOverrideActive) and db.showSwingIconSpark and db.showJudgeIcon ~= false and judgeParallelActive
    local csDisplayed = canShowPrimaryS0 and db.showSwingIconSpark and db.showCSIcon ~= false and csRecommended
    local fillerDisplayed = canShowPrimaryS0 and (not csOverrideActive) and db.showSwingIconSpark and db.showFillerIconSpark and fillerSpellId ~= nil

    soCVisualDelay = GetZeroStickStableDelay(self, "soc", soCVisualDelay, socDisplayed)
    judgeVisualDelay = GetZeroStickStableDelay(self, "judge", judgeVisualDelay, judgeDisplayed)
    csVisualDelay = GetZeroStickStableDelay(self, "cs", csVisualDelay, csDisplayed)
    fillerVisualDelay = GetZeroStickStableDelay(self, "filler", fillerVisualDelay, fillerDisplayed)

    local prevDelays = self._iconPrevDelays or {}
    local socPrev = prevDelays.soc
    local judgePrev = prevDelays.judge
    local csPrev = prevDelays.cs
    local fillerPrev = prevDelays.filler
    local socDelta = (socDisplayed and socPrev ~= nil and soCVisualDelay ~= nil) and ((soCVisualDelay or 0) - socPrev) or 0
    local judgeDelta = (judgeDisplayed and judgePrev ~= nil and judgeVisualDelay ~= nil) and ((judgeVisualDelay or 0) - judgePrev) or 0
    local csDelta = (csDisplayed and csPrev ~= nil and csVisualDelay ~= nil) and ((csVisualDelay or 0) - csPrev) or 0
    local fillerDelta = (fillerDisplayed and fillerPrev ~= nil and fillerVisualDelay ~= nil) and ((fillerVisualDelay or 0) - fillerPrev) or 0

    local significantRightJump = false
    if socDisplayed and socPrev ~= nil and soCVisualDelay ~= nil then
        if socDelta > ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS and socPrev <= ICON_NEAR_ZERO_WINDOW_SECONDS then
            significantRightJump = true
        end
    end
    if judgeDisplayed and judgePrev ~= nil and judgeVisualDelay ~= nil then
        if judgeDelta > ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS and judgePrev <= ICON_NEAR_ZERO_WINDOW_SECONDS then
            significantRightJump = true
        end
    end
    if csDisplayed and csPrev ~= nil and csVisualDelay ~= nil then
        if csDelta > ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS and csPrev <= ICON_NEAR_ZERO_WINDOW_SECONDS then
            significantRightJump = true
        end
    end
    if fillerDisplayed and fillerPrev ~= nil and fillerVisualDelay ~= nil then
        if fillerDelta > ICON_SIGNIFICANT_RIGHT_JUMP_SECONDS and fillerPrev <= ICON_NEAR_ZERO_WINDOW_SECONDS then
            significantRightJump = true
        end
    end

    if significantRightJump then
        self._iconSuppressUntil = now + ICON_GCD_SUPPRESS_SECONDS
    end
    local iconsSuppressed = (self._iconSuppressUntil or 0) > now

    self._iconPrevDelays = self._iconPrevDelays or {}
    self._iconPrevDelays.soc = socDisplayed and (soCVisualDelay or 0) or nil
    self._iconPrevDelays.judge = judgeDisplayed and (judgeVisualDelay or 0) or nil
    self._iconPrevDelays.cs = csDisplayed and (csVisualDelay or 0) or nil
    self._iconPrevDelays.filler = fillerDisplayed and (fillerVisualDelay or 0) or nil

    if NAG.IsDevModeEnabled and NAG:IsDevModeEnabled() and false then
        local sharedGrouped = sideBySideJudgeSoc and judgeParallelActive and socShouldShow
        print(string.format(
            "[TWIST_BAR_DEBUG] swingLeft=%.3f speed=%.3f gcdLeft=%.3f socRec=%s judgeRec=%s csRec=%s socRawHold=%.3f judgeRawHold=%.3f csRawReady=%.3f socDelay=%.3f judgeDelay=%.3f csDelay=%.3f grouped=%s",
            swingLeft or 0,
            swingSpeed or 0,
            gcdLeft or 0,
            tostring(soCRecommended),
            tostring(judgeParallelActive),
            tostring(csRecommended),
            soCRawDelay or 0,
            judgeRawDelay or 0,
            csRawReady or 0,
            soCVisualDelay or 0,
            judgeVisualDelay or 0,
            csVisualDelay or 0,
            tostring(sharedGrouped)
        ))
        print(string.format(
            "[TWIST_BAR_FILLER] rec=%s spell=%s rawReady=%.3f delay=%.3f source=%s",
            tostring(fillerDisplayed),
            tostring(fillerSpellId),
            fillerRawReady or 0,
            fillerVisualDelay or 0,
            tostring(db.fillerSourcePosition or "left1")
        ))
        print(string.format(
            "[TWIST_BAR_GCD_SUPPRESS] gcdLeft=%.3f sigRightJump=%s active=%s remaining=%.3f socPrev=%.3f socDelta=%.3f judgePrev=%.3f judgeDelta=%.3f csPrev=%.3f csDelta=%.3f fillerPrev=%.3f fillerDelta=%.3f",
            gcdLeft or 0,
            tostring(significantRightJump),
            tostring(iconsSuppressed),
            math.max(0, (self._iconSuppressUntil or 0) - now),
            socPrev or -1,
            socDelta or 0,
            judgePrev or -1,
            judgeDelta or 0,
            csPrev or -1,
            csDelta or 0,
            fillerPrev or -1,
            fillerDelta or 0
        ))
    end

    self:ApplyJudgeSocBackgroundTransforms(judgeParallelActive)

    local socActionSecondsDebug = nil
    local judgeActionSecondsDebug = nil
    local csActionSecondsDebug = nil
    local fillerActionSecondsDebug = nil
    local socXDebug = nil
    local judgeXDebug = nil
    local csXDebug = nil
    local csYDebug = nil
    local fillerXDebug = nil
    local fillerYDebug = nil
    local csFadeAlphaDebug = nil
    local predictionTopLaneOffsetY = db.predictionTopLaneOffsetY or 12
    local predictionBottomLaneOffsetY = db.predictionBottomLaneOffsetY or -12
    local predictionCSSplitExtraOffsetY = db.predictionCSSplitExtraOffsetY or -14

    -- SoC icon lane: shown whenever SoC is recommended (PRIMARY or AOE).
    if ui.socIconSparkFrame then
        if iconsSuppressed then
            GetPredictionIconFadeAlpha(self, "soc", false, now)
            SetSparkKeybind(ui.socIconSparkFrame, false)
            ui.socIconSparkFrame:Hide()
            ui.socIconSparkFrame:SetAlpha(1)
            if ui.socIconSparkBackground then
                ui.socIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.socIconSparkBackground:Hide()
            end
        elseif socDisplayed then
            -- When mana < 2%, show Seal of Wisdom; when no seal, show SoB/SoM; else show SoC
            local displaySoCId = (manaCritical and SPELL_SEAL_OF_WISDOM) or ((noSealActive and twistSealId) and (resolvedTwistSealId or twistSealId)) or (resolvedSoCId or soCId)
            local socTexture = (displaySoCId and NAG.Spell and NAG.Spell[displaySoCId] and NAG.Spell[displaySoCId].icon)
                or (displaySoCId and _G.GetSpellTexture and _G.GetSpellTexture(displaySoCId))
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            if socTexture ~= ui.lastSoCIconTexture then
                ui.lastSoCIconTexture = socTexture
                if ui.socIconSparkIcon then
                    ui.socIconSparkIcon:SetTexture(socTexture)
                end
            end

            local soCActionDelay = soCVisualDelay or 0
            -- Icon timing convention:
            -- - SoB/SoM weapon icon follows the moving swing timeline (handled in the weapon spark lane).
            -- - SoC/Judge "cast now" (delay == 0) should sit on the fixed zero marker (swing moment),
            --   not on the moving swing spark.
            local socActionSeconds
            if (soCActionDelay or 0) <= SECONDS_EPSILON then
                socActionSeconds = 0
            else
                -- Weave-style visualization: map HOLD countdown directly to timeline distance
                -- from the fixed zero marker so it moves smoothly each ui.frame.
                socActionSeconds = ClampActionSecondsForTimeline(soCActionDelay, swingSpeed)
            end
            if socActionSeconds < 0 then
                socActionSeconds = 0
            end
            socActionSecondsDebug = socActionSeconds
            local socX = SecondsBeforeSwingToX(socActionSeconds, width, swingSpeed)
            local socIconSize = ui.socIconSparkFrame:GetWidth() or 16
            local topY = swingCenterY + (swingHeight / 2) + (socIconSize / 2) + 1 + predictionTopLaneOffsetY
            if sideBySideJudgeSoc and judgeParallelActive then
                socX = socX + (db.socSideBySideOffsetX or 0)
                topY = topY + (db.judgeSocSideBySideOffsetY or 0)
            end
            socXDebug = socX
            ui.socIconSparkFrame:ClearAllPoints()
            ui.socIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(socX), topY)

            if ui.socIconSparkBackground then
                local r, g, b, a = GetIconTintByActionRemaining(soCActionDelay or 0)
                ui.socIconSparkBackground:SetVertexColor(r, g, b, a)
                ui.socIconSparkBackground:Show()
            end
            ui.socIconSparkFrame.spellId = (manaCritical and SPELL_SEAL_OF_WISDOM) or (noSealActive and twistSealId) or soCId
            ui.socIconSparkFrame:SetAlpha(GetPredictionIconFadeAlpha(self, "soc", true, now))
            ui.socIconSparkFrame:Show()
            SetSparkKeybind(ui.socIconSparkFrame, self.db.class.showKeybindOnBar)
        else
            GetPredictionIconFadeAlpha(self, "soc", false, now)
            SetSparkKeybind(ui.socIconSparkFrame, false)
            ui.socIconSparkFrame:Hide()
            ui.socIconSparkFrame:SetAlpha(1)
            if ui.socIconSparkBackground then
                ui.socIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.socIconSparkBackground:Hide()
            end
        end
    end

    -- Judgement parallel lane: shown with SoC split recommendations, rendered below the bar.
    if ui.judgeIconSparkFrame then
        if iconsSuppressed then
            GetPredictionIconFadeAlpha(self, "judge", false, now)
            SetSparkKeybind(ui.judgeIconSparkFrame, false)
            ui.judgeIconSparkFrame:Hide()
            ui.judgeIconSparkFrame:SetAlpha(1)
            if ui.judgeIconSparkBackground then
                ui.judgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.judgeIconSparkBackground:Hide()
            end
        elseif judgeDisplayed then
            local judgeTexture = (NAG.Spell and NAG.Spell[20271] and NAG.Spell[20271].icon)
                or (_G.GetSpellTexture and _G.GetSpellTexture(20271))
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            if judgeTexture ~= ui.lastJudgeIconTexture then
                ui.lastJudgeIconTexture = judgeTexture
                if ui.judgeIconSparkIcon then
                    ui.judgeIconSparkIcon:SetTexture(judgeTexture)
                end
            end

            local judgeActionDelay = judgeVisualDelay or 0
            local judgeActionSeconds
            if (judgeActionDelay or 0) <= SECONDS_EPSILON then
                judgeActionSeconds = 0
            else
                -- Weave-style visualization: map HOLD countdown directly to timeline distance
                -- from the fixed zero marker so it moves smoothly each ui.frame.
                judgeActionSeconds = ClampActionSecondsForTimeline(judgeActionDelay, swingSpeed)
            end
            if judgeActionSeconds < 0 then
                judgeActionSeconds = 0
            end
            judgeActionSecondsDebug = judgeActionSeconds
            local judgeX = SecondsBeforeSwingToX(judgeActionSeconds, width, swingSpeed)
            local judgeIconSize = ui.judgeIconSparkFrame:GetWidth() or 16
            local judgeY
            if sideBySideJudgeSoc then
                judgeY = swingCenterY + (swingHeight / 2) + (judgeIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.judgeSocSideBySideOffsetY or 0)
                judgeX = judgeX + (db.judgeSideBySideOffsetX or 0)
            else
                judgeY = swingCenterY - (swingHeight / 2) - (judgeIconSize / 2) - 1 + predictionBottomLaneOffsetY
            end
            judgeXDebug = judgeX
            ui.judgeIconSparkFrame:ClearAllPoints()
            ui.judgeIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(judgeX), judgeY)

            if ui.judgeIconSparkBackground then
                local r, g, b, a = GetIconTintByActionRemaining(judgeActionDelay or 0)
                ui.judgeIconSparkBackground:SetVertexColor(r, g, b, a)
                ui.judgeIconSparkBackground:Show()
            end
            ui.judgeIconSparkFrame:SetAlpha(GetPredictionIconFadeAlpha(self, "judge", true, now))
            ui.judgeIconSparkFrame:Show()
            SetSparkKeybind(ui.judgeIconSparkFrame, self.db.class.showKeybindOnBar)
        else
            GetPredictionIconFadeAlpha(self, "judge", false, now)
            SetSparkKeybind(ui.judgeIconSparkFrame, false)
            ui.judgeIconSparkFrame:Hide()
            ui.judgeIconSparkFrame:SetAlpha(1)
            if ui.judgeIconSparkBackground then
                ui.judgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.judgeIconSparkBackground:Hide()
            end
        end
    end

    -- CS icon lane: shown when Crusader Strike is currently recommended.
    if ui.csIconSparkFrame then
        if iconsSuppressed then
            GetPredictionIconFadeAlpha(self, "cs", false, now)
            SetSparkKeybind(ui.csIconSparkFrame, false)
            ui.csIconSparkFrame:Hide()
            ui.csIconSparkFrame:SetAlpha(1)
            if ui.csIconSparkBackground then
                ui.csIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.csIconSparkBackground:Hide()
            end
        elseif csDisplayed then
            local csTexture = (NAG.Spell and NAG.Spell[35395] and NAG.Spell[35395].icon)
                or (_G.GetSpellTexture and _G.GetSpellTexture(35395))
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            if csTexture ~= ui.lastCSIconTexture then
                ui.lastCSIconTexture = csTexture
                if ui.csIconSparkIcon then
                    ui.csIconSparkIcon:SetTexture(csTexture)
                end
            end

            local csActionDelay = csVisualDelay or 0
            local csActionSeconds
            if (csActionDelay or 0) <= SECONDS_EPSILON then
                csActionSeconds = 0
            else
                csActionSeconds = ClampActionSecondsForTimeline(csActionDelay, swingSpeed)
            end
            csActionSecondsDebug = csActionSeconds

            local csX = SecondsBeforeSwingToX(csActionSeconds, width, swingSpeed)
            local csIconSize = ui.csIconSparkFrame:GetWidth() or 16
            local csY
            local csLaneMode = db.csLaneMode or "auto"
            local csUseTopLane = sideBySideJudgeSoc
            if csLaneMode == "top" then
                csUseTopLane = true
            elseif csLaneMode == "bottom" then
                csUseTopLane = false
            end
            if csUseTopLane then
                -- Top-group alignment: same vertical baseline as SoC/Judgement top cluster.
                csY = swingCenterY + (swingHeight / 2) + (csIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.judgeSocSideBySideOffsetY or 0)
            else
                -- Dedicated lower lane in split mode (or forced bottom mode).
                csY = swingCenterY - (swingHeight / 2) - (csIconSize / 2) - 1 + predictionBottomLaneOffsetY + predictionCSSplitExtraOffsetY
            end
            csXDebug = csX
            csYDebug = csY
            ui.csIconSparkFrame:ClearAllPoints()
            ui.csIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(csX), csY)

            if ui.csIconSparkBackground then
                local r, g, b, a = GetIconTintByActionRemaining(csActionDelay or 0)
                ui.csIconSparkBackground:SetVertexColor(r, g, b, a)
                ui.csIconSparkBackground:Show()
            end
            csFadeAlphaDebug = GetPredictionIconFadeAlpha(self, "cs", true, now)
            ui.csIconSparkFrame:SetAlpha(csFadeAlphaDebug)
            ui.csIconSparkFrame:Show()
            SetSparkKeybind(ui.csIconSparkFrame, self.db.class.showKeybindOnBar)
        else
            GetPredictionIconFadeAlpha(self, "cs", false, now)
            SetSparkKeybind(ui.csIconSparkFrame, false)
            ui.csIconSparkFrame:Hide()
            ui.csIconSparkFrame:SetAlpha(1)
            if ui.csIconSparkBackground then
                ui.csIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.csIconSparkBackground:Hide()
            end
        end
    end

    if NAG.IsDevModeEnabled and NAG:IsDevModeEnabled() and false then
        local csSmooth = holdSmoothState and holdSmoothState["cs"] or nil
        local csSmoothRaw = csSmooth and csSmooth.raw or nil
        local csSmoothPredicted = csSmooth and csSmooth.predicted or nil
        local csSmoothLastSample = csSmooth and csSmooth.lastSampleAt or nil
        local zeroStickActive = self._zeroStickState and self._zeroStickState.cs and true or false
        if csRecommended or csDisplayed then
            print(string.format(
                "[TWIST_BAR_CS_DEBUG] show=%s rec=%s rawReady=%.3f visDelay=%.3f actionSec=%.3f x=%.1f y=%.1f fade=%.2f gcdLeft=%.3f prev=%.3f delta=%.3f suppress=%s suppressLeft=%.3f zeroStick=%s smoothRaw=%.3f smoothPred=%.3f smoothAge=%.3f laneMode=%s iconSize=%.1f",
                tostring(csDisplayed),
                tostring(csRecommended),
                csRawReady or -1,
                csVisualDelay or -1,
                csActionSecondsDebug or -1,
                csXDebug or -1,
                csYDebug or -1,
                csFadeAlphaDebug or -1,
                gcdLeft or 0,
                csPrev or -1,
                csDelta or 0,
                tostring(iconsSuppressed),
                math.max(0, (self._iconSuppressUntil or 0) - now),
                tostring(zeroStickActive),
                csSmoothRaw or -1,
                csSmoothPredicted or -1,
                (csSmoothLastSample and (now - csSmoothLastSample)) or -1,
                tostring(db.csLaneMode or "auto"),
                (ui.csIconSparkFrame and ui.csIconSparkFrame:GetWidth()) or -1
            ))
        end
    end

    -- Filler icon lane: Consecration/Exorcism on reverted Judgement lane.
    if ui.fillerIconSparkFrame then
        if iconsSuppressed then
            GetPredictionIconFadeAlpha(self, "filler", false, now)
            SetSparkKeybind(ui.fillerIconSparkFrame, false)
            ui.fillerIconSparkFrame:Hide()
            ui.fillerIconSparkFrame:SetAlpha(1)
            if ui.fillerIconSparkBackground then
                ui.fillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.fillerIconSparkBackground:Hide()
            end
        elseif fillerDisplayed then
            local fillerTexture = (NAG.Spell and NAG.Spell[fillerSpellId] and NAG.Spell[fillerSpellId].icon)
                or (_G.GetSpellTexture and _G.GetSpellTexture(fillerSpellId))
                or "Interface\\Icons\\INV_Misc_QuestionMark"
            if fillerTexture ~= ui.lastFillerIconTexture then
                ui.lastFillerIconTexture = fillerTexture
                if ui.fillerIconSparkIcon then
                    ui.fillerIconSparkIcon:SetTexture(fillerTexture)
                end
            end

            local fillerActionDelay = fillerVisualDelay or 0
            local fillerActionSeconds
            if (fillerActionDelay or 0) <= SECONDS_EPSILON then
                fillerActionSeconds = 0
            else
                fillerActionSeconds = ClampActionSecondsForTimeline(fillerActionDelay, swingSpeed)
            end
            fillerActionSecondsDebug = fillerActionSeconds

            local fillerX = SecondsBeforeSwingToX(fillerActionSeconds, width, swingSpeed) + (db.fillerOffsetX or 0)
            local fillerIconSize = ui.fillerIconSparkFrame:GetWidth() or 16
            local fillerLaneMode = db.fillerLaneMode or "bottom"
            local fillerY
            if fillerLaneMode == "top" then
                fillerY = swingCenterY + (swingHeight / 2) + (fillerIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.fillerOffsetY or 0)
            else
                fillerY = swingCenterY - (swingHeight / 2) - (fillerIconSize / 2) - 1 + predictionBottomLaneOffsetY + (db.fillerOffsetY or 0)
            end
            fillerXDebug = fillerX
            fillerYDebug = fillerY
            ui.fillerIconSparkFrame.spellId = fillerSpellId
            ui.fillerIconSparkFrame:ClearAllPoints()
            ui.fillerIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(fillerX), fillerY)

            if ui.fillerIconSparkBackground then
                local r, g, b, a = GetIconTintByActionRemaining(fillerActionDelay or 0)
                ui.fillerIconSparkBackground:SetVertexColor(r, g, b, a)
                ui.fillerIconSparkBackground:Show()
            end
            ui.fillerIconSparkFrame:SetAlpha(GetPredictionIconFadeAlpha(self, "filler", true, now))
            ui.fillerIconSparkFrame:Show()
            SetSparkKeybind(ui.fillerIconSparkFrame, self.db.class.showKeybindOnBar)
        else
            GetPredictionIconFadeAlpha(self, "filler", false, now)
            SetSparkKeybind(ui.fillerIconSparkFrame, false)
            ui.fillerIconSparkFrame:Hide()
            ui.fillerIconSparkFrame:SetAlpha(1)
            if ui.fillerIconSparkBackground then
                ui.fillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.fillerIconSparkBackground:Hide()
            end
        end
    end

    -- ============================ NEXT-NEXT ICON LANES (SAME AS CURRENT) ============================
    -- Next-next icons use the same Y lanes as current icons; show when within two swings so they're visible.
    local visibleBarSeconds = (swingSpeed or 1.5) * 2

    -- Debug: next-next payload and per-lane show/hide reasons (throttled; dev mode only)
    local dbgThrottle = tonumber(db.debugThrottleSeconds or 0.25) or 0.25
    local lastAt = tonumber(self._nextNextDebugAt or 0) or 0
    local nextNextDebugThisFrame = (now - lastAt) >= dbgThrottle
        and (NAG.IsDevModeEnabled and NAG:IsDevModeEnabled())
    if nextNextDebugThisFrame then
        self._nextNextDebugAt = now
        if not nextNextCore then
            print(string.format("[TWIST_BAR_NEXTNEXT] NO_PAYLOAD: nextNextCore=nil (payload empty or no state1)"))
        else
        self._nextNextDebugDetail = true
        local coreWait = tonumber(nextNextCore.waitFromNow or 0) or 0
        local fillerWait = tonumber(nextNextFiller and nextNextFiller.waitFromNow or 0) or 0
        print(string.format(
            "[TWIST_BAR_NEXTNEXT] action=%s spell=%s soc=%s judge=%s cs=%s filler=%s | coreWait=%.2f fillerWait=%.2f visibleMax=%.2f swing=%.2f",
            tostring(nextNextCoreActionKey or ""),
            tostring(nextNextCoreSpellId or 0),
            tostring(nextNextSoCRecommended),
            tostring(nextNextJudgeActive),
            tostring(nextNextCSRecommended),
            tostring(nextNextFillerSpellId or 0),
            coreWait, fillerWait, visibleBarSeconds, swingSpeed or 1.5
        ))
        print(string.format(
            "  -> showSwing=%s showSoc=%s showJudge=%s showCS=%s showFiller=%s nextNextEnabled=%s iconsSuppressed=%s",
            tostring(db.showSwingIconSpark), tostring(db.showSocIcon ~= false), tostring(db.showJudgeIcon ~= false),
            tostring(db.showCSIcon ~= false), tostring(db.showFillerIconSpark), tostring(nextNextEnabled), tostring(iconsSuppressed)
        ))
        print(string.format(
            "  -> socInWindow=%s judgeInWindow=%s csInWindow=%s fillerInWindow=%s (delay<=%.2f)",
            tostring((nextNextSoCDelay or 999) <= visibleBarSeconds),
            tostring((nextNextJudgeDelay or 999) <= visibleBarSeconds),
            tostring((nextNextCSDelay or 999) <= visibleBarSeconds),
            tostring((nextNextFillerDelay or 999) <= visibleBarSeconds),
            visibleBarSeconds
        ))
        end
    end

    if ui.nextSocIconSparkFrame then
        if iconsSuppressed or nextNextForceHide then
            GetNextNextIconDisplayState(self, "soc_nn", false, true, now)
            SetSparkKeybind(ui.nextSocIconSparkFrame, false)
            ui.nextSocIconSparkFrame:SetAlpha(1)
            ui.nextSocIconSparkFrame:Hide()
            if ui.nextSocIconSparkBackground then
                ui.nextSocIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextSocIconSparkBackground:Hide()
            end
        elseif db.showSwingIconSpark and db.showSocIcon ~= false and nextNextEnabled and nextNextSoCRecommended then
            local socActionDelay = nextNextSoCDelay or 0
            if socActionDelay <= visibleBarSeconds then
                -- Use nextNextCoreSpellId when twist/hold (seal from state machine); else SoC ids.
                local displaySoCId = (nextNextCoreActionKey == "twist" or nextNextCoreActionKey == "hold") and nextNextCoreSpellId
                    or resolvedSoCId or soCId or (nextNextSocFollow and tonumber(nextNextSocFollow.spellId or 0) or 0)
                local socTexture = displaySoCId and displaySoCId > 0 and GetNextNextSpellIcon(displaySoCId, inCombat) or nil
                if self._nextNextDebugDetail then
                    print(string.format("  [SoC_nn] displayId=%s texture=%s inCombat=%s -> %s",
                        tostring(displaySoCId or 0),
                        socTexture and "ok" or "nil",
                        tostring(inCombat),
                        socTexture and "SHOW" or "HIDE(no texture)"
                    ))
                end
                if socTexture then
                    if socTexture ~= ui.lastNextSoCIconTexture then
                        ui.lastNextSoCIconTexture = socTexture
                        if ui.nextSocIconSparkIcon then
                            ui.nextSocIconSparkIcon:SetTexture(socTexture)
                        end
                    end

                    local socActionSeconds = (socActionDelay <= SECONDS_EPSILON) and 0 or ClampActionSecondsForTimeline(socActionDelay, swingSpeed)
                    local socX = SecondsBeforeSwingToX(socActionSeconds, width, swingSpeed)
                    local socIconSize = ui.nextSocIconSparkFrame:GetWidth() or 16
                    local topY = swingCenterY + (swingHeight / 2) + (socIconSize / 2) + 1 + predictionTopLaneOffsetY
                    if sideBySideJudgeSoc and nextNextJudgeActive then
                        socX = socX + (db.socSideBySideOffsetX or 0)
                        topY = topY + (db.judgeSocSideBySideOffsetY or 0)
                    end
                    ui.nextSocIconSparkFrame:ClearAllPoints()
                    ui.nextSocIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(socX), topY)
                    if ui.nextSocIconSparkBackground then
                        local r, g, b, a = GetIconTintByActionRemaining(socActionDelay)
                        ui.nextSocIconSparkBackground:SetVertexColor(r, g, b, a)
                        ui.nextSocIconSparkBackground:Show()
                    end
                    ui.nextSocIconSparkFrame.spellId = displaySoCId
                    local showFrame, alpha = GetNextNextIconDisplayState(self, "soc_nn", true, false, now)
                    ui.nextSocIconSparkFrame:SetAlpha(alpha)
                    ui.nextSocIconSparkFrame:Show()
                    SetSparkKeybind(ui.nextSocIconSparkFrame, self.db.class.showKeybindOnBar)
                else
                    local showFrame, alpha = GetNextNextIconDisplayState(self, "soc_nn", false, false, now)
                    SetSparkKeybind(ui.nextSocIconSparkFrame, false)
                    ui.nextSocIconSparkFrame:SetAlpha(alpha)
                    if showFrame then ui.nextSocIconSparkFrame:Show() else ui.nextSocIconSparkFrame:Hide() end
                    if not showFrame and ui.nextSocIconSparkBackground then
                        ui.nextSocIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                        ui.nextSocIconSparkBackground:Hide()
                    end
                end
        else
            if self._nextNextDebugDetail and nextNextSoCRecommended then
                print(string.format("  [SoC_nn] HIDE: delay=%.2f > visible=%.2f", socActionDelay, visibleBarSeconds))
            end
            local showFrame, alpha = GetNextNextIconDisplayState(self, "soc_nn", false, false, now)
            SetSparkKeybind(ui.nextSocIconSparkFrame, false)
            ui.nextSocIconSparkFrame:SetAlpha(alpha)
            if showFrame then ui.nextSocIconSparkFrame:Show() else ui.nextSocIconSparkFrame:Hide() end
            if not showFrame and ui.nextSocIconSparkBackground then
                ui.nextSocIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextSocIconSparkBackground:Hide()
            end
        end
    else
        if self._nextNextDebugDetail then
            print(string.format("  [SoC_nn] HIDE: showSwing=%s showSoc=%s nextNextEnabled=%s nextNextSoCRecommended=%s iconsSuppressed=%s",
                tostring(db.showSwingIconSpark), tostring(db.showSocIcon ~= false), tostring(nextNextEnabled),
                tostring(nextNextSoCRecommended), tostring(iconsSuppressed)))
        end
        local showFrame, alpha = GetNextNextIconDisplayState(self, "soc_nn", false, false, now)
        SetSparkKeybind(ui.nextSocIconSparkFrame, false)
        ui.nextSocIconSparkFrame:SetAlpha(alpha)
        if showFrame then ui.nextSocIconSparkFrame:Show() else ui.nextSocIconSparkFrame:Hide() end
        if not showFrame and ui.nextSocIconSparkBackground then
            ui.nextSocIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
            ui.nextSocIconSparkBackground:Hide()
        end
    end
end

    if ui.nextJudgeIconSparkFrame then
        if iconsSuppressed or nextNextForceHide then
            GetNextNextIconDisplayState(self, "judge_nn", false, true, now)
            SetSparkKeybind(ui.nextJudgeIconSparkFrame, false)
            ui.nextJudgeIconSparkFrame:Hide()
            ui.nextJudgeIconSparkFrame:SetAlpha(1)
            if ui.nextJudgeIconSparkBackground then
                ui.nextJudgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextJudgeIconSparkBackground:Hide()
            end
        elseif db.showSwingIconSpark and db.showJudgeIcon ~= false and nextNextEnabled and nextNextJudgeActive then
            local judgeActionDelay = nextNextJudgeDelay or 0
            if judgeActionDelay <= visibleBarSeconds then
                local judgeTexture = GetNextNextSpellIcon(20271, inCombat)
                if self._nextNextDebugDetail then
                    print(string.format("  [Judge_nn] spellId=20271 texture=%s inCombat=%s -> %s",
                        judgeTexture and "ok" or "nil", tostring(inCombat), judgeTexture and "SHOW" or "HIDE(no texture)"))
                end
                if judgeTexture then
                if judgeTexture ~= ui.lastNextJudgeIconTexture then
                    ui.lastNextJudgeIconTexture = judgeTexture
                    if ui.nextJudgeIconSparkIcon then
                        ui.nextJudgeIconSparkIcon:SetTexture(judgeTexture)
                    end
                end

                local judgeActionSeconds = (judgeActionDelay <= SECONDS_EPSILON) and 0 or ClampActionSecondsForTimeline(judgeActionDelay, swingSpeed)
                local judgeX = SecondsBeforeSwingToX(judgeActionSeconds, width, swingSpeed)
                local judgeIconSize = ui.nextJudgeIconSparkFrame:GetWidth() or 16
                local judgeY
                if sideBySideJudgeSoc then
                    judgeY = swingCenterY + (swingHeight / 2) + (judgeIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.judgeSocSideBySideOffsetY or 0)
                    judgeX = judgeX + (db.judgeSideBySideOffsetX or 0)
                else
                    judgeY = swingCenterY - (swingHeight / 2) - (judgeIconSize / 2) - 1 + predictionBottomLaneOffsetY
                end
                ui.nextJudgeIconSparkFrame:ClearAllPoints()
                ui.nextJudgeIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(judgeX), judgeY)
                if ui.nextJudgeIconSparkBackground then
                    local r, g, b, a = GetIconTintByActionRemaining(judgeActionDelay)
                    ui.nextJudgeIconSparkBackground:SetVertexColor(r, g, b, a)
                    ui.nextJudgeIconSparkBackground:Show()
                end
                ui.nextJudgeIconSparkFrame.spellId = 20271
                local showFrame, alpha = GetNextNextIconDisplayState(self, "judge_nn", true, false, now)
                ui.nextJudgeIconSparkFrame:SetAlpha(alpha)
                ui.nextJudgeIconSparkFrame:Show()
                SetSparkKeybind(ui.nextJudgeIconSparkFrame, self.db.class.showKeybindOnBar)
                else
                    local showFrame, alpha = GetNextNextIconDisplayState(self, "judge_nn", false, false, now)
                    SetSparkKeybind(ui.nextJudgeIconSparkFrame, false)
                    ui.nextJudgeIconSparkFrame:SetAlpha(alpha)
                    if showFrame then ui.nextJudgeIconSparkFrame:Show() else ui.nextJudgeIconSparkFrame:Hide() end
                    if not showFrame and ui.nextJudgeIconSparkBackground then
                        ui.nextJudgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                        ui.nextJudgeIconSparkBackground:Hide()
                    end
                end
            else
                local showFrame, alpha = GetNextNextIconDisplayState(self, "judge_nn", false, false, now)
                SetSparkKeybind(ui.nextJudgeIconSparkFrame, false)
                ui.nextJudgeIconSparkFrame:SetAlpha(alpha)
                if showFrame then ui.nextJudgeIconSparkFrame:Show() else ui.nextJudgeIconSparkFrame:Hide() end
                if not showFrame and ui.nextJudgeIconSparkBackground then
                    ui.nextJudgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                    ui.nextJudgeIconSparkBackground:Hide()
                end
            end
        else
            local showFrame, alpha = GetNextNextIconDisplayState(self, "judge_nn", false, false, now)
            SetSparkKeybind(ui.nextJudgeIconSparkFrame, false)
            ui.nextJudgeIconSparkFrame:SetAlpha(alpha)
            if showFrame then ui.nextJudgeIconSparkFrame:Show() else ui.nextJudgeIconSparkFrame:Hide() end
            if not showFrame and ui.nextJudgeIconSparkBackground then
                ui.nextJudgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextJudgeIconSparkBackground:Hide()
            end
        end
    end

    if ui.nextCSIconSparkFrame then
        if iconsSuppressed or nextNextForceHide then
            GetNextNextIconDisplayState(self, "cs_nn", false, true, now)
            SetSparkKeybind(ui.nextCSIconSparkFrame, false)
            ui.nextCSIconSparkFrame:Hide()
            ui.nextCSIconSparkFrame:SetAlpha(1)
            if ui.nextCSIconSparkBackground then
                ui.nextCSIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextCSIconSparkBackground:Hide()
            end
        elseif db.showSwingIconSpark and db.showCSIcon ~= false and nextNextEnabled and nextNextCSRecommended then
            local csActionDelay = nextNextCSDelay or 0
            if csActionDelay <= visibleBarSeconds then
                local csTexture = GetNextNextSpellIcon(35395, inCombat)
                if self._nextNextDebugDetail then
                    print(string.format("  [CS_nn] spellId=35395 texture=%s inCombat=%s -> %s",
                        csTexture and "ok" or "nil", tostring(inCombat), csTexture and "SHOW" or "HIDE(no texture)"))
                end
                if csTexture then
                if csTexture ~= ui.lastNextCSIconTexture then
                    ui.lastNextCSIconTexture = csTexture
                    if ui.nextCSIconSparkIcon then
                        ui.nextCSIconSparkIcon:SetTexture(csTexture)
                    end
                end

                local csActionSeconds = (csActionDelay <= SECONDS_EPSILON) and 0 or ClampActionSecondsForTimeline(csActionDelay, swingSpeed)
                local csX = SecondsBeforeSwingToX(csActionSeconds, width, swingSpeed)
                local csIconSize = ui.nextCSIconSparkFrame:GetWidth() or 16
                local csLaneMode = db.csLaneMode or "auto"
                local csUseTopLane = sideBySideJudgeSoc
                if csLaneMode == "top" then
                    csUseTopLane = true
                elseif csLaneMode == "bottom" then
                    csUseTopLane = false
                end
                local csY
                if csUseTopLane then
                    csY = swingCenterY + (swingHeight / 2) + (csIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.judgeSocSideBySideOffsetY or 0)
                else
                    csY = swingCenterY - (swingHeight / 2) - (csIconSize / 2) - 1 + predictionBottomLaneOffsetY + predictionCSSplitExtraOffsetY
                end
                ui.nextCSIconSparkFrame:ClearAllPoints()
                ui.nextCSIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(csX), csY)
                if ui.nextCSIconSparkBackground then
                    local r, g, b, a = GetIconTintByActionRemaining(csActionDelay)
                    ui.nextCSIconSparkBackground:SetVertexColor(r, g, b, a)
                    ui.nextCSIconSparkBackground:Show()
                end
                ui.nextCSIconSparkFrame.spellId = 35395
                local showFrame, alpha = GetNextNextIconDisplayState(self, "cs_nn", true, false, now)
                ui.nextCSIconSparkFrame:SetAlpha(alpha)
                ui.nextCSIconSparkFrame:Show()
                SetSparkKeybind(ui.nextCSIconSparkFrame, self.db.class.showKeybindOnBar)
                else
                    local showFrame, alpha = GetNextNextIconDisplayState(self, "cs_nn", false, false, now)
                    SetSparkKeybind(ui.nextCSIconSparkFrame, false)
                    ui.nextCSIconSparkFrame:SetAlpha(alpha)
                    if showFrame then ui.nextCSIconSparkFrame:Show() else ui.nextCSIconSparkFrame:Hide() end
                    if not showFrame and ui.nextCSIconSparkBackground then
                        ui.nextCSIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                        ui.nextCSIconSparkBackground:Hide()
                    end
                end
            else
                local showFrame, alpha = GetNextNextIconDisplayState(self, "cs_nn", false, false, now)
                SetSparkKeybind(ui.nextCSIconSparkFrame, false)
                ui.nextCSIconSparkFrame:SetAlpha(alpha)
                if showFrame then ui.nextCSIconSparkFrame:Show() else ui.nextCSIconSparkFrame:Hide() end
                if not showFrame and ui.nextCSIconSparkBackground then
                    ui.nextCSIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                    ui.nextCSIconSparkBackground:Hide()
                end
            end
        else
            local showFrame, alpha = GetNextNextIconDisplayState(self, "cs_nn", false, false, now)
            SetSparkKeybind(ui.nextCSIconSparkFrame, false)
            ui.nextCSIconSparkFrame:SetAlpha(alpha)
            if showFrame then ui.nextCSIconSparkFrame:Show() else ui.nextCSIconSparkFrame:Hide() end
            if not showFrame and ui.nextCSIconSparkBackground then
                ui.nextCSIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextCSIconSparkBackground:Hide()
            end
        end
    end

    if ui.nextFillerIconSparkFrame then
        if iconsSuppressed or nextNextForceHide then
            GetNextNextIconDisplayState(self, "filler_nn", false, true, now)
            SetSparkKeybind(ui.nextFillerIconSparkFrame, false)
            ui.nextFillerIconSparkFrame:Hide()
            ui.nextFillerIconSparkFrame:SetAlpha(1)
            if ui.nextFillerIconSparkBackground then
                ui.nextFillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextFillerIconSparkBackground:Hide()
            end
        elseif db.showSwingIconSpark and db.showFillerIconSpark and nextNextEnabled and nextNextFillerSpellId and nextNextFillerSpellId > 0 then
            local fillerActionDelay = nextNextFillerDelay or 0
            if fillerActionDelay <= visibleBarSeconds then
                local fillerTexture = GetNextNextSpellIcon(nextNextFillerSpellId, inCombat)
                if self._nextNextDebugDetail then
                    print(string.format("  [Filler_nn] spellId=%s texture=%s inCombat=%s -> %s",
                        tostring(nextNextFillerSpellId or 0), fillerTexture and "ok" or "nil",
                        tostring(inCombat), fillerTexture and "SHOW" or "HIDE(no texture)"))
                end
                if fillerTexture then
                if fillerTexture ~= ui.lastNextFillerIconTexture then
                    ui.lastNextFillerIconTexture = fillerTexture
                    if ui.nextFillerIconSparkIcon then
                        ui.nextFillerIconSparkIcon:SetTexture(fillerTexture)
                    end
                end

                local fillerActionSeconds = (fillerActionDelay <= SECONDS_EPSILON) and 0 or ClampActionSecondsForTimeline(fillerActionDelay, swingSpeed)
                local fillerX = SecondsBeforeSwingToX(fillerActionSeconds, width, swingSpeed) + (db.fillerOffsetX or 0)
                local fillerIconSize = ui.nextFillerIconSparkFrame:GetWidth() or 16
                local fillerLaneMode = db.fillerLaneMode or "bottom"
                local fillerY
                if fillerLaneMode == "top" then
                    fillerY = swingCenterY + (swingHeight / 2) + (fillerIconSize / 2) + 1 + predictionTopLaneOffsetY + (db.fillerOffsetY or 0)
                else
                    fillerY = swingCenterY - (swingHeight / 2) - (fillerIconSize / 2) - 1 + predictionBottomLaneOffsetY + (db.fillerOffsetY or 0)
                end
                ui.nextFillerIconSparkFrame.spellId = nextNextFillerSpellId
                ui.nextFillerIconSparkFrame:ClearAllPoints()
                ui.nextFillerIconSparkFrame:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(fillerX), fillerY)
                if ui.nextFillerIconSparkBackground then
                    local r, g, b, a = GetIconTintByActionRemaining(fillerActionDelay)
                    ui.nextFillerIconSparkBackground:SetVertexColor(r, g, b, a)
                    ui.nextFillerIconSparkBackground:Show()
                end
                local showFrame, alpha = GetNextNextIconDisplayState(self, "filler_nn", true, false, now)
                ui.nextFillerIconSparkFrame:SetAlpha(alpha)
                ui.nextFillerIconSparkFrame:Show()
                SetSparkKeybind(ui.nextFillerIconSparkFrame, self.db.class.showKeybindOnBar)
                else
                    local showFrame, alpha = GetNextNextIconDisplayState(self, "filler_nn", false, false, now)
                    SetSparkKeybind(ui.nextFillerIconSparkFrame, false)
                    ui.nextFillerIconSparkFrame:SetAlpha(alpha)
                    if showFrame then ui.nextFillerIconSparkFrame:Show() else ui.nextFillerIconSparkFrame:Hide() end
                    if not showFrame and ui.nextFillerIconSparkBackground then
                        ui.nextFillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                        ui.nextFillerIconSparkBackground:Hide()
                    end
                end
            else
                local showFrame, alpha = GetNextNextIconDisplayState(self, "filler_nn", false, false, now)
                SetSparkKeybind(ui.nextFillerIconSparkFrame, false)
                ui.nextFillerIconSparkFrame:SetAlpha(alpha)
                if showFrame then ui.nextFillerIconSparkFrame:Show() else ui.nextFillerIconSparkFrame:Hide() end
                if not showFrame and ui.nextFillerIconSparkBackground then
                    ui.nextFillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                    ui.nextFillerIconSparkBackground:Hide()
                end
            end
        else
            local showFrame, alpha = GetNextNextIconDisplayState(self, "filler_nn", false, false, now)
            SetSparkKeybind(ui.nextFillerIconSparkFrame, false)
            ui.nextFillerIconSparkFrame:SetAlpha(alpha)
            if showFrame then ui.nextFillerIconSparkFrame:Show() else ui.nextFillerIconSparkFrame:Hide() end
            if not showFrame and ui.nextFillerIconSparkBackground then
                ui.nextFillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
                ui.nextFillerIconSparkBackground:Hide()
            end
        end
    end

    if self._nextNextDebugDetail then
        self._nextNextDebugDetail = nil
    end

    if NAG.IsDevModeEnabled and NAG:IsDevModeEnabled() and false then
        print(string.format(
            "[TWIST_BAR_POS] socSeconds=%.3f judgeSeconds=%.3f csSeconds=%.3f fillerSeconds=%.3f socX=%.1f judgeX=%.1f csX=%.1f csY=%.1f fillerX=%.1f fillerY=%.1f",
            socActionSecondsDebug or -1,
            judgeActionSecondsDebug or -1,
            csActionSecondsDebug or -1,
            fillerActionSecondsDebug or -1,
            socXDebug or -1,
            judgeXDebug or -1
            ,
            csXDebug or -1,
            csYDebug or -1,
            fillerXDebug or -1,
            fillerYDebug or -1
        ))
    end

    -- Past swing spark: show the most recent swing in the fixed 0.4s history region.
    if ui.pastSwingSpark and historyPx and historyPx > 0 and swingSpeed and swingSpeed > 0 then
        local timeSinceSwing = swingSpeed - (swingLeft or 0)
        local historySeconds = 0.4
        if timeSinceSwing < 0 then timeSinceSwing = 0 end

        if historySeconds > 0 and timeSinceSwing <= historySeconds then
            local t = Clamp01(timeSinceSwing / historySeconds)
            local x = historyPx * (1 - t)
            ui.pastSwingSpark:SetSize(2, swingHeight)
            ui.pastSwingSpark:ClearAllPoints()
            ui.pastSwingSpark:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(x), swingCenterY)
            ui.pastSwingSpark:Show()
        else
            ui.pastSwingSpark:Hide()
        end
    else
        ui.pastSwingSpark:Hide()
    end

    -- ============================ GCD LANE (separate, below swing lane) ============================
    -- GCD bar: 2px height, positioned 6px below the swing lane so it doesn't block the view.
    local gcd = gcdLeft
    local clampedGcd = gcd
    if clampedGcd < 0 then clampedGcd = 0 end
    if clampedGcd > swingSpeed then clampedGcd = swingSpeed end
    if showGCDLane then
        ui.gcdBar:ClearAllPoints()
        local gcdProgress = Clamp01(clampedGcd / swingSpeed)
        ui.gcdBar:SetWidth(futurePx * gcdProgress)
        ui.gcdBar:SetHeight(gcdHeight)
        if leftToRight then
            -- Fill left-to-right: anchor right edge at swing moment, bar extends leftward.
            ui.gcdBar:SetPoint("RIGHT", ui.frame, "LEFT", toVisualX(historyPx), gcdCenterY)
        else
            ui.gcdBar:SetPoint("LEFT", ui.frame, "LEFT", toVisualX(historyPx), gcdCenterY)
        end
    end
    if showGCDLane and gcd > 0 then
        ui.gcdBar:Show()
        if db.showGCDSparks ~= false then
            -- Right spark: bottom-aligned to the GCD bar.
            ui.gcdSpark:SetSize(2, gcdSparkHeight)
            ui.gcdSpark:ClearAllPoints()
            ui.gcdSpark:SetPoint("BOTTOM", ui.gcdBar, "BOTTOMRIGHT", 0, 0)
            ui.gcdSpark:Show()

            -- Left spark: bottom-aligned to the GCD bar.
            if ui.gcdSparkLeft then
                ui.gcdSparkLeft:SetSize(2, gcdSparkHeight)
                ui.gcdSparkLeft:ClearAllPoints()
                ui.gcdSparkLeft:SetPoint("BOTTOM", ui.gcdBar, "BOTTOMLEFT", 0, 0)
                ui.gcdSparkLeft:Show()
            end
        else
            ui.gcdSpark:Hide()
            if ui.gcdSparkLeft then
                ui.gcdSparkLeft:Hide()
            end
        end
    else
        ui.gcdBar:Hide()
        ui.gcdSpark:Hide()
        if ui.gcdSparkLeft then
            ui.gcdSparkLeft:Hide()
        end
    end

    -- ============================ TWIST WINDOW VISUALIZATION ============================
    -- Twist window visuals are combat-only and only show while SoC/twist timing is relevant.
    if inCombat and db.showTwistWindow and ui.twistWindowBar then
        local window = db.twistWindowSeconds or 0.4
        if window < 0 then window = 0 end
        if window > swingSpeed then window = swingSpeed end

        -- Zero mark spark: fixed reference tick at the swing boundary (where the twist gap used to be static).
        -- This should always be visible when the twist window feature is enabled, even if the moving gap hides.
        if ui.twistZeroSpark then
            ui.twistZeroSpark:SetSize(2, swingHeight)
            ui.twistZeroSpark:ClearAllPoints()
            ui.twistZeroSpark:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(historyPx), swingCenterY)
            ui.twistZeroSpark:Show()
        end

        -- Moving twist gap: [spark-window, spark] where spark is the current swing marker position.
        -- Visibility is tied to the auto spark/icon gate (same as ui.swingIconSparkFrame visibility).
        if autoSparkVisible then
            local startSeconds = (swingLeft or 0) - window
            local endSeconds = (swingLeft or 0)
            local startX = SecondsBeforeSwingToX(startSeconds, width, swingSpeed)
            local endX = SecondsBeforeSwingToX(endSeconds, width, swingSpeed)
            local barWidth = endX - startX

            if barWidth > 0 then
                -- Dynamic twist gap color:
                -- - keep configured alpha
                -- - yellow when left edge is < 1.0s from fixed zero mark
                -- - green when left edge is < 0.05s from fixed zero mark
                local base = db.twistWindowColor or defaults.class.twistWindowColor
                local a = (base and base.a) or 0.18
                local timeToZero = (swingLeft or 0) - window -- when this hits 0, left edge reaches fixed zero mark
                if timeToZero < 0 then timeToZero = 0 end
                if timeToZero <= 0.05 then
                    ui.twistWindowBar:SetColorTexture(0.20, 0.95, 0.35, a)
                elseif timeToZero < 1.0 then
                    ui.twistWindowBar:SetColorTexture(1.0, 1.0, 0.0, a)
                else
                    ui.twistWindowBar:SetColorTexture(base.r or 0.90, base.g or 0.90, base.b or 0.90, a)
                end

                ui.twistWindowBar:SetHeight(swingHeight)
                ui.twistWindowBar:SetWidth(barWidth)
                ui.twistWindowBar:ClearAllPoints()
                ui.twistWindowBar:SetPoint("LEFT", ui.frame, "LEFT", leftToRight and toVisualX(endX) or toVisualX(startX), swingCenterY)
                ui.twistWindowBar:Show()
            else
                ui.twistWindowBar:Hide()
            end

        else
            ui.twistWindowBar:Hide()
        end

        -- Optional div boundary marker:
        -- fixed reference where a fresh GCD can still finish before the twist window opens.
        if ui.divBoundaryMarker then
            if db.showDivBoundaryMarker and autoSparkVisible then
                local lastGCDValue = NAG.GCDTimeValue and NAG:GCDTimeValue() or 0
                if lastGCDValue < 0 then lastGCDValue = 0 end
                local markerSecondsBeforeSwing = (swingLeft or 0) - window - lastGCDValue
                local markerX = SecondsBeforeSwingToX(markerSecondsBeforeSwing, width, swingSpeed)
                if markerX >= 0 and markerX <= width then
                    ui.divBoundaryMarker:SetSize(2, swingHeight)
                    ui.divBoundaryMarker:ClearAllPoints()
                    ui.divBoundaryMarker:SetPoint("CENTER", ui.frame, "LEFT", toVisualX(markerX), swingCenterY)
                    ui.divBoundaryMarker:Show()
                else
                    ui.divBoundaryMarker:Hide()
                end
            else
                ui.divBoundaryMarker:Hide()
            end
        end
    else
        if ui.twistWindowBar then ui.twistWindowBar:Hide() end
        if ui.twistZeroSpark then ui.twistZeroSpark:Hide() end
        if ui.divBoundaryMarker then ui.divBoundaryMarker:Hide() end
    end

    -- Debug prints (always-on, throttled): verify all geometry inputs live.
    local throttle = db.debugThrottleSeconds or 0.25
    if throttle < 0 then throttle = 0 end

    local gcdShown = ui.gcdBar:IsShown()
    local gcdW = ui.gcdBar:GetWidth() or 0
    local swingW = ui.swingBar:GetWidth() or 0
    local twistShown = ui.twistWindowBar and ui.twistWindowBar:IsShown() or false
    local feasibleShown = false
    local divShown = ui.divBoundaryMarker and ui.divBoundaryMarker:IsShown() or false

    -- Calculate markerX for debug output only
    local markerX = swingW or 0

    self:ThrottledInfo(
        "RetTwistBar: combat=%d gcd=%.3f swingLeft=%.3f speed=%.3f swingProg=%.3f markerX=%.1f gcdW=%.1f twistShown=%d feasibleShown=%d divShown=%d",
        "retTwistBar_debug_core",
        throttle,
        To01(UnitAffectingCombat("player")),
        gcd,
        swingLeft,
        swingSpeed,
        swingProgress,
        markerX,
        gcdW,
        To01(twistShown),
        To01(feasibleShown),
        To01(divShown)
    )

    -- ============================ TWIST SUCCESS TOAST (SUCCESS-ONLY) ============================
    -- Triggered by `PaladinRetTwistModule` on swing impact via raw aura scanning.
    if ui.twistOutcomeText and NAG.RetTwistGetLastSuccess then
        local lastSuccessTime, _, twistId = NAG:RetTwistGetLastSuccess()
        if lastSuccessTime and lastSuccessTime > 0 and self._retTwistToastLastSuccessTime ~= lastSuccessTime then
            self._retTwistToastLastSuccessTime = lastSuccessTime
            self._retTwistToastStartTime = GetTime()
            local toast = buildSuccessToast(twistId)
            self._retTwistToastText = toast.text
            self._retTwistToastColor = { toast.r, toast.g, toast.b }
        end
    end

    -- Render the toast:
    -- - Solid for 1.0s
    -- - Fade out over the next 1.0s (total lifetime 2.0s)
    -- - While fading, slide up by 30px
    if ui.twistOutcomeText and self._retTwistToastStartTime and self._retTwistToastText then
        local now = GetTime()
        local age = now - (self._retTwistToastStartTime or now)
        if age < 0 then age = 0 end

        if age >= 2.0 then
            ui.twistOutcomeText:Hide()
            self._retTwistToastStartTime = nil
            self._retTwistToastText = nil
            self._retTwistToastColor = nil
        else
            local a = 1.0
            local slideUp = 0
            if age > 1.0 then
                local t = (age - 1.0) / 1.0 -- 0..1 over the fade window
                if t < 0 then t = 0 end
                if t > 1 then t = 1 end
                a = 1.0 - t
                slideUp = 30 * t
            end

            -- Position centered above the swing lane.
            ui.twistOutcomeText:ClearAllPoints()
            ui.twistOutcomeText:SetPoint("BOTTOM", ui.frame, "LEFT", width * 0.5, swingCenterY + (swingHeight / 2) + 2 + slideUp)

            ui.twistOutcomeText:SetText(self._retTwistToastText)
            local c = self._retTwistToastColor
            local effectiveAlpha = a * (targetAlpha or 1.0)
            if c then
                ui.twistOutcomeText:SetTextColor(c[1], c[2], c[3], effectiveAlpha)
            else
                ui.twistOutcomeText:SetTextColor(1, 1, 1, effectiveAlpha)
            end
            ui.twistOutcomeText:Show()
        end
    elseif ui.twistOutcomeText then
        ui.twistOutcomeText:Hide()
    end
end

-- ============================ UI BUILD ============================
function PaladinRetTwistBar:CreateFrameUI()
    if ui.frame then return end

    OptionsFactory = NAG:GetModule("OptionsFactory")
    local db = self.db.class
    local predictionIconSize = math.floor(db.predictionIconSize or 16)
    if predictionIconSize < 8 then predictionIconSize = 8 end
    if predictionIconSize > 48 then predictionIconSize = 48 end
    local predictionRingSize = predictionIconSize + 21

    ui.frame = CreateFrame("Frame", "NAGPaladinRetTwistBar", _G.UIParent)
    -- Initial size (UpdateDisplay will recompute precisely)
    ui.frame:SetSize(db.width, (db.height + 5) + 6 + 5)
    ui.frame:SetPoint(db.point, db.x, db.y)
    ui.frame:SetAlpha(db.alpha or 1.0)
    ui.frame:Hide()
    ui.frame:SetMovable(true)
    ui.frame:RegisterForDrag("LeftButton")
    ui.frame:EnableMouse(NAG.IsAnyEditMode and NAG:IsAnyEditMode())
    ui.frame:SetScript("OnDragStart", function()
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        if not (moduleSelf and moduleSelf.db and moduleSelf.db.class) then
            return
        end
        local canDrag = NAG.IsAnyEditMode and NAG:IsAnyEditMode()
        if not canDrag then
            return
        end
        ui.frame:StartMoving()
    end)

    -- Right-click context menu (disable/toggle off entirely).
    ui.frame.contextMenu = ui.frame.contextMenu or CreateFrame("Frame", "NAGPaladinRetTwistBarContextMenu", ui.frame,
        "UIDropDownMenuTemplate")
    local moduleSelf = self

    -- Use an invisible Button overlay as the click target:
    -- - Larger hitbox than the visible bar
    -- - Higher ui.frame level so it receives mouse clicks reliably
    ui.clickCatcher = CreateFrame("Button", nil, ui.frame)
    ui.clickCatcher:SetPoint("TOPLEFT", ui.frame, "TOPLEFT", -6, 6)
    ui.clickCatcher:SetPoint("BOTTOMRIGHT", ui.frame, "BOTTOMRIGHT", 6, -6)
    ui.clickCatcher:SetFrameLevel((ui.frame:GetFrameLevel() or 0) + 50)
    ui.clickCatcher:EnableMouse(true)
    ui.clickCatcher:RegisterForClicks("RightButtonUp")
    -- Forward drag to frame so frame receives OnDragStop (frame has the position/save logic)
    ui.clickCatcher:RegisterForDrag("LeftButton")
    ui.clickCatcher:SetScript("OnDragStart", function()
        if ui.frame and ui.frame.StartMoving then
            ui.frame:StartMoving()
        end
    end)
    ui.clickCatcher:SetScript("OnDragStop", function()
        if not ui.frame or not ui.frame.StopMovingOrSizing then return end
        ui.frame:StopMovingOrSizing()
        if not (moduleSelf and moduleSelf.db and moduleSelf.db.class) then return end
        local db = moduleSelf.db.class
        local anchor = NAG.GetDisplayAnchor and NAG:GetDisplayAnchor() or nil
        if anchor and anchor ~= _G.UIParent and db.autoAnchor then
            -- Read positions first while frame is still where the user dropped it (match Hunter bar).
            local saved = false
            local offsetX, offsetY
            if db.anchorSide == "right" then
                local barLeft, barBottom = ui.frame:GetLeft(), ui.frame:GetBottom()
                local anchorRight, anchorBottom = anchor:GetRight(), anchor:GetBottom()
                if barLeft and barBottom and anchorRight and anchorBottom then
                    offsetX = barLeft - anchorRight
                    offsetY = barBottom - anchorBottom
                    saved = true
                end
            else
                local barCenterX = select(1, ui.frame:GetCenter())
                local barTop = ui.frame:GetTop()
                local anchorCenterX = select(1, anchor:GetCenter())
                local anchorBottom = anchor:GetBottom()
                if barCenterX and barTop and anchorCenterX and anchorBottom then
                    offsetX = barCenterX - anchorCenterX
                    offsetY = barTop - anchorBottom
                    saved = true
                end
            end
            -- Save to db FIRST so any re-entrant UpdateFrameAnchor uses the new position (prevents snap-left).
            if saved then
                if db.anchorSide == "right" then
                    db.point = "BOTTOMLEFT"
                    db.x = offsetX
                    db.y = offsetY
                else
                    db.point = "TOP"
                    db.x = offsetX
                    db.y = offsetY
                end
            end
            -- Then clear and re-anchor using saved or existing offsets.
            ui.frame:SetParent(_G.UIParent)
            ui.frame:ClearAllPoints()
            if saved then
                if db.anchorSide == "right" then
                    ui.frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", offsetX, offsetY)
                else
                    ui.frame:SetPoint("TOP", anchor, "BOTTOM", offsetX, offsetY)
                end
            else
                -- Offset calc failed; keep autoAnchor and re-apply with existing db so bar stays attached.
                if db.anchorSide == "right" then
                    ui.frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", db.x or 8, db.y or 0)
                else
                    ui.frame:SetPoint("TOP", anchor, "BOTTOM", db.x, db.y)
                end
            end
        else
            local left, bottom = ui.frame:GetLeft(), ui.frame:GetBottom()
            if left and bottom then
                -- Save to db FIRST so any re-entrant UpdateFrameAnchor uses the new position (prevents snap-left).
                db.point = "BOTTOMLEFT"
                db.x = left
                db.y = bottom
                db.userPositioned = true
                db.autoAnchor = false
                -- Then re-anchor in UIParent space.
                ui.frame:SetParent(_G.UIParent)
                ui.frame:ClearAllPoints()
                ui.frame:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", left, bottom)
            else
                local point, _, _, x, y = ui.frame:GetPoint(1)
                if point then db.point = point end
                db.x = x or db.x or 0
                db.y = y or db.y or 0
                db.userPositioned = true
                db.autoAnchor = false
            end
        end
    end)

    local function showContextMenu()
        local function isAutoAttackImageEnabled()
            return moduleSelf and moduleSelf.db and moduleSelf.db.class and moduleSelf.db.class.showSwingIconSpark
        end

        local function toggleAutoAttackImage()
            if not (moduleSelf and moduleSelf.db and moduleSelf.db.class) then
                return
            end
            moduleSelf.db.class.showSwingIconSpark = not moduleSelf.db.class.showSwingIconSpark
            if moduleSelf.UpdateDisplay and ui.frame then
                moduleSelf:UpdateDisplay()
            end
        end

        local function isLocked()
            local dm = NAG:GetModule("DisplayManager")
            return not (dm and dm.classHelperEditMode)
        end

        local function toggleLocked()
            local dm = NAG:GetModule("DisplayManager")
            if not dm then return end
            local wasLocked = not dm.classHelperEditMode
            local newLocked = not wasLocked
            dm.classHelperEditMode = not newLocked
            NAG:SendMessage("NAG_FRAME_UPDATED")

            -- When unlocking: do NOT clear autoAnchor - let user drag and save offset so bar stays attached.
            -- When locking: if user manual-positioned during this session, keep autoAnchor off.
            if not newLocked and moduleSelf and moduleSelf.db and moduleSelf.db.class then
                if moduleSelf.UpdateVisibility then
                    moduleSelf:UpdateVisibility()
                end
                if CloseDropDownMenus then
                    CloseDropDownMenus()
                end
            else
                if moduleSelf and moduleSelf.db and moduleSelf.db.class and moduleSelf.db.class.userPositioned then
                    moduleSelf.db.class.autoAnchor = false
                end
                -- Defer UpdateVisibility when locking so the display/anchor has settled before we re-apply anchor+offset.
                if moduleSelf and moduleSelf.UpdateVisibility then
                    local doUpdate = function()
                        if moduleSelf and moduleSelf.UpdateVisibility then
                            moduleSelf:UpdateVisibility()
                        end
                    end
                    if C_Timer and C_Timer.After then
                        C_Timer.After(0, doUpdate)
                    else
                        doUpdate()
                    end
                end
            end
        end

        local function isAnchored()
            return moduleSelf and moduleSelf.db and moduleSelf.db.class and moduleSelf.db.class.autoAnchor ~= false
        end

        local function toggleAnchored()
            if not (moduleSelf and moduleSelf.db and moduleSelf.db.class) then
                return
            end
            local newAnchored = not (moduleSelf.db.class.autoAnchor ~= false)
            moduleSelf.db.class.autoAnchor = newAnchored
            if newAnchored then
                moduleSelf.db.class.userPositioned = false
                -- Snap back to the original anchored defaults.
                moduleSelf.db.class.point = defaults.class.point
                moduleSelf.db.class.x = defaults.class.x
                moduleSelf.db.class.y = defaults.class.y
            end
            if moduleSelf.UpdateVisibility then
                moduleSelf:UpdateVisibility()
            end
        end

        local function confirmDisable()
            if StaticPopup_Show then
                StaticPopup_Show("NAG_RET_TWIST_BAR_DISABLE_CONFIRM", nil, nil, { module = moduleSelf })
            end
        end

        local function confirmReset()
            if StaticPopup_Show then
                StaticPopup_Show("NAG_RET_TWIST_BAR_RESET_CONFIRM", nil, nil, { module = moduleSelf })
            end
        end

        local menu = {
            { text = "Ret Twist Bar", isTitle = true, notCheckable = true },
            {
                text = "Auto Attack image",
                isNotRadio = true,
                keepShownOnClick = true,
                checked = isAutoAttackImageEnabled,
                func = toggleAutoAttackImage,
            },
            {
                text = "Locked",
                isNotRadio = true,
                keepShownOnClick = true,
                checked = isLocked,
                func = toggleLocked,
            },
            {
                text = "Anchor to NAG",
                isNotRadio = true,
                keepShownOnClick = true,
                checked = isAnchored,
                func = toggleAnchored,
            },
            {
                text = "Restore Defaults",
                notCheckable = true,
                func = confirmReset,
            },
            {
                text = "Disable Bar",
                notCheckable = true,
                func = confirmDisable,
            },
            {
                text = "Cancel",
                notCheckable = true,
                func = function()
                    if CloseDropDownMenus then
                        CloseDropDownMenus()
                    end
                end
            },
        }

        if EasyMenu then
            EasyMenu(menu, ui.frame.contextMenu, "cursor", 0, 0, "MENU")
            return
        end

        -- Fallback for clients without EasyMenu: use UIDropDownMenu_Initialize + ToggleDropDownMenu.
        if UIDropDownMenu_Initialize and UIDropDownMenu_AddButton and ToggleDropDownMenu then
            UIDropDownMenu_Initialize(ui.frame.contextMenu, function(_, level)
                for i = 1, #menu do
                    UIDropDownMenu_AddButton(menu[i], level)
                end
            end, "MENU")
            ToggleDropDownMenu(1, nil, ui.frame.contextMenu, "cursor", 0, 0)
        end
    end

    ui.clickCatcher:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" then
            return
        end
        showContextMenu()
    end)

    -- Background (lowest) - sized/positioned dynamically in UpdateDisplay so it only covers the swing lane.
    ui.background = ui.frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.background:SetColorTexture(db.backgroundColor.r, db.backgroundColor.g, db.backgroundColor.b, db.backgroundColor.a)

    -- Outcome toast text (appears above the swing lane, fades out automatically).
    ui.twistOutcomeText = ui.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ui.twistOutcomeText:SetJustifyH("CENTER")
    ui.twistOutcomeText:SetJustifyV("MIDDLE")
    ui.twistOutcomeText:SetText("")
    -- Make toast text 100% bigger (2x).
    local fontPath, fontSize, fontFlags = ui.twistOutcomeText:GetFont()
    if fontPath and fontSize then
        ui.twistOutcomeText:SetFont(fontPath, fontSize * 2, fontFlags)
    end
    ui.twistOutcomeText:Hide()

    -- Swing timer "bar" is a hidden positioning surface; only the spark line is meant to be visible.
    -- Keep it low in ARTWORK; it is fully transparent anyway.
    ui.swingBar = ui.frame:CreateTexture(nil, "ARTWORK", nil, -7)
    ui.swingBar:SetPoint("LEFT", ui.frame, "LEFT", 0, 0)
    ui.swingBar:SetWidth(0)
    -- Swing bar is a hidden "positioning bar" (transparent). The visible indicator is ui.swingSpark.
    ui.swingBar:SetColorTexture(db.swingColor.r, db.swingColor.g, db.swingColor.b, db.swingColor.a)

    -- GCD overlay bar: use a HIGH sublevel just like ShamanWeaveBar so it is unmistakably on top.
    ui.gcdBar = ui.frame:CreateTexture(nil, "ARTWORK", nil, 6)
    ui.gcdBar:SetPoint("LEFT", ui.frame, "LEFT", 0, 0)
    ui.gcdBar:SetWidth(0)
    ui.gcdBar:SetColorTexture(db.gcdColor.r, db.gcdColor.g, db.gcdColor.b, db.gcdColor.a)
    ui.gcdBar:Hide()

    -- Twist window overlay bars: below GCD overlay, above ui.background.
    ui.twistWindowBar = ui.frame:CreateTexture(nil, "ARTWORK", nil, 4)
    ui.twistWindowBar:SetPoint("LEFT", ui.frame, "LEFT", 0, 0)
    ui.twistWindowBar:SetWidth(0)
    ui.twistWindowBar:SetColorTexture(db.twistWindowColor.r, db.twistWindowColor.g, db.twistWindowColor.b, db.twistWindowColor.a)
    ui.twistWindowBar:Hide()

    -- Zero spark: vertical tick at the left border of the twist window (0.4 marker boundary).
    ui.twistZeroSpark = ui.frame:CreateTexture(nil, "OVERLAY", nil, 6)
    ui.twistZeroSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    ui.twistZeroSpark:Hide()

    -- Put swing spark above the GCD overlay (so you always see the actual swing moment line).
    -- Texture sublevels are limited to [-8, 7].
    ui.swingSpark = ui.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    ui.swingSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    ui.swingSpark:Hide()

    -- Past swing spark: same style as ui.swingSpark, but rendered slightly dimmer.
    ui.pastSwingSpark = ui.frame:CreateTexture(nil, "OVERLAY", nil, 7)
    ui.pastSwingSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, (db.sparkColor.a or 0.9) * 0.55)
    ui.pastSwingSpark:Hide()

    -- Mainhand weapon icon spark (circular), positioned above the swing marker.
    ui.swingIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.swingIconSparkFrame:SetSize(16, 16)
    ui.swingIconSparkFrame:Hide()

    -- Background art for the weapon spark (sits behind the circular icon).
    -- File: NAG/media/extras/iconBar.png
    -- Use a low sublevel to guarantee this stays behind the masked weapon icon.
    swingIconSparkBackground = ui.swingIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    swingIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    swingIconSparkBackground:SetPoint("CENTER", ui.swingIconSparkFrame, "CENTER", 0, 0)
    swingIconSparkBackground:SetSize(37, 37)
    swingIconSparkBackground:SetAlpha(0.95)
    swingIconSparkBackground:Hide()

    ui.swingIconSparkIcon = ui.swingIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.swingIconSparkIcon:SetAllPoints()
    ui.swingIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.swingIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85) -- crop for a clean look

    ui.swingIconSparkMask = ui.swingIconSparkFrame:CreateMaskTexture()
    ui.swingIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.swingIconSparkMask:SetAllPoints()
    ui.swingIconSparkIcon:AddMaskTexture(ui.swingIconSparkMask)
    local swingKeybindText = ui.swingIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    swingKeybindText:SetPoint("BOTTOM", ui.swingIconSparkFrame, "TOP", 0, 2)
    swingKeybindText:SetJustifyH("CENTER")
    swingKeybindText:SetTextColor(1, 1, 0)
    swingKeybindText:SetText("")
    swingKeybindText:Hide()
    ui.swingIconSparkFrame.keybindText = swingKeybindText

    -- SoC icon spark (mirrors SoB icon styling, independent from twist gap bar).
    ui.socIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.socIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.socIconSparkFrame:Hide()

    ui.socIconSparkBackground = ui.socIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.socIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.socIconSparkBackground:SetPoint("CENTER", ui.socIconSparkFrame, "CENTER", 0, 0)
    ui.socIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.socIconSparkBackground:SetAlpha(0.95)
    ui.socIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.socIconSparkBackground:Hide()

    ui.socIconSparkIcon = ui.socIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.socIconSparkIcon:SetAllPoints()
    ui.socIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.socIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.socIconSparkMask = ui.socIconSparkFrame:CreateMaskTexture()
    ui.socIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.socIconSparkMask:SetAllPoints()
    ui.socIconSparkIcon:AddMaskTexture(ui.socIconSparkMask)
    local socKeybindText = ui.socIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    socKeybindText:SetPoint("BOTTOM", ui.socIconSparkFrame, "TOP", 0, 2)
    socKeybindText:SetJustifyH("CENTER")
    socKeybindText:SetTextColor(1, 1, 0)
    socKeybindText:SetText("")
    socKeybindText:Hide()
    ui.socIconSparkFrame.keybindText = socKeybindText

    -- Judgement icon spark (parallel lane below, ui.background flipped to point up).
    ui.judgeIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.judgeIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.judgeIconSparkFrame:Hide()

    ui.judgeIconSparkBackground = ui.judgeIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.judgeIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.judgeIconSparkBackground:SetPoint("CENTER", ui.judgeIconSparkFrame, "CENTER", 0, 0)
    ui.judgeIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.judgeIconSparkBackground:SetAlpha(0.95)
    ui.judgeIconSparkBackground:SetTexCoord(0, 1, 0, 1)
    ui.judgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.judgeIconSparkBackground:Hide()

    ui.judgeIconSparkIcon = ui.judgeIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.judgeIconSparkIcon:SetAllPoints()
    ui.judgeIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.judgeIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.judgeIconSparkMask = ui.judgeIconSparkFrame:CreateMaskTexture()
    ui.judgeIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.judgeIconSparkMask:SetAllPoints()
    ui.judgeIconSparkIcon:AddMaskTexture(ui.judgeIconSparkMask)
    local judgeKeybindText = ui.judgeIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    judgeKeybindText:SetPoint("BOTTOM", ui.judgeIconSparkFrame, "TOP", 0, 2)
    judgeKeybindText:SetJustifyH("CENTER")
    judgeKeybindText:SetTextColor(1, 1, 0)
    judgeKeybindText:SetText("")
    judgeKeybindText:Hide()
    ui.judgeIconSparkFrame.keybindText = judgeKeybindText
    ui.judgeIconSparkFrame.spellId = 20271

    -- Filler icon spark (Consecration/Exorcism) on reverted Judgement lane.
    ui.fillerIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.fillerIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.fillerIconSparkFrame:Hide()

    ui.fillerIconSparkBackground = ui.fillerIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.fillerIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.fillerIconSparkBackground:SetPoint("CENTER", ui.fillerIconSparkFrame, "CENTER", 0, 0)
    ui.fillerIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.fillerIconSparkBackground:SetAlpha(0.95)
    ui.fillerIconSparkBackground:SetTexCoord(0, 1, 1, 0) -- reverted lane marker
    ui.fillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.fillerIconSparkBackground:Hide()

    ui.fillerIconSparkIcon = ui.fillerIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.fillerIconSparkIcon:SetAllPoints()
    ui.fillerIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.fillerIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.fillerIconSparkMask = ui.fillerIconSparkFrame:CreateMaskTexture()
    ui.fillerIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.fillerIconSparkMask:SetAllPoints()
    ui.fillerIconSparkIcon:AddMaskTexture(ui.fillerIconSparkMask)
    local fillerKeybindText = ui.fillerIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fillerKeybindText:SetPoint("BOTTOM", ui.fillerIconSparkFrame, "TOP", 0, 2)
    fillerKeybindText:SetJustifyH("CENTER")
    fillerKeybindText:SetTextColor(1, 1, 0)
    fillerKeybindText:SetText("")
    fillerKeybindText:Hide()
    ui.fillerIconSparkFrame.keybindText = fillerKeybindText

    -- Crusader Strike icon spark (extra lane below Judgement).
    ui.csIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.csIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.csIconSparkFrame:Hide()

    ui.csIconSparkBackground = ui.csIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.csIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.csIconSparkBackground:SetPoint("CENTER", ui.csIconSparkFrame, "CENTER", 0, 0)
    ui.csIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.csIconSparkBackground:SetAlpha(0.95)
    ui.csIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.csIconSparkBackground:Hide()

    ui.csIconSparkIcon = ui.csIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.csIconSparkIcon:SetAllPoints()
    ui.csIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.csIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.csIconSparkMask = ui.csIconSparkFrame:CreateMaskTexture()
    ui.csIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.csIconSparkMask:SetAllPoints()
    ui.csIconSparkIcon:AddMaskTexture(ui.csIconSparkMask)
    local csKeybindText = ui.csIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    csKeybindText:SetPoint("BOTTOM", ui.csIconSparkFrame, "TOP", 0, 2)
    csKeybindText:SetJustifyH("CENTER")
    csKeybindText:SetTextColor(1, 1, 0)
    csKeybindText:SetText("")
    csKeybindText:Hide()
    ui.csIconSparkFrame.keybindText = csKeybindText
    ui.csIconSparkFrame.spellId = 35395

    -- Next-next SoC icon spark lane (additive preview lane, never replaces current lane).
    ui.nextSocIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.nextSocIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.nextSocIconSparkFrame:Hide()

    ui.nextSocIconSparkBackground = ui.nextSocIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.nextSocIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.nextSocIconSparkBackground:SetPoint("CENTER", ui.nextSocIconSparkFrame, "CENTER", 0, 0)
    ui.nextSocIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.nextSocIconSparkBackground:SetAlpha(0.95)
    ui.nextSocIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.nextSocIconSparkBackground:Hide()

    ui.nextSocIconSparkIcon = ui.nextSocIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.nextSocIconSparkIcon:SetAllPoints()
    ui.nextSocIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.nextSocIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.nextSocIconSparkMask = ui.nextSocIconSparkFrame:CreateMaskTexture()
    ui.nextSocIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.nextSocIconSparkMask:SetAllPoints()
    ui.nextSocIconSparkIcon:AddMaskTexture(ui.nextSocIconSparkMask)
    local nextSocKeybindText = ui.nextSocIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextSocKeybindText:SetPoint("BOTTOM", ui.nextSocIconSparkFrame, "TOP", 0, 2)
    nextSocKeybindText:SetJustifyH("CENTER")
    nextSocKeybindText:SetTextColor(1, 1, 0)
    nextSocKeybindText:SetText("")
    nextSocKeybindText:Hide()
    ui.nextSocIconSparkFrame.keybindText = nextSocKeybindText

    -- Next-next Judgement icon spark lane.
    ui.nextJudgeIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.nextJudgeIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.nextJudgeIconSparkFrame:Hide()

    ui.nextJudgeIconSparkBackground = ui.nextJudgeIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.nextJudgeIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.nextJudgeIconSparkBackground:SetPoint("CENTER", ui.nextJudgeIconSparkFrame, "CENTER", 0, 0)
    ui.nextJudgeIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.nextJudgeIconSparkBackground:SetAlpha(0.95)
    ui.nextJudgeIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.nextJudgeIconSparkBackground:Hide()

    ui.nextJudgeIconSparkIcon = ui.nextJudgeIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.nextJudgeIconSparkIcon:SetAllPoints()
    ui.nextJudgeIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.nextJudgeIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.nextJudgeIconSparkMask = ui.nextJudgeIconSparkFrame:CreateMaskTexture()
    ui.nextJudgeIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.nextJudgeIconSparkMask:SetAllPoints()
    ui.nextJudgeIconSparkIcon:AddMaskTexture(ui.nextJudgeIconSparkMask)
    local nextJudgeKeybindText = ui.nextJudgeIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextJudgeKeybindText:SetPoint("BOTTOM", ui.nextJudgeIconSparkFrame, "TOP", 0, 2)
    nextJudgeKeybindText:SetJustifyH("CENTER")
    nextJudgeKeybindText:SetTextColor(1, 1, 0)
    nextJudgeKeybindText:SetText("")
    nextJudgeKeybindText:Hide()
    ui.nextJudgeIconSparkFrame.keybindText = nextJudgeKeybindText
    ui.nextJudgeIconSparkFrame.spellId = 20271

    -- Next-next CS icon spark lane.
    ui.nextCSIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.nextCSIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.nextCSIconSparkFrame:Hide()

    ui.nextCSIconSparkBackground = ui.nextCSIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.nextCSIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.nextCSIconSparkBackground:SetPoint("CENTER", ui.nextCSIconSparkFrame, "CENTER", 0, 0)
    ui.nextCSIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.nextCSIconSparkBackground:SetAlpha(0.95)
    ui.nextCSIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.nextCSIconSparkBackground:Hide()

    ui.nextCSIconSparkIcon = ui.nextCSIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.nextCSIconSparkIcon:SetAllPoints()
    ui.nextCSIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.nextCSIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.nextCSIconSparkMask = ui.nextCSIconSparkFrame:CreateMaskTexture()
    ui.nextCSIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.nextCSIconSparkMask:SetAllPoints()
    ui.nextCSIconSparkIcon:AddMaskTexture(ui.nextCSIconSparkMask)
    local nextCSKeybindText = ui.nextCSIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextCSKeybindText:SetPoint("BOTTOM", ui.nextCSIconSparkFrame, "TOP", 0, 2)
    nextCSKeybindText:SetJustifyH("CENTER")
    nextCSKeybindText:SetTextColor(1, 1, 0)
    nextCSKeybindText:SetText("")
    nextCSKeybindText:Hide()
    ui.nextCSIconSparkFrame.keybindText = nextCSKeybindText
    ui.nextCSIconSparkFrame.spellId = 35395

    -- Next-next filler icon spark lane.
    ui.nextFillerIconSparkFrame = CreateFrame("Frame", nil, ui.frame)
    ui.nextFillerIconSparkFrame:SetSize(predictionIconSize, predictionIconSize)
    ui.nextFillerIconSparkFrame:Hide()

    ui.nextFillerIconSparkBackground = ui.nextFillerIconSparkFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    ui.nextFillerIconSparkBackground:SetTexture("Interface\\AddOns\\NAG\\media\\extras\\iconBar3Inverted.png")
    ui.nextFillerIconSparkBackground:SetPoint("CENTER", ui.nextFillerIconSparkFrame, "CENTER", 0, 0)
    ui.nextFillerIconSparkBackground:SetSize(predictionRingSize, predictionRingSize)
    ui.nextFillerIconSparkBackground:SetAlpha(0.95)
    ui.nextFillerIconSparkBackground:SetVertexColor(0.0, 0.0, 0.0, 1.0)
    ui.nextFillerIconSparkBackground:Hide()

    ui.nextFillerIconSparkIcon = ui.nextFillerIconSparkFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    ui.nextFillerIconSparkIcon:SetAllPoints()
    ui.nextFillerIconSparkIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    ui.nextFillerIconSparkIcon:SetTexCoord(0.15, 0.85, 0.15, 0.85)

    ui.nextFillerIconSparkMask = ui.nextFillerIconSparkFrame:CreateMaskTexture()
    ui.nextFillerIconSparkMask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE",
        "CLAMPTOBLACKADDITIVE")
    ui.nextFillerIconSparkMask:SetAllPoints()
    ui.nextFillerIconSparkIcon:AddMaskTexture(ui.nextFillerIconSparkMask)
    local nextFillerKeybindText = ui.nextFillerIconSparkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nextFillerKeybindText:SetPoint("BOTTOM", ui.nextFillerIconSparkFrame, "TOP", 0, 2)
    nextFillerKeybindText:SetJustifyH("CENTER")
    nextFillerKeybindText:SetTextColor(1, 1, 0)
    nextFillerKeybindText:SetText("")
    nextFillerKeybindText:Hide()
    ui.nextFillerIconSparkFrame.keybindText = nextFillerKeybindText

    -- GCD spark: above the GCD bar, below the swing spark.
    ui.gcdSpark = ui.frame:CreateTexture(nil, "OVERLAY", nil, 6)
    ui.gcdSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    ui.gcdSpark:Hide()

    -- GCD left spark: same style as gcdSpark.
    ui.gcdSparkLeft = ui.frame:CreateTexture(nil, "OVERLAY", nil, 6)
    ui.gcdSparkLeft:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    ui.gcdSparkLeft:Hide()

    -- Div boundary marker: a moving tick line for "swing - 0.4 - gcdDurationValue".
    ui.divBoundaryMarker = ui.frame:CreateTexture(nil, "OVERLAY", nil, 5)
    ui.divBoundaryMarker:SetColorTexture(db.divMarkerColor.r, db.divMarkerColor.g, db.divMarkerColor.b, db.divMarkerColor.a)
    ui.divBoundaryMarker:Hide()

    self:ApplyPredictionIconSizing()
    self:ApplyJudgeSocBackgroundTransforms()
end

-- ============================ BAR COLORS (OPTIONS APPLY) ============================
--- Applies current db.class color settings to all bar textures. Safe to call when ui.frame not yet created.
function PaladinRetTwistBar:ApplyBarColors()
    if not ui.frame then
        return
    end
    local db = self.db.class
    if not db then
        return
    end

    if ui.background and db.backgroundColor then
        ui.background:SetColorTexture(db.backgroundColor.r, db.backgroundColor.g, db.backgroundColor.b, db.backgroundColor.a)
    end
    if ui.swingBar and db.swingColor then
        ui.swingBar:SetColorTexture(db.swingColor.r, db.swingColor.g, db.swingColor.b, db.swingColor.a)
    end
    if ui.gcdBar and db.gcdColor then
        ui.gcdBar:SetColorTexture(db.gcdColor.r, db.gcdColor.g, db.gcdColor.b, db.gcdColor.a)
    end
    if ui.twistWindowBar and db.twistWindowColor then
        ui.twistWindowBar:SetColorTexture(db.twistWindowColor.r, db.twistWindowColor.g, db.twistWindowColor.b, db.twistWindowColor.a)
    end
    if ui.twistZeroSpark and db.sparkColor then
        ui.twistZeroSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    end
    if ui.swingSpark and db.sparkColor then
        ui.swingSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    end
    if ui.pastSwingSpark and db.sparkColor then
        ui.pastSwingSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, (db.sparkColor.a or 0.9) * 0.55)
    end
    if ui.gcdSpark and db.sparkColor then
        ui.gcdSpark:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    end
    if ui.gcdSparkLeft and db.sparkColor then
        ui.gcdSparkLeft:SetColorTexture(db.sparkColor.r, db.sparkColor.g, db.sparkColor.b, db.sparkColor.a)
    end
    if ui.divBoundaryMarker and db.divMarkerColor then
        ui.divBoundaryMarker:SetColorTexture(db.divMarkerColor.r, db.divMarkerColor.g, db.divMarkerColor.b, db.divMarkerColor.a)
    end

    self:ApplyJudgeSocBackgroundTransforms()
end

-- ============================ LIFECYCLE ============================
function PaladinRetTwistBar:ModuleInitialize()
    -- One-time position tweak: move the bar 5px down for existing users.
    -- (WoW UI Y grows upward, so "down" means subtracting.)
    if self.db and self.db.class and not self.db.class._migratedDown5 then
        self.db.class.y = (self.db.class.y or defaults.class.y or 0) - 5
        self.db.class._migratedDown5 = true
    end

    if self.db and self.db.class then
        local db = self.db.class
        if db.judgeBackgroundInverted == nil then db.judgeBackgroundInverted = defaults.class.judgeBackgroundInverted end
        if db.judgeSocLayoutMode == nil then db.judgeSocLayoutMode = defaults.class.judgeSocLayoutMode end
        if not db._migratedJudgeSocLayoutDefaultV2 then
            if db.judgeSocLayoutMode == nil or db.judgeSocLayoutMode == "split" then
                db.judgeSocLayoutMode = "sideBySide"
            end
            db._migratedJudgeSocLayoutDefaultV2 = true
        end
        if db.socSideBySideOffsetX == nil then db.socSideBySideOffsetX = defaults.class.socSideBySideOffsetX end
        if db.judgeSideBySideOffsetX == nil then db.judgeSideBySideOffsetX = defaults.class.judgeSideBySideOffsetX end
        if db.judgeSocSideBySideOffsetY == nil then db.judgeSocSideBySideOffsetY = defaults.class.judgeSocSideBySideOffsetY end
        if db.socBackgroundRotationSideBySideDeg == nil then
            db.socBackgroundRotationSideBySideDeg = defaults.class.socBackgroundRotationSideBySideDeg
        end
        if db.judgeBackgroundRotationSideBySideDeg == nil then
            db.judgeBackgroundRotationSideBySideDeg = defaults.class.judgeBackgroundRotationSideBySideDeg
        end
        if db.socBackgroundOffsetX == nil then db.socBackgroundOffsetX = defaults.class.socBackgroundOffsetX end
        if db.socBackgroundOffsetY == nil then db.socBackgroundOffsetY = defaults.class.socBackgroundOffsetY end
        if db.judgeBackgroundOffsetX == nil then db.judgeBackgroundOffsetX = defaults.class.judgeBackgroundOffsetX end
        if db.judgeBackgroundOffsetY == nil then db.judgeBackgroundOffsetY = defaults.class.judgeBackgroundOffsetY end
        if db.showFillerIconSpark == nil then db.showFillerIconSpark = defaults.class.showFillerIconSpark end
        if db.fillerSourcePosition == nil then db.fillerSourcePosition = defaults.class.fillerSourcePosition end
        if db.fillerOffsetX == nil then db.fillerOffsetX = defaults.class.fillerOffsetX end
        if db.fillerOffsetY == nil then db.fillerOffsetY = defaults.class.fillerOffsetY end
        if db.showTwistWindow == nil then db.showTwistWindow = defaults.class.showTwistWindow end
        if db.twistWindowSeconds == nil then db.twistWindowSeconds = defaults.class.twistWindowSeconds end
        if db.showDivBoundaryMarker == nil then db.showDivBoundaryMarker = defaults.class.showDivBoundaryMarker end
        if not db._migratedDivBoundaryDefaultOffV1 then
            db.showDivBoundaryMarker = false
            db._migratedDivBoundaryDefaultOffV1 = true
        end
        if db.showGCDBar == nil then db.showGCDBar = defaults.class.showGCDBar end
        if db.showGCDSparks == nil then db.showGCDSparks = defaults.class.showGCDSparks end
        if db.gcdLaneHeight == nil then db.gcdLaneHeight = defaults.class.gcdLaneHeight end
        if db.gcdLaneGap == nil then db.gcdLaneGap = defaults.class.gcdLaneGap end
        if db.gcdSparkHeight == nil then db.gcdSparkHeight = defaults.class.gcdSparkHeight end
        if db.predictionIconSize == nil then db.predictionIconSize = defaults.class.predictionIconSize end
        if db.predictionTopLaneOffsetY == nil then db.predictionTopLaneOffsetY = defaults.class.predictionTopLaneOffsetY end
        if db.predictionBottomLaneOffsetY == nil then
            db.predictionBottomLaneOffsetY = defaults.class.predictionBottomLaneOffsetY
        end
        if db.predictionCSSplitExtraOffsetY == nil then
            db.predictionCSSplitExtraOffsetY = defaults.class.predictionCSSplitExtraOffsetY
        end
        if db.showSocIcon == nil then db.showSocIcon = defaults.class.showSocIcon end
        if db.showJudgeIcon == nil then db.showJudgeIcon = defaults.class.showJudgeIcon end
        if db.showCSIcon == nil then db.showCSIcon = defaults.class.showCSIcon end
        if db.csLaneMode == nil then db.csLaneMode = defaults.class.csLaneMode end
        if db.fillerLaneMode == nil then db.fillerLaneMode = defaults.class.fillerLaneMode end
        if db.barFillDirection == nil then db.barFillDirection = defaults.class.barFillDirection end
    end

    -- No heavy work; UI built lazily.
    -- Register swing timer callbacks to force instant refresh at swing boundaries.
    if swingTimerLib and swingTimerLib.RegisterCallback then
        swingTimerLib.RegisterCallback(self, "UNIT_SWING_TIMER_START", function(_, unitId, speed, expirationTime, hand)
            if unitId == "player" and hand == "mainhand" and self.UpdateDisplay then
                self:UpdateDisplay()
            end
        end)
        swingTimerLib.RegisterCallback(self, "UNIT_SWING_TIMER_STOP", function(_, unitId, hand)
            if unitId == "player" and hand == "mainhand" and self.UpdateDisplay then
                self:UpdateDisplay()
            end
        end)
        swingTimerLib.RegisterCallback(self, "UNIT_SWING_TIMER_UPDATE", function(_, unitId, speed, expirationTime, hand)
            if unitId == "player" and hand == "mainhand" and self.UpdateDisplay then
                self:UpdateDisplay()
            end
        end)
    end
end

function PaladinRetTwistBar:ModuleEnable()
    if UnitClassBase("player") ~= "PALADIN" then
        self:SetEnabledState(false)
        return
    end

    -- Delay ui.frame creation by 7 seconds to allow addon/spell data to fully load
    local TimerManager = ns.TimerManager
    if TimerManager then
        TimerManager:Cancel(TimerManager.Categories.UI_NOTIFICATION, "retTwistBarDelayedInit")
        TimerManager:Create(
            TimerManager.Categories.UI_NOTIFICATION,
            "retTwistBarDelayedInit",
            function()
                self:CreateFrameUI()
                self:UpdateVisibility()
            end,
            7.0,  -- 7 second delay
            false -- Don't repeat
        )
    else
        -- Fallback: create immediately if TimerManager not available
        self:CreateFrameUI()
        self:UpdateVisibility()
    end
end

function PaladinRetTwistBar:ModuleDisable()
    if ui.frame then
        ui.frame:SetScript("OnUpdate", nil)
        ui.frame:Hide()
    end
    timelineSmoothState = {}
end

-- ============================ EVENTS ============================
function PaladinRetTwistBar:PLAYER_REGEN_DISABLED()
    self:UpdateVisibility()
end

function PaladinRetTwistBar:PLAYER_REGEN_ENABLED()
    self:UpdateVisibility()
    -- Clear next-next icon cache so we re-populate spell-known/icon when out of combat.
    nextNextIconCache = {}
    -- Pre-populate cache for common Ret spells so next combat has textures ready.
    PrePopulateNextNextIconCache()
    -- Clear twist success toast state so we do not carry over or re-show from previous combat.
    self._retTwistToastLastSuccessTime = nil
    self._retTwistToastStartTime = nil
    self._retTwistToastText = nil
    self._retTwistToastColor = nil
    if ui.twistOutcomeText then
        ui.twistOutcomeText:Hide()
    end
    if self._pendingReloadUI and ReloadUI and (not (InCombatLockdown and InCombatLockdown())) then
        self._pendingReloadUI = false
        ReloadUI()
    end
end

function PaladinRetTwistBar:PLAYER_ENTERING_WORLD()
    self:UpdateVisibility()
end

function PaladinRetTwistBar:PLAYER_TARGET_CHANGED()
    -- Target affects swing state (auto-attack start/stop). Refresh quickly.
    self.forceInstantUpdate = true
    self:UpdateDisplay()
    self.forceInstantUpdate = false
end

function PaladinRetTwistBar:NAG_FRAME_UPDATED()
    if self.db.class.autoAnchor then
        self:UpdateFrameAnchor()
    end
    if ui.frame then
        self:UpdateVisibility()
    end
end

function PaladinRetTwistBar:NAG_PALADIN_BAR_SCALE_UPDATED()
    self:UpdateFrameAnchor()
end

-- Declarative event registration
PaladinRetTwistBar.eventHandlers = {
    PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_DISABLED = true,
    PLAYER_REGEN_ENABLED = true,
    PLAYER_TARGET_CHANGED = true,
}

-- ============================ OPTIONS ============================
function PaladinRetTwistBar:GetOptions()
    if not OptionsFactory then
        OptionsFactory = NAG:GetModule("OptionsFactory")
    end

    -- Ensure color tables exist (e.g. for older saved profiles).
    local colorKeys = { "backgroundColor", "swingColor", "gcdColor", "sparkColor", "twistWindowColor", "divMarkerColor" }
    for _, key in ipairs(colorKeys) do
        if not self.db.class[key] and defaults.class[key] then
            local d = defaults.class[key]
            self.db.class[key] = { r = d.r, g = d.g, b = d.b, a = d.a or 1 }
        end
    end

    local function colorGetter(color)
        return function()
            if not color then return 0.3, 0.75, 0.3, 0 end
            return color.r, color.g, color.b, color.a
        end
    end

    local function colorSetter(color)
        return function(_, r, g, b, a)
            if not color then return end
            color.r, color.g, color.b, color.a = r, g, b, a
            self:ApplyBarColors()
        end
    end

    return {
        type = "group",
        name = "Ret Twist Bar",
        order = 26,
        childGroups = "tab",
        width = "full",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    enabled = OptionsFactory:CreateToggle(
                        "Enabled",
                        "Enable or disable the Ret Twist Bar module.",
                        function() return self:GetSetting("class", "enabled") end,
                        function(_, value)
                            self:SetSetting("class", "enabled", value)
                            if value then self:Enable() else self:Disable() end
                        end,
                        { order = 1 }
                    ),
                    showBar = OptionsFactory:CreateToggle(
                        "Show Bar",
                        "Show or hide the ui.frame.",
                        function() return self:GetSetting("class", "showBar") end,
                        function(_, value)
                            self:SetSetting("class", "showBar", value)
                            self:UpdateVisibility()
                        end,
                        { order = 2 }
                    ),
                    hideOutOfCombat = OptionsFactory:CreateToggle(
                        "Hide Out of Combat",
                        "Hide the bar while out of combat.",
                        function() return self:GetSetting("class", "hideOutOfCombat") end,
                        function(_, value)
                            self:SetSetting("class", "hideOutOfCombat", value)
                            self:UpdateVisibility()
                        end,
                        { order = 3 }
                    ),
                    showKeybindOnBar = OptionsFactory:CreateToggle(
                        "Show Keybind Above Bar Icons",
                        "Display the keybind above the icons on the bar.",
                        function() return self:GetSetting("class", "showKeybindOnBar") end,
                        function(_, value)
                            self:SetSetting("class", "showKeybindOnBar", value)
                            self:UpdateDisplay()
                        end,
                        { order = 4 }
                    ),
                    anchorHeader = OptionsFactory:CreateHeader("Anchor", { order = 10 }),
                    autoAnchor = OptionsFactory:CreateToggle(
                        "Auto Anchor to NAG",
                        "Anchor relative to NAG's primary display frame when available.",
                        function() return self:GetSetting("class", "autoAnchor") end,
                        function(_, value)
                            self:SetSetting("class", "autoAnchor", value)
                            self:UpdateVisibility()
                        end,
                        { order = 11 }
                    ),
                    anchorSide = OptionsFactory:CreateSelect(
                        "Anchor Side",
                        "When auto-anchored: place below NAG or to the right.",
                        function() return self:GetSetting("class", "anchorSide") or "bottom" end,
                        function(_, value)
                            self:SetSetting("class", "anchorSide", value)
                            self:UpdateVisibility()
                        end,
                        { order = 12, values = { bottom = "Below NAG frame", right = "Right of NAG frame" } }
                    ),
                    sizeHeader = OptionsFactory:CreateHeader("Frame Size and Position", { order = 20 }),
                    width = OptionsFactory:CreateRange(
                        "Width",
                        "Bar width.",
                        function() return self:GetSetting("class", "width") end,
                        function(_, value)
                            self:SetSetting("class", "width", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 80, max = 600, step = 1, order = 21 }
                    ),
                    height = OptionsFactory:CreateRange(
                        "Height",
                        "Bar height.",
                        function() return self:GetSetting("class", "height") end,
                        function(_, value)
                            self:SetSetting("class", "height", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 1, max = 60, step = 1, order = 22 }
                    ),
                    alpha = OptionsFactory:CreateRange(
                        "Alpha",
                        "Frame alpha.",
                        function() return self:GetSetting("class", "alpha") end,
                        function(_, value)
                            self:SetSetting("class", "alpha", value)
                            if ui.frame then ui.frame:SetAlpha(value) end
                        end,
                        { min = 0.1, max = 1.0, step = 0.05, order = 23 }
                    ),
                    x = OptionsFactory:CreateRange(
                        "X Offset",
                        "Horizontal offset.",
                        function() return self:GetSetting("class", "x") end,
                        function(_, value)
                            self:SetSetting("class", "x", value)
                            self:UpdateVisibility()
                        end,
                        { min = -2000, max = 2000, step = 1, order = 24 }
                    ),
                    y = OptionsFactory:CreateRange(
                        "Y Offset",
                        "Vertical offset.",
                        function() return self:GetSetting("class", "y") end,
                        function(_, value)
                            self:SetSetting("class", "y", value)
                            self:UpdateVisibility()
                        end,
                        { min = -2000, max = 2000, step = 1, order = 25 }
                    ),
                    barFillDirection = OptionsFactory:CreateSelect(
                        "Bar Fill Direction",
                        "Direction the swing bar fills: right-to-left countdown (default) or left-to-right like a classic swing timer.",
                        function() return self:GetSetting("class", "barFillDirection") or "rightToLeft" end,
                        function(_, value)
                            self:SetSetting("class", "barFillDirection", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 26, values = { rightToLeft = "Right to left (countdown)", leftToRight = "Left to right (fill)" } }
                    ),
                }
            },
            predictionIcons = {
                type = "group",
                name = "Prediction Icons",
                order = 2,
                args = {
                    iconVisibilityHeader = OptionsFactory:CreateHeader("Visibility", { order = 1 }),
                    showSwingIconSpark = OptionsFactory:CreateToggle(
                        "Show Weapon Spark",
                        "Show your mainhand weapon icon on the swing marker.",
                        function() return self:GetSetting("class", "showSwingIconSpark") end,
                        function(_, value)
                            self:SetSetting("class", "showSwingIconSpark", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 2 }
                    ),
                    showSocIcon = OptionsFactory:CreateToggle(
                        "Show SoC Icon",
                        "Show Seal of Command action icon lane.",
                        function() return self:GetSetting("class", "showSocIcon", true) end,
                        function(_, value)
                            self:SetSetting("class", "showSocIcon", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 3, disabled = function() return not self:GetSetting("class", "showSwingIconSpark", true) end }
                    ),
                    showJudgeIcon = OptionsFactory:CreateToggle(
                        "Show Judgement Icon",
                        "Show Judgement action icon lane when recommended.",
                        function() return self:GetSetting("class", "showJudgeIcon", true) end,
                        function(_, value)
                            self:SetSetting("class", "showJudgeIcon", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 4, disabled = function() return not self:GetSetting("class", "showSwingIconSpark", true) end }
                    ),
                    showCSIcon = OptionsFactory:CreateToggle(
                        "Show Crusader Strike Icon",
                        "Show Crusader Strike action icon lane when recommended.",
                        function() return self:GetSetting("class", "showCSIcon", true) end,
                        function(_, value)
                            self:SetSetting("class", "showCSIcon", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 5, disabled = function() return not self:GetSetting("class", "showSwingIconSpark", true) end }
                    ),
                    showFillerIconSpark = OptionsFactory:CreateToggle(
                        "Show Filler Icon",
                        "Show Consecration/Exorcism filler icon lane.",
                        function() return self:GetSetting("class", "showFillerIconSpark", true) end,
                        function(_, value)
                            self:SetSetting("class", "showFillerIconSpark", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 6, disabled = function() return not self:GetSetting("class", "showSwingIconSpark", true) end }
                    ),
                    showNextNextIconSpark = OptionsFactory:CreateToggle(
                        "Show Next-Next Icons",
                        "Show additive next-next prediction lanes (state1) without replacing current lanes.",
                        function() return self:GetSetting("class", "showNextNextIconSpark", true) end,
                        function(_, value)
                            self:SetSetting("class", "showNextNextIconSpark", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 7, disabled = function() return not self:GetSetting("class", "showSwingIconSpark", true) end }
                    ),
                    iconGeometryHeader = OptionsFactory:CreateHeader("Shared Icon Geometry", { order = 10 }),
                    predictionIconSize = OptionsFactory:CreateRange(
                        "Prediction Icon Size",
                        "Shared size for SoC/Judgement/CS/Filler icon masks.",
                        function() return self:GetSetting("class", "predictionIconSize", 16) end,
                        function(_, value)
                            self:SetSetting("class", "predictionIconSize", value)
                            self:ApplyPredictionIconSizing()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 8, max = 48, step = 1, order = 11 }
                    ),
                    predictionTopLaneOffsetY = OptionsFactory:CreateRange(
                        "Top Lane Offset Y",
                        "Vertical offset for top prediction lane icons.",
                        function() return self:GetSetting("class", "predictionTopLaneOffsetY", 12) end,
                        function(_, value)
                            self:SetSetting("class", "predictionTopLaneOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 80, step = 1, order = 12 }
                    ),
                    predictionBottomLaneOffsetY = OptionsFactory:CreateRange(
                        "Bottom Lane Offset Y",
                        "Vertical offset for bottom prediction lane icons.",
                        function() return self:GetSetting("class", "predictionBottomLaneOffsetY", -12) end,
                        function(_, value)
                            self:SetSetting("class", "predictionBottomLaneOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -80, max = 60, step = 1, order = 13 }
                    ),
                    predictionCSSplitExtraOffsetY = OptionsFactory:CreateRange(
                        "CS Split Extra Offset Y",
                        "Additional vertical shift for CS while using bottom split lane.",
                        function() return self:GetSetting("class", "predictionCSSplitExtraOffsetY", -14) end,
                        function(_, value)
                            self:SetSetting("class", "predictionCSSplitExtraOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -80, max = 40, step = 1, order = 14 }
                    ),
                    nextNextLaneOffsetY = OptionsFactory:CreateRange(
                        "Next-Next Lane Offset Y",
                        "Additional vertical separation applied to all next-next lanes so they never block current lanes.",
                        function() return self:GetSetting("class", "nextNextLaneOffsetY", 22) end,
                        function(_, value)
                            self:SetSetting("class", "nextNextLaneOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 0, max = 100, step = 1, order = 14.5 }
                    ),
                    csLaneMode = OptionsFactory:CreateSelect(
                        "Crusader Strike Lane",
                        "Choose whether CS uses top, bottom, or automatic lane behavior.",
                        function() return self:GetSetting("class", "csLaneMode", "auto") end,
                        function(_, value)
                            self:SetSetting("class", "csLaneMode", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 15, values = { auto = "Auto", top = "Top lane", bottom = "Bottom lane" } }
                    ),
                    layoutHeader = OptionsFactory:CreateHeader("SoC and Judgement Layout", { order = 30 }),
                    judgeSocLayoutMode = OptionsFactory:CreateSelect(
                        "SoC/Judgement Layout",
                        "Choose how SoC and Judgement icons are arranged.",
                        function() return self:GetSetting("class", "judgeSocLayoutMode") or "sideBySide" end,
                        function(_, value)
                            self:SetSetting("class", "judgeSocLayoutMode", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 31, values = { split = "Split (SoC top, Judge bottom)", sideBySide = "Side by side (both top)" } }
                    ),
                    judgeBackgroundInverted = OptionsFactory:CreateToggle(
                        "Invert Judgement Background",
                        "Flip Judgement icon ui.background vertically.",
                        function() return self:GetSetting("class", "judgeBackgroundInverted", false) end,
                        function(_, value)
                            self:SetSetting("class", "judgeBackgroundInverted", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 32 }
                    ),
                    sideBySideHeader = OptionsFactory:CreateHeader("Side-by-Side Tuning", { order = 33 }),
                    socSideBySideOffsetX = OptionsFactory:CreateRange(
                        "SoC X Offset",
                        "Horizontal offset for SoC icon when side-by-side is active.",
                        function() return self:GetSetting("class", "socSideBySideOffsetX", 4) end,
                        function(_, value)
                            self:SetSetting("class", "socSideBySideOffsetX", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 60, step = 1, order = 34, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    judgeSideBySideOffsetX = OptionsFactory:CreateRange(
                        "Judgement X Offset",
                        "Horizontal offset for Judgement icon when side-by-side is active.",
                        function() return self:GetSetting("class", "judgeSideBySideOffsetX", -4) end,
                        function(_, value)
                            self:SetSetting("class", "judgeSideBySideOffsetX", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 60, step = 1, order = 35, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    judgeSocSideBySideOffsetY = OptionsFactory:CreateRange(
                        "Shared Y Offset",
                        "Vertical offset applied to SoC/Judgement top group when side-by-side is active.",
                        function() return self:GetSetting("class", "judgeSocSideBySideOffsetY", 0) end,
                        function(_, value)
                            self:SetSetting("class", "judgeSocSideBySideOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 60, step = 1, order = 36, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    backgroundHeader = OptionsFactory:CreateHeader("Background Transform", { order = 40 }),
                    socBackgroundRotationSideBySideDeg = OptionsFactory:CreateRange(
                        "SoC Background Rotation",
                        "Background rotation in degrees for SoC while side-by-side is active.",
                        function() return self:GetSetting("class", "socBackgroundRotationSideBySideDeg", -15) end,
                        function(_, value)
                            self:SetSetting("class", "socBackgroundRotationSideBySideDeg", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -180, max = 180, step = 1, order = 41, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    judgeBackgroundRotationSideBySideDeg = OptionsFactory:CreateRange(
                        "Judgement Background Rotation",
                        "Background rotation in degrees for Judgement while side-by-side is active.",
                        function() return self:GetSetting("class", "judgeBackgroundRotationSideBySideDeg", 15) end,
                        function(_, value)
                            self:SetSetting("class", "judgeBackgroundRotationSideBySideDeg", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -180, max = 180, step = 1, order = 42, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    socBackgroundOffsetX = OptionsFactory:CreateRange(
                        "SoC Background X",
                        "Horizontal offset for SoC ui.background art.",
                        function() return self:GetSetting("class", "socBackgroundOffsetX", 0) end,
                        function(_, value)
                            self:SetSetting("class", "socBackgroundOffsetX", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -30, max = 30, step = 1, order = 43, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    socBackgroundOffsetY = OptionsFactory:CreateRange(
                        "SoC Background Y",
                        "Vertical offset for SoC ui.background art.",
                        function() return self:GetSetting("class", "socBackgroundOffsetY", 0) end,
                        function(_, value)
                            self:SetSetting("class", "socBackgroundOffsetY", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -30, max = 30, step = 1, order = 44, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    judgeBackgroundOffsetX = OptionsFactory:CreateRange(
                        "Judgement Background X",
                        "Horizontal offset for Judgement ui.background art.",
                        function() return self:GetSetting("class", "judgeBackgroundOffsetX", 0) end,
                        function(_, value)
                            self:SetSetting("class", "judgeBackgroundOffsetX", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -30, max = 30, step = 1, order = 45, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                    judgeBackgroundOffsetY = OptionsFactory:CreateRange(
                        "Judgement Background Y",
                        "Vertical offset for Judgement ui.background art.",
                        function() return self:GetSetting("class", "judgeBackgroundOffsetY", 0) end,
                        function(_, value)
                            self:SetSetting("class", "judgeBackgroundOffsetY", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -30, max = 30, step = 1, order = 46, hidden = function() return self:GetJudgeSocLayoutMode() ~= "sideBySide" end }
                    ),
                }
            },
            gcdBar = {
                type = "group",
                name = "GCD Bar",
                order = 3,
                args = {
                    showGCDBar = OptionsFactory:CreateToggle(
                        "Show GCD Bar",
                        "Show or hide the GCD lane under the swing timeline.",
                        function() return self:GetSetting("class", "showGCDBar", true) end,
                        function(_, value)
                            self:SetSetting("class", "showGCDBar", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 1 }
                    ),
                    showGCDSparks = OptionsFactory:CreateToggle(
                        "Show GCD Lane Sparks",
                        "Show start and end spark markers on the GCD lane.",
                        function() return self:GetSetting("class", "showGCDSparks", true) end,
                        function(_, value)
                            self:SetSetting("class", "showGCDSparks", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 2, disabled = function() return not self:GetSetting("class", "showGCDBar", true) end }
                    ),
                    gcdLaneHeight = OptionsFactory:CreateRange(
                        "GCD Lane Height",
                        "Height of the GCD lane bar.",
                        function() return self:GetSetting("class", "gcdLaneHeight", 2) end,
                        function(_, value)
                            self:SetSetting("class", "gcdLaneHeight", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 1, max = 10, step = 1, order = 3, disabled = function() return not self:GetSetting("class", "showGCDBar", true) end }
                    ),
                    gcdLaneGap = OptionsFactory:CreateRange(
                        "GCD Lane Gap",
                        "Vertical gap between swing lane and GCD lane.",
                        function() return self:GetSetting("class", "gcdLaneGap", 6) end,
                        function(_, value)
                            self:SetSetting("class", "gcdLaneGap", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 0, max = 20, step = 1, order = 4, disabled = function() return not self:GetSetting("class", "showGCDBar", true) end }
                    ),
                    gcdSparkHeight = OptionsFactory:CreateRange(
                        "GCD Spark Height",
                        "Height of the GCD lane spark markers.",
                        function() return self:GetSetting("class", "gcdSparkHeight", 5) end,
                        function(_, value)
                            self:SetSetting("class", "gcdSparkHeight", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 2, max = 16, step = 1, order = 5, disabled = function() return not self:GetSetting("class", "showGCDBar", true) end }
                    ),
                }
            },
            twistBar = {
                type = "group",
                name = "Twist Bar",
                order = 4,
                args = {
                    showTwistWindow = OptionsFactory:CreateToggle(
                        "Show Twist Window",
                        "Show the moving twist window overlay near swing.",
                        function() return self:GetSetting("class", "showTwistWindow", true) end,
                        function(_, value)
                            self:SetSetting("class", "showTwistWindow", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 1 }
                    ),
                    twistWindowSeconds = OptionsFactory:CreateRange(
                        "Twist Window Seconds",
                        "Duration of the twist window before swing.",
                        function() return self:GetSetting("class", "twistWindowSeconds", 0.4) end,
                        function(_, value)
                            self:SetSetting("class", "twistWindowSeconds", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = 0.05, max = 1.0, step = 0.01, order = 2, disabled = function() return not self:GetSetting("class", "showTwistWindow", true) end }
                    ),
                    showDivBoundaryMarker = OptionsFactory:CreateToggle(
                        "Show Div Boundary Marker",
                        "Show marker for the latest safe cast point before twist window opens.",
                        function() return self:GetSetting("class", "showDivBoundaryMarker", true) end,
                        function(_, value)
                            self:SetSetting("class", "showDivBoundaryMarker", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { order = 3, disabled = function() return not self:GetSetting("class", "showTwistWindow", true) end }
                    ),
                }
            },
            colors = {
                type = "group",
                name = "Colors",
                order = 5,
                args = {
                    barsHeader = OptionsFactory:CreateHeader("Bars", { order = 1 }),
                    backgroundColor = OptionsFactory:CreateColor(
                        "Background",
                        "Color of the swing lane ui.background.",
                        colorGetter(self.db.class.backgroundColor),
                        colorSetter(self.db.class.backgroundColor),
                        { hasAlpha = true, order = 2 }
                    ),
                    swingColor = OptionsFactory:CreateColor(
                        "Swing Bar",
                        "Color of the swing timeline bar (typically transparent).",
                        colorGetter(self.db.class.swingColor),
                        colorSetter(self.db.class.swingColor),
                        { hasAlpha = true, order = 3 }
                    ),
                    gcdColor = OptionsFactory:CreateColor(
                        "GCD Bar",
                        "Color of the GCD lane bar.",
                        colorGetter(self.db.class.gcdColor),
                        colorSetter(self.db.class.gcdColor),
                        { hasAlpha = true, order = 4 }
                    ),
                    overlaysHeader = OptionsFactory:CreateHeader("Overlays", { order = 10 }),
                    twistWindowColor = OptionsFactory:CreateColor(
                        "Twist Window",
                        "Base color of the twist window overlay.",
                        colorGetter(self.db.class.twistWindowColor),
                        colorSetter(self.db.class.twistWindowColor),
                        { hasAlpha = true, order = 11 }
                    ),
                    markersHeader = OptionsFactory:CreateHeader("Markers", { order = 20 }),
                    sparkColor = OptionsFactory:CreateColor(
                        "Spark and Marker Color",
                        "Color used by swing spark and related markers.",
                        colorGetter(self.db.class.sparkColor),
                        colorSetter(self.db.class.sparkColor),
                        { hasAlpha = true, order = 21 }
                    ),
                    divMarkerColor = OptionsFactory:CreateColor(
                        "Div Boundary Marker",
                        "Color of the div boundary marker.",
                        colorGetter(self.db.class.divMarkerColor),
                        colorSetter(self.db.class.divMarkerColor),
                        { hasAlpha = true, order = 22 }
                    ),
                }
            },
            advanced = {
                type = "group",
                name = "Advanced",
                order = 6,
                args = {
                    fillerHeader = OptionsFactory:CreateHeader("Filler", { order = 1 }),
                    fillerLaneMode = OptionsFactory:CreateSelect(
                        "Filler Lane",
                        "Choose whether filler icons are placed on top or bottom lane.",
                        function() return self:GetSetting("class", "fillerLaneMode", "bottom") end,
                        function(_, value)
                            self:SetSetting("class", "fillerLaneMode", value)
                            self:ApplyJudgeSocBackgroundTransforms()
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        {
                            order = 2,
                            values = { bottom = "Bottom lane (reverted)", top = "Top lane" },
                            disabled = function() return not self:GetSetting("class", "showFillerIconSpark", true) end
                        }
                    ),
                    fillerSourcePosition = OptionsFactory:CreateSelect(
                        "Filler Source",
                        "Secondary suggestion slot used to source filler actions (Left 1 or Right 1).",
                        function() return self:GetSetting("class", "fillerSourcePosition", "left1") end,
                        function(_, value)
                            self:SetSetting("class", "fillerSourcePosition", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        {
                            order = 3,
                            values = { left1 = "Left 1", right1 = "Right 1" },
                            disabled = function() return not self:GetSetting("class", "showFillerIconSpark", true) end
                        }
                    ),
                    fillerOffsetX = OptionsFactory:CreateRange(
                        "Filler Offset X",
                        "Horizontal filler icon lane adjustment.",
                        function() return self:GetSetting("class", "fillerOffsetX", 0) end,
                        function(_, value)
                            self:SetSetting("class", "fillerOffsetX", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 60, step = 1, order = 4, disabled = function() return not self:GetSetting("class", "showFillerIconSpark", true) end }
                    ),
                    fillerOffsetY = OptionsFactory:CreateRange(
                        "Filler Offset Y",
                        "Vertical filler icon lane adjustment.",
                        function() return self:GetSetting("class", "fillerOffsetY", 0) end,
                        function(_, value)
                            self:SetSetting("class", "fillerOffsetY", value)
                            if ui.frame then self:UpdateDisplay() end
                        end,
                        { min = -60, max = 60, step = 1, order = 5, disabled = function() return not self:GetSetting("class", "showFillerIconSpark", true) end }
                    ),
                    debugThrottleSeconds = OptionsFactory:CreateRange(
                        "Debug Throttle (seconds)",
                        "Throttle interval for development debug logging.",
                        function() return self:GetSetting("class", "debugThrottleSeconds", 0.25) end,
                        function(_, value)
                            self:SetSetting("class", "debugThrottleSeconds", value)
                        end,
                        { min = 0, max = 2.0, step = 0.01, order = 10 }
                    ),
                    resetHeader = OptionsFactory:CreateHeader("Reset", { order = 20 }),
                    resetBarToDefaults = OptionsFactory:CreateExecute(
                        "Reset Bar to Defaults",
                        "Restore all Ret Twist Bar settings to defaults.",
                        function()
                            if StaticPopup_Show then
                                StaticPopup_Show("NAG_RET_TWIST_BAR_RESET_CONFIRM", nil, nil, { module = self })
                            end
                        end,
                        { order = 21 }
                    ),
                }
            },
        }
    }
end


