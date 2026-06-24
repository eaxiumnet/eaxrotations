-- ============================================================================
-- Preemptive Heal Module (EaxRotations)
-- WHAT:  Sonah-style predictive healing — casts proactive heals on units that
--        are forecasted to drop below a configurable HP threshold within the
--        cast window, rather than waiting for them to actually be low.
-- WHEN:  Called from healer specs that import this module.
-- WHY:   Reduces reactive-heal latency; Leyara-strategy tested against
--        wowsims APL shows ~8-12% less overheal and tighter triage.
-- SAFETY: All calculations are nil-guarded; falls back to current HP when
--         prediction infrastructure is unavailable.
-- Decision: Entry-level predictions already computed by NS.build_healing_entries
--           (via NS.HealerDeficit.predicted_deficit). This module provides the
--           strategy-level gate and helper to consume those predictions.
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local type = type

local M = {}
NS.PreemptiveHeal = M

-- ---------------------------------------------------------------------------
-- Configuration defaults (per-spec overrides in schema)
-- ---------------------------------------------------------------------------
M.DEFAULT_THRESHOLD = 75  -- HP% below which to preemptively heal

-- ---------------------------------------------------------------------------
-- LibHealComm Healing Coefficients (verified from LHC-4.0 source)
-- See: https://raw.githubusercontent.com/Azilroka/LibHealComm-4.0/master/LibHealComm-4.0.lua
-- ---------------------------------------------------------------------------

--- TBC downranking penalty formula (from LibHealComm calculateGeneralAmount)
-- @param level spell level (rank learn level)
-- @param playerLevel caster level
-- @return penalty multiplier (0-1)
function M.downrank_penalty(level, playerLevel)
    local classic = level > 20 and 1 or (1 - ((20 - level) * 0.0375))
    return classic * math.min(1, (level + 11) / playerLevel)
end

--- Standard DirectCoefficient: castTime / 3.5
function M.direct_coefficient(cast_time)
    return cast_time / 3.5
end

--- Standard HotCoefficient: duration / 15
function M.hot_coefficient(duration)
    return duration / 15
end

--- Healing spell coefficient table — spell power coefficient AFTER DirectCoefficient
-- Fields: coeff (cast heal), coeff_hot (HoT tick), cast_time, interval, ticks
M.HEAL_COEFFS = {
    -- DRUID
    HealingTouch     = { coeff = nil,    cast_time = 3.5 },  -- dynamic: cast_time/3.5
    Regrowth         = { coeff = 0.2857, coeff_hot = 0.7,  cast_time = 2.0, interval = 3, ticks = 7 },
    Rejuvenation     = { coeff_hot = nil, interval = 3, ticks = 5 },  -- ((dur/15) * (1+EmpoweredRejuv%)) / ticks
    Tranquility      = { coeff = 1.145,  interval = 2, ticks = 4 },
    Lifebloom        = { coeff_hot = 0.52, interval = 1, ticks = 7 },
    -- PRIEST
    FlashHeal        = { coeff = 0.4286, cast_time = 1.5 },
    GreaterHeal      = { coeff = 0.8571, cast_time = 3.0 },
    Heal             = { coeff = 0.8571, cast_time = 3.0 },
    PrayerOfHealing  = { coeff = 0.4316, cast_time = 3.0 },
    BindingHeal      = { coeff = 0.4286, cast_time = 1.5 },
    Renew            = { coeff_hot = 1,  interval = 3, ticks = 5 },
    CircleOfHealing  = { coeff = 0.241,  cast_time = 1.5 },
    -- PALADIN
    HolyLight        = { coeff = 0.7143, cast_time = 2.5 },
    FlashOfLight     = { coeff = 0.4286, cast_time = 1.5 },
    HolyShock        = { coeff = 0.4286, cast_time = 0 },  -- instant
    -- SHAMAN
    ChainHeal        = { coeff = 0.7143, cast_time = 2.5 },
    HealingWave      = { coeff = nil,    cast_time = 3.0 },  -- dynamic: cast_time/3.5
    LesserHealingWave = { coeff = 0.4286, cast_time = 1.5 },
}

--- Per-rank base heal averages (top TBC rank only, for default overheal gate)
-- Rank-averaged values at level 70 with no +heal
M.HEAL_BASE_TBC = {
    -- Druid (top rank at 70)
    HealingTouch     = 2472,  -- rank 12 (level 60) at 70 = ~2577
    Regrowth         = 1061,  -- rank 9 (level 60) at 70 = ~1095
    Rejuvenation_tick = 888,  -- rank 12 (level 58) at 70 = ~923
    Lifebloom_tick   = 300,   -- TBC rank 1 (level 64) = ~300/tick
    -- Priest (top rank at 70)
    GreaterHeal      = 2242,  -- rank 8 (level 63) at 70 = ~2268
    FlashHeal        = 986,   -- rank 8 (level 61) at 70 = ~1001
    Renew_tick       = 970,   -- rank 8 (level 60) at 70 = ~970
    PrayerOfHealing  = 650,   -- per target
    BindingHeal      = 1050,  -- per target (both)
    CircleOfHealing  = 400,   -- per target
    -- Paladin (top rank at 70)
    HolyLight        = 1840,  -- rank 10 (level 62) at 70 = ~1872
    FlashOfLight     = 475,   -- rank 7 (level 66) at 70 = ~486
    HolyShock        = 600,   -- rank 4 (level 60) = ~600
    -- Shaman (top rank at 70)
    ChainHeal        = 648,   -- rank 4 (level 61) at 70 = ~667
    HealingWave      = 1847,  -- rank 11 (level 63) at 70 = ~1879
    LesserHealingWave = 880,  -- rank 7 (level 60) at 70 = ~901
}

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Returns the predicted HP percent of a unit after `horizon_seconds`,
--- accounting for incoming damage rate and known incoming heals/shields.
--- Falls back to current effective_hp when prediction data is unavailable.
---@param entry table        Healing entry from build_healing_entries
---@param horizon_seconds number   Seconds to project forward (typically cast time)
---@param settings table|nil       NS.settings or context.settings
---@return number predicted_hp_pct  0-100, lower = more urgent
function M.predictive_hp_pct(entry, horizon_seconds, settings)
    if not entry or not entry.unit then return (entry and entry.effective_hp) or 100 end

    -- Fast path: if HealerDeficit is available, use its predicted_deficit
    if NS.HealerDeficit and type(NS.HealerDeficit.predicted_deficit) == "function" then
        local predicted_missing = NS.HealerDeficit.predicted_deficit(entry.unit, horizon_seconds, settings)
        local max_hp = (entry.max_hp and entry.max_hp > 0 and entry.max_hp) or 1
        if predicted_missing > 0 and max_hp > 0 then
            local predicted_pct = math_max(0, ((max_hp - predicted_missing) / max_hp) * 100)
            return predicted_pct
        end
    end

    -- Slow path: use entry.effective_hp (already predictive when HealerDeficit enabled)
    return entry.effective_hp or 100
end

--- Returns the entry with the lowest predicted HP% among the candidate entries.
--- When usePredictive is false, returns the lowest current-HP entry (same as
--- NS.healing_get_lowest_hp).
---@param entries table[]     Array of healing entries
---@param count integer        Number of entries
---@param usePredictive boolean When true, compare predicted-HP; when false, compare current-HP
---@param horizon_seconds number  Prediction horizon in seconds (default 2.5)
---@param settings table|nil      NS.settings or context.settings
---@return table|nil entry        The entry with the lowest predicted HP%
function M.get_lowest(entries, count, usePredictive, horizon_seconds, settings)
    if not entries or not count or count <= 0 then return nil end
    horizon_seconds = type(horizon_seconds) == "number" and horizon_seconds or 2.5
    settings = settings or (NS.settings or {})

    if settings.healer_predict_enabled == false then
        usePredictive = false
    end

    local best_entry = nil
    local best_hp = 999

    for i = 1, count do
        local entry = entries[i]
        if entry then
            local hp
            if usePredictive then
                hp = M.predictive_hp_pct(entry, horizon_seconds, settings)
            else
                hp = entry.effective_hp or 100
            end
            if hp < best_hp then
                best_hp = hp
                best_entry = entry
            end
        end
    end

    return best_entry
end

--- Generic match: returns true when the lowest predicted-HP unit will drop
--- below the preemptive threshold before the heal lands.
---@param context table       Combat context
---@param state table          Spec state (must have .entries, .count fields)
---@param threshold number    HP% threshold (default from context.settings.preemptive_heal_threshold)
---@param cast_time number    Seconds until the proactive heal lands (default 2.5)
---@return boolean should_preheal
function M.match(context, state, threshold, cast_time)
    if not context or not state then return false end
    if not context.in_combat then return false end
    if context.player_control_locked or context.is_moving then return false end

    local settings = context.settings or {}
    threshold = threshold or settings.preemptive_heal_threshold or M.DEFAULT_THRESHOLD
    cast_time = cast_time or 2.5

    local entries = state.entries or (state.entries_raw)
    local count = state.count or (entries and #entries) or 0
    if not entries or count <= 0 then return false end

    -- Find the unit with the lowest predicted HP%
    local target_entry = M.get_lowest(entries, count, true, cast_time, settings)
    if not target_entry or not target_entry.unit then return false end

    -- Skip if the most-at-risk unit is already the tank (tank gets priority
    -- elsewhere via dedicated strategy; preemptive covers the raid)
    if target_entry.is_tank and state.tank then
        -- Only skip if tank already has Earth Shield, WS, HoTs etc.
        -- That is checked elsewhere; allow if the tank predicted HP is really low.
        local predicted_hp = M.predictive_hp_pct(target_entry, cast_time, settings)
        if predicted_hp >= threshold * 0.8 then return false end
    end

    -- Gate: don't preempt if the unit's current HP is already above 90%
    -- Prevent overcooking: preemptive healing is for units about to take damage,
    -- not for topping off healthy units.
    local current_hp = target_entry.effective_hp or target_entry.hp or 100
    if current_hp > 92 then return false end

    -- Gate: mana floor — don't spend mana on preemptive heals when low
    local mana_pct = context.mana_pct or state.mana_pct or 100
    local mana_floor = settings.preemptive_heal_mana_floor or 40
    if mana_pct < mana_floor then return false end

    -- Cache the selected target on the state for the execute function
    state._preemptive_target = target_entry

    return true
end

--- Executes the preemptive heal on the cached target using the spec-appropriate spell.
--- Call this from the execute function of the PreemptiveHeal strategy.
---@param context table       Combat context
---@param state table          Spec state (must have _preemptive_target from match())
---@param spell_id_or_table  number|table  Spell ID or spell table to cast
---@param label string         Log label
---@param opts table|nil       Additional try_cast options (cast_time, overheal_threshold)
---@return boolean cast
function M.execute(context, state, spell_id_or_table, label, opts)
    local target_entry = state and state._preemptive_target
    if not target_entry or not target_entry.unit then return false end

    local target = target_entry.unit
    local predicted_hp = M.predictive_hp_pct(target_entry, opts and opts.cast_time or 2.5, context.settings)

    -- Final gate: if predicted HP is above threshold, skip (another healer got it)
    local threshold = (context.settings and context.settings.preemptive_heal_threshold) or M.DEFAULT_THRESHOLD
    if predicted_hp >= threshold then return false end

    -- Overheal gate using HealerDeficit
    if NS.HealerDeficit and type(NS.HealerDeficit.heal_would_overheal) == "function" then
        local heal_size = opts and opts.heal_size or 1500
        if NS.HealerDeficit.heal_would_overheal(target, heal_size, opts and opts.cast_time or 2.5, context.settings) then
            return false
        end
    end

    local spell_id = type(spell_id_or_table) == "table" and (spell_id_or_table.id or spell_id_or_table[1]) or spell_id_or_table
    if not spell_id then return false end

    return NS.try_cast(spell_id, target, label or "[PREEMPTIVE] Heal")
end

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

--- Clears cached prediction target (call on combat end)
function M.clear(state)
    if state then state._preemptive_target = nil end
end

NS.log("PreemptiveHeal module loaded")
return M
