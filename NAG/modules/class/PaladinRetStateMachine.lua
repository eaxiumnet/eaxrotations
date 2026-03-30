--- @module "NAG.PaladinRetStateMachine"
--- State machine for TBC Retribution Paladin seal twisting rotation.
---
--- Replaces the linear APL or-chain with a deterministic, committed-plan
--- approach per swing cycle.  Uses StateMachine.CreateTimelinePredictor
--- (same pattern as TBCHunterAPI) to simulate future swing cycles and
--- pre-compute the optimal SoC / twist / CS / filler sequence.
---
--- The WA logic from 2021 is the authoritative reference for the core
--- decision matrix (before-div / after-div / in-twist / swing-ready).
---
--- Phase 1 (current): prediction-only — exposes results so we can compare
--- against the existing APL.  Does NOT override NAG.nextSpell.
---
--- License: CC BY-NC 4.0
--- Authors: Rakizi, Fonsas

-- ============================ LOCALIZE ============================
local _, ns = ...
local GetTime = _G.GetTime
local UnitAttackSpeed = _G.UnitAttackSpeed
local UnitGUID = _G.UnitGUID
local max = math.max
local min = math.min
local abs = math.abs
local sort = table.sort

--- @type NAG|AceAddon
local NAG = LibStub("AceAddon-3.0"):GetAddon("NAG")
local PaladinTwistConstants = ns.PaladinTwistConstants or {}

local swingTimerLib = ns.LibClassicSwingTimerAPI

-- ============================ CONSTANTS ============================

local TWIST_WINDOW_SECONDS = 0.4
local INPUT_DELAY_SECONDS = 0.1
local MAX_SWING_CYCLES = 8
local SWING_RING_SIZE = 8
local DEFAULT_HORIZON_SECONDS = 6
local MONITOR_INTERVAL_SECONDS = 0.1
local SPELL_SENT_BASE_DELAY_SECONDS = 0.1
local SPELL_SENT_LATENCY_CAP_SECONDS = 0.25
local ATTACK_SPEED_CHANGE_EPSILON = 0.02
local SWING_EXPIRY_CHANGE_EPSILON = 0.05
-- Div is div: no FILLER_REACTION/FILLER_SAFETY/FILLER_SOC_BUFFER. Use gcdDuration only.
local FILLER_STATIC_GCD_SECONDS = 1.5
local FILLER_MIN_REMAINING_TIME_SECONDS = 5
local FILLER_MIN_TARGETS_AOE = 2
local FILLER_CONS_MANA_MIN = 0.3

local JUDGE_COOLDOWN = 8
local CS_COOLDOWN = 6

--- Display tolerance for HOLD actions: when state machine has decided the next action, show it regardless of CD.
local RET_SM_HOLD_DISPLAY_TOLERANCE = 999

-- Actions the state machine can recommend per swing cycle.
local ACTION_NONE       = "none"
local ACTION_SOC        = "soc"         -- Apply Seal of Command
local ACTION_TWIST      = "twist"       -- Apply twist seal (SoB/SoM) in the window
local ACTION_JUDGE_SOC  = "judge_soc"   -- Judge current seal then apply SoC
local ACTION_CS         = "cs"          -- Crusader Strike
local ACTION_FILLER_EXO = "filler_exo"  -- Exorcism filler
local ACTION_FILLER_CON = "filler_con"  -- Consecration filler
local ACTION_HOLD       = "hold"        -- Hold — wait for twist window
local ACTION_BURST      = "burst_twist" -- Avenging Wrath + twist
local ACTION_MANA       = "mana"        -- Emergency Seal of Wisdom

-- Swing region tags (matching WA terminology).
local REGION_BEFORE_DIV = "before_div"
local REGION_AFTER_DIV  = "after_div"
local REGION_IN_TWIST   = "in_twist"
local REGION_SWING_READY = "swing_ready"

-- Spell IDs (TBC).
local SPELL_JUDGEMENT   = 20271
local SPELL_CS          = 35395
local SPELL_EXORCISM    = 879
local SPELL_CONS        = 26573
local SPELL_SEAL_WISDOM = 20166
local SPELL_AW          = 31884
local SPELL_TWIST_SEAL_FALLBACK = 21084 -- Seal of Righteousness fallback if twist seal is not yet resolved
local BRIDGE_MAX_QUEUE_STEPS = 3
local BRIDGE_MAX_STATES = 3
-- Keep an action visible briefly after reaching 0 to avoid blank frames
-- between compute ticks.
local ACTION_PAST_TOLERANCE_SECONDS = 0.35

--- Resolve the primary display spell ID for a state machine action.
--- Uses NAG helpers for seals (SoC / SoB/SoM) to get the exact learned rank.
--- @param action string ACTION_* constant
--- @return number spellId (0 if unknown)
local function ActionToSpellId(action)
    if action == ACTION_SOC then
        return (NAG.RetTwistGetSoCSealId and NAG:RetTwistGetSoCSealId()) or 20375
    elseif action == ACTION_TWIST then
        return (NAG.RetTwistGetTwistSealId and NAG:RetTwistGetTwistSealId()) or SPELL_TWIST_SEAL_FALLBACK
    elseif action == ACTION_CS then
        return SPELL_CS
    elseif action == ACTION_JUDGE_SOC then
        return SPELL_JUDGEMENT
    elseif action == ACTION_FILLER_EXO then
        return SPELL_EXORCISM
    elseif action == ACTION_FILLER_CON then
        return SPELL_CONS
    elseif action == ACTION_HOLD then
        return (NAG.RetTwistGetTwistSealId and NAG:RetTwistGetTwistSealId()) or SPELL_TWIST_SEAL_FALLBACK
    elseif action == ACTION_BURST then
        return SPELL_AW
    elseif action == ACTION_MANA then
        return SPELL_SEAL_WISDOM
    end
    return 0
end

--- Resolve spell ID for a filler action.
--- @param fillerAction string|nil
--- @return number
local function FillerToSpellId(fillerAction)
    if fillerAction == ACTION_FILLER_EXO then
        return SPELL_EXORCISM
    elseif fillerAction == ACTION_FILLER_CON then
        return SPELL_CONS
    end
    return 0
end

-- ============================ MODULE DEFINITION ============================

local defaults = {
    class = {
        enabled = true,
        debugEnabled = false,
        debugThrottleSeconds = 0.25,
        horizonSeconds = DEFAULT_HORIZON_SECONDS,
        reactionTimeMs = 100,
        csMaxDelayMs = 1700,
        buildFutureTimelineForAPL = true,
    }
}

--- @class PaladinRetStateMachine:CoreModule
local PaladinRetStateMachine = NAG:CreateModule("PaladinRetStateMachine", defaults, {
    moduleType = ns.MODULE_TYPES.CLASS,
    className = "PALADIN",
    optionsCategory = ns.MODULE_CATEGORIES.CLASS,

    slashCommands = {
        ["retsm"] = {
            handler = true,
            help = "Toggle Ret state machine debug. Usage: /retsm [on|off]",
        },
        ["retsmpredict"] = {
            handler = true,
            help = "Print current state machine prediction. Usage: /retsmpredict",
        },
    },

    eventHandlers = {
        PLAYER_REGEN_DISABLED = "OnCombatStateChanged",
        PLAYER_REGEN_ENABLED  = "OnCombatStateChanged",
        PLAYER_TARGET_CHANGED = "OnTargetChanged",
        UNIT_ATTACK_SPEED     = "OnAttackSpeedChanged",
        -- Recompute on spell cast success (CLEU), not spell sent — HandleSpellCast schedules delayed compute.
        -- UNIT_AURA, SPELL_UPDATE_COOLDOWN: not needed for compute; monitor CD mismatch picks up changes.
    },

    cleuHandlers = {
        SWING_DAMAGE       = "HandleSwing",
        SWING_MISSED       = "HandleSwing",
        SPELL_CAST_SUCCESS = "HandleSpellCast",
        SPELL_MISSED       = "HandleSpellCast",
    },

    defaultState = {
        inCombat = false,
        swingCount = 0,
        lastSwingTime = 0,
        lastCSCastTime = 0,
        lastJudgeCastTime = 0,
        lastSpellCastTime = 0,
        lastGCDDuration = 1.5,
        lastObservedAttackSpeed = 0,
        lastObservedHasteExpiry = 0,
        lastObservedSwingExpiration = 0,
        lastObservedTargetGuid = "",
        cooldownDirty = false,
    },
})

ns.PaladinRetStateMachine = PaladinRetStateMachine
local SM = PaladinRetStateMachine

-- ============================ TRACKED COOLDOWNS ============================
-- CLEU-driven CD tracking: store the exact GetTime() when a spell was cast,
-- so we know precisely when the CD expires. More reliable than SpellTimeToReady
-- which can lag behind or report stale values between CLEU and GetSpellCooldown updates.

local CD_MISMATCH_TOLERANCE = 0.15
-- Throttled monitor: periodic recompute interval (only runs if something triggered during this window).
local THROTTLED_COMPUTE_INTERVAL_SECONDS = 3
-- CD mismatch heartbeat: runs every 500ms; triggers compute when cs_cd_mismatch or judge_cd_mismatch.
local CD_MISMATCH_HEARTBEAT_INTERVAL_SECONDS = 0.5

--- Get the best estimate of seconds until a spell is ready.
--- Prefers CLEU-tracked cast time when it gives a later (more conservative) estimate,
--- falls back to live SpellTimeToReady otherwise.
--- @param spellId number
--- @param cdDuration number Full cooldown duration in seconds
--- @param trackedCastTime number|nil GetTime() when the spell was last confirmed cast (from CLEU)
--- @param now number Current GetTime()
--- @return number readyIn Seconds until ready (0 = ready now)
local function GetBestCDEstimate(spellId, cdDuration, trackedCastTime, now)
    local liveReadyIn = max(0, NAG:SpellTimeToReady(spellId) or 0)

    if not trackedCastTime or trackedCastTime <= 0 then
        return liveReadyIn
    end

    local trackedExpiresAt = trackedCastTime + cdDuration
    local trackedReadyIn = max(0, trackedExpiresAt - now)

    -- Use whichever is larger (most conservative / safest)
    return max(liveReadyIn, trackedReadyIn)
end

--- Raw CD remaining from GetTime (not NextTime). Used for CD mismatch comparison so both
--- live and predicted use the same time base. Predictions store absolute expiry and decay
--- naturally; comparing against live raw CD avoids NextTime/GetTime mismatch.
--- @param spellId number
--- @return number secondsRemaining 0 if ready or missing
local function GetRawCDRemaining(spellId)
    if not spellId then return 0 end
    local WoWAPI = ns.WoWAPI
    if not WoWAPI or not WoWAPI.GetSpellCooldown then return 0 end
    local cdInfo = WoWAPI.GetSpellCooldown(spellId)
    if not cdInfo then return 0 end
    local start = type(cdInfo) == "table" and (cdInfo.startTime or 0) or 0
    local duration = type(cdInfo) == "table" and (cdInfo.duration or 0) or 0
    if start <= 0 or duration <= 0 then return 0 end
    return max(0, (start + duration) - GetTime())
end

--- Absolute GetTime when spell CD expires. Used to store prediction so we can decay
--- correctly: predictedReadyIn = expiresAt - now. Prefer CLEU when available.
--- @param spellId number
--- @param cdDuration number
--- @param trackedCastTime number|nil
--- @param now number
--- @return number expiresAt 0 if spell ready
local function GetCDExpiresAt(spellId, cdDuration, trackedCastTime, now)
    if trackedCastTime and trackedCastTime > 0 then
        return trackedCastTime + cdDuration
    end
    local WoWAPI = ns.WoWAPI
    if not WoWAPI or not WoWAPI.GetSpellCooldown then return 0 end
    local cdInfo = WoWAPI.GetSpellCooldown(spellId)
    if not cdInfo then return 0 end
    local start = type(cdInfo) == "table" and (cdInfo.startTime or 0) or 0
    local duration = type(cdInfo) == "table" and (cdInfo.duration or 0) or 0
    if start <= 0 or duration <= 0 then return now end
    return start + duration
end

-- ============================ SNAPSHOT ============================

-- Known haste buff spell IDs whose expiry can shift the swing timer.
-- When these fade mid-swing, the remaining swing time stretches proportionally
-- (RetSim Player.RecalculateNext pattern).
local HASTE_BUFF_IDS = {
    [2825]  = true,  -- Bloodlust
    [32182] = true,  -- Heroism
    [26635] = true,  -- Berserking (Troll)
}

--- Scan player buffs for known haste effects and return the earliest
--- expiration time that falls before a given deadline.
--- @param deadline number Absolute time to compare against
--- @param now number Current GetTime()
--- @return number|nil expiresAt Earliest haste buff expiration, or nil if none
local function GetEarliestHasteBuffExpiry(deadline, now)
    local WoWAPI = ns.WoWAPI
    if not WoWAPI then return nil end
    local earliest = nil
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = WoWAPI.UnitBuff("player", i)
        if not name then break end
        if spellId and HASTE_BUFF_IDS[spellId] and expirationTime and expirationTime > 0 then
            if expirationTime > now and expirationTime < deadline then
                if not earliest or expirationTime < earliest then
                    earliest = expirationTime
                end
            end
        end
    end
    return earliest
end

--- Build a lightweight snapshot for the external-change monitor.
--- Only includes fields the monitor compares between ticks so we avoid
--- doing a full combat-context snapshot too frequently.
--- @return table snap
function SM:BuildMonitorSnapshot()
    local now = GetTime()
    local snap = {
        now = now,
        targetGuid = UnitGUID("target"),
        attackSpeed = 0,
        swingExpiration = 0,
        hasteBuffExpiresAt = nil,
    }

    local attackSpeed = UnitAttackSpeed("player")
    if attackSpeed and attackSpeed > 0 then
        snap.attackSpeed = attackSpeed
    end

    if swingTimerLib and swingTimerLib.UnitSwingTimerInfo then
        local _, mhExpiration = swingTimerLib:UnitSwingTimerInfo("player", "mainhand")
        if mhExpiration and mhExpiration > 0 then
            snap.swingExpiration = mhExpiration
            snap.hasteBuffExpiresAt = GetEarliestHasteBuffExpiry(mhExpiration, now)
        end
    end

    return snap
end

--- Build a timing snapshot from live game state.
--- Equivalent to HunterWeaveModule:GetWeaveSnapshot() but for melee Paladin.
--- @return table snap
function SM:BuildSnapshot()
    local now = GetTime()
    local snap = {
        ok = false,
        now = now,
        targetGuid = UnitGUID("target"),
        attackSpeed = 0,
        baseAttackSpeed = 0,
        timeToNextSwing = 0,
        swingExpiration = 0,
        gcdLeft = 0,
        gcdDuration = 1.5,
        activeSeal = "none", -- "soc", "sob", "none"
        csReadyIn = 0,
        judgeReadyIn = 0,
        exoReadyIn = 0,
        consReadyIn = 0,
        manaPercent = 1.0,
        inCombat = false,
        isAttacking = false,
        swingCount = 0,
        hasteBuffExpiresAt = nil,
        targetInMeleeRange = false,
        targetCount = 1,
        remainingTime = 9999,
        isUndead = false,
        isDemon = false,
        exoCastTime = 0,
        consCastTime = 0,
        exoUsable = false,
        consUsable = false,
    }

    -- Attack speed (current, may include haste buffs)
    local atkSpeed = UnitAttackSpeed("player")
    if not atkSpeed or atkSpeed <= 0 then
        return snap
    end
    snap.attackSpeed = atkSpeed
    snap.baseAttackSpeed = atkSpeed

    -- Swing timer via LibClassicSwingTimerAPI
    if swingTimerLib and swingTimerLib.UnitSwingTimerInfo then
        local mhSpeed, mhExpiration = swingTimerLib:UnitSwingTimerInfo("player", "mainhand")
        if mhExpiration and mhExpiration > 0 then
            snap.swingExpiration = mhExpiration
            snap.timeToNextSwing = max(0, mhExpiration - now)
        end
    end

    if snap.timeToNextSwing <= 0 and snap.attackSpeed > 0 then
        return snap
    end
    snap.ok = true

    -- Haste-aware swing prediction (RetSim Player.RecalculateNext pattern):
    -- If a known haste buff expires before the next swing, the swing will be
    -- delayed because the remaining time stretches when haste drops.
    -- We also compute a baseAttackSpeed (without the expiring haste) for
    -- future cycle predictions where the buff will have faded.
    local swingExpAt = snap.swingExpiration
    if swingExpAt > 0 then
        local hasteExpiry = GetEarliestHasteBuffExpiry(swingExpAt, now)
        if hasteExpiry then
            snap.hasteBuffExpiresAt = hasteExpiry
            -- After the haste buff drops, UnitAttackSpeed will return the unhasted
            -- value. We can estimate it: if we know current hasted speed and the
            -- buff's haste %, we could be precise. However, we don't easily know
            -- the exact buff contribution. A practical approach: use the swing timer
            -- library's speed (which is the current swing's effective speed) as-is
            -- for the current swing, but flag future cycles to re-poll attack speed.
            -- For now, we just record the expiry so the timeline can adjust.
        end
    end

    -- GCD with floor enforcement (RetSim Constants: MinimumGCD = 1000ms, DefaultGCD = 1500ms).
    -- Spell haste can reduce GCD but never below 1.0s.
    snap.gcdLeft = max(0, NAG:GCDTimeToReady() or 0)
    snap.gcdDuration = NAG:GCDTimeValue() or 1.5
    if snap.gcdDuration < 1.0 then snap.gcdDuration = 1.0 end
    if snap.gcdDuration > 1.5 then snap.gcdDuration = 1.5 end

    -- Active seal
    if NAG.RetTwistIsSoCActive and NAG:RetTwistIsSoCActive() then
        snap.activeSeal = "soc"
    elseif NAG.RetTwistIsSoBActive and NAG:RetTwistIsSoBActive() then
        snap.activeSeal = "sob"
    else
        snap.activeSeal = "none"
    end

    -- Cooldowns: best-of tracked CLEU cast time vs live SpellTimeToReady
    self:InitializeState()
    local st = self.state
    snap.csReadyIn = GetBestCDEstimate(SPELL_CS, CS_COOLDOWN, st.lastCSCastTime, now)
    snap.judgeReadyIn = GetBestCDEstimate(SPELL_JUDGEMENT, JUDGE_COOLDOWN, st.lastJudgeCastTime, now)
    snap.exoReadyIn = max(0, NAG:SpellTimeToReady(SPELL_EXORCISM) or 0)
    snap.consReadyIn = max(0, NAG:SpellTimeToReady(SPELL_CONS) or 0)
    -- Store absolute CD expiry (GetTime-based) so CD mismatch compares decayed prediction vs live raw CD
    snap.csExpiresAt = GetCDExpiresAt(SPELL_CS, CS_COOLDOWN, st.lastCSCastTime, now)
    snap.judgeExpiresAt = GetCDExpiresAt(SPELL_JUDGEMENT, JUDGE_COOLDOWN, st.lastJudgeCastTime, now)
    snap.exoExpiresAt = GetCDExpiresAt(SPELL_EXORCISM, 0, nil, now)
    snap.consExpiresAt = GetCDExpiresAt(SPELL_CONS, 0, nil, now)

    -- Mana
    snap.manaPercent = NAG:CurrentManaPercent() or 1.0

    -- Combat state
    snap.inCombat = NAG:InCombat() or false
    snap.isAttacking = NAG:IsAttacking() or false

    -- Target / encounter context for filler gating
    snap.targetInMeleeRange = (NAG.TargetInMeleeRange and NAG:TargetInMeleeRange(5)) or false
    snap.targetCount = (NAG.NumberTargets and NAG:NumberTargets(5, false)) or 1
    snap.remainingTime = (NAG.RemainingTime and NAG:RemainingTime()) or 9999
    snap.isUndead = (NAG.TargetMobType and NAG:TargetMobType(NAG.Types.MobType.Undead)) or false
    snap.isDemon = (NAG.TargetMobType and NAG:TargetMobType(NAG.Types.MobType.Demon)) or false
    snap.exoCastTime = (NAG.SpellCastTime and NAG:SpellCastTime(SPELL_EXORCISM)) or 0
    snap.consCastTime = (NAG.SpellCastTime and NAG:SpellCastTime(SPELL_CONS)) or 0
    snap.exoUsable = (NAG.SpellCanCast and NAG:SpellCanCast(SPELL_EXORCISM)) or false
    snap.consUsable = (NAG.SpellCanCast and NAG:SpellCanCast(SPELL_CONS)) or false

    -- Swing count from PaladinRetTwistModule
    snap.swingCount = NAG:RetTwistSwingCount() or 0

    return snap
end

-- ============================ SWING REGION CLASSIFIER ============================

--- Classify where we are in the current swing cycle (WA terminology).
--- @param timeToSwing number Seconds until next melee swing
--- @param gcdDuration number Current GCD duration
--- @param twistWindow number Twist window size (default 0.4)
--- @return string region One of REGION_* constants
local function ClassifySwingRegion(timeToSwing, gcdDuration, twistWindow)
    if timeToSwing <= 0 then
        return REGION_SWING_READY
    end

    local divBoundary = twistWindow + gcdDuration
    if timeToSwing > divBoundary then
        return REGION_BEFORE_DIV
    elseif timeToSwing > twistWindow then
        return REGION_AFTER_DIV
    else
        return REGION_IN_TWIST
    end
end

--- Compute key timing boundaries for a swing cycle.
--- @param swingEndAt number Absolute time when swing fires
--- @param attackSpeed number Weapon speed
--- @param gcdDuration number GCD duration
--- @param twistWindow number Twist window size
--- @param reactionTime number Player reaction compensation
--- @return table boundaries
local function ComputeSwingBoundaries(swingEndAt, attackSpeed, gcdDuration, twistWindow, reactionTime)
    return {
        swingEndAt = swingEndAt,
        nextSwingEndAt = swingEndAt + attackSpeed,
        -- Div = swing - twistWindow - gcdDuration. No extra protections (reaction, etc.).
        divBoundary = swingEndAt - twistWindow - gcdDuration,
        twistGapStart = swingEndAt - twistWindow - (reactionTime * 0.25),
        twistWindowStart = swingEndAt - twistWindow,
    }
end

--- Return the first swing end at or after a given absolute time.
--- @param context table
--- @param input table
--- @param atTime number
--- @return number
local function GetSwingEndAtOrAfter(context, input, atTime)
    local swingEndAt = tonumber(context.swingEndAt or 0) or 0
    local attackSpeed = tonumber(input.attackSpeed or 0) or 0
    if attackSpeed <= 0 then
        return swingEndAt
    end
    while swingEndAt > 0 and swingEndAt < (atTime - 0.015) do
        swingEndAt = swingEndAt + attackSpeed
    end
    return swingEndAt
end

--- Return the projected time-to-swing from an absolute time.
--- @param context table
--- @param input table
--- @param atTime number
--- @return number
local function GetProjectedSwingIn(context, input, atTime)
    local swingEndAt = GetSwingEndAtOrAfter(context, input, atTime)
    if swingEndAt <= 0 then
        return 0
    end
    return max(0, swingEndAt - atTime)
end

--- Determine whether fillers are urgent enough to check before SoC setup.
--- APL equivalent: TimeUntilSoC == -1 OR TimeUntilSoC >= gcd + 0.1
--- @param decision table
--- @param context table
--- @param input table
--- @param now number
--- @param predictionHoldTarget number
--- @return boolean
local function CanCheckFillersBeforeSoC(decision, context, input, now, predictionHoldTarget)
    local timeUntilSoC = -1
    if context.activeSeal ~= "soc" and decision.action == ACTION_SOC then
        if decision.holdFlag and predictionHoldTarget and predictionHoldTarget > now then
            timeUntilSoC = predictionHoldTarget - now
        else
            timeUntilSoC = 0
        end
    end
    -- Div is div: use gcdDuration only, no FILLER_SOC_BUFFER.
    return timeUntilSoC < 0 or timeUntilSoC >= (input.gcdDuration or 0)
end

--- APL equivalent of RetTwistShouldBlockFillersInSoBPreDiv().
--- Block fillers when SoB is active, SoC is not active, and we are still pre-div
--- at the moment the filler would actually start.
--- @param context table
--- @param input table
--- @param fillerStartAt number
--- @return boolean
local function ShouldBlockFillersInSoBPreDiv(context, input, fillerStartAt)
    if context.activeSeal ~= "sob" then
        return false
    end
    local projectedSwingIn = GetProjectedSwingIn(context, input, fillerStartAt)
    local rawDivAtAction = projectedSwingIn - ((input.twistWindow or 0) + (input.gcdDuration or 0))
    return rawDivAtAction > 0
end

--- Filler safety: must complete before we need to twist. When next action is twist, the limit
--- is the twist window (when we twist), not the div. GCD ready before div + twist next = filler OK.
--- @param spellCastTime number
--- @param context table
--- @param input table
--- @param fillerStartAt number
--- @return boolean
local function CanCastFillerBeforeTwist(spellCastTime, context, input, fillerStartAt)
    local projectedSwingIn = GetProjectedSwingIn(context, input, fillerStartAt)
    local twistWindow = input.twistWindow or 0
    local gcdDuration = input.gcdDuration or 0
    local rawDivAtAction = projectedSwingIn - (twistWindow + gcdDuration)
    local useNextSwing = context.activeSeal ~= "soc" and rawDivAtAction <= 0 and (input.attackSpeed or 0) > 0

    if context.activeSeal == "sob" and rawDivAtAction > 0 then
        return false
    end

    -- Limit = twist window (when we need to twist), not div. Filler must complete before twist.
    local swingForTwist = projectedSwingIn
    if useNextSwing then
        swingForTwist = swingForTwist + (input.attackSpeed or 0)
    end
    local timeToTwistWindow = max(0, swingForTwist - twistWindow)
    local fillerBudget = gcdDuration
    if fillerBudget > timeToTwistWindow then
        return false
    end

    if spellCastTime and spellCastTime > 0 then
        local castPlusGcd = spellCastTime + gcdDuration
        if castPlusGcd > timeToTwistWindow then
            return false
        end
    end

    return true
end

--- Filler must complete before CS. Div is div: use gcdDuration only, no extra margins.
--- @param csReadyAt number
--- @param input table
--- @param fillerStartAt number
--- @return boolean
local function CanCastFillerBeforeCS(csReadyAt, input, fillerStartAt)
    if not csReadyAt or csReadyAt <= 0 then
        return false
    end
    local fillerBudget = input.gcdDuration or 0
    return (fillerStartAt + fillerBudget) < csReadyAt
end

-- ============================ CORE DECISION FUNCTION ============================

--- Decide what action to take in a given swing cycle.
--- This is the heart of the state machine — a direct port of the 2021 WA logic
--- adapted into a structured decision function.
---
--- @param context table Carry-forward state between cycles
--- @param input table Timing constants (attackSpeed, gcdDuration, twistWindow, reactionTime, csMaxDelay)
--- @param window table Swing cycle boundaries from ComputeSwingBoundaries
--- @return table decision { action, holdFlag, fillerFlag, reason, actionAt, ... }
local function DecideRetAction(context, input, window)
    local decision = {
        action = ACTION_NONE,
        holdFlag = false,
        fillerFlag = false,
        judgeFlag = false,
        waitingJudgement = false,
        judgeRecommended = false,
        judgeRecommendedAt = 0,
        reason = "",
        actionAt = 0,
        actionSpellId = 0,
        fillerAt = 0,
        fillerSpellId = 0,
        predictionHoldUntil = 0,
    }

    local now = context.now or input.now
    local actionableAt = context.actionableAt or now
    local gcdFreeAt = max(actionableAt, now)
    local gcdDuration = input.gcdDuration
    local twistWindow = input.twistWindow
    local reactionTime = input.reactionTime
    local attackSpeed = input.attackSpeed

    local activeSeal = context.activeSeal or "none"

    local divBoundary = window.divBoundary
    local twistGapStart = window.twistGapStart
    local twistWindowStart = window.twistWindowStart
    local swingEndAt = window.swingEndAt
    local nextSwingEndAt = window.nextSwingEndAt

    -- Next-swing boundaries (for planning when current swing is missed)
    local nextDivBoundary = nextSwingEndAt - twistWindow - gcdDuration
    local nextTwistGapStart = nextSwingEndAt - twistWindow

    local gcdReady = (gcdFreeAt <= now + 0.015)

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ CS DELAY ANALYZER ~~~~~~~~~~~~~~~~~~~~~~~~
    -- If holding/twisting would delay CS beyond the configured max, force CS.
    local csMaxDelay = input.csMaxDelay or 0.5
    local csReadyAt = context.csReadyAt or now
    if csReadyAt < now then csReadyAt = now end

    local predictionHoldTarget = 0

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ MAIN DECISION TREE ~~~~~~~~~~~~~~~~~~~~~~~~
    -- Evaluate event boundaries in chronological order, RetSim-style. The first
    -- boundary that warrants an action becomes the decision; "waits" naturally
    -- fall out of picking a future boundary instead of branching on GCD state.
    local boundaryTimes = {
        now,
        gcdFreeAt,
        csReadyAt,
        context.judgeReadyAt or now,
        divBoundary,
        twistGapStart,
        twistWindowStart,
        swingEndAt,
        nextDivBoundary,
        nextTwistGapStart,
    }
    sort(boundaryTimes)

    local dedupedBoundaries = {}
    local lastBoundary = nil
    for _, boundaryAt in ipairs(boundaryTimes) do
        if boundaryAt and boundaryAt >= (now - 0.015) then
            if not lastBoundary or (boundaryAt - lastBoundary) > 0.015 then
                dedupedBoundaries[#dedupedBoundaries + 1] = boundaryAt
                lastBoundary = boundaryAt
            end
        end
    end

    for _, boundaryAt in ipairs(dedupedBoundaries) do
        local evalAt = max(boundaryAt, now)
        if evalAt >= (gcdFreeAt - 0.015) then
            local useNextSwing = evalAt >= (swingEndAt - 0.015)
            local refSwingEnd = useNextSwing and nextSwingEndAt or swingEndAt
            local refDivBoundary = useNextSwing and nextDivBoundary or divBoundary
            local refTwistGapStart = useNextSwing and nextTwistGapStart or twistGapStart
            local refTwistWindowStart = useNextSwing and nextTwistGapStart or twistWindowStart
            local followSwingEndAt = refSwingEnd + attackSpeed
            local followDivBoundary = followSwingEndAt - twistWindow - gcdDuration
            local followTwistGapStart = followSwingEndAt - twistWindow
            local predictionLandAt = evalAt + gcdDuration
            local futureBoundary = evalAt > (now + 0.03)
            local region = ClassifySwingRegion(
                refSwingEnd - evalAt,
                gcdDuration,
                twistWindow
            )

            if region == REGION_BEFORE_DIV or region == REGION_SWING_READY then
                if activeSeal ~= "soc" then
                    decision.action = ACTION_SOC
                    decision.reason = useNextSwing
                        and "gap_next_before_div_need_soc"
                        or "gap_before_div_need_soc"
                    predictionHoldTarget = reactionTime + max(predictionLandAt, refTwistGapStart)
                    break
                end
            elseif region == REGION_IN_TWIST then
                if activeSeal == "soc" then
                    decision.action = ACTION_TWIST
                    decision.reason = futureBoundary
                        and "gap_in_twist_soc_hold_for_twist"
                        or "gap_in_twist_soc_twist_now"
                    predictionHoldTarget = futureBoundary and (reactionTime + refTwistGapStart) or -1
                    decision.holdFlag = futureBoundary
                    break
                elseif activeSeal == "sob" then
                    decision.action = ACTION_SOC
                    if predictionLandAt > followDivBoundary then
                        decision.reason = useNextSwing
                            and "gap_next_in_twist_sob_soc_for_following"
                            or "gap_in_twist_sob_soc_for_next"
                    else
                        decision.holdFlag = true
                        decision.reason = useNextSwing
                            and "gap_next_in_twist_sob_hold_following"
                            or "gap_in_twist_sob_hold_next"
                    end
                    -- Hold until the next valid gap: when ref swing fires (not the twist after that).
                    predictionHoldTarget = reactionTime + max(predictionLandAt, refSwingEnd)
                    break
                else
                    if csReadyAt <= (evalAt + gcdDuration) then
                        decision.action = ACTION_SOC
                        decision.reason = useNextSwing
                            and "gap_next_in_twist_no_seal_cs_soon_soc"
                            or "gap_in_twist_no_seal_cs_soon_soc"
                        predictionHoldTarget = reactionTime + evalAt
                    else
                        decision.action = ACTION_TWIST
                        decision.reason = useNextSwing
                            and "gap_next_in_twist_no_seal_sob_direct"
                            or "gap_in_twist_no_seal_sob_direct"
                        predictionHoldTarget = futureBoundary
                            and (reactionTime + refTwistGapStart)
                            or reactionTime
                        decision.holdFlag = futureBoundary
                    end
                    break
                end
            elseif region == REGION_AFTER_DIV then
                if activeSeal == "soc" then
                    -- SoC is already active; hold until twist gap opens, then twist.
                    decision.action = ACTION_TWIST
                    decision.holdFlag = true
                    decision.reason = useNextSwing
                        and "gap_next_after_div_soc_hold_for_twist"
                        or "gap_after_div_soc_hold_for_twist"
                    predictionHoldTarget = reactionTime + refTwistGapStart
                    break
                elseif activeSeal == "sob" then
                    decision.action = ACTION_SOC
                    if predictionLandAt > followDivBoundary then
                        decision.reason = useNextSwing
                            and "gap_next_after_div_sob_soc_following"
                            or "gap_after_div_sob_soc_next"
                    else
                        decision.holdFlag = true
                        decision.reason = useNextSwing
                            and "gap_next_after_div_sob_hold_following"
                            or "gap_after_div_sob_hold_next"
                    end
                    -- Hold until the next valid gap: when ref swing fires (not the twist after that).
                    predictionHoldTarget = reactionTime + max(predictionLandAt, refSwingEnd)
                    break
                else
                    if csReadyAt <= (evalAt + gcdDuration) then
                        decision.action = ACTION_SOC
                        decision.reason = useNextSwing
                            and "gap_next_after_div_no_seal_cs_soon"
                            or "gap_after_div_no_seal_cs_soon"
                    else
                        decision.action = ACTION_TWIST
                        decision.reason = useNextSwing
                            and "gap_next_after_div_no_seal_sob_direct"
                            or "gap_after_div_no_seal_sob_direct"
                        predictionHoldTarget = futureBoundary
                            and (reactionTime + refTwistWindowStart)
                            or reactionTime
                        decision.holdFlag = futureBoundary
                        break
                    end
                    predictionHoldTarget = reactionTime + evalAt
                    break
                end
            end
        end
    end

    if not decision.action then
        decision.reason = "gap_no_action"
    end

    -- Clamp prediction hold
    if predictionHoldTarget > 0 and predictionHoldTarget < now then
        predictionHoldTarget = now
    end
    decision.predictionHoldUntil = predictionHoldTarget

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ CS OVERRIDE (TWIST-GATED) ~~~~~~~~~~~~~~~~~~~~~~~~
    -- CS delay is only allowed for the real twist case: SoC is currently active and
    -- the pending action is a twist back into SoB/SoM. For every other action, once
    -- CS is ready we should not keep waiting on seal work.
    --
    -- The important value here is the ACTUAL time we expect the current primary action
    -- to fire, not a generic "hold + gcd + reaction" estimate. That lets us enforce
    -- the user's configured max delay (default 1.7s) from the moment CS becomes ready.
    --
    -- Additionally: if CS is already off CD and we are not twisting in the next 200ms,
    -- send CS anyway. Do not commit to a distant twist when CS is ready now.
    local TWIST_IMMINENT_SECONDS = 0.2
    do
        local judgeReadyAt = context.judgeReadyAt or now
        local canDelayForTwist = decision.action == ACTION_TWIST and activeSeal == "soc"
        local allowedCSDelay = canDelayForTwist and csMaxDelay or 0
        local plannedActionAt = max(gcdFreeAt, now)

        if decision.action == ACTION_TWIST or decision.action == ACTION_HOLD then
            plannedActionAt = max(gcdFreeAt, twistWindowStart)
        elseif decision.action == ACTION_SOC then
            local holdTarget = predictionHoldTarget
            if holdTarget <= 0 then
                holdTarget = now
            end
            plannedActionAt = max(gcdFreeAt, holdTarget)
        elseif decision.action == ACTION_JUDGE_SOC then
            plannedActionAt = max(gcdFreeAt, judgeReadyAt)
        end

        local csReadyNow = csReadyAt <= (now + 0.015)
        local twistNotImminent = (plannedActionAt - now) > TWIST_IMMINENT_SECONDS
        local csWillBeDelayed = plannedActionAt > (csReadyAt + allowedCSDelay + 0.015)
        local csArrivesBeforeAction = csReadyAt <= (plannedActionAt + 0.015)
        local shouldOverrideForCS = csWillBeDelayed and csArrivesBeforeAction

        if shouldOverrideForCS or (csReadyNow and not canDelayForTwist) or (csReadyNow and canDelayForTwist and twistNotImminent) then
            local prevReason = decision.reason
            decision.holdFlag = false
            decision.action = ACTION_CS
            decision.predictionHoldUntil = 0

            if csReadyNow and not canDelayForTwist then
                decision.reason = "cs_ready_now_" .. prevReason
            elseif csReadyNow and canDelayForTwist and twistNotImminent then
                decision.reason = "cs_twist_not_imminent_" .. prevReason
            else
                decision.reason = "cs_delay_cap_" .. prevReason
            end

            local csCDTimer = max(0, csReadyAt - now)
            if gcdReady then
                if csCDTimer > 0.1 then
                    decision.holdFlag = true
                end
            else
                -- CSCD = CSStart + 6 (absolute). aura_env.CSCD + 0.1 > gcdWhen
                if (csReadyAt + 0.1) > gcdFreeAt then
                    decision.holdFlag = true
                end
            end
        end
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ SOC SWING SAFETY ~~~~~~~~~~~~~~~~~~~~~~~~
    -- Core seal discipline rules:
    --   Rule #1: ALWAYS auto-attack with SoB active. Never let a swing land with SoC.
    --   Rule #2: The EARLIEST we apply SoC is 100ms AFTER the swing fires.
    --   Rule #3: In pre-div, SoC is OK immediately (enough time for SoC -> twist SoB -> swing).
    --
    -- When the decision is ACTION_SOC with SoB active and we're past the div boundary,
    -- force a HOLD until the current swing fires + 100ms safety. This matches the APL's
    -- RetTwistHoldSoBToSoCTransition and RetTwistSoCSetupHoldSeconds behavior.
    -- Runs AFTER CS override — if CS took over, action != ACTION_SOC, so this is skipped.
    -- The hold target is also stored for downstream sections (judge+SoC inherits it).
    local SOC_POST_SWING_SAFETY = 0.1
    local socSwingHoldAt = 0

    if decision.action == ACTION_SOC and activeSeal == "sob" then
        local regionNow = ClassifySwingRegion(swingEndAt - now, gcdDuration, twistWindow)

        if regionNow ~= REGION_BEFORE_DIV and regionNow ~= REGION_SWING_READY then
            local socEarliestAt = swingEndAt + SOC_POST_SWING_SAFETY

            if socEarliestAt > now then
                decision.holdFlag = true
                decision.predictionHoldUntil = socEarliestAt
                socSwingHoldAt = socEarliestAt
                if not decision.reason:find("soc_swing_safety") then
                    decision.reason = decision.reason .. "_soc_swing_safety"
                end
            end
        end
    end

    -- Next-action-only mode: fillers are optional hints only and never replace
    -- the primary action.
    decision.fillerAction = nil
    decision.fillerFlag = false
    decision.fillerAt = 0

    -- WA judge exception (next-action-only): while SoB is active and action is SoC,
    -- switch to Judge+SoC when judge is ready before the next div reference.
    -- If judge is already ready, keep SoC hold timing (swing+100ms) and just
    -- promote the action key to judge_soc.
    if decision.action == ACTION_SOC and activeSeal == "sob" then
        local judgeReadyAt = context.judgeReadyAt or now
        local judgeReadyIn = max(0, judgeReadyAt - now)
        local regionNow = ClassifySwingRegion(swingEndAt - now, gcdDuration, twistWindow)
        local divReference = (regionNow == REGION_BEFORE_DIV) and divBoundary or nextDivBoundary
        local timeToDiv = max(0, divReference - now)

        if judgeReadyIn <= timeToDiv then
            decision.action = ACTION_JUDGE_SOC
            decision.judgeFlag = true
            decision.waitingJudgement = judgeReadyIn > 0
            decision.holdFlag = true
            decision.judgeRecommended = true
            decision.judgeRecommendedAt = judgeReadyAt
            if judgeReadyIn > 0 then
                decision.predictionHoldUntil = judgeReadyAt
            end
            decision.reason = decision.reason .. "_judge_soc"
        end
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ MANA EMERGENCY ~~~~~~~~~~~~~~~~~~~~~~~~
    if context.manaPercent < 0.1 then
        decision.action = ACTION_MANA
        decision.holdFlag = false
        decision.fillerFlag = false
        decision.judgeFlag = false
        decision.waitingJudgement = false
        decision.reason = "mana_emergency"
    end

    -- ~~~~~~~~~~~~~~~~~~~~~~~~ RESOLVE SPELL IDS & ACTION TIMING ~~~~~~~~~~~~~~~~~~~~~~~~
    -- The HOLD flag means "this is WHAT to cast, but wait for the right WHEN."
    -- Each hold scenario has a different target time — we resolve it here so the bar
    -- can place icons at the exact future moment the button should be pressed.
    decision.actionSpellId = ActionToSpellId(decision.action)

    -- Only twist/soc/judge_soc use HOLD countdowns in next-action-only mode.
    if decision.action ~= ACTION_TWIST and decision.action ~= ACTION_SOC and decision.action ~= ACTION_JUDGE_SOC then
        decision.holdFlag = false
        decision.predictionHoldUntil = 0
        decision.waitingJudgement = false
    end

    if decision.holdFlag then
        if decision.action == ACTION_TWIST or decision.action == ACTION_HOLD then
            local holdAt = twistGapStart
            if holdAt <= now then
                holdAt = nextTwistGapStart
            end
            -- If GCD clears after this swing, this cycle's twist is unreachable.
            if gcdFreeAt > swingEndAt then
                holdAt = nextTwistGapStart
            end
            decision.predictionHoldUntil = holdAt
            decision.actionAt = max(gcdFreeAt, holdAt)
        elseif decision.action == ACTION_SOC then
            local nextSwingAt = swingEndAt
            if nextSwingAt <= now then
                nextSwingAt = nextSwingEndAt
            end
            local holdAt = nextSwingAt + 0.1
            decision.predictionHoldUntil = holdAt
            decision.actionAt = max(gcdFreeAt, holdAt)
        elseif decision.action == ACTION_JUDGE_SOC then
            -- If SoC already established a valid HOLD (swing+100ms), keep it.
            -- Otherwise use judge-ready time.
            local holdAt = decision.predictionHoldUntil or 0
            if holdAt <= now then
                holdAt = max(now, context.judgeReadyAt or now)
            end
            decision.predictionHoldUntil = holdAt
            decision.actionAt = max(gcdFreeAt, holdAt)
        else
            local holdAt = max(now, decision.predictionHoldUntil or now)
            decision.predictionHoldUntil = holdAt
            decision.actionAt = max(gcdFreeAt, holdAt)
        end
    else
        decision.predictionHoldUntil = 0
        -- CS is only castable when its CD is ready; place at max(gcdFreeAt, csReadyAt).
        if decision.action == ACTION_CS then
            decision.actionAt = max(gcdFreeAt, csReadyAt, now)
        else
            decision.actionAt = max(gcdFreeAt, now)
        end
    end

    -- Optional filler pass: fillers can push the next action as long as it stays before next div.
    -- WA-style: fillerFlag when holding for soc/twist; allow filler if it completes before nextDivBoundary.
    decision.fillerRejectReason = nil
    decision.fillerChosenReason = nil
    do
        if decision.holdFlag then
            -- Div is div: use gcdDuration only, no FILLER_REACTION/FILLER_SAFETY.
            local fillerBudget = gcdDuration or 0
            local divGap = max(0, nextDivBoundary - gcdFreeAt)
            -- Allow filler if div gap fits (can push action to div). No swingCount gate (WA limitation).
            local canTryFillers = divGap >= fillerBudget and attackSpeed > 2.2

            if not canTryFillers then
                if divGap < fillerBudget then
                    decision.fillerRejectReason = string.format("divGap_too_small gap=%.2f need=%.2f", divGap, fillerBudget)
                else
                    decision.fillerRejectReason = string.format("attackSpeed_too_low speed=%.2f", attackSpeed)
                end
            elseif canTryFillers then
                local exoReadyAt = context.exoReadyAt or now
                local consReadyAt = context.consReadyAt or now
                local isUndeadOrDemon = context.isUndead or context.isDemon
                local exoSuppressedByReady = isUndeadOrDemon and exoReadyAt <= gcdFreeAt

                local function TryAssignOptionalFiller(actionName, fillerReadyAt, castTime)
                    local fillerStartAt = max(gcdFreeAt, fillerReadyAt or now)
                    -- Div is div: filler OK if it completes before next div. fillerBudget = gcdDuration only.
                    if (fillerStartAt + fillerBudget) > nextDivBoundary then
                        return false, "filler_would_push_past_div"
                    end
                    if ShouldBlockFillersInSoBPreDiv(context, input, fillerStartAt) then
                        return false, "blocked_SoB_pre_div"
                    end
                    if not CanCastFillerBeforeTwist(castTime or 0, context, input, fillerStartAt) then
                        return false, "cannot_cast_before_twist"
                    end
                    if not CanCastFillerBeforeCS(context.csReadyAt or now, input, fillerStartAt) then
                        return false, "cannot_cast_before_CS"
                    end

                    decision.fillerFlag = true
                    decision.fillerAction = actionName
                    decision.fillerAt = fillerStartAt
                    decision.fillerRejectReason = nil
                    return true
                end

                -- Priority: Cons 2+ targets > Exo (Undead/Demon) > Cons solo (matches Paladin.lua)
                local triedConsAoe = false
                local triedExo = false
                local triedConsSolo = false

                if (context.targetCount or 0) >= FILLER_MIN_TARGETS_AOE
                    and context.targetInMeleeRange
                    and (not exoSuppressedByReady)
                    and (context.manaPercent or 0) >= FILLER_CONS_MANA_MIN
                    and (context.remainingTime or 0) >= FILLER_MIN_REMAINING_TIME_SECONDS
                    and context.consUsable
                then
                    triedConsAoe = true
                    local ok, reason = TryAssignOptionalFiller(ACTION_FILLER_CON, consReadyAt, context.consCastTime or 0)
                    if ok then
                        decision.fillerChosenReason = "Cons_2+_targets"
                    elseif reason then
                        decision.fillerRejectReason = string.format("Cons_2+:%s", reason)
                    end
                end

                if not decision.fillerFlag and isUndeadOrDemon and context.exoUsable then
                    triedExo = true
                    local ok, reason = TryAssignOptionalFiller(ACTION_FILLER_EXO, exoReadyAt, context.exoCastTime or 0)
                    if ok then
                        decision.fillerChosenReason = "Exo_Undead_Demon"
                    elseif reason then
                        decision.fillerRejectReason = (decision.fillerRejectReason and (decision.fillerRejectReason .. "; ") or "")
                            .. string.format("Exo:%s", reason)
                    end
                end

                if not decision.fillerFlag
                    and context.targetInMeleeRange
                    and (not exoSuppressedByReady)
                    and (context.manaPercent or 0) >= FILLER_CONS_MANA_MIN
                    and (context.remainingTime or 0) >= FILLER_MIN_REMAINING_TIME_SECONDS
                    and context.consUsable
                then
                    triedConsSolo = true
                    local ok, reason = TryAssignOptionalFiller(ACTION_FILLER_CON, consReadyAt, context.consCastTime or 0)
                    if ok then
                        decision.fillerChosenReason = "Cons_solo"
                    elseif reason then
                        decision.fillerRejectReason = (decision.fillerRejectReason and (decision.fillerRejectReason .. "; ") or "")
                            .. string.format("Cons_solo:%s", reason)
                    end
                end

                if not decision.fillerFlag and not decision.fillerRejectReason then
                    local noCand = {}
                    if not triedConsAoe then table.insert(noCand, "Cons_2+") end
                    if not triedExo then table.insert(noCand, "Exo") end
                    if not triedConsSolo then table.insert(noCand, "Cons_solo") end
                    local conds = {}
                    if (context.targetCount or 0) < FILLER_MIN_TARGETS_AOE then table.insert(conds, "targets<2") end
                    if not context.targetInMeleeRange then table.insert(conds, "not_melee") end
                    if (context.manaPercent or 0) < FILLER_CONS_MANA_MIN then table.insert(conds, "mana_low") end
                    if (context.remainingTime or 0) < FILLER_MIN_REMAINING_TIME_SECONDS then table.insert(conds, "fight_short") end
                    if not context.consUsable then table.insert(conds, "cons_unusable") end
                    if exoSuppressedByReady then table.insert(conds, "exo_suppressed") end
                    if not isUndeadOrDemon then table.insert(conds, "not_undead_demon") end
                    if not context.exoUsable then table.insert(conds, "exo_unusable") end
                    decision.fillerRejectReason = "no_filler_candidate: " .. table.concat(conds, ",")
                end
            end
        else
            decision.fillerRejectReason = "no_hold"
        end
    end

    -- Filler timing: press as soon as the GCD slot opens (during the hold wait).
    -- Fillers fill idle time BEFORE the main action fires.
    if decision.fillerAction then
        decision.fillerSpellId = FillerToSpellId(decision.fillerAction)
        if not decision.fillerAt or decision.fillerAt <= 0 then
            decision.fillerAt = max(gcdFreeAt, now)
        end
    end

    -- Judge timing: Judgement is OFF the GCD — it can be cast anytime its own CD is ready,
    -- regardless of GCD state. Only gated by its own cooldown.
    if decision.action == ACTION_JUDGE_SOC then
        local judgeReadyAt = context.judgeReadyAt or now
        decision.judgeAt = max(judgeReadyAt, now)
        decision.judgeSpellId = SPELL_JUDGEMENT
        -- SoC follows judge immediately — store for bar display as secondary icon
        decision.socFollowUpSpellId = ActionToSpellId(ACTION_SOC)
    end

    return decision
end

-- ============================ TIMELINE STEP FUNCTION ============================

--- Build one swing cycle step for the timeline predictor.
--- @param context table Carry-forward context between steps
--- @param input table Shared timing constants
--- @param meta table { stepIndex, maxSteps }
--- @return table stepResult { context, state, done }
local function BuildRetCycleStep(context, input, meta)
    if context.cycleIndex >= MAX_SWING_CYCLES then
        return { done = true, context = context }
    end

    local now = input.now
    local attackSpeed = input.attackSpeed
    local swingEndAt = context.swingEndAt
    local horizonAt = input.horizonAt

    -- Past-horizon check
    if swingEndAt > horizonAt then
        return { done = true, context = context }
    end

    -- Compute boundaries
    local window = ComputeSwingBoundaries(
        swingEndAt, attackSpeed,
        input.gcdDuration, input.twistWindow, input.reactionTime
    )

    -- Run decision
    local decision = DecideRetAction(context, input, window)

    -- Build state record
    local cycleIndex = context.cycleIndex + 1
    local stateId = ((cycleIndex - 1) % SWING_RING_SIZE) + 1

    local state = {
        stateId = stateId,
        cycleIndex = cycleIndex,
        swingStartAt = context.swingStartAt,
        swingEndAt = swingEndAt,
        divBoundary = window.divBoundary,
        twistWindowStart = window.twistWindowStart,
        twistGapStart = window.twistGapStart,
        action = decision.action,
        actionAt = decision.actionAt,
        actionSpellId = decision.actionSpellId,
        holdFlag = decision.holdFlag,
        fillerFlag = decision.fillerFlag,
        fillerAction = decision.fillerAction,
        fillerAt = decision.fillerAt,
        fillerSpellId = decision.fillerSpellId,
        fillerRejectReason = decision.fillerRejectReason,
        fillerChosenReason = decision.fillerChosenReason,
        judgeFlag = decision.judgeFlag,
        judgeAt = decision.judgeAt,
        judgeSpellId = decision.judgeSpellId,
        waitingJudgement = decision.waitingJudgement,
        judgeRecommended = decision.judgeRecommended,
        judgeRecommendedAt = decision.judgeRecommendedAt,
        socFollowUpSpellId = decision.socFollowUpSpellId,
        reason = decision.reason,
        actionableAt = context.actionableAt,
        activeSeal = context.activeSeal,
        csReadyAt = context.csReadyAt,
        judgeReadyAt = context.judgeReadyAt,
        predictionHoldUntil = decision.predictionHoldUntil,
        region = ClassifySwingRegion(
            swingEndAt - max(context.actionableAt, now),
            input.gcdDuration, input.twistWindow
        ),
    }

    -- Advance context for next cycle.
    -- GCD starts from when the spell is ACTUALLY CAST (actionAt), not from "now".
    -- This matters for held actions (e.g. CS override waiting for CD) — the GCD
    -- doesn't start until the spell fires, pushing subsequent actions further out.
    local nextActionableAt = context.actionableAt
    local castAt = decision.actionAt or max(context.actionableAt, now)

    if decision.action == ACTION_SOC or decision.action == ACTION_TWIST or decision.action == ACTION_HOLD then
        nextActionableAt = castAt + input.gcdDuration
    elseif decision.action == ACTION_CS then
        nextActionableAt = castAt + input.gcdDuration
    elseif decision.action == ACTION_JUDGE_SOC then
        nextActionableAt = castAt + input.gcdDuration
    end

    -- Simulate seal state for next cycle (twist/hold both cast twist seal)
    local nextSeal = context.activeSeal
    if decision.action == ACTION_SOC then
        nextSeal = "soc"
    elseif decision.action == ACTION_TWIST or decision.action == ACTION_HOLD then
        nextSeal = "sob"
    elseif decision.action == ACTION_JUDGE_SOC then
        nextSeal = "soc"
    elseif decision.action == ACTION_MANA then
        nextSeal = "none"
    end

    -- Advance cooldowns (from actual cast time, not "now")
    local nextCsReadyAt = context.csReadyAt
    if decision.action == ACTION_CS then
        nextCsReadyAt = castAt + CS_COOLDOWN
    end

    local nextJudgeReadyAt = context.judgeReadyAt
    if decision.action == ACTION_JUDGE_SOC then
        -- Judge is off-GCD: its CD starts from when it's actually cast (judgeAt),
        -- not from the GCD-gated actionableAt. Even if we held for judge, we cast
        -- it in this cycle so the CD must advance.
        local judgeCastAt = decision.judgeAt or max(context.judgeReadyAt or now, now)
        nextJudgeReadyAt = judgeCastAt + JUDGE_COOLDOWN
    end

    -- Haste-aware swing prediction (RetSim RecalculateNext pattern):
    -- If a haste buff expires before the next swing starts, the next swing cycle
    -- will use the unhasted attack speed. If the buff expires MID-swing, the
    -- remaining time stretches proportionally.
    local nextSwingEndAt = swingEndAt + attackSpeed
    local hasteExpiry = input.hasteBuffExpiresAt
    local baseSpeed = input.baseAttackSpeed or attackSpeed
    if hasteExpiry and hasteExpiry > 0 and baseSpeed > attackSpeed then
        if hasteExpiry <= swingEndAt then
            -- Buff already expired before this swing ends — all future swings are unhasted.
            nextSwingEndAt = swingEndAt + baseSpeed
        elseif hasteExpiry < nextSwingEndAt then
            -- Buff expires mid-next-swing: stretch the remaining time proportionally.
            -- elapsed = hasteExpiry - swingEndAt (at hasted speed)
            -- remaining = nextSwingEndAt - hasteExpiry (would have been at hasted speed)
            -- adjustedRemaining = remaining * (baseSpeed / attackSpeed)
            local elapsedAtHaste = hasteExpiry - swingEndAt
            local remainingAtHaste = (swingEndAt + attackSpeed) - hasteExpiry
            local speedRatio = baseSpeed / attackSpeed
            nextSwingEndAt = hasteExpiry + (remainingAtHaste * speedRatio)
            -- Ensure at minimum one attackSpeed from the start
            if nextSwingEndAt < swingEndAt + attackSpeed then
                nextSwingEndAt = swingEndAt + attackSpeed
            end
        end
    end

    local newContext = {
        now = now,
        cycleIndex = cycleIndex,
        swingStartAt = swingEndAt,
        swingEndAt = nextSwingEndAt,
        actionableAt = nextActionableAt,
        activeSeal = nextSeal,
        csReadyAt = nextCsReadyAt,
        judgeReadyAt = nextJudgeReadyAt,
        exoReadyAt = context.exoReadyAt,
        consReadyAt = context.consReadyAt,
        manaPercent = context.manaPercent,
        isUndead = context.isUndead,
        isDemon = context.isDemon,
        remainingTime = context.remainingTime,
        targetInMeleeRange = context.targetInMeleeRange,
        targetCount = context.targetCount,
        exoUsable = context.exoUsable,
        consUsable = context.consUsable,
        exoCastTime = context.exoCastTime,
        consCastTime = context.consCastTime,
    }

    return { context = newContext, state = state }
end

-- ============================ TIMELINE EVALUATION ============================

--- Run the state machine prediction.
--- @param snap table|nil Snapshot from BuildSnapshot() (builds one if nil)
--- @param horizonSeconds number|nil Prediction horizon (default 4s)
--- @param includeFutureStates boolean|nil Build future states beyond state0
--- @return table result { ok, state0, states, snap }
function SM:EvaluateStateTimeline(snap, horizonSeconds, includeFutureStates)
    local result = {
        ok = false,
        state0 = nil,
        states = {},
        snap = nil,
        includesFutureStates = false,
    }

    if not snap then
        snap = self:BuildSnapshot()
    end
    result.snap = snap

    if not snap.ok then
        return result
    end

    local horizon = horizonSeconds or self.db.class.horizonSeconds or DEFAULT_HORIZON_SECONDS
    local now = snap.now
    local attackSpeed = snap.attackSpeed
    -- GCD floor: RetSim enforces max(gcdDuration / castSpeed, 1000ms) = min 1.0s.
    -- Snapshot already clamps, but enforce defensively here too.
    local gcdDuration = max(snap.gcdDuration, 1.0)
    local twistWindow = TWIST_WINDOW_SECONDS
    local reactionTime = (self.db.class.reactionTimeMs or 100) / 1000
    local csMaxDelay = (self.db.class.csMaxDelayMs or 500) / 1000

    -- Current swing boundaries
    local swingEndAt = snap.swingExpiration
    if swingEndAt <= now then
        swingEndAt = now + snap.timeToNextSwing
    end
    local swingStartAt = swingEndAt - attackSpeed

    -- Timing input (shared across all steps)
    local input = {
        now = now,
        attackSpeed = attackSpeed,
        gcdDuration = gcdDuration,
        twistWindow = twistWindow,
        reactionTime = reactionTime,
        csMaxDelay = csMaxDelay,
        horizonAt = now + horizon,
        swingCount = snap.swingCount or 0,
        hasteBuffExpiresAt = snap.hasteBuffExpiresAt,
        baseAttackSpeed = snap.baseAttackSpeed or attackSpeed,
    }

    -- State 0 context (from live game state)
    -- Use absolute expiry (GetTime-based) when available so CD mismatch compares decayed prediction vs raw live CD
    local csReadyAt = (snap.csExpiresAt and snap.csExpiresAt > 0) and snap.csExpiresAt or (now + snap.csReadyIn)
    local judgeReadyAt = (snap.judgeExpiresAt and snap.judgeExpiresAt > 0) and snap.judgeExpiresAt or (now + snap.judgeReadyIn)
    local exoReadyAt = (snap.exoExpiresAt and snap.exoExpiresAt > 0) and snap.exoExpiresAt or (now + snap.exoReadyIn)
    local consReadyAt = (snap.consExpiresAt and snap.consExpiresAt > 0) and snap.consExpiresAt or (now + snap.consReadyIn)
    local state0Context = {
        now = now,
        cycleIndex = 0,
        swingStartAt = swingStartAt,
        swingEndAt = swingEndAt,
        actionableAt = now + snap.gcdLeft,
        activeSeal = snap.activeSeal,
        csReadyAt = csReadyAt,
        judgeReadyAt = judgeReadyAt,
        exoReadyAt = exoReadyAt,
        consReadyAt = consReadyAt,
        manaPercent = snap.manaPercent,
        remainingTime = snap.remainingTime,
        targetInMeleeRange = snap.targetInMeleeRange,
        targetCount = snap.targetCount,
        isUndead = snap.isUndead,
        isDemon = snap.isDemon,
        exoUsable = snap.exoUsable,
        consUsable = snap.consUsable,
        exoCastTime = snap.exoCastTime,
        consCastTime = snap.consCastTime,
    }

    -- Compute state 0 (current swing)
    local window0 = ComputeSwingBoundaries(swingEndAt, attackSpeed, gcdDuration, twistWindow, reactionTime)
    local state0Decision = DecideRetAction(state0Context, input, window0)

    result.state0 = {
        stateId = 0,
        cycleIndex = 0,
        swingStartAt = swingStartAt,
        swingEndAt = swingEndAt,
        divBoundary = window0.divBoundary,
        twistWindowStart = window0.twistWindowStart,
        twistGapStart = window0.twistGapStart,
        action = state0Decision.action,
        actionAt = state0Decision.actionAt,
        actionSpellId = state0Decision.actionSpellId,
        holdFlag = state0Decision.holdFlag,
        fillerFlag = state0Decision.fillerFlag,
        fillerAction = state0Decision.fillerAction,
        fillerAt = state0Decision.fillerAt,
        fillerSpellId = state0Decision.fillerSpellId,
        fillerRejectReason = state0Decision.fillerRejectReason,
        fillerChosenReason = state0Decision.fillerChosenReason,
        judgeFlag = state0Decision.judgeFlag,
        judgeAt = state0Decision.judgeAt,
        judgeSpellId = state0Decision.judgeSpellId,
        waitingJudgement = state0Decision.waitingJudgement,
        judgeRecommended = state0Decision.judgeRecommended,
        judgeRecommendedAt = state0Decision.judgeRecommendedAt,
        socFollowUpSpellId = state0Decision.socFollowUpSpellId,
        reason = state0Decision.reason,
        actionableAt = state0Context.actionableAt,
        activeSeal = snap.activeSeal,
        predictionHoldUntil = state0Decision.predictionHoldUntil,
        -- Absolute CD expiry (GetTime-based) for GetCDMismatchReason; predicted decays as expiresAt - now
        csReadyAt = state0Context.csReadyAt,
        judgeReadyAt = state0Context.judgeReadyAt,
        region = ClassifySwingRegion(
            swingEndAt - max(state0Context.actionableAt, now),
            gcdDuration, twistWindow
        ),
    }
    if includeFutureStates == true then
        -- Build state1 by advancing context as if state0 was cast. step0 produces nextContext;
        -- step1 evaluates the next swing with that context (CS on CD, seal updated, etc.).
        local step0 = BuildRetCycleStep(state0Context, input, { stepIndex = 0, maxSteps = 1 })
        local nextContext = step0 and step0.context or nil
        if nextContext then
            local step1 = BuildRetCycleStep(nextContext, input, { stepIndex = 1, maxSteps = 1 })
            if step1 and step1.state then
                result.states[1] = step1.state
                result.includesFutureStates = true
            end
        end
    end

    result.ok = true
    return result
end

-- ============================ PUBLIC API ============================

--- Run prediction and return the result.
--- @param horizonSeconds number|nil
--- @param includeFutureStates boolean|nil
--- @return table result
function SM:PredictLive(horizonSeconds, includeFutureStates)
    local snap = self:BuildSnapshot()
    return self:EvaluateStateTimeline(snap, horizonSeconds, includeFutureStates == true)
end

--- Debug helper: classify a swing region with explicit inputs.
--- Used by parity tests and manual WA-vs-SM verification.
--- @param timeToSwing number
--- @param gcdDuration number
--- @param twistWindow number|nil
--- @return string
function SM:DebugClassifySwingRegion(timeToSwing, gcdDuration, twistWindow)
    local swingIn = tonumber(timeToSwing) or 0
    local gcd = tonumber(gcdDuration) or 1.5
    local window = tonumber(twistWindow) or TWIST_WINDOW_SECONDS
    return ClassifySwingRegion(swingIn, gcd, window)
end

--- Debug helper: compute swing boundaries with explicit inputs.
--- Used by parity tests and manual WA-vs-SM verification.
--- @param swingEndAt number
--- @param attackSpeed number
--- @param gcdDuration number
--- @param twistWindow number|nil
--- @param reactionTime number|nil
--- @return table
function SM:DebugComputeSwingBoundaries(swingEndAt, attackSpeed, gcdDuration, twistWindow, reactionTime)
    local swingAt = tonumber(swingEndAt) or 0
    local speed = tonumber(attackSpeed) or 0
    local gcd = tonumber(gcdDuration) or 1.5
    local window = tonumber(twistWindow) or TWIST_WINDOW_SECONDS
    local react = tonumber(reactionTime) or 0
    return ComputeSwingBoundaries(swingAt, speed, gcd, window, react)
end

--- Debug helper: evaluate one decision with explicit context and boundaries.
--- Used by parity tests and manual WA-vs-SM verification.
--- @param context table
--- @param input table
--- @param window table
--- @return table|nil
--- @return string|nil
function SM:DebugDecideRetAction(context, input, window)
    if type(context) ~= "table" then
        return nil, "context must be table"
    end
    if type(input) ~= "table" then
        return nil, "input must be table"
    end
    if type(window) ~= "table" then
        return nil, "window must be table"
    end
    return DecideRetAction(context, input, window), nil
end

-- Recompute control: lazy bridge-first mode.
-- Event handlers only invalidate cached prediction/state; fresh prediction is
-- built on demand when the bridge or explicit debug tools ask for it.
SM._lastPrediction = nil
SM._lastPredictionTime = 0
SM._monitorTimerHandle = nil
SM._delayedComputeTimerHandle = nil
SM._delayedPredictionAt = 0

-- ============================ DEBUG FORMAT HELPERS ============================

--- Returns true when Ret SM debug printing is allowed.
--- Uses global Dev Mode only (no separate module toggle).
--- @param obj table|nil Unused; kept for call-site compatibility
--- @return boolean
local function IsRetSMDebugEnabled(obj)
    return NAG and NAG.IsDevModeEnabled and NAG:IsDevModeEnabled() or false
end

-- Last GetTime() for Ret SM chat debug lines (delta = time since previous line).
local lastRetSMDebugPrintAt = 0

--- Print one debug line with session GetTime() and Δ since the previous Ret SM debug line.
--- @param msg string
local function RetSMDebugPrint(msg)
    if not IsRetSMDebugEnabled(nil) then return end
    local t = GetTime()
    local deltaStr
    if lastRetSMDebugPrintAt <= 0 then
        deltaStr = "—"
    else
        deltaStr = string.format("%+.3fs", t - lastRetSMDebugPrintAt)
    end
    lastRetSMDebugPrintAt = t
    print(string.format("[|cff888888t=%.3f Δ%s|r] %s", t, deltaStr, tostring(msg)))
end

--- Split a multi-line string and print each line with RetSMDebugPrint.
--- @param msg string
local function RetSMDebugPrintLines(msg)
    if not msg or msg == "" then return end
    for line in string.gmatch(msg, "[^\n]+") do
        RetSMDebugPrint(line)
    end
end

-- Forward declarations: PrintComputeDiagnostics / PrintTimelineDebug run before these are defined below.
local CollectChronologicalActionMoments
local BuildActionTimeChainString
local ShouldBuildFutureTimeline

--- Returns true when future-state prediction is actually needed.
--- APL bridge queue mode requires future states so we can surface
--- multiple upcoming spell moments with accurate wait timings.
--- @param obj table|nil
--- @return boolean
ShouldBuildFutureTimeline = function(obj)
    if IsRetSMDebugEnabled(obj) then
        return true
    end

    local bar = ns.PaladinRetSMBar
    local barDb = bar and bar.db and bar.db.class
    if barDb and barDb.enabled == true then
        return true
    end

    local twistBar = ns.PaladinRetTwistBar
    local twistBarDb = twistBar and twistBar.db and twistBar.db.class
    if twistBarDb and twistBarDb.enabled == true then
        return true
    end

    local classDb = obj and obj.db and obj.db.class
    return classDb and classDb.buildFutureTimelineForAPL ~= false or false
end

--- Format a state record into a compact one-line string for debug output.
--- @param label string e.g. "S0", "S1"
--- @param state table State record from the timeline
--- @param now number Current GetTime()
--- @return string
local function FormatStateDebugLine(label, state, now)
    if not state then return label .. ": (nil)" end
    local actionAt = tonumber(state.actionAt or 0) or 0
    local inSeconds = (actionAt > 0 and actionAt > now) and (actionAt - now) or 0
    local holdStr = state.holdFlag and "HOLD" or "NOW"
    local fillerStr = ""
    if state.fillerFlag and state.fillerAction then
        local fillerAt = tonumber(state.fillerAt or 0) or 0
        local fillerIn = (fillerAt > 0 and fillerAt > now) and (fillerAt - now) or 0
        fillerStr = string.format(" filler=%s@+%.2fs", tostring(state.fillerAction), fillerIn)
    end
    local judgeStr = ""
    if state.judgeFlag then
        local judgeAt = tonumber(state.judgeAt or 0) or 0
        local judgeIn = (judgeAt > 0 and judgeAt > now) and (judgeAt - now) or 0
        judgeStr = string.format(" judge@+%.2fs", judgeIn)
    end
    return string.format(
        "%s: |cff00ff00%s|r %s @+%.2fs seal=%s region=%s%s%s",
        label,
        tostring(state.action),
        holdStr,
        inSeconds,
        tostring(state.activeSeal or "?"),
        tostring(state.region or "?"),
        judgeStr,
        fillerStr
    )
end

--- Format a detailed breakdown of state0's decision reasoning.
--- @param state table State0 record
--- @param snap table Snapshot
--- @param now number
--- @return string
local function FormatState0DetailedReason(state, snap, now)
    if not state then return "(no state0)" end
    local lines = {}

    local actionAt = tonumber(state.actionAt or 0) or 0
    local actionIn = (actionAt > 0 and actionAt > now) and (actionAt - now) or 0

    lines[#lines + 1] = string.format(
        "  |cffffcc00WHY|r action=|cff00ff00%s|r: %s",
        tostring(state.action),
        tostring(state.reason or "?")
    )

    if state.holdFlag then
        local holdUntil = tonumber(state.predictionHoldUntil or 0) or 0
        local holdIn = (holdUntil > 0 and holdUntil > now) and (holdUntil - now) or 0
        lines[#lines + 1] = string.format(
            "  |cffffcc00WHEN|r holdUntil=+%.2fs actionAt=+%.2fs (waiting %.2fs)",
            holdIn, actionIn, actionIn
        )
    else
        lines[#lines + 1] = string.format(
            "  |cffffcc00WHEN|r actionAt=+%.2fs (immediate, no hold)",
            actionIn
        )
    end

    local swingIn = (snap and snap.timeToNextSwing) or 0
    local gcdIn = (snap and snap.gcdLeft) or 0
    local csIn = (snap and snap.csReadyIn) or 0
    local judgeIn = (snap and snap.judgeReadyIn) or 0
    lines[#lines + 1] = string.format(
        "  |cff888888CONTEXT|r seal=%s swing=%.2fs gcd=%.2fs cs=%.2fs judge=%.2fs mana=%.0f%%",
        tostring(snap and snap.activeSeal or "?"),
        swingIn, gcdIn, csIn, judgeIn,
        (snap and snap.manaPercent or 0) * 100
    )

    -- Filler debug: chosen or reject reason
    if state.fillerFlag and state.fillerChosenReason then
        lines[#lines + 1] = string.format(
            "  |cff00ff00FILLER|r chosen=%s action=%s",
            tostring(state.fillerChosenReason),
            tostring(state.fillerAction or "?")
        )
    elseif state.holdFlag and state.fillerRejectReason then
        lines[#lines + 1] = string.format(
            "  |cffff6666FILLER|r reject: %s",
            tostring(state.fillerRejectReason)
        )
    end

    return table.concat(lines, "\n")
end

--- Persist the latest observed external state used by the monitor.
--- @param snap table|nil
function SM:CaptureObservedState(snap)
    self:InitializeState()
    local st = self.state
    if not snap then
        return
    end
    st.lastObservedAttackSpeed = tonumber(snap.attackSpeed or 0) or 0
    st.lastObservedHasteExpiry = tonumber(snap.hasteBuffExpiresAt or 0) or 0
    st.lastObservedSwingExpiration = tonumber(snap.swingExpiration or 0) or 0
    st.lastObservedTargetGuid = tostring(snap.targetGuid or "")
end

--- Compute prediction immediately and cache it for consumers.
--- @param triggerSource string|nil
--- @param horizonSeconds number|nil
--- @param snap table|nil
--- @param includeFutureStates boolean|nil
--- @return table|nil
function SM:ComputePrediction(triggerSource, horizonSeconds, snap, includeFutureStates)
    if not self.db or not self.db.class.enabled then return end
    local now = GetTime()
    if not snap then
        snap = self:BuildSnapshot()
    end
    local shouldBuildFuture = includeFutureStates == true or ShouldBuildFutureTimeline(self) == true
    self._lastPrediction = self:EvaluateStateTimeline(snap, horizonSeconds, shouldBuildFuture)
    self._lastPredictionTime = now
    self._lastPredictionTriggerSource = triggerSource or "unknown"
    self._delayedPredictionAt = 0
    -- Reset CD mismatch throttle so we don't trigger another compute immediately after this one.
    self._lastCDMismatchComputeAt = now
    local wasCooldownDirty = self.state and self.state.cooldownDirty
    self:CaptureObservedState(self._lastPrediction and self._lastPrediction.snap or snap)
    self:InitializeState()
    self.state.cooldownDirty = false

    if IsRetSMDebugEnabled(self) then
        self._computeDiagSeq = (tonumber(self._computeDiagSeq) or 0) + 1
        self:PrintComputeDiagnostics(triggerSource, horizonSeconds, shouldBuildFuture, snap, self._lastPrediction, now, wasCooldownDirty)
    end
    return self._lastPrediction
end

--- Print a compact timeline debug dump (6 decisions + state0 reasoning).
--- @param result table Prediction result
--- @param now number
function SM:PrintTimelineDebug(result, now)
    if not result or not result.ok then return end

    local snap = result.snap

    -- State0 headline
    local s0Line = FormatStateDebugLine("S0", result.state0, now)
    local s0Detail = FormatState0DetailedReason(result.state0, snap, now)
    RetSMDebugPrint("|cff00ffffRetSM|r " .. s0Line)
    RetSMDebugPrintLines(s0Detail)

    -- Future states (up to 5 more)
    local parts = {}
    local maxShow = 5
    for i, s in ipairs(result.states) do
        if i > maxShow then break end
        local actionAt = tonumber(s.actionAt or 0) or 0
        local inSec = (actionAt > 0 and actionAt > now) and (actionAt - now) or 0
        local holdMark = s.holdFlag and "H" or ""
        parts[#parts + 1] = string.format(
            "|cff00ff00%s|r%s@+%.1fs",
            tostring(s.action), holdMark, inSec
        )
    end
    if #parts > 0 then
        RetSMDebugPrint("  |cff888888NEXT|r " .. table.concat(parts, " > "))
    end
    RetSMDebugPrint("  |cff888888CHAIN|r " .. BuildActionTimeChainString(result, now, self.db.class.horizonSeconds, 8))
end

--- Full diagnostic block for every ComputePrediction (when Ret SM debug is on).
--- @param triggerSource string|nil
--- @param horizonSeconds number|nil
--- @param includeFutureStates boolean|nil
--- @param snapPre table|nil Snapshot passed in (may differ from result.snap)
--- @param result table|nil
--- @param now number
--- @param wasCooldownDirty boolean|nil True if cooldownDirty was set before this compute reset state
function SM:PrintComputeDiagnostics(triggerSource, horizonSeconds, includeFutureStates, snapPre, result, now, wasCooldownDirty)
    local seq = tonumber(self._computeDiagSeq) or 0
    local horizon = tonumber(horizonSeconds) or tonumber(self.db and self.db.class and self.db.class.horizonSeconds) or DEFAULT_HORIZON_SECONDS
    local gcdLive = (NAG and NAG.GCDTimeToReady and NAG:GCDTimeToReady()) or 0
    local pendingDelayed = self:IsDelayedPredictionPending() and true or false

    -- Throttle repeated identical compute diagnostics.
    local throttleSeconds = tonumber(self.db and self.db.class and self.db.class.debugThrottleSeconds or 0.25) or 0.25
    if throttleSeconds < 0 then
        throttleSeconds = 0
    end
    local s0 = result and result.state0 or nil
    local s1 = result and result.states and result.states[1] or nil
    local diagKey = table.concat({
        tostring(triggerSource or "unknown"),
        tostring(includeFutureStates == true),
        tostring(result and result.ok == true),
        tostring(s0 and s0.action or ACTION_NONE),
        tostring(s0 and s0.reason or ""),
        tostring(s0 and s0.holdFlag == true),
        tostring(s1 and s1.action or ACTION_NONE),
        tostring(s1 and s1.reason or ""),
        tostring(s1 and s1.holdFlag == true),
        tostring(wasCooldownDirty == true),
    }, "|")
    local lastDiagKey = self._lastComputeDiagKey
    local lastDiagAt = tonumber(self._lastComputeDiagAt or 0) or 0
    if lastDiagKey == diagKey and (now - lastDiagAt) < throttleSeconds then
        return
    end
    self._lastComputeDiagKey = diagKey
    self._lastComputeDiagAt = now

    RetSMDebugPrint(string.format(
        "|cff00ffffRetSM Compute|r #%d |cff888888trigger|r=%s |cff888888now|r=%.3f |cff888888pendingDelayed|r=%s |cff888888gcdLive|r=%.3f",
        seq,
        tostring(triggerSource or "unknown"),
        now,
        tostring(pendingDelayed),
        gcdLive
    ))
    RetSMDebugPrint(string.format(
        "  |cff888888ARGS|r horizon=%.2f includeFutureArg=%s shouldBuildFuture=%s",
        horizon,
        tostring(includeFutureStates == true),
        tostring(ShouldBuildFutureTimeline(self) == true)
    ))
    RetSMDebugPrint(string.format(
        "  |cff888888WHY_TRIGGER|r source=%s pendingDelayed=%s cooldownDirty=%s",
        tostring(triggerSource or "unknown"),
        tostring(pendingDelayed),
        tostring(wasCooldownDirty == true)
    ))

    local snap = snapPre
    if result and result.snap then
        snap = result.snap
    end
    if snap then
        RetSMDebugPrint(string.format(
            "  |cff888888SNAP|r ok=%s now=%.3f seal=%s swingIn=%.3f gcd=%.3f gcdDur=%.3f cs=%.3f judge=%.3f atk=%.3f swingExp=%.3f swingCnt=%s combat=%s targetMelee=%s",
            tostring(snap.ok == true),
            tonumber(snap.now or now) or now,
            tostring(snap.activeSeal or "?"),
            tonumber(snap.timeToNextSwing or 0) or 0,
            tonumber(snap.gcdLeft or 0) or 0,
            tonumber(snap.gcdDuration or 0) or 0,
            tonumber(snap.csReadyIn or 0) or 0,
            tonumber(snap.judgeReadyIn or 0) or 0,
            tonumber(snap.attackSpeed or 0) or 0,
            tonumber(snap.swingExpiration or 0) or 0,
            tostring(snap.swingCount),
            tostring(snap.inCombat),
            tostring(snap.targetInMeleeRange)
        ))
        if snap.ok ~= true then
            RetSMDebugPrint("  |cffff4444SNAP|r ok=false — usually missing swing timer / no MH swing in flight (see BuildSnapshot).")
        end
    else
        RetSMDebugPrint("  |cffff4444SNAP|r (nil)")
    end

    if not result then
        RetSMDebugPrint("  |cffff4444RESULT|r nil")
        return
    end

    RetSMDebugPrint(string.format(
        "  |cff888888RESULT|r ok=%s includesFuture=%s futureStates=%d cooldownDirty=%s",
        tostring(result.ok == true),
        tostring(result.includesFutureStates == true),
        #(result.states or {}),
        tostring(wasCooldownDirty == true)
    ))

    if not result.ok then
        RetSMDebugPrint("  |cffff4444FAIL|r EvaluateStateTimeline did not set ok (see SNAP ok=false above).")
        return
    end

    if result.state0 then
        RetSMDebugPrint("|cff00ffffRetSM|r " .. FormatStateDebugLine("S0", result.state0, now))
        RetSMDebugPrintLines(FormatState0DetailedReason(result.state0, result.snap or snap, now))
    else
        RetSMDebugPrint("  |cffff4444S0|r (nil)")
    end

    local parts = {}
    local maxShow = 8
    for i, s in ipairs(result.states or {}) do
        if i > maxShow then break end
        local actionAt = tonumber(s.actionAt or 0) or 0
        local inSec = (actionAt > 0 and actionAt > now) and (actionAt - now) or 0
        local holdMark = s.holdFlag and "H" or ""
        parts[#parts + 1] = string.format("|cff00ff00%s|r%s@+%.1fs", tostring(s.action), holdMark, inSec)
    end
    if #parts > 0 then
        RetSMDebugPrint("  |cff888888NEXT|r " .. table.concat(parts, " > "))
        local firstNext = result.states and result.states[1] or nil
        if firstNext then
            local nextActionAt = tonumber(firstNext.actionAt or 0) or 0
            local nextIn = (nextActionAt > 0 and nextActionAt > now) and (nextActionAt - now) or 0
            RetSMDebugPrint(string.format(
                "  |cff888888S1 WHY|r action=%s reason=%s wait=+%.2fs hold=%s",
                tostring(firstNext.action or ACTION_NONE),
                tostring(firstNext.reason or "?"),
                nextIn,
                tostring(firstNext.holdFlag == true)
            ))
            if firstNext.fillerFlag then
                RetSMDebugPrint(string.format(
                    "  |cff888888S1 FILLER|r action=%s chosen=%s",
                    tostring(firstNext.fillerAction or "?"),
                    tostring(firstNext.fillerChosenReason or "?")
                ))
            elseif firstNext.fillerRejectReason then
                RetSMDebugPrint(string.format(
                    "  |cff888888S1 FILLER|r reject=%s",
                    tostring(firstNext.fillerRejectReason)
                ))
            end
        end
    end
    RetSMDebugPrint("  |cff888888CHAIN|r " .. BuildActionTimeChainString(result, now, self.db.class.horizonSeconds, 8))
end

--- Return the spell-triggered recompute delay: 100ms + latency, capped.
--- @return number
function SM:GetSpellTriggeredComputeDelay()
    local latencyMs = (NAG and NAG.GetNetStats and NAG:GetNetStats()) or 0
    if type(latencyMs) ~= "number" or latencyMs < 0 then
        latencyMs = 0
    end
    return SPELL_SENT_BASE_DELAY_SECONDS + min(SPELL_SENT_LATENCY_CAP_SECONDS, latencyMs / 1000)
end

--- Schedule a delayed recompute after a spell press, mirroring the Hunter timing.
--- @param triggerSource string|nil
function SM:ScheduleDelayedPredictionCompute(triggerSource)
    if self._delayedComputeTimerHandle then
        self:CancelTimer(self._delayedComputeTimerHandle)
        self._delayedComputeTimerHandle = nil
    end

    local delaySeconds = self:GetSpellTriggeredComputeDelay()
    self._delayedPredictionAt = GetTime() + delaySeconds
    if IsRetSMDebugEnabled(self) then
        local now = GetTime()
        local cached = self._lastPrediction and self._lastPrediction.state0 or nil
        local cachedAction = cached and cached.action or ACTION_NONE
        local cachedReason = cached and cached.reason or "none"
        local gcdLeft = NAG:GCDTimeToReady() or 0
        RetSMDebugPrint(string.format(
            "|cff00ffffRetSM Pending|r trigger=%s delay=%.3f cached=%s reason=%s gcd=%.3f due=+%.3fs",
            tostring(triggerSource or "spell_cast_success"),
            delaySeconds or 0,
            tostring(cachedAction),
            tostring(cachedReason),
            gcdLeft or 0,
            max(0, (self._delayedPredictionAt or now) - now)
        ))
    end
    self._delayedComputeTimerHandle = self:ScheduleTimer(function()
        self._delayedComputeTimerHandle = nil
        if self:IsEnabled() then
            self:ComputePrediction(triggerSource or "spell_cast_success")
        end
    end, delaySeconds)
end

--- Determine whether a delayed spell-sent recompute is still pending.
--- @return boolean
function SM:IsDelayedPredictionPending()
    return (tonumber(self._delayedPredictionAt or 0) or 0) > GetTime()
end

--- Compare predicted cooldowns against live cooldowns.
--- Returns the mismatch source, if any, so the monitor can recompute.
--- @param prediction table|nil
--- @return string|nil
function SM:GetCDMismatchReason(prediction)
    if not prediction or prediction.ok ~= true then
        return nil
    end

    local now = GetTime()
    local state0 = prediction.state0 or {}
    local predictionSnap = prediction.snap or {}

    local snapNow = tonumber(predictionSnap.now or now) or now
    -- Predicted: use absolute expiry so we decay correctly (expiresAt - now). Prefer stored expiry over snap.now+readyIn.
    local predictedCSReadyAt = tonumber(state0.csReadyAt or 0) or 0
    if predictedCSReadyAt <= 0 and predictionSnap then
        predictedCSReadyAt = (predictionSnap.csExpiresAt and predictionSnap.csExpiresAt > 0)
            and predictionSnap.csExpiresAt or (snapNow + (tonumber(predictionSnap.csReadyIn or 0) or 0))
    end
    local predictedJudgeReadyAt = tonumber(state0.judgeReadyAt or 0) or 0
    if predictedJudgeReadyAt <= 0 and predictionSnap then
        predictedJudgeReadyAt = (predictionSnap.judgeExpiresAt and predictionSnap.judgeExpiresAt > 0)
            and predictionSnap.judgeExpiresAt or (snapNow + (tonumber(predictionSnap.judgeReadyIn or 0) or 0))
    end
    local predictedExoReadyAt = (predictionSnap.exoExpiresAt and predictionSnap.exoExpiresAt > 0)
        and predictionSnap.exoExpiresAt or (snapNow + (tonumber(predictionSnap.exoReadyIn or 0) or 0))
    local predictedConsReadyAt = (predictionSnap.consExpiresAt and predictionSnap.consExpiresAt > 0)
        and predictionSnap.consExpiresAt or (snapNow + (tonumber(predictionSnap.consReadyIn or 0) or 0))

    -- Live: use raw CD remaining (GetTime-based) so we compare apples-to-apples with predicted (also GetTime-based)
    local liveCSReadyIn = GetRawCDRemaining(SPELL_CS)
    local liveJudgeReadyIn = GetRawCDRemaining(SPELL_JUDGEMENT)
    local liveExoReadyIn = GetRawCDRemaining(SPELL_EXORCISM)
    local liveConsReadyIn = GetRawCDRemaining(SPELL_CONS)

    -- Predicted decays naturally: predictedReadyIn = expiresAt - now (elapsed time since snapshot reduces this)
    local predictedCSReadyIn = max(0, predictedCSReadyAt - now)
    local predictedJudgeReadyIn = max(0, predictedJudgeReadyAt - now)
    local predictedExoReadyIn = max(0, predictedExoReadyAt - now)
    local predictedConsReadyIn = max(0, predictedConsReadyAt - now)
    local judgeDelta = liveJudgeReadyIn - predictedJudgeReadyIn
    local judgeAbsDelta = abs(judgeDelta)

    if IsRetSMDebugEnabled(self) then
        local throttleSeconds = tonumber(self.db.class.debugThrottleSeconds or 0.25) or 0.25
        if throttleSeconds < 0 then
            throttleSeconds = 0
        end
        local judgeDbgKey = table.concat({
            tostring(math.floor((liveJudgeReadyIn * 100) + 0.5)),
            tostring(math.floor((predictedJudgeReadyIn * 100) + 0.5)),
            tostring(math.floor((judgeAbsDelta * 100) + 0.5)),
            tostring(judgeAbsDelta > CD_MISMATCH_TOLERANCE)
        }, "|")
        local lastKey = self._lastJudgeCDCheckDebugKey
        local lastAt = tonumber(self._lastJudgeCDCheckDebugAt or 0) or 0
        -- Skip idle 0/0/0 lines; throttle only repeats when values actually change.
        local boringJudge =
            (liveJudgeReadyIn < 0.001)
            and (predictedJudgeReadyIn < 0.001)
            and (judgeAbsDelta < 0.001)
        local shouldPrintJudge = (not boringJudge) and (lastKey ~= judgeDbgKey or (now - lastAt) >= throttleSeconds)
        if shouldPrintJudge then
            self._lastJudgeCDCheckDebugKey = judgeDbgKey
            self._lastJudgeCDCheckDebugAt = now
            RetSMDebugPrint(string.format(
                "|cff00ffffRetSM JudgeCD|r live=%.3f predicted=%.3f delta=%.3f abs=%.3f tol=%.3f mismatch=%s trigger=%s age=%.3f",
                liveJudgeReadyIn,
                predictedJudgeReadyIn,
                judgeDelta,
                judgeAbsDelta,
                CD_MISMATCH_TOLERANCE,
                tostring(judgeAbsDelta > CD_MISMATCH_TOLERANCE),
                tostring(self._lastPredictionTriggerSource or "unknown"),
                max(0, now - (tonumber(self._lastPredictionTime or 0) or 0))
            ))
        end
    end

    -- When a mismatch is found, print both values and context to detect apples-vs-oranges comparison.
    local function PrintCDMismatchDetail(label, liveVal, predictedVal, spellId)
        local gcdReadyIn = (NAG.GCDTimeToReady and NAG:GCDTimeToReady()) or 0
        local now = GetTime()
        local nextTime = (NAG.NextTime and NAG:NextTime()) or now
        local rawCDRemaining = 0
        if ns.WoWAPI and ns.WoWAPI.GetSpellCooldown and spellId then
            local cdInfo = ns.WoWAPI.GetSpellCooldown(spellId)
            if cdInfo then
                local start = type(cdInfo) == "table" and cdInfo.startTime or 0
                local duration = type(cdInfo) == "table" and cdInfo.duration or 0
                if start > 0 and duration > 0 then
                    rawCDRemaining = max(0, (start + duration) - now)
                end
            end
        end
        RetSMDebugPrint(string.format(
            "  |cffff8800CD_MISMATCH_DETAIL %s|r live=%.3f predicted=%.3f delta=%.3f | rawCD=%.3f gcd=%.3f nextTime-getTime=%.3f",
            label, liveVal, predictedVal, liveVal - predictedVal, rawCDRemaining, gcdReadyIn, nextTime - now
        ))
    end

    if abs(liveCSReadyIn - predictedCSReadyIn) > CD_MISMATCH_TOLERANCE then
        if IsRetSMDebugEnabled(self) then
            PrintCDMismatchDetail("CS", liveCSReadyIn, predictedCSReadyIn, SPELL_CS)
        end
        return "cs_cd_mismatch"
    end
    if judgeAbsDelta > CD_MISMATCH_TOLERANCE then
        if IsRetSMDebugEnabled(self) then
            PrintCDMismatchDetail("Judge", liveJudgeReadyIn, predictedJudgeReadyIn, SPELL_JUDGEMENT)
        end
        return "judge_cd_mismatch"
    end
    if abs(liveExoReadyIn - predictedExoReadyIn) > CD_MISMATCH_TOLERANCE then
        if IsRetSMDebugEnabled(self) then
            PrintCDMismatchDetail("Exo", liveExoReadyIn, predictedExoReadyIn, SPELL_EXORCISM)
        end
        return "exo_cd_mismatch"
    end
    if abs(liveConsReadyIn - predictedConsReadyIn) > CD_MISMATCH_TOLERANCE then
        if IsRetSMDebugEnabled(self) then
            PrintCDMismatchDetail("Cons", liveConsReadyIn, predictedConsReadyIn, SPELL_CONS)
        end
        return "cons_cd_mismatch"
    end

    return nil
end

--- Get cached state0 data for lightweight API consumers.
--- @param sm table|nil
--- @param horizonSeconds number|nil
--- @return table|nil state0
--- @return table|nil result
local function GetCachedState0(sm, horizonSeconds)
    if not sm or not sm.db or not sm.db.class.enabled then
        return nil, nil
    end

    local result = sm:GetCachedPrediction(horizonSeconds)
    if not result or not result.ok or not result.state0 then
        return nil, result
    end

    return result.state0, result
end

--- Derive the exposed action and hold time from a cached state0.
--- @param state0 table|nil
--- @param now number
--- @return string action
--- @return number holdSeconds
--- @return number actionAt
local function GetActionAndHoldFromState0(state0, now)
    local action = (state0 and state0.action) or ACTION_NONE
    local actionAt = tonumber(state0 and state0.actionAt or 0) or 0
    local holdSeconds = 0
    if actionAt > now then
        holdSeconds = actionAt - now
    end
    return action, holdSeconds, actionAt
end

--- Push one state-machine action moment into the flattened list.
--- @param out table
--- @param at number|nil
--- @param spellId number|nil
--- @param slot number|nil
--- @param stateIndex number
--- @param actionKey string|nil
local function PushActionMoment(out, at, spellId, slot, stateIndex, actionKey)
    local ts = tonumber(at or 0) or 0
    local sid = tonumber(spellId or 0) or 0
    if ts <= 0 or sid <= 0 then
        return
    end
    out[#out + 1] = {
        at = ts,
        spellId = sid,
        slot = slot or 1,
        stateIndex = tonumber(stateIndex) or 0,
        actionKey = tostring(actionKey or ACTION_NONE),
    }
end

--- Collect displayable moments from one state record.
--- Next-action-only mode: primary action + optional filler (when fillerFlag).
--- Filler is a side hint and never replaces the primary action.
--- @param state table|nil
--- @param out table
--- @param stateIndex number
local function CollectStateActionMoments(state, out, stateIndex)
    if not state then
        return
    end
    local sidx = tonumber(stateIndex) or 0
    local actionAt = tonumber(state.actionAt or 0) or 0
    local actionSpellId = tonumber(state.actionSpellId or 0) or 0

    if actionAt > 0 and actionSpellId > 0 then
        PushActionMoment(out, actionAt, actionSpellId, 1, sidx, state.action)
    end

    -- Optional filler: show as side icon when state machine detected filler fits.
    if state.fillerFlag and state.fillerAction and state.fillerSpellId and state.fillerSpellId > 0 then
        local fillerAt = tonumber(state.fillerAt or 0) or 0
        if fillerAt > 0 then
            PushActionMoment(out, fillerAt, state.fillerSpellId, 2, sidx, state.fillerAction)
        end
    end
end

--- Tie-break equal timestamps so Judge appears before SoC follow-up.
--- @param actionKey string|nil
--- @return number
local function ActionOrderPriority(actionKey)
    if actionKey == ACTION_JUDGE_SOC or actionKey == "judge" then
        return 10
    end
    if actionKey == "soc_followup" then
        return 20
    end
    if actionKey == ACTION_FILLER_CON or actionKey == ACTION_FILLER_EXO then
        return 30
    end
    return 15
end

--- Convert action keys into compact debug labels.
--- @param actionKey string|nil
--- @return string
local function ActionDebugLabel(actionKey)
    local key = tostring(actionKey or ACTION_NONE)
    if key == ACTION_CS then return "CS" end
    if key == ACTION_SOC or key == "soc_followup" then return "SoC" end
    if key == ACTION_TWIST or key == ACTION_HOLD then return "Twist" end
    if key == ACTION_JUDGE_SOC or key == "judge" then return "Judge" end
    if key == ACTION_FILLER_EXO then return "Exo" end
    if key == ACTION_FILLER_CON then return "Cons" end
    if key == ACTION_MANA then return "ManaSeal" end
    if key == ACTION_BURST then return "BurstTwist" end
    return key
end

--- Build a compact action timeline string in {ACTION,TIME} format.
--- Example: {CS,+0.00s} -> {Judge,+1.20s} -> {SoC,+1.20s}
--- @param result table|nil
--- @param now number
--- @param horizonSeconds number|nil
--- @param maxMoments number|nil
--- @return string
BuildActionTimeChainString = function(result, now, horizonSeconds, maxMoments)
    if not result or result.ok ~= true then
        return "{none,+0.00s}"
    end

    local horizon = tonumber(horizonSeconds) or DEFAULT_HORIZON_SECONDS
    if horizon <= 0 then
        horizon = DEFAULT_HORIZON_SECONDS
    end
    local limit = tonumber(maxMoments) or 8
    if limit < 1 then
        limit = 1
    end

    local moments = CollectChronologicalActionMoments(result, now, horizon, BRIDGE_MAX_STATES)
    if not moments or #moments == 0 then
        return "{none,+0.00s}"
    end

    local parts = {}
    local count = math.min(limit, #moments)
    for i = 1, count do
        local m = moments[i]
        local at = tonumber(m.at or now) or now
        local inSec = max(0, at - now)
        parts[#parts + 1] = string.format("{%s,+%.2fs}", ActionDebugLabel(m.actionKey), inSec)
    end
    return table.concat(parts, " -> ")
end

--- Flatten prediction output into sorted spell moments.
--- @param result table|nil
--- @param now number
--- @param horizonSeconds number|nil
--- @param maxStates number|nil Number of state records to include (state0 + futures)
--- @return table
CollectChronologicalActionMoments = function(result, now, horizonSeconds, maxStates)
    if not result or result.ok ~= true then
        return {}
    end

    local actions = {}
    CollectStateActionMoments(result.state0, actions, 0)

    local requestedStates = tonumber(maxStates) or 1
    if requestedStates > 1 and type(result.states) == "table" and #result.states > 0 then
        local limit = math.min(requestedStates - 1, #result.states)
        for i = 1, limit do
            CollectStateActionMoments(result.states[i], actions, i)
        end
    end

    local horizon = tonumber(horizonSeconds) or DEFAULT_HORIZON_SECONDS
    if horizon <= 0 then
        horizon = DEFAULT_HORIZON_SECONDS
    end
    local horizonAt = now + horizon
    local filtered = {}
    for i = 1, #actions do
        local e = actions[i]
        if e then
            local at = tonumber(e.at or 0) or 0
            local withinHorizon = at <= horizonAt
            local inFutureOrNow = at >= now
            -- Persist briefly AFTER crossing zero to avoid blank frames between recomputes.
            local withinPastGrace = (at < now) and ((now - at) <= ACTION_PAST_TOLERANCE_SECONDS)
            if withinHorizon and (inFutureOrNow or withinPastGrace) then
                filtered[#filtered + 1] = e
            end
        end
    end

    sort(filtered, function(a, b)
        if a.at == b.at then
            local pa = ActionOrderPriority(a.actionKey)
            local pb = ActionOrderPriority(b.actionKey)
            if pa == pb then
                return (a.spellId or 0) < (b.spellId or 0)
            end
            return pa < pb
        end
        return a.at < b.at
    end)

    return filtered
end

--- Resolve bridge display position for one queued action.
--- @param entry table
--- @param previous table|nil
--- @return string
local function ResolveBridgeQueuePosition(entry, previous)
    local actionKey = tostring(entry and entry.actionKey or ACTION_NONE)
    local spellId = tonumber(entry and entry.spellId or 0) or 0
    local previousSpellId = tonumber(previous and previous.spellId or 0) or 0

    if actionKey == ACTION_FILLER_CON or actionKey == ACTION_FILLER_EXO then
        -- Use configured filler side (left1/right1) from PaladinRetTwistBar.
        return (NAG.RetTwistGetFillerSourcePosition and NAG:RetTwistGetFillerSourcePosition()) or "left1"
    end

    if spellId == SPELL_JUDGEMENT or actionKey == ACTION_JUDGE_SOC or actionKey == "judge" then
        return ns.SPELL_POSITIONS.PRIMARY
    end

    if actionKey == ACTION_TWIST or actionKey == ACTION_HOLD then
        return ns.SPELL_POSITIONS.PRIMARY
    end

    if actionKey == "soc_followup" then
        return ns.SPELL_POSITIONS.AOE
    end

    if actionKey == ACTION_SOC and previousSpellId == SPELL_JUDGEMENT then
        return ns.SPELL_POSITIONS.AOE
    end

    return ns.SPELL_POSITIONS.PRIMARY
end

--- Build queue label text for future steps.
--- @param waitFromNow number
--- @return string
local function BuildQueueOverlayText(waitFromNow)
    local waitSeconds = tonumber(waitFromNow or 0) or 0
    if waitSeconds <= 0.05 then
        return "NOW"
    end
    return string.format("+%.1fs", waitSeconds)
end

--- Monitor runs periodically; recomputes when 3s since last compute.
--- CD mismatch (cs/judge) is checked by separate 500ms heartbeat (MonitorCDMismatchHeartbeat).
function SM:MonitorExternalChanges()
    if not self.db or not self.db.class.enabled then
        return
    end
    if self:IsDelayedPredictionPending() then
        if IsRetSMDebugEnabled(self) then
            local now = GetTime()
            local throttleSeconds = tonumber(self.db.class.debugThrottleSeconds or 0.25) or 0.25
            if throttleSeconds < 0 then
                throttleSeconds = 0
            end
            local pendingFor = max(0, (tonumber(self._delayedPredictionAt or now) or now) - now)
            local pendingDbgKey = string.format(
                "%s|%d",
                tostring(self._lastPredictionTriggerSource or "unknown"),
                math.floor((pendingFor * 100) + 0.5)
            )
            local lastKey = self._lastPendingSkipDebugKey
            local lastAt = tonumber(self._lastPendingSkipDebugAt or 0) or 0
            if lastKey ~= pendingDbgKey or (now - lastAt) >= throttleSeconds then
                self._lastPendingSkipDebugKey = pendingDbgKey
                self._lastPendingSkipDebugAt = now
                RetSMDebugPrint(string.format(
                    "|cff00ffffRetSM MonitorSkip|r reason=pending_delayed_compute pendingFor=%.3f lastTrigger=%s age=%.3f",
                    pendingFor,
                    tostring(self._lastPredictionTriggerSource or "unknown"),
                    max(0, now - (tonumber(self._lastPredictionTime or 0) or 0))
                ))
            end
        end
        return
    end

    local prediction = self._lastPrediction
    if not prediction or prediction.ok ~= true then
        self:ComputePrediction("monitor_initial")
        return
    end

    local now = GetTime()
    local lastComputeAt = tonumber(self._lastPredictionTime or 0) or 0

    -- Throttled path: recompute if 3s since last compute.
    if (now - lastComputeAt) >= THROTTLED_COMPUTE_INTERVAL_SECONDS then
        self:ComputePrediction("monitor_throttled")
    end
end

--- CD mismatch heartbeat: runs every 500ms; triggers compute when cs or judge CD mismatch detected.
function SM:MonitorCDMismatchHeartbeat()
    if not self.db or not self.db.class.enabled then
        return
    end
    if self:IsDelayedPredictionPending() then
        return
    end
    local prediction = self._lastPrediction
    if not prediction or prediction.ok ~= true then
        return
    end
    local mismatchReason = self:GetCDMismatchReason(prediction)
    if mismatchReason == "cs_cd_mismatch" or mismatchReason == "judge_cd_mismatch" then
        self:ComputePrediction(mismatchReason)
    end
end

--- Start the repeating monitors: main at 100ms, CD mismatch heartbeat at 500ms.
function SM:StartMonitorTimer()
    self:StopMonitorTimer()
    self._monitorTimerHandle = self:ScheduleRepeatingTimer(function()
        self:MonitorExternalChanges()
    end, MONITOR_INTERVAL_SECONDS)
    self._cdMismatchHeartbeatHandle = self:ScheduleRepeatingTimer(function()
        self:MonitorCDMismatchHeartbeat()
    end, CD_MISMATCH_HEARTBEAT_INTERVAL_SECONDS)
end

--- Stop the repeating monitors and any delayed spell-sent recompute.
function SM:StopMonitorTimer()
    if self._monitorTimerHandle then
        self:CancelTimer(self._monitorTimerHandle)
        self._monitorTimerHandle = nil
    end
    if self._cdMismatchHeartbeatHandle then
        self:CancelTimer(self._cdMismatchHeartbeatHandle)
        self._cdMismatchHeartbeatHandle = nil
    end
    if self._delayedComputeTimerHandle then
        self:CancelTimer(self._delayedComputeTimerHandle)
        self._delayedComputeTimerHandle = nil
    end
    self._delayedPredictionAt = 0
end

--- Return the latest cached prediction.
--- If no prediction is available yet, compute one on-demand.
--- @param horizonSeconds number|nil
--- @return table|nil result
function SM:GetCachedPrediction(horizonSeconds)
    if self._lastPrediction then
        return self._lastPrediction
    end
    -- Bar/APL polls for display; do NOT trigger compute. Only event-driven triggers compute.
    return nil
end

-- ============================ NAG API (for APL comparison) ============================

--- Get the state machine's recommended action for the current swing cycle.
--- Returns action string and reason. Does NOT override APL — purely informational.
--- @return string action
--- @return string reason
--- @return boolean holdFlag
--- @return boolean fillerFlag
function NAG:RetSMCurrentAction()
    local sm = ns.PaladinRetStateMachine
    if not sm or not sm.db or not sm.db.class.enabled then
        return ACTION_NONE, "disabled", false, false
    end

    local state0 = GetCachedState0(sm)
    if not state0 then
        return ACTION_NONE, "no_prediction", false, false
    end

    return state0.action, state0.reason, state0.holdFlag, state0.fillerFlag
end

--- Get the state machine's primary committed next action and when it should occur.
--- Ignores optional filler recommendations and returns only the main planned action.
--- @return string action
--- @return number holdSeconds Seconds until the action should happen (0 = now)
function NAG:RetStatemachine()
    local sm = ns.PaladinRetStateMachine
    local state0, result = GetCachedState0(sm)
    if not state0 or not result then
        return ACTION_NONE, 0
    end

    local now = GetTime()
    local action, holdSeconds = GetActionAndHoldFromState0(state0, now)

    if IsRetSMDebugEnabled(sm) then
        local throttleSeconds = tonumber(sm.db.class.debugThrottleSeconds or 0.25) or 0.25
        if throttleSeconds < 0 then
            throttleSeconds = 0
        end
        local predictionAge = max(0, now - (tonumber(sm._lastPredictionTime or 0) or 0))
        local pending = sm:IsDelayedPredictionPending()
        local dbgKey = table.concat({
            tostring(action),
            tostring(state0.reason or ""),
            tostring(state0.holdFlag == true),
            tostring(math.floor((holdSeconds * 100) + 0.5)),
            tostring(pending),
            tostring(sm._lastPredictionTriggerSource or "unknown")
        }, "|")
        local lastKey = sm._lastAPIAccessDebugKey
        local lastAt = tonumber(sm._lastAPIAccessDebugAt or 0) or 0
        if lastKey ~= dbgKey or (now - lastAt) >= throttleSeconds then
            sm._lastAPIAccessDebugKey = dbgKey
            sm._lastAPIAccessDebugAt = now
            RetSMDebugPrint(string.format(
                "|cff00ffffRetSM Access|r action=%s hold=%.3f reason=%s trigger=%s pending=%s age=%.3f gcd=%.3f swing=%.3f",
                tostring(action),
                holdSeconds,
                tostring(state0.reason or "?"),
                tostring(sm._lastPredictionTriggerSource or "unknown"),
                tostring(pending),
                predictionAge,
                (result.snap and result.snap.gcdLeft) or 0,
                (result.snap and result.snap.timeToNextSwing) or 0
            ))
        end
    end

    return action, holdSeconds
end

--- Build the next-N state-machine queue with wait timing metadata.
--- Queue is chronological and includes state0 + predicted future moments.
--- @param maxSteps number|nil
--- @return table queue
--- @return table|nil result
function NAG:RetStatemachineQueue(maxSteps)
    local sm = ns.PaladinRetStateMachine
    if not sm or not sm.db or not sm.db.class.enabled then
        return {}, nil
    end

    local horizonSeconds = tonumber(sm.db.class.horizonSeconds) or DEFAULT_HORIZON_SECONDS
    if horizonSeconds <= 0 then
        horizonSeconds = DEFAULT_HORIZON_SECONDS
    end

    local result = sm:GetCachedPrediction(horizonSeconds)
    if not result or result.ok ~= true then
        return {}, result
    end

    local now = GetTime()
    local moments = CollectChronologicalActionMoments(result, now, horizonSeconds, BRIDGE_MAX_STATES)
    local _ = maxSteps
    -- Allow up to 2 moments: primary + optional filler (filler shown as side icon).
    local limit = (#moments > 0) and min(#moments, 2) or 0

    local queue = {}
    local previousAt = now
    for i = 1, limit do
        local e = moments[i]
        local waitFromNow = max(0, (tonumber(e.at or now) or now) - now)
        local waitFromPrev = max(0, (tonumber(e.at or now) or now) - previousAt)
        local item = {
            queueSlot = i,
            at = tonumber(e.at or 0) or 0,
            spellId = tonumber(e.spellId or 0) or 0,
            actionKey = tostring(e.actionKey or ACTION_NONE),
            stateIndex = tonumber(e.stateIndex or 0) or 0,
            waitFromNow = waitFromNow,
            waitFromPrev = waitFromPrev,
            position = ns.SPELL_POSITIONS.PRIMARY,
            overlayText = BuildQueueOverlayText(waitFromNow),
        }
        item.position = ResolveBridgeQueuePosition(item, queue[i - 1])
        queue[#queue + 1] = item
        previousAt = item.at
    end

    return queue, result
end

--- Shared collector for bars/debug consumers so bridge and bar stay aligned.
--- @param result table|nil
--- @param now number|nil
--- @param horizonSeconds number|nil
--- @param maxStates number|nil
--- @return table
function NAG:RetSMCollectActionMoments(result, now, horizonSeconds, maxStates)
    local nowTs = tonumber(now) or GetTime()
    local horizon = tonumber(horizonSeconds)
    if not horizon or horizon <= 0 then
        horizon = DEFAULT_HORIZON_SECONDS
    end
    return CollectChronologicalActionMoments(result, nowTs, horizon, maxStates or BRIDGE_MAX_STATES)
end

--- Return deterministic current + next-next entries for TwistBar rendering.
--- Read-only/advisory API; does not affect bridge primary execution.
--- @param horizonSeconds number|nil
--- @return table|nil payload
function NAG:RetSMGetTwistBarPrediction(horizonSeconds)
    local sm = ns.PaladinRetStateMachine
    if not sm or not sm.db or not sm.db.class.enabled then
        return nil
    end

    local horizon = tonumber(horizonSeconds) or tonumber(sm.db.class.horizonSeconds) or DEFAULT_HORIZON_SECONDS
    if horizon <= 0 then
        horizon = DEFAULT_HORIZON_SECONDS
    end

    local result = sm:GetCachedPrediction(horizon)
    if not result or result.ok ~= true then
        return nil
    end
    -- Twist bar needs state1 for next-next icons; ensure we have it.
    if not (result.states and result.states[1]) and sm.PredictLive then
        -- State1 is the next swing; it may be beyond the default horizon when S0 is CS.
        -- Extend horizon so the next swing fits: timeToNextSwing + attackSpeed + buffer.
        local snap = result.snap
        if snap and snap.attackSpeed and snap.attackSpeed > 0 then
            local timeToNext = snap.timeToNextSwing or (snap.swingExpiration and snap.now and (snap.swingExpiration - snap.now)) or snap.attackSpeed
            local minHorizonForState1 = timeToNext + snap.attackSpeed + 0.5
            if minHorizonForState1 > horizon then
                horizon = minHorizonForState1
            end
        end
        result = sm:PredictLive(horizon, true)
        if not result or result.ok ~= true then
            return nil
        end
    end

    local now = GetTime()
    local state0 = result.state0 or nil
    local state1 = result.states and result.states[1] or nil

    local function BuildEntry(state, stateIndex, actionKey, spellId, at)
        local sid = tonumber(spellId or 0) or 0
        local ts = tonumber(at or 0) or 0
        if sid <= 0 or ts <= 0 then
            return nil
        end
        local wait = ts - now
        if wait < 0 then
            wait = 0
        end
        return {
            stateIndex = tonumber(stateIndex) or 0,
            actionKey = tostring(actionKey or ACTION_NONE),
            spellId = sid,
            at = ts,
            waitFromNow = wait,
            holdFlag = state and (state.holdFlag == true) or false,
            reason = state and tostring(state.reason or "") or "",
        }
    end

    local payload = {
        now = now,
        current = state0 and BuildEntry(state0, 0, state0.action, state0.actionSpellId, state0.actionAt) or nil,
        nextNext = state1 and BuildEntry(state1, 1, state1.action, state1.actionSpellId, state1.actionAt) or nil,
        nextNextFiller = nil,
        nextNextSocFollow = nil,
    }

    if state1 and state1.fillerFlag and state1.fillerAction and state1.fillerSpellId and state1.fillerAt then
        payload.nextNextFiller = BuildEntry(state1, 1, state1.fillerAction, state1.fillerSpellId, state1.fillerAt)
    end
    if state1 and state1.action == ACTION_JUDGE_SOC and state1.socFollowUpSpellId and state1.actionAt then
        payload.nextNextSocFollow = BuildEntry(state1, 1, "soc_followup", state1.socFollowUpSpellId, state1.actionAt)
    end

    return payload
end

--- Print the current state machine decision when the APL bridge consumes it.
--- Uses the existing SM debug format so APL-vs-SM monitoring stays consistent.
--- @param sourceTag string|nil
--- @return boolean
function NAG:RetStatemachineDebugDecision(sourceTag)
    local sm = ns.PaladinRetStateMachine
    if not sm or not sm.db or not sm.db.class.enabled or not IsRetSMDebugEnabled(sm) then
        return true
    end

    local state0, result = GetCachedState0(sm)
    if not state0 or not result then
        return true
    end

    local now = GetTime()
    local throttleSeconds = tonumber(sm.db.class.debugThrottleSeconds or 0.25) or 0.25
    if throttleSeconds < 0 then
        throttleSeconds = 0
    end

    local actionAt = tonumber(state0.actionAt or 0) or 0
    local dbgKey = table.concat({
        tostring(sourceTag or "apl"),
        tostring(state0.action or ACTION_NONE),
        tostring(state0.reason or ""),
        tostring(state0.holdFlag == true),
        tostring(math.floor((actionAt * 100) + 0.5))
    }, "|")

    local lastKey = sm._lastAPLBridgeDebugKey
    local lastAt = tonumber(sm._lastAPLBridgeDebugAt or 0) or 0
    if lastKey == dbgKey and (now - lastAt) < throttleSeconds then
        return true
    end

    sm._lastAPLBridgeDebugKey = dbgKey
    sm._lastAPLBridgeDebugAt = now

    RetSMDebugPrint(string.format("|cff00ffffRetSM APL|r source=%s", tostring(sourceTag or "apl")))
    RetSMDebugPrint("  " .. FormatStateDebugLine("S0", state0, now))
    RetSMDebugPrintLines(FormatState0DetailedReason(state0, result.snap, now))
    return true
end

--- Execute the Ret state machine APL bridge with one cached state0 lookup.
--- Mirrors the old Paladin.lua bridge behavior while avoiding repeated
--- `RetStatemachine()` wrapper calls inside a single APL evaluation.
--- @return boolean
function NAG:RetStatemachineAPLBridge()
    local function rememberBridgePrimary(primaryEntry, actionKey, holdSeconds)
        if not primaryEntry then
            return true
        end
        local spellId = tonumber(primaryEntry.spellId or 0) or 0
        if spellId <= 0 then
            return true
        end
        self._retSMBridgeLastPrimary = {
            spellId = spellId,
            actionKey = tostring(actionKey or primaryEntry.actionKey or ACTION_NONE),
            holdSeconds = tonumber(holdSeconds or 0) or 0,
            updatedAt = GetTime(),
        }
        return true
    end

    local function fallbackToPreviousPrimary(reasonTag)
        local cached = self._retSMBridgeLastPrimary
        if not cached or not cached.spellId then
            return false
        end
        local normalizedPrimary = self:NormalizePrimaryAction(cached.spellId, {
            context = "ret_sm_bridge_fallback",
        })
        if not normalizedPrimary then
            return false
        end
        self.nextSpell = normalizedPrimary
        if IsRetSMDebugEnabled(ns.PaladinRetStateMachine) then
            RetSMDebugPrint(string.format(
                "|cff00ffffRetSM BridgeFallback|r reason=%s spell=%s action=%s age=%.3f",
                tostring(reasonTag or "unknown"),
                tostring(cached.spellId),
                tostring(cached.actionKey or ACTION_NONE),
                max(0, GetTime() - (tonumber(cached.updatedAt or 0) or 0))
            ))
        end
        return true
    end

    local function commitOrFallback(ok, primaryEntry, actionKey, holdSeconds, reasonTag)
        if ok then
            rememberBridgePrimary(primaryEntry, actionKey, holdSeconds)
            return true
        end
        return fallbackToPreviousPrimary(reasonTag)
    end

    local queue, result = NAG:RetStatemachineQueue(BRIDGE_MAX_QUEUE_STEPS)
    if not queue or #queue == 0 then
        return fallbackToPreviousPrimary("queue_empty")
    end

    local primaryIndex = 1
    -- Keep state0 authoritative for bridge primary execution.
    -- Prefer non-filler state0 moments first; if none, fall back to existing behavior.
    for i = 1, #queue do
        local candidate = queue[i]
        if candidate and (tonumber(candidate.stateIndex or -1) == 0)
            and candidate.actionKey ~= ACTION_FILLER_CON
            and candidate.actionKey ~= ACTION_FILLER_EXO
        then
            primaryIndex = i
            break
        end
    end
    if queue[primaryIndex] and (queue[primaryIndex].actionKey == ACTION_FILLER_CON or queue[primaryIndex].actionKey == ACTION_FILLER_EXO) then
        for i = 1, #queue do
            local candidate = queue[i]
            if candidate and candidate.actionKey ~= ACTION_FILLER_CON and candidate.actionKey ~= ACTION_FILLER_EXO then
                primaryIndex = i
                break
            end
        end
    end

    local primary = queue[primaryIndex] or queue[1]
    local primaryStateIndex = tonumber(primary and primary.stateIndex or 0) or 0

    for i = 1, #queue do
        if i ~= primaryIndex then
        local queued = queue[i]
        if queued and queued.spellId and queued.spellId > 0 then
            local queuedStateIndex = tonumber(queued.stateIndex or -1) or -1
            local isFiller = queued.actionKey == ACTION_FILLER_CON or queued.actionKey == ACTION_FILLER_EXO
            local allowSecondary = isFiller and (queuedStateIndex == primaryStateIndex)
            if allowSecondary then
                local overlayText = queued.overlayText
                if isFiller then
                    overlayText = "FILLER"
                end
                local normalizedSecondary = NAG:NormalizeSecondaryAction({
                    spellId = queued.spellId,
                    queueSlot = i,
                    overlayText = overlayText,
                }, queued.position, {
                    context = "ret_sm_queue_secondary",
                })
                if normalizedSecondary then
                    local replaced = false
                    for sidx = 1, #NAG.secondarySpells do
                        local existing = NAG:NormalizeSecondarySpellEntry(NAG.secondarySpells[sidx])
                        if existing and existing.spellId == normalizedSecondary.spellId
                            and (tonumber(existing.queueSlot) or 0) == (tonumber(normalizedSecondary.queueSlot) or 0)
                        then
                            NAG.secondarySpells[sidx] = normalizedSecondary
                            replaced = true
                            break
                        end
                    end
                    if not replaced then
                        NAG.secondarySpells[#NAG.secondarySpells + 1] = normalizedSecondary
                    end
                end
            end
        end
        end
    end

    primary = queue[primaryIndex] or queue[1]
    local action = tostring(primary.actionKey or ACTION_NONE)
    local holdSeconds = tonumber(primary.waitFromNow or 0) or 0
    local shouldHold = holdSeconds > 0.05
    local state0 = result and result.state0 or nil

    -- Next-action-only mode: do not inject derived judge secondary recommendations.

    local displayTolerance = shouldHold and RET_SM_HOLD_DISPLAY_TOLERANCE or holdSeconds

    if action == ACTION_CS then
        local ok = NAG:CastSpell(SPELL_CS, displayTolerance, nil, nil, nil)
            and (NAG:RetStatemachineDebugDecision("apl_cs") or true)
        return commitOrFallback(ok, primary, action, holdSeconds, "apl_cs_failed")
    end

    if action == ACTION_TWIST or action == ACTION_HOLD then
        -- HOLD overlay only when actually waiting (holdSeconds > 0.05); never bare "HOLD".
        local overlay = (holdSeconds and holdSeconds > 0.05) and string.format("HOLD\n%.1fs", holdSeconds) or nil
        local ok = NAG:CastSpell(NAG:RetTwistGetTwistSealId(), displayTolerance, nil, nil, overlay)
            and (NAG:RetStatemachineDebugDecision("apl_twist") or true)
        return commitOrFallback(ok, primary, action, holdSeconds, "apl_twist_failed")
    end

    if action == ACTION_SOC or action == "soc_followup" then
        local ok = (
            (shouldHold and NAG:RetTwistSoCHoldForSeconds(holdSeconds))
            or ((not shouldHold) and NAG:Cast(NAG:RetTwistGetSoCSealId()))
        ) and (NAG:RetStatemachineDebugDecision("apl_soc") or true)
        return commitOrFallback(ok, primary, action, holdSeconds, "apl_soc_failed")
    end

    if action == ACTION_JUDGE_SOC then
        local ok = (
            (shouldHold and NAG:RetTwistJudgeHold(holdSeconds))
            or ((not shouldHold) and NAG:CastPlaceHolder(SPELL_JUDGEMENT, nil, nil, nil, "Judge\n+\nSoC"))
        )
            and (NAG:Cast(NAG:RetTwistGetSoCSealId(), shouldHold and displayTolerance or nil, NAG.SPELL_POSITIONS.AOE) or true)
            and (NAG:RetStatemachineDebugDecision("apl_judge_soc") or true)
        return commitOrFallback(ok, primary, action, holdSeconds, "apl_judge_soc_failed")
    end

    if action == "judge" then
        local ok = NAG:CastSpell(SPELL_JUDGEMENT, displayTolerance, nil, nil, nil)
            and (NAG:RetStatemachineDebugDecision("apl_judge") or true)
        return commitOrFallback(ok, primary, action, holdSeconds, "apl_judge_failed")
    end

    if action == ACTION_FILLER_CON or action == ACTION_FILLER_EXO then
        local fillerSpellId = tonumber(primary.spellId or 0) or 0
        if fillerSpellId > 0 then
            local ok = NAG:CastSpell(fillerSpellId, displayTolerance, nil, nil, nil)
                and (NAG:RetStatemachineDebugDecision("apl_filler") or true)
            return commitOrFallback(ok, primary, action, holdSeconds, "apl_filler_failed")
        end
    end

    return fallbackToPreviousPrimary("action_unhandled")
end

--- Get the state machine's full prediction (state0 + future states).
--- Uses event-driven cached prediction to avoid redundant recomputes.
--- @param horizonSeconds number|nil
--- @return table|nil result
function NAG:RetSMPredict(horizonSeconds)
    local sm = ns.PaladinRetStateMachine
    if not sm or not sm.db or not sm.db.class.enabled then
        return nil
    end
    return sm:PredictLive(horizonSeconds, true)
end

--- Get the current state machine prediction region for comparison.
--- @return string region REGION_* constant
function NAG:RetSMCurrentRegion()
    local sm = ns.PaladinRetStateMachine
    local state0 = GetCachedState0(sm)
    if not state0 then
        return REGION_SWING_READY
    end

    return state0.region or REGION_SWING_READY
end

-- ============================ RECOMPUTE TRIGGERS ============================

--- Invalidate the cached prediction, forcing a fresh compute on next access.
--- This is the central recompute trigger — called by all event handlers that
--- change timing-relevant state (swing, seal, GCD, cooldown).
function SM:InvalidatePrediction()
    self._lastPrediction = nil
    self._lastPredictionTime = 0
end

-- ============================ EVENT HANDLERS ============================

function SM:OnCombatStateChanged(event)
    self:InitializeState()
    if event == "PLAYER_REGEN_DISABLED" then
        self.state.inCombat = true
        self.state.swingCount = 0
    else
        self.state.inCombat = false
        self.state.swingCount = 0
        -- Clear tracked cast times so stale CDs from this fight don't pollute the next
        self.state.lastCSCastTime = 0
        self.state.lastJudgeCastTime = 0
    end
    self:InvalidatePrediction()
end

--- CLEU swing event — new swing cycle started.
--- Also detects parry-haste (`SWING_MISSED` with missType `PARRY`) and
--- recomputes immediately so the shortened swing is reflected without delay.
function SM:HandleSwing(timestamp, subEvent, hideCaster, sourceGUID, sourceName,
    sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, missType)
    if sourceGUID ~= (NAG.state and NAG.state.player and NAG.state.player.guid) then
        return
    end
    self:InitializeState()
    self.state.swingCount = (self.state.swingCount or 0) + 1
    self.state.lastSwingTime = GetTime()

    local isParryHaste = (subEvent == "SWING_MISSED") and (tostring(missType or "") == "PARRY")
    if isParryHaste then
        self:ComputePrediction("parry_haste_cleu")
        return
    end

    self:InvalidatePrediction()
end

--- CLEU spell cast success — seal/CS/judge cast confirmed, CDs changed.
--- Tracks exact cast times for CS and Judgement so the snapshot can use
--- CLEU-verified CD expiry instead of potentially stale GetSpellCooldown values.
function SM:HandleSpellCast(timestamp, subEvent, hideCaster, sourceGUID, sourceName,
    sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId)
    if sourceGUID ~= (NAG.state and NAG.state.player and NAG.state.player.guid) then
        return
    end
    self:InitializeState()
    local now = GetTime()

    if spellId == SPELL_CS then
        self.state.lastCSCastTime = now
    elseif spellId == SPELL_JUDGEMENT then
        self.state.lastJudgeCastTime = now
    end

    -- Any GCD-triggering spell updates timing: seals, CS, Judge, Exo, Cons
    -- Seal casts are detected via the constants lookup sets
    local constants = ns.PaladinTwistConstants
    local isSealCast = (constants and (
        (constants.SOC_CAST_IDS and constants.SOC_CAST_IDS[spellId]) or
        (constants.TWIST_CAST_IDS and constants.TWIST_CAST_IDS[spellId])
    )) or false

    -- Judgement is OFF the GCD — it does not trigger GCD or update GCD timing.
    local isGCDSpell = isSealCast
        or spellId == SPELL_CS
        or spellId == SPELL_EXORCISM
        or spellId == SPELL_CONS
        or spellId == SPELL_SEAL_WISDOM

    if isGCDSpell then
        self.state.lastSpellCastTime = now
        self.state.lastGCDDuration = NAG:GCDTimeValue() or 1.5
    end

    -- Recompute after cast success: CS, Judge, seals, Exo, Cons — game state is now authoritative.
    if spellId == SPELL_CS or spellId == SPELL_JUDGEMENT or isSealCast
        or spellId == SPELL_EXORCISM or spellId == SPELL_CONS or spellId == SPELL_SEAL_WISDOM then
        self:InvalidatePrediction()
        self:ScheduleDelayedPredictionCompute("spell_cast_success")
    end
end

--- UNIT_AURA — seal buff applied or removed.
--- The active seal is the most critical input to the decision function.
--- Invalidate immediately so the next frame picks up the new seal state.
function SM:OnUnitAura(event, unit)
    if unit ~= "player" then return end
    if self:IsDelayedPredictionPending() then
        return
    end
    self:InvalidatePrediction()
end

--- PLAYER_TARGET_CHANGED — immediate recompute for new target context.
function SM:OnTargetChanged()
    if self:IsDelayedPredictionPending() then
        return
    end
    self:InvalidatePrediction()
end

--- UNIT_ATTACK_SPEED — immediate recompute when the game reports speed changes.
function SM:OnAttackSpeedChanged(event, unit)
    if unit ~= "player" then
        return
    end
    if self:IsDelayedPredictionPending() then
        return
    end
    self:InvalidatePrediction()
end

--- SPELL_UPDATE_COOLDOWN — CS or Judge came off cooldown.
--- In lazy mode we just mark prediction dirty so the next bridge access
--- rebuilds from fresh cooldown state.
function SM:OnCooldownUpdate()
    self:InitializeState()
    self.state.cooldownDirty = true
    self:InvalidatePrediction()
end

-- ============================ LIFECYCLE ============================

function SM:ModuleEnable()
    self:StartMonitorTimer()
    self:InvalidatePrediction()
    self._delayedPredictionAt = 0
end

function SM:ModuleDisable()
    self:StopMonitorTimer()
    self._lastPrediction = nil
    self._lastPredictionTime = 0
end

-- ============================ SLASH COMMANDS ============================

function SM:retsm(_)
    local dev = NAG and NAG.IsDevModeEnabled and NAG:IsDevModeEnabled()
    self:Print(string.format(
        "Ret SM chat diagnostics: |cffffcc00Dev Mode|r=%s (compute/timeline prints use Dev Mode only; see /retsmpredict).",
        dev and "ON" or "OFF"
    ))
end

function SM:retsmpredict()
    local result = self:PredictLive(nil, true)
    if not result or not result.ok then
        self:Print("RetSM: no valid prediction (check swing timer / class)")
        return
    end

    local now = GetTime()
    local snap = result.snap

    self:Print("|cff00ffffRetSM Timeline|r (" .. tostring(1 + #(result.states or {})) .. " decisions)")
    self:Print("CHAIN: " .. BuildActionTimeChainString(result, now, self.db.class.horizonSeconds, 8))

    -- State0 with full detail
    self:Print(FormatStateDebugLine("S0", result.state0, now))
    self:Print(FormatState0DetailedReason(result.state0, snap, now))

    -- Future states (up to 5 more = 6 total)
    local maxShow = 5
    for i, s in ipairs(result.states) do
        if i > maxShow then break end
        self:Print(FormatStateDebugLine("S" .. i, s, now))
    end
end

-- ============================ OPTIONS ============================

function SM:GetOptions()
    local OptionsFactory = NAG:GetModule("OptionsFactory", true)
    if not OptionsFactory then return nil end

    return {
        type = "group",
        name = "Ret State Machine",
        order = 28,
        args = {
            description = {
                type = "description",
                name = "|cffaaaaaa(Experimental) State machine prediction for Ret seal twisting. Currently runs alongside the APL for comparison — does not override spell recommendations.|r",
                order = 0,
            },
            enabled = OptionsFactory:CreateToggle(
                "Enable State Machine",
                "Enable the Ret state machine predictor (runs alongside APL for comparison).",
                function() return self:GetSetting("class", "enabled") end,
                function(_, value) self:SetSetting("class", "enabled", value) end,
                { order = 1 }
            ),
            debugEnabled = OptionsFactory:CreateToggle(
                "Legacy: debug toggle (unused)",
                "Chat diagnostics for the state machine use |cffffcc00Dev Mode|r only. This saved toggle is kept for compatibility and does not gate prints.",
                function() return self:GetSetting("class", "debugEnabled") end,
                function(_, value) self:SetSetting("class", "debugEnabled", value) end,
                { order = 2 }
            ),
            reactionTimeMs = OptionsFactory:CreateRange(
                "Reaction Time (ms)",
                "Human reaction time compensation. Lower = more aggressive timing.",
                function() return self:GetSetting("class", "reactionTimeMs") end,
                function(_, value) self:SetSetting("class", "reactionTimeMs", value) end,
                { order = 3, min = 0, max = 300, step = 10 }
            ),
            csMaxDelayMs = OptionsFactory:CreateRange(
                "Max CS Delay (ms)",
                "Maximum time CS can be delayed by twist planning before forcing CS.",
                function() return self:GetSetting("class", "csMaxDelayMs") end,
                function(_, value) self:SetSetting("class", "csMaxDelayMs", value) end,
                { order = 4, min = 0, max = 2000, step = 50 }
            ),
        },
    }
end
