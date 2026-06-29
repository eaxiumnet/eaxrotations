-- hunter_adaptive_sylvanas.lua -- Hunter Adaptive DPS Rotation (wowsims port).
-- WHAT:   Hunter Adaptive DPS Rotation (wowsims port).
-- WHEN:   called per-frame by Marks/BM/Survival when use_adaptive_rotation=true
-- WHY:    replaces threshold-based shot selection with DPS-math-optimal choices
-- SAFETY: lazy recompute on aura/equip delta; no on_update allocs
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- Hunter Adaptive DPS Rotation (ported from Flux AIO)
-- Direct port of the wowsims TBC adaptive rotation:
--    https://github.com/wowsims/tbc/blob/main/sim/hunter/rotation.go (lines 139-280)
--
-- Each tick we compute expected damage of every option (shoot vs steady vs
-- multi vs arcane), subtracting the DPS lost by delaying the others. Pick
-- max. No threshold gates, no special burst-mode branches -- the math
-- rebalances naturally as ranged swing speed changes.
--
-- The expensive recompute (stats -> avg damages -> DPS rates -> cast times)
-- only runs when an aura we care about applies/refreshes/expires, or when
-- the soonest tracked aura is about to drop. Per-tick decision is ~20
-- floating-point ops.
--
-- Public API:
--    NS.HunterAdaptive.ChooseAction(unit) -> "shoot"|"steady"|"multi"|"arcane"|"none"
--    NS.HunterAdaptive.SetDebug(enabled)
--    NS.HunterAdaptive.GetState()
--    NS.HunterAdaptive.Recompute()  -- force dirty
--    NS.HunterAdaptive.ForceRecompute()  -- immediate recompute
--    NS.HunterAdaptive.GetAuraDebug()
--    NS.HunterAdaptive.ClearDecisionLog()
--    NS.HunterAdaptive.GetDecisionCSV()
--    NS.HunterAdaptive.RecordFire(spellName)

local NS = _G.EaxRotations
if not NS then return nil end
local core = require("api/core")
local SPELLS = NS.HunterSpells or {}
if not SPELLS.MultiShot then
    NS.log_warning("[HunterAdaptive] NS.HunterSpells not found - hunter class not loaded")
    return nil
end

local _G, math = _G, math
local math_max, math_huge = math.max, math.huge
local floor = math.floor

local function safe_call(name, fallback, nreturns)
    nreturns = nreturns or 1
    local function fallback_args(...)
        if type(fallback) == "function" then
            return fallback(...)
        end
        local r = fallback
        local out = { r }
        for _ = 2, nreturns do out[#out + 1] = nil end
        return unpack(out)
    end
    local fn = _G[name]
    if type(fn) ~= "function" then
        return function(...) return fallback_args(...) end
    end
    return function(...)
        local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 =
            pcall(fn, ...)
        if not ok then return fallback_args(...) end
        local out = { r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 }
        for _ = #out + 1, nreturns do out[#out + 1] = nil end
        return unpack(out)
    end
end

local UnitRangedAttackPower = safe_call("UnitRangedAttackPower",
    function() return 0, 0, 0 end, 3)
local UnitRangedDamage     = safe_call("UnitRangedDamage",
    function() return 2.8, 0, 0, 0, 0, 1 end, 6)
local GetRangedCritChance  = safe_call("GetRangedCritChance",
    function() return 0 end, 1)
local UnitBuff             = safe_call("UnitBuff",
    function(unit, i) return nil end, 11)
local UnitGUID             = safe_call("UnitGUID",
    function() return "" end, 1)
local GetTime              = safe_call("GetTime",
    function() return os and os.clock() or 0 end, 1)
local GetCVar              = safe_call("GetCVar",
    function() return "" end, 1)
local CombatLogGetCurrentEventInfo = safe_call("CombatLogGetCurrentEventInfo",
    function() end, 20)
local GetTalentInfo        = safe_call("GetTalentInfo",
    function() return nil, nil, nil, nil, 0, nil end, 6)

local date = os.date
local time = os.time

-- Sylvanas API bindings
local SwingTimer = NS.SwingTimer or {}
local get_ranged_time_until = SwingTimer.get_ranged_time_until or function() return 0 end

local TRACKED_FIRES = {
    ["Steady Shot"] = true, ["Multi-Shot"] = true, ["Arcane Shot"] = true,
    ["Kill Command"] = true, ["Serpent Sting"] = true, ["Scorpid Sting"] = true,
    ["Viper Sting"] = true,
}

local RANGED_SWING_RESET_SPELLS = {
    [75]    = true, -- Auto Shot
    [2480]  = true, -- Shoot Bow
    [7919]  = true, -- Shoot Crossbow
    [7918]  = true, -- Shoot Gun
    [2764]  = true, -- Throw
    [3018]  = true, -- Shoot
    [5019]  = true, -- Shoot/Wand
    [5384]  = true, -- Feign Death
    [19434] = true, -- Aimed Shot rank 1
    [20900] = true, -- Aimed Shot rank 2
    [20901] = true, -- Aimed Shot rank 3
    [20902] = true, -- Aimed Shot rank 4
    [20903] = true, -- Aimed Shot rank 5
    [20904] = true, -- Aimed Shot rank 6
    [27065] = true, -- Aimed Shot rank 7
}

-- ============================================================================
-- ENUM
-- ============================================================================
local OPT_SHOOT  = "shoot"
local OPT_STEADY = "steady"
local OPT_MULTI  = "multi"
local OPT_ARCANE = "arcane"
local OPT_NONE   = "none"

-- ============================================================================
-- TRACKED AURAS
-- Auras whose application/expiration changes our damage or speed math.
-- value = duration estimate (seconds). Used to schedule next recompute when
-- we don't get a clean removebuff event. Set to 0 if we shouldn't auto-expire.
-- ============================================================================
local TRACKED_AURAS = {
    -- Ranged speed multipliers
    [3045]   = 15,    -- Rapid Fire (+40% ranged speed)
    [2825]   = 40,    -- Bloodlust (+30% all speed)
    [32182]  = 40,    -- Heroism
    [6150]   = 12,    -- Quick Shots / Imp Aspect of the Hawk proc
    [27066]  =  0,    -- Aspect of the Hawk (highest TBC rank, +RAP)
    [27044]  =  0,    -- Aspect of the Hawk (alt rank ID)
    [13165]  =  0,    -- Aspect of the Hawk (rank 1)

    -- Haste rating sources
    [33807]  = 10,    -- Abacus of Violent Odds
    [28507]  = 15,    -- Haste Potion
    [35476]  = 30,    -- Drums of Battle
    [28498]  = 15,    -- Drum of Battle alt
    [33687]  = 15,    -- Bloodlust trinket / haste trinket alt

    -- Damage multipliers
    [34471]  = 18,    -- The Beast Within (BW active, +10% damage)
    [34456]  = 10,    -- Ferocious Inspiration (pet buff, +3% damage)
    [33667]  = 15,    -- Ferocity trinket buff
    [20572]  = 15,    -- Blood Fury
    [26297]  = 10,    -- Berserking
    [28880]  = 30,    -- Gift of the Naaru

    -- AP / Crit raid buffs
    [27141]  =  0,    -- Greater Blessing of Might
    [25898]  =  0,    -- Greater Blessing of Kings
    [30809]  =  0,    -- Unleashed Rage
    [19506]  =  0,    -- Trueshot Aura
    [24932]  =  0,    -- Leader of the Pack
    [37182]  =  0,    -- Improved Hunter's Mark

    [34477]  =  8,    -- Misdirection
}

-- ============================================================================
-- STATE CACHE
-- ============================================================================
local State = {
    -- Raw stats (refreshed by readStats)
    rap            = 0,
    rangedSpeed    = 2.8,
    weaponBaseSpd  = 2.8,
    hasteMult      = 1.0,
    weaponDmgAvg   = 0,
    rangedDmgAvg   = 0,
    rangedDmgBonus = 0,
    rangedDmgPercent = 1,
    rangedDmgIncludesAP = false,
    critPct        = 0,

    -- Average damage per cast
    avgShootDmg    = 0,
    avgSteadyDmg   = 0,
    avgMultiDmg    = 0,
    avgArcaneDmg   = 0,

    -- DPS rates
    shootDPS       = 0,
    steadyDPS      = 0,

    -- Cast times (seconds)
    steadyCastTime = 1.5,
    multiCastTime  = 0.5,
    arcaneCastTime = 0,

    -- Auto-shot ranged windup
    rangedWindup   = 0.5,

    -- Crit multiplier (recomputed from Mortal Shots talent rank in readStats)
    critMultiplier = 2.0,

    -- Bookkeeping
    dirty          = true,
    nextRecomputeAt = 0,
    lastRecomputeAt = 0,
    debug          = false,

    useMultiForCatchup = false,
    lastChooseAt = 0,
    lastShootDoneAt = 0,
    zeroShootSince = 0,
    inhouseShoot = {
        known = false,
        state = "unknown",
        lastSwingAt = 0,
        lastSuccessAt = 0,
        duration = 0,
        nextDoneAt = 0,
        lastSpeed = 0,
        lastSource = "",
    },

    -- Snapshot of last ChooseAction call
    lastDecision = {
        now = 0, gcdRemaining = 0, shootRemaining = 0, chosenOpt = "none",
        chooseDelta = 0, tmwUpdateInterval = 0, tmwClockLag = 0,
        rawShootRemaining = 0, shootTimerMode = "action", shootTimerState = "unknown",
        rShoot = 0, rSteady = 0, rMulti = 0, rArcane = 0,
        shootGCDDelay = 0, steadyShootDelay = 0,
        multiShootDelay = 0, arcaneShootDelay = 0,
        manaPct = 0, enoughMana = true, expensiveManaOk = true,
        multiGated = false, arcaneGated = false,
        clipBucket = "BASE", steadyClipCap = 0, multiClipCap = 0,
        arcaneClipCap = 0, steadyClipGated = false,
        multiClipGated = false, arcaneClipGated = false,
    },

    -- Ring buffer of actually-fired specials (populated via RecordFire)
    fireHistory = {},
    fireHistoryMax = 20,
    fireCounts = { steady = 0, multi = 0, arcane = 0, kc = 0, sting = 0 },
    fireCombatStart = 0,

    decisionLog = {},
    decisionLogMax = 900,
    lastDecisionLogAt = 0,
    lastDecisionLogChoice = nil,
}

-- ============================================================================
-- CONSTANTS
-- ============================================================================
local CRIT_MULTIPLIER_BASE = 2.0
local MORTAL_SHOTS_RANK_BONUS = 0.06   -- +6% crit damage per rank, ranged only

local HIT_PCT_BOSS = 0.95
local GCD_DEFAULT = NS.get_global_cooldown and NS.get_global_cooldown() or 1.5
local SHOOT_TIMER_EPSILON = 0.05
local SHOOT_TIMER_ZERO_GRACE = 0.15
local INHOUSE_SHOOT_DEDUPE = 0.08
-- Clip caps are bucketed by current ranged speed.
local CLIP_BUDGETS = {
    BASE   = { steady = 0.22, multi = 0.14, arcane = 0.10 },
    LIGHT  = { steady = 0.30, multi = 0.18, arcane = 0.10 },
    MAJOR  = { steady = 0.20, multi = 0.12, arcane = 0.10 },
    DOUBLE = { steady = 0.30, multi = 0.22, arcane = 0.12 },
    PEAK   = { steady = 0.50, multi = 0.16, arcane = 0.08 },
    ULTRA  = { steady = 0.50, multi = 0.12, arcane = 0.06 },
}

-- ============================================================================
-- SETTINGS ACCESS
-- ============================================================================
local function setting(key, default)
    return NS.get_setting and NS.get_setting(key, default) or default
end

local function resetInhouseShootTimer(reason)
    local shot = State.inhouseShoot
    shot.known = false
    shot.state = reason or "unknown"
    shot.lastSwingAt = 0
    shot.lastSuccessAt = 0
    shot.duration = 0
    shot.nextDoneAt = 0
    shot.lastSpeed = 0
    shot.lastSource = reason or ""
end

local function recordInhouseShootSuccess(source)
    local now = GetTime()
    local shot = State.inhouseShoot
    if shot.lastSuccessAt > 0 and (now - shot.lastSuccessAt) < INHOUSE_SHOOT_DEDUPE then
        return
    end

    local speed = UnitRangedDamage("player")
    speed = (speed and speed > 0) and speed or State.rangedSpeed or 2.8
    shot.known = true
    shot.state = "known"
    shot.lastSwingAt = now
    shot.lastSuccessAt = now
    shot.duration = speed
    shot.nextDoneAt = now + speed
    shot.lastSpeed = speed
    shot.lastSource = source or "success"
    State.lastShootDoneAt = shot.nextDoneAt
    State.zeroShootSince = 0
end

local function inhouseShootRemaining(now)
    local shot = State.inhouseShoot
    if not shot.known then
        shot.state = "unknown"
        return 0, shot.state
    end

    local remaining = shot.nextDoneAt - now
    if remaining > SHOOT_TIMER_EPSILON then
        shot.state = shot.lastSource and shot.lastSource ~= "" and ("known:" .. shot.lastSource) or "known"
        return remaining, shot.state
    end

    shot.known = false
    shot.state = "elapsed"
    return 0, shot.state
end

-- ============================================================================
-- STAT READERS
-- ============================================================================
local function readStats()
    local base, posBuff, negBuff = UnitRangedAttackPower("player")
    State.rap = (base or 0) + (posBuff or 0) + (negBuff or 0)

    local speed, lowDmg, hiDmg, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
    State.rangedSpeed = speed or 2.8

    local raw = setting("weapon_speed", 2.9)
    State.weaponBaseSpd = raw > 10 and raw / 10 or raw  -- schema uses tenths (29=2.9s)
    State.hasteMult = State.weaponBaseSpd / math_max(0.1, State.rangedSpeed)

    percent = percent or 1
    if percent == 0 then percent = 1 end
    State.rangedDmgBonus = (physicalBonusPos or 0) + (physicalBonusNeg or 0)
    State.rangedDmgPercent = percent
    State.rangedDmgAvg = ((lowDmg or 0) + (hiDmg or 0)) * 0.5
    local rangedBaseWithAP = ((((lowDmg or 0) / percent) - State.rangedDmgBonus)
        + (((hiDmg or 0) / percent) - State.rangedDmgBonus)) * 0.5
    local apPerShot = State.rap * State.weaponBaseSpd / 14.0
    local baseFromPaperDoll = rangedBaseWithAP - apPerShot
    if baseFromPaperDoll > 0 and rangedBaseWithAP > apPerShot then
        State.weaponDmgAvg = baseFromPaperDoll
        State.rangedDmgIncludesAP = true
    else
        State.weaponDmgAvg = rangedBaseWithAP > 0 and rangedBaseWithAP or State.rangedDmgAvg
        State.rangedDmgIncludesAP = false
    end

    State.critPct = GetRangedCritChance() or 0

    -- Mortal Shots rank → +6% crit damage on ranged specials per rank.
    -- Tab 3 (Marksmanship), row 3, column 3 = Mortal Shots.
    local mortalShotsRanks = select(5, GetTalentInfo(3, 3)) or 0
    State.critMultiplier = CRIT_MULTIPLIER_BASE * (1 + MORTAL_SHOTS_RANK_BONUS * mortalShotsRanks)
end

-- ============================================================================
-- DAMAGE FORMULAS
-- Source: wowsims/tbc/sim/hunter/{auto_attack,steady_shot,multi_shot,arcane_shot}.go
-- Multipliers (Ferocious Inspiration, Beast Within, etc.) are applied uniformly
-- to all four options, so they CANCEL OUT in the comparison and we skip them.
-- ============================================================================
local function critFactor()
    local pct = State.critPct / 100.0
    return 1.0 + pct * (State.critMultiplier - 1.0)
end

local function recomputeDamageEstimates()
    local rap     = State.rap
    local wepDmg  = State.weaponDmgAvg
    local wepSpd  = State.weaponBaseSpd
    local cf      = critFactor()
    local hitMul  = HIT_PCT_BOSS

    local autoBase = State.rangedDmgIncludesAP
        and ((wepDmg + rap * wepSpd / 14.0 + State.rangedDmgBonus) * State.rangedDmgPercent)
        or (wepDmg + rap * wepSpd / 14.0)
    State.avgShootDmg = autoBase * cf * hitMul

    local steadyBase = rap * 0.20 + wepDmg * 2.8 / math_max(0.1, wepSpd) + 150
    State.avgSteadyDmg = steadyBase * cf * hitMul

    local multiBase = rap * 0.20 + wepDmg + 205
    State.avgMultiDmg = multiBase * cf * hitMul

    local arcaneBase = rap * 0.15 + 273
    State.avgArcaneDmg = arcaneBase * cf * hitMul

    -- Cast/rate math excludes latency. Clip budgets below are the safety margin.
    State.shootDPS  = State.avgShootDmg  / math_max(0.1, State.rangedSpeed)
    State.steadyDPS = State.avgSteadyDmg / GCD_DEFAULT

    State.steadyCastTime = 1.5 / State.hasteMult
    State.multiCastTime  = 0.5 / State.hasteMult
    State.arcaneCastTime = 0

    State.rangedWindup = 0.5 / State.hasteMult

    -- useMultiForCatchup (rotation.go:175-181): "When ranged swing speed lines
    -- up closely with GCD without clipping, it's never worth saving Multi for
    -- the lower cast time."
    local rangedGapTime = State.rangedSpeed - State.rangedWindup
    local autoCycleDuration = rangedGapTime
    local guard = 0
    while autoCycleDuration < GCD_DEFAULT and guard < 10 do
        autoCycleDuration = autoCycleDuration + (rangedGapTime + State.rangedWindup)
        guard = guard + 1
    end
    local denom = (rangedGapTime + State.rangedWindup)
    local leftoverGCDRatio = denom > 0 and (autoCycleDuration - GCD_DEFAULT) / denom or 1.0
    State.useMultiForCatchup = leftoverGCDRatio < 0.95
end

-- ============================================================================
-- RECOMPUTE PIPELINE
-- ============================================================================
local function recompute()
    readStats()
    recomputeDamageEstimates()
    State.dirty = false
    State.lastRecomputeAt = GetTime()
end

local function scheduleNextRecompute()
    local now = GetTime()
    local soonest = math_huge
    for i = 1, 40 do
        local name, _, _, _, _, expirationTime, _, _, _, spellID = UnitBuff("player", i)
        if not name then break end
        if spellID and TRACKED_AURAS[spellID] and expirationTime and expirationTime > now then
            if expirationTime < soonest then soonest = expirationTime end
        end
    end
    if soonest == math_huge then
        State.nextRecomputeAt = now + 60
    else
        State.nextRecomputeAt = soonest + 0.05
    end
end

local wallClockOffset
pcall(function() wallClockOffset = ((time and time()) or 0) - GetTime() end)
if not wallClockOffset then wallClockOffset = 0 end

local function timestamp()
    local gameTime = GetTime()
    if date and time then
        local wall = wallClockOffset + gameTime
        local sec = floor(wall)
        local centis = floor((wall - sec) * 100 + 0.5)
        if centis >= 100 then
            sec = sec + 1
            centis = 0
        end
        return string.format("%s.%02d", date("%H:%M:%S", sec), centis)
    end
    return string.format("%.3f", gameTime)
end

local function boolText(v)
    return v and "true" or "false"
end

local function clipBudgetForSpeed(speed)
    if not speed or speed <= 0 then
        return CLIP_BUDGETS.BASE, "BASE"
    elseif speed >= 2.35 then
        return CLIP_BUDGETS.BASE, "BASE"
    elseif speed >= 2.00 then
        return CLIP_BUDGETS.LIGHT, "LIGHT"
    elseif speed >= 1.70 then
        return CLIP_BUDGETS.MAJOR, "MAJOR"
    elseif speed >= 1.40 then
        return CLIP_BUDGETS.DOUBLE, "DOUBLE"
    elseif speed >= 1.15 then
        return CLIP_BUDGETS.PEAK, "PEAK"
    end
    return CLIP_BUDGETS.ULTRA, "ULTRA"
end

local function adaptiveExecutionPad()
    local ms = tonumber(setting("adaptive_exec_pad_ms", 100))
    if ms < 0 then ms = 0 end
    if ms > 250 then ms = 250 end
    return ms / 1000
end

local function score(v)
    if type(v) ~= "number" or v < -1e8 then return "" end
    return string.format("%.1f", v)
end

local function decisionMargin(bestOpt, rShoot, rSteady, rMulti, rArcane)
    local best = -math_huge
    local second = -math_huge
    local function add(opt, value)
        if type(value) ~= "number" then return end
        if opt == bestOpt then
            if value > best then best = value end
        elseif value > second then
            second = value
        end
    end
    add(OPT_SHOOT, rShoot)
    add(OPT_STEADY, rSteady)
    add(OPT_MULTI, rMulti)
    add(OPT_ARCANE, rArcane)
    if second < -1e8 then return 0 end
    return best - second
end

local function logDecision(unit, d, shootAt, shootDoneAt)
    local now = d.now or GetTime()
    if d.chosenOpt == State.lastDecisionLogChoice and (now - (State.lastDecisionLogAt or 0)) < 0.20 then
        return
    end

    State.lastDecisionLogAt = now
    State.lastDecisionLogChoice = d.chosenOpt

    local lat = (core.get_ping and core.get_ping() or 0) * 1000
    local sqw = tonumber(GetCVar and GetCVar("SpellQueueWindow")) or 0
    local margin = decisionMargin(d.chosenOpt, d.rShoot, d.rSteady, d.rMulti, d.rArcane)
    local shootAtIn = math_max(0, (shootAt or now) - now)
    local shootDoneIn = math_max(0, (shootDoneAt or now) - now)

    table.insert(State.decisionLog, {
        timestamp = timestamp(),
        rawTime = now,
        chooseDelta = d.chooseDelta or 0,
        tmwUpdateInterval = d.tmwUpdateInterval or 0,
        tmwClockLag = d.tmwClockLag or 0,
        unit = unit or "",
        choice = d.chosenOpt or "",
        margin = margin,
        gcdRemaining = d.gcdRemaining or 0,
        shootRemaining = d.shootRemaining or 0,
        rawShootRemaining = d.rawShootRemaining or 0,
        shootTimerMode = d.shootTimerMode or "",
        shootTimerState = d.shootTimerState or "",
        shootAtIn = shootAtIn,
        shootDoneIn = shootDoneIn,
        shootGCDDelay = d.shootGCDDelay or 0,
        steadyShootDelay = d.steadyShootDelay or 0,
        multiShootDelay = d.multiShootDelay or 0,
        arcaneShootDelay = d.arcaneShootDelay or 0,
        rShoot = d.rShoot,
        rSteady = d.rSteady,
        rMulti = d.rMulti,
        rArcane = d.rArcane,
        manaPct = d.manaPct or 0,
        expensiveManaOk = d.expensiveManaOk and true or false,
        multiGated = d.multiGated and true or false,
        arcaneGated = d.arcaneGated and true or false,
        clipBucket = d.clipBucket or "",
        steadyClipCap = d.steadyClipCap or 0,
        multiClipCap = d.multiClipCap or 0,
        arcaneClipCap = d.arcaneClipCap or 0,
        executionPad = d.executionPad or 0,
        steadyClipGated = d.steadyClipGated and true or false,
        multiClipGated = d.multiClipGated and true or false,
        arcaneClipGated = d.arcaneClipGated and true or false,
        rangedSpeed = State.rangedSpeed or 0,
        rangedWindup = State.rangedWindup or 0,
        steadyCastTime = State.steadyCastTime or 0,
        multiCastTime = State.multiCastTime or 0,
        arcaneCastTime = State.arcaneCastTime or 0,
        latency = lat,
        sqw = sqw,
        hasteMult = State.hasteMult or 1,
        useMultiForCatchup = State.useMultiForCatchup and true or false,
    })

    while #State.decisionLog > State.decisionLogMax do
        table.remove(State.decisionLog, 1)
    end
end

local function clearDecisionLog()
    for i = #State.decisionLog, 1, -1 do
        State.decisionLog[i] = nil
    end
    State.lastDecisionLogAt = 0
    State.lastDecisionLogChoice = nil
end

local function resetShootTimerState()
    State.lastShootDoneAt = 0
    State.zeroShootSince = 0
    resetInhouseShootTimer("reset")
end

local function resolveShootRemaining(now, rawRemaining)
    rawRemaining = rawRemaining or 0
    if rawRemaining < 0 then rawRemaining = 0 end

    if rawRemaining > SHOOT_TIMER_EPSILON then
        State.lastShootDoneAt = now + rawRemaining
        State.zeroShootSince = 0
        return rawRemaining
    end

    if State.lastShootDoneAt > now + SHOOT_TIMER_EPSILON then
        return State.lastShootDoneAt - now
    end

    if State.zeroShootSince == 0 then
        State.zeroShootSince = now
    end

    if State.lastShootDoneAt > 0 and (now - State.zeroShootSince) >= SHOOT_TIMER_ZERO_GRACE then
        local nextDoneAt = State.lastShootDoneAt
        local cycle = math_max(0.5, State.rangedSpeed or 0)
        while nextDoneAt <= now + SHOOT_TIMER_EPSILON do
            nextDoneAt = nextDoneAt + cycle
        end
        State.lastShootDoneAt = nextDoneAt
        State.zeroShootSince = 0
        return math_max(0, nextDoneAt - now)
    end

    return 0
end

local function decisionCSV()
    local lines = {
        "timestamp,raw_time,choose_delta,tmw_upd_intv,tmw_clock_lag,unit,choice,margin,gcd_remaining,shoot_remaining,raw_shoot_remaining,shoot_timer_mode,shoot_timer_state,shoot_at_in,shoot_done_in,shoot_gcd_delay,steady_shoot_delay,multi_shoot_delay,arcane_shoot_delay,r_shoot,r_steady,r_multi,r_arcane,mana_pct,expensive_mana_ok,multi_gated,arcane_gated,clip_bucket,steady_clip_cap,multi_clip_cap,arcane_clip_cap,steady_clip_gated,multi_clip_gated,arcane_clip_gated,ranged_speed,ranged_windup,steady_cast_time,multi_cast_time,arcane_cast_time,latency,sqw,haste_mult,use_multi_for_catchup,execution_pad"
    }
    for _, e in ipairs(State.decisionLog or {}) do
        table.insert(lines, string.format(
            "%s,%.3f,%.3f,%.3f,%.3f,%s,%s,%.1f,%.3f,%.3f,%.3f,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%s,%s,%s,%s,%.1f,%s,%s,%s,%s,%.3f,%.3f,%.3f,%s,%s,%s,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%.3f,%s,%.3f",
            e.timestamp or "", e.rawTime or 0, e.chooseDelta or 0, e.tmwUpdateInterval or 0,
            e.tmwClockLag or 0, e.unit or "", e.choice or "", e.margin or 0,
            e.gcdRemaining or 0, e.shootRemaining or 0, e.rawShootRemaining or 0,
            e.shootTimerMode or "", e.shootTimerState or "", e.shootAtIn or 0, e.shootDoneIn or 0,
            e.shootGCDDelay or 0, e.steadyShootDelay or 0, e.multiShootDelay or 0, e.arcaneShootDelay or 0,
            score(e.rShoot), score(e.rSteady), score(e.rMulti), score(e.rArcane),
            e.manaPct or 0, boolText(e.expensiveManaOk), boolText(e.multiGated), boolText(e.arcaneGated),
            e.clipBucket or "", e.steadyClipCap or 0, e.multiClipCap or 0, e.arcaneClipCap or 0,
            boolText(e.steadyClipGated), boolText(e.multiClipGated), boolText(e.arcaneClipGated),
            e.rangedSpeed or 0, e.rangedWindup or 0, e.steadyCastTime or 0, e.multiCastTime or 0,
            e.arcaneCastTime or 0, e.latency or 0, e.sqw or 0, e.hasteMult or 1, boolText(e.useMultiForCatchup),
            e.executionPad or 0
        ))
    end
    return table.concat(lines, "\n")
end

local function auraDebugSnapshot()
    local now = GetTime()
    local firstLine = nil
    local trackedLine = nil
    local count = 0

    local function val(v)
        if v == nil then return "nil" end
        if type(v) == "number" then return string.format("%.1f", v) end
        return tostring(v)
    end

    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime, sourceUnit, _, _, spellID, slot11 = UnitBuff("player", i)
        if not name then break end
        count = count + 1

        local ttl = "--"
        if type(expirationTime) == "number" and expirationTime > 0 then
            ttl = string.format("%.1fs", math_max(0, expirationTime - now))
        end

        local line = string.format("#%d %s s6=%s s7=%s id10=%s s11=%s ttl=%s",
            i, name, val(expirationTime), val(sourceUnit), val(spellID), val(slot11), ttl)

        if not firstLine then firstLine = line end
        if spellID and TRACKED_AURAS[spellID] then
            trackedLine = line
        end
    end

    local nextIn = (State.nextRecomputeAt or 0) - now
    return {
        buffCount = count,
        firstLine = firstLine or "no player buffs",
        trackedLine = trackedLine or "none active",
        nextRecomputeIn = nextIn,
        recomputeDue = nextIn <= 0,
    }
end

-- ============================================================================
-- EVENT HOOKS
-- ============================================================================
local function OnUnitAura(unitID)
    if unitID ~= "player" then return end
    State.dirty = true
end

local function OnCombatStart()
    State.dirty = true
    State.lastChooseAt = 0
    resetShootTimerState()
    State.fireCombatStart = GetTime()
    State.fireCounts.steady = 0
    State.fireCounts.multi = 0
    State.fireCounts.arcane = 0
    State.fireCounts.kc = 0
    State.fireCounts.sting = 0
    for i = #State.fireHistory, 1, -1 do State.fireHistory[i] = nil end
end

local SHORT_CODES = {
    ["Steady Shot"] = "S", ["Multi-Shot"] = "M", ["Arcane Shot"] = "A",
    ["Kill Command"] = "K", ["Serpent Sting"] = "Z", ["Scorpid Sting"] = "Z",
    ["Viper Sting"] = "Z",
}

local function RecordFire(spellName)
    if not spellName then return end
    local now = GetTime()
    table.insert(State.fireHistory, { name = spellName, code = SHORT_CODES[spellName] or "?", time = now })
    while #State.fireHistory > State.fireHistoryMax do
        table.remove(State.fireHistory, 1)
    end
    if spellName == "Steady Shot" then State.fireCounts.steady = State.fireCounts.steady + 1
    elseif spellName == "Multi-Shot" then State.fireCounts.multi = State.fireCounts.multi + 1
    elseif spellName == "Arcane Shot" then State.fireCounts.arcane = State.fireCounts.arcane + 1
    elseif spellName == "Kill Command" then State.fireCounts.kc = State.fireCounts.kc + 1
    elseif spellName:find("Sting") then State.fireCounts.sting = State.fireCounts.sting + 1
    end
end

local function OnEquipChange()
    State.dirty = true
    resetInhouseShootTimer("equip")
end

local pGUID_adapt = nil
local function OnCLEU_AdaptiveFire()
    local _, subevent, _, sourceGUID, _, _, _, _, _, _, _, spellID, spellName = CombatLogGetCurrentEventInfo()
    if subevent ~= "SPELL_CAST_SUCCESS" then return end
    if not pGUID_adapt then pGUID_adapt = UnitGUID("player") end
    if sourceGUID ~= pGUID_adapt then return end
    if spellID and RANGED_SWING_RESET_SPELLS[spellID] then
        recordInhouseShootSuccess("cleu")
    end
    if spellName and TRACKED_FIRES[spellName] then
        RecordFire(spellName)
    end
end

local function OnUnitSpellcastSucceeded(unitID, _, spellID)
    if unitID ~= "player" then return end
    if spellID and RANGED_SWING_RESET_SPELLS[spellID] then
        recordInhouseShootSuccess("unit")
    end
end

-- ============================================================================
-- CORE: ChooseAction
-- Direct port of adaptiveRotation (rotation.go:139-280).
-- All times are in absolute seconds.
-- ============================================================================
local function ChooseAction(unit, opts)
    local wallNow = GetTime()
    local now = wallNow
    local chooseDelta = State.lastChooseAt > 0 and math_max(0, now - State.lastChooseAt) or 0
    State.lastChooseAt = now
    local tmwUpdateInterval = 0
    local tmwClockLag = wallNow - now
    opts = opts or {}

    -- Lazy recompute if dirty or scheduled
    if State.dirty or now >= State.nextRecomputeAt then
        recompute()
        scheduleNextRecompute()
    end

    -- Time bases
    local gcdRemaining = NS.gcd_remains() or 0
    local gcdAt = math_max(now, now + gcdRemaining)

    local rawShootRemaining = get_ranged_time_until()
    local shootTimerMode = setting("inhouse_swingshot", false) and "inhouse" or "action"
    local shootTimerState = "action"
    local shootRemaining
    if setting("inhouse_swingshot", false) then
        shootRemaining, shootTimerState = inhouseShootRemaining(now)
        if shootRemaining <= SHOOT_TIMER_EPSILON and rawShootRemaining > SHOOT_TIMER_EPSILON then
            shootRemaining = resolveShootRemaining(now, rawShootRemaining)
            shootTimerState = shootTimerState .. "+action_fallback"
        end
    else
        shootRemaining = resolveShootRemaining(now, rawShootRemaining)
    end
    local shootDoneAt = math_max(now, now + shootRemaining)
    local shootAt = math_max(now, shootDoneAt - State.rangedWindup)

    -- Compute dmgResults[]
    local NEG = -1e9
    local rShoot, rSteady, rMulti, rArcane = NEG, NEG, NEG, NEG

    -- shoot option
    local shootGCDDelay = math_max(0, shootDoneAt - gcdAt)
    rShoot = State.avgShootDmg - (State.steadyDPS * shootGCDDelay)

    -- Mana gates
    local manaPct = opts.manaPct or (NS.mana_pct and NS.mana_pct(NS.GetPlayer())) or 100
    local manaSaveFloor = opts.manaSaveFloor or setting("mana_save", 30)
    local expensiveManaOk = manaPct > manaSaveFloor

    -- Pre-compute delays
    local executionPad = adaptiveExecutionPad()
    local castStartAt = gcdAt + executionPad
    local steadyShootDelay = math_max(0, (castStartAt + State.steadyCastTime) - shootAt)
    local multiShootDelay  = math_max(0, (castStartAt + State.multiCastTime)  - shootAt)
    local arcaneShootDelay = math_max(0, (castStartAt + State.arcaneCastTime) - shootAt)
    local multiGated, arcaneGated = false, false
    local clipBudget, clipBucket = clipBudgetForSpeed(State.rangedSpeed)
    local steadyClipGated = steadyShootDelay > clipBudget.steady
    local multiClipGated = multiShootDelay > clipBudget.multi
    local arcaneClipGated = arcaneShootDelay > clipBudget.arcane

    -- steady option
    if not steadyClipGated then
        rSteady = State.avgSteadyDmg - (State.shootDPS * steadyShootDelay)
    end

    -- multi-shot option
    local useMulti = opts.useMulti
    if useMulti == nil then useMulti = setting("aoe_threshold", 3) > 0 end
    if useMulti and expensiveManaOk and NS.spell_ready(SPELLS.MultiShot, unit) then
        if multiClipGated then
            multiGated = true
        elseif (not State.useMultiForCatchup) or (multiShootDelay < steadyShootDelay) then
            rMulti = State.avgMultiDmg - (State.shootDPS * multiShootDelay)
        else
            multiGated = true
        end
    else
        multiGated = true
    end

    -- arcane shot option
    local useArcane = opts.useArcane
    if useArcane == nil then useArcane = setting("use_arcane", true) end
    local arcaneManaFloor = opts.arcaneManaFloor or setting("arcane_shot_mana", 15)
    if useArcane and not opts.arcaneImmune and manaPct > arcaneManaFloor and NS.spell_ready(SPELLS.ArcaneShot, unit) then
        if arcaneClipGated then
            arcaneGated = true
        else
            rArcane = State.avgArcaneDmg - (State.shootDPS * arcaneShootDelay)
        end
    else
        arcaneGated = true
    end

    -- Pick max
    local bestOpt, bestDmg = OPT_SHOOT, rShoot
    if rSteady > bestDmg then bestOpt, bestDmg = OPT_STEADY, rSteady end
    if rMulti  > bestDmg then bestOpt, bestDmg = OPT_MULTI,  rMulti  end
    if rArcane > bestDmg then bestOpt, bestDmg = OPT_ARCANE, rArcane end

    -- Sanity: GCD spell selected but GCD not actually off yet -> fall back to shoot.
    if bestOpt ~= OPT_SHOOT and gcdRemaining > 0.05 then
        if rShoot >= bestDmg - 0.01 then
            bestOpt = OPT_SHOOT
        end
    end

    -- Snapshot the decision
    local d = State.lastDecision
    d.now = now
    d.chooseDelta = chooseDelta
    d.tmwUpdateInterval = tmwUpdateInterval
    d.tmwClockLag = tmwClockLag
    d.gcdRemaining = gcdRemaining
    d.shootRemaining = shootRemaining
    d.rawShootRemaining = rawShootRemaining
    d.shootTimerMode = shootTimerMode
    d.shootTimerState = shootTimerState
    d.chosenOpt = bestOpt
    d.rShoot, d.rSteady, d.rMulti, d.rArcane = rShoot, rSteady, rMulti, rArcane
    d.shootGCDDelay = shootGCDDelay
    d.steadyShootDelay = steadyShootDelay
    d.multiShootDelay = multiShootDelay
    d.arcaneShootDelay = arcaneShootDelay
    d.manaPct = manaPct
    d.enoughMana = expensiveManaOk
    d.expensiveManaOk = expensiveManaOk
    d.multiGated = multiGated
    d.arcaneGated = arcaneGated
    d.clipBucket = clipBucket
    d.steadyClipCap = clipBudget.steady
    d.multiClipCap = clipBudget.multi
    d.arcaneClipCap = clipBudget.arcane
    d.executionPad = executionPad
    d.steadyClipGated = steadyClipGated
    d.multiClipGated = multiClipGated
    d.arcaneClipGated = arcaneClipGated
    logDecision(unit, d, shootAt, shootDoneAt)

    if State.debug then
        print(string.format(
            "[Adaptive] now=%.2f gcd+%.2f shoot+%.2f -> %s | shoot=%.0f steady=%.0f multi=%.0f arcane=%.0f | hM=%.2f rW=%.2f sCT=%.2f",
            now, gcdRemaining, shootRemaining, bestOpt,
            rShoot, rSteady, rMulti, rArcane,
            State.hasteMult, State.rangedWindup, State.steadyCastTime
        ))
    end

    return bestOpt
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
local M = {
    ChooseAction = ChooseAction,
    SetDebug = function(v) State.debug = v and true or false end,
    GetState = function() return State end,
    GetAuraDebug = auraDebugSnapshot,
    ClearDecisionLog = clearDecisionLog,
    GetDecisionCSV = decisionCSV,
    Recompute = function() State.dirty = true end,
    ForceRecompute = function() recompute() end,
    RecordFire = RecordFire,

    OPT_SHOOT  = OPT_SHOOT,
    OPT_STEADY = OPT_STEADY,
    OPT_MULTI  = OPT_MULTI,
    OPT_ARCANE = OPT_ARCANE,
    OPT_NONE   = OPT_NONE,
}

NS.HunterAdaptive = M

-- ============================================================================
-- EVENT REGISTRATION
-- Use frame-based events for UNIT_AURA and other WoW events.
-- ============================================================================
local frame, frame_created = nil, false
do
    local ok, f = pcall(_G.CreateFrame, "Frame", "EaxHunterAdaptiveFrame")
    if ok and f then
        frame = f
        frame_created = true

        pcall(frame.RegisterEvent, frame, "UNIT_AURA")
        pcall(frame.RegisterEvent, frame, "PLAYER_REGEN_DISABLED")
        pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
        pcall(frame.RegisterEvent, frame, "PLAYER_EQUIPMENT_CHANGED")
        pcall(frame.RegisterEvent, frame, "PLAYER_TALENT_UPDATE")
        pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")

        pcall(frame.SetScript, frame, "OnEvent", function(self, event, ...)
            if event == "UNIT_AURA" then
                OnUnitAura(...)
            elseif event == "PLAYER_REGEN_DISABLED" then
                OnCombatStart()
            elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
                OnUnitSpellcastSucceeded(...)
            elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
                OnEquipChange()
            elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
                OnCLEU_AdaptiveFire()
            end
        end)
    end
end

-- Fallback: if frame creation failed, register via Sylvanas APIs
if not frame_created then
    NS.register_on_combat_start(OnCombatStart)
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            OnUnitSpellcastSucceeded("player", nil, spell_id)
        end)
    end
end

-- Force initial recompute on first ChooseAction call.
State.dirty = true

NS.log("[HunterAdaptive] Adaptive engine loaded")

return M
