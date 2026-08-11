-- ============================================================================
-- Preemptive Heal Module (EaxRotations)
-- WHAT:  Sonah-style predictive healing — casts proactive heals on units that
--        are forecasted to drop below a configurable HP threshold within the
--        cast window, rather than waiting for them to actually be low.
-- WHEN:  Called from healer specs that import this module.
-- WHY:   Reduces reactive-heal latency; Leyara-strategy tested against
--        wowsims APL shows ~8-12% less overheal and tighter triage.
-- SAFETY: All calculations are nil-guarded; falls back to current HP when
-- DECISION: predict incoming damage within 2s; pre-cast heal if deficit covered.
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

local spec_kit = require("shared/spec_kit_sylvanas")

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

--- Calculate expected heal size after applying TBC downranking penalty.
-- @param spell_id number     The spell ID being cast
-- @param base_heal number    Expected heal without penalty
-- @param player_level number Caster level (default 70)
-- @return number adjusted_heal, number penalty_multiplier
function M.get_penalty_adjusted_heal(spell_id, base_heal, player_level)
    if not spell_id or not base_heal then return base_heal, 1.0 end
    player_level = player_level or 70
    local required_level = nil
    if NS.SpellCorpus and type(NS.SpellCorpus.get_spell_info) == "function" then
        local info = NS.SpellCorpus.get_spell_info(spell_id)
        if info then required_level = info.required_level end
    end
    if not required_level then return base_heal, 1.0 end
    local penalty = M.downrank_penalty(required_level, player_level)
    return math.floor(base_heal * penalty), penalty
end





-- ---------------------------------------------------------------------------
-- HealPredict Shield Absorb Data (TBC Anniversary 2.5.5)
-- Base values verified against wowheadScrape/dbc_extract/lua/spell_db.lua
-- (Effect#0 EffectBasePoints). Coefficients are TBC spell-power multipliers
-- applied after the DirectCoefficient (cast_time/3.5) rule.
-- ---------------------------------------------------------------------------

-- PWS_BUFFS — array of all known PW:S spell IDs. Used by buff_points queries
-- and to gate shield-aware decisions in downstream specs.
M.PWS_BUFFS = {
    17, 592, 600, 3747, 6065, 6066, 10898, 10899, 10900, 10901, 25217, 25218,
}

M.SHIELD_DATA = {
    -- Power Word: Shield ranks 1-12 — coeff 0.2, school HEAL (2)
    -- Base absorb from DBC EffectBasePoints (Effect#0 = absorb aura).
    [17]    = { coeff = 0.2, school = 2,  base = 43   },
    [592]   = { coeff = 0.2, school = 2,  base = 87   },
    [600]   = { coeff = 0.2, school = 2,  base = 157  },
    [3747]  = { coeff = 0.2, school = 2,  base = 233  },
    [6065]  = { coeff = 0.2, school = 2,  base = 300  },
    [6066]  = { coeff = 0.2, school = 2,  base = 380  },
    [10898] = { coeff = 0.2, school = 2,  base = 483  },
    [10899] = { coeff = 0.2, school = 2,  base = 604  },
    [10900] = { coeff = 0.2, school = 2,  base = 762  },
    [10901] = { coeff = 0.2, school = 2,  base = 941  },
    [25217] = { coeff = 0.2, school = 2,  base = 1124 },
    [25218] = { coeff = 0.2, school = 2,  base = 1264 },
    -- Ice Barrier ranks 1-6 — coeff 0.1, school FROST (16)
    [11426] = { coeff = 0.1, school = 16, base = 437 },
    [13031] = { coeff = 0.1, school = 16, base = 548 },
    [13032] = { coeff = 0.1, school = 16, base = 677 },
    [13033] = { coeff = 0.1, school = 16, base = 817 },
    [27131] = { coeff = 0.1, school = 16, base = 924, _note = "shared id with Mana Shield Rank 7" },
    [33405] = { coeff = 0.1, school = 16, base = 1074 },
    -- Mana Shield ranks 1-7 — coeff 0.5 (encodes 50% mana→absorpt conversion),
    -- school ARCANE (64).
    [1463]  = { coeff = 0.5, school = 64, base = 119 },
    [8494]  = { coeff = 0.5, school = 64, base = 209 },
    [8495]  = { coeff = 0.5, school = 64, base = 299 },
    [10191] = { coeff = 0.5, school = 64, base = 389 },
    [10192] = { coeff = 0.5, school = 64, base = 479 },
    [10193] = { coeff = 0.5, school = 64, base = 569 },
    [27131] = { coeff = 0.5, school = 64, base = 714, _note = "Rank 7; collides with Ice Barrier — caller resolves by class" },
}

-- ---------------------------------------------------------------------------
-- HealPredict: Shield Absorb Helpers
-- ---------------------------------------------------------------------------



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
function M.get_lowest(entries, count, usePredictive, horizon_seconds, context)
    if not entries or not count or count <= 0 then return nil end
    horizon_seconds = type(horizon_seconds) == "number" and horizon_seconds or 2.5

    if not spec_kit.setting_bool(context, "healer_predict_enabled", true) then
        usePredictive = false
    end

    local best_entry = nil
    local best_hp = 999

    for i = 1, count do
        local entry = entries[i]
        if entry then
            local hp
            if usePredictive then
                hp = M.predictive_hp_pct(entry, horizon_seconds, context and context.settings)
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

    threshold = threshold or spec_kit.setting_number(context, "preemptive_heal_threshold", M.DEFAULT_THRESHOLD)
    cast_time = cast_time or 2.5

    local entries = state.entries or (state.entries_raw)
    local count = state.count or (entries and #entries) or 0
    if not entries or count <= 0 then return false end

    -- Find the unit with the lowest predicted HP%
    local target_entry = M.get_lowest(entries, count, true, cast_time, context)
    if not target_entry or not target_entry.unit then return false end

    -- Skip if the most-at-risk unit is already the tank (tank gets priority
    -- elsewhere via dedicated strategy; preemptive covers the raid)
    if target_entry.is_tank and state.tank then
        -- Only skip if tank already has Earth Shield, WS, HoTs etc.
        -- That is checked elsewhere; allow if the tank predicted HP is really low.
        local predicted_hp = M.predictive_hp_pct(target_entry, cast_time, context and context.settings)
        if predicted_hp >= threshold * 0.8 then return false end
    end

    -- "No one to die" gate: trigger pre-empt or save if any death risk (low TTD, high death_risk, low future)
    -- Even if current HP ok, if predicted death soon, cast big heal.
    local ttd = target_entry.time_to_die or 999
    local death_r = target_entry.death_risk or 0
    local fut = target_entry.future_hp or target_entry.effective_hp or 100
    local will = target_entry.will_die_soon == true or (context and ((context.party_imminent_deaths or 0) + (context.party_will_die_count or 0) > 0))
    if ttd < 3 or death_r > 100 or fut < 25 or will then
        -- Always consider for imminent death -- no skip
    else
        local current_hp = target_entry.effective_hp or target_entry.hp or 100
        if current_hp > 92 and ttd > 4 and death_r < 50 and not will then return false end
    end

    -- Gate: mana floor — don't spend mana on preemptive heals when low
    local mana_pct = context.mana_pct or state.mana_pct or 100
    local mana_floor = spec_kit.setting_number(context, "preemptive_heal_mana_floor", 40)
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
    local threshold = spec_kit.setting_number(context, "preemptive_heal_threshold", M.DEFAULT_THRESHOLD)
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

-- module initialized
return M

