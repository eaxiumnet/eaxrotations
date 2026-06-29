-- triage_sylvanas.lua — Smart healing target ranking + AoE cluster finder.
-- WHAT:  NS.Triage.rank (tank-priority + predicted-deficit-aware sort) and
--        NS.AoEHeal.best_target (cluster finder for Tranq/CoH/Chain Heal).
-- WHEN:  Loaded at startup by main.lua; used by all 5 healer specs.
-- WHY:   Consolidates NS.Triage + NS.AoEHeal that 5 healer specs reference with nil-guards.
-- SAFETY: All reads nil-guarded; returns empty table/nil on invalid input.
-- DECISION: healer triage scoring (tank bias 15% + focus bias 10%).
-- Decision: Keep rank() and best_target() in one module because both are small
--           and share the same load lifecycle (must be present before any
--           healer build_state runs).

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local table_sort = table.sort
local type = type
local ipairs = ipairs

local M = {}
NS.Triage = M
NS.AoEHeal = M

-- ---------------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------------
local DEFAULT_TANK_HP_BIAS = 15   -- Default tank bias: treat tank as 15% lower HP
local DEFAULT_FOCUS_BIAS = 10     -- Focus target gets 10% bias

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function safe_number(v, fallback)
    fallback = fallback or 0
    return type(v) == "number" and v or fallback
end

--- Compute a composite urgency score for a healing entry.
-- Lower score = higher urgency (sorted ascending).
-- Tank under 60% gets a large boost so they outrank anyone above them.
-- Tank HP bias: subtract bias_pct from effective HP so tanks outrank DPS at same HP.
-- @param entry     healing entry table
-- @param settings  table|nil  Context settings (tank_hp_bias, focus_hp_bias)
local function urgency_score(entry, settings)
    local hp = safe_number(entry.effective_hp, entry.hp, 100)
    local is_tank = entry.is_tank == true
    local is_focus = entry.is_focus == true
    local max_hp = safe_number(entry.max_hp, 1)
    local deficit = safe_number(entry.effective_deficit, entry.deficit, 0)

    settings = settings or (NS.settings or {})

    -- Apply configurable tank HP bias (default 15%)
    -- e.g. tank at 70% effective HP is treated as 55% for scoring
    local tank_bias = safe_number(settings.tank_hp_bias, DEFAULT_TANK_HP_BIAS)
    if is_tank and tank_bias > 0 then
        hp = hp - tank_bias
    end

    -- Apply focus target bias (default 10%)
    local focus_bias = safe_number(settings.focus_hp_bias, DEFAULT_FOCUS_BIAS)
    if is_focus and focus_bias > 0 then
        hp = hp - focus_bias
    end

    -- Base score: biased effective HP % (primary)
    local score = hp

    -- Tank priority: if tank is under 60%, subtract a large penalty
    if is_tank and hp < 60 then
        score = score - 200
    end

    -- Predicted deficit tie-breaker: use effective_deficit (already computed by
    -- build_healing_entries using HealerDeficit.predicted_deficit). Higher deficit
    -- lowers the score, pushing the entry earlier in the sorted result.
    local eff_deficit = safe_number(entry.effective_deficit, deficit)
    if max_hp > 0 then
        local deficit_pct = (eff_deficit / max_hp) * 100
        score = score - deficit_pct * 0.5
    end

    return score
end

-- ---------------------------------------------------------------------------
-- NS.Triage.rank
-- ---------------------------------------------------------------------------

--- Rank healing entries by urgency: tank-priority when low, then predicted deficit.
-- @param entries  array of { unit, hp, effective_hp, is_tank, max_hp, deficit, ... }
-- @param count    number of valid entries (may be nil; we use #entries)
-- @param settings table|nil  Context settings (tank_hp_bias, focus_hp_bias)
-- @return table   new sorted array, worst-first (most urgent at index 1)
function M.rank(entries, count, settings)
    if type(entries) ~= "table" then
        return {}
    end
    count = type(count) == "number" and count or #entries
    if count <= 0 then
        return {}
    end

    -- Copy valid entries into a new array
    local out = {}
    local n = 0
    for i = 1, count do
        local e = entries[i]
        if e and type(e) == "table" then
            n = n + 1
            out[n] = e
        end
    end

    if n == 0 then
        return {}
    end

    table_sort(out, function(a, b)
        return urgency_score(a, settings) < urgency_score(b, settings)
    end)

    return out
end

-- ---------------------------------------------------------------------------
-- NS.AoEHeal.best_target
-- ---------------------------------------------------------------------------

--- Find the best cluster center for AoE heals (Tranquility, CoH, PoH, Chain Heal).
-- Uses O(n^2) scan — n is small (<40 raid members), so this is fine.
-- @param entries      array of healing entries
-- @param count        number of valid entries
-- @param radius       radius in yards (e.g., 15 for Chain Heal, 40 for Tranq)
-- @param min_targets  minimum cluster size to consider (e.g., 3)
-- @return best_entry|nil, cluster_count
function M.best_target(entries, count, radius, min_targets)
    if type(entries) ~= "table" then
        return nil, 0
    end
    count = type(count) == "number" and count or #entries
    radius = type(radius) == "number" and radius or 15
    min_targets = type(min_targets) == "number" and min_targets or 3
    if count < min_targets then
        return nil, 0
    end

    local best_entry = nil
    local best_count = 0

    for i = 1, count do
        local center = entries[i]
        if center and center.unit then
            local cluster = 1 -- center counts as 1
            for j = 1, count do
                if i ~= j then
                    local other = entries[j]
                    if other and other.unit then
                        local dist = 999
                        if NS.unit_distance then
                            local ok, d = pcall(NS.unit_distance, center.unit, other.unit)
                            if ok and type(d) == "number" then
                                dist = d
                            end
                        end
                        if dist <= radius then
                            cluster = cluster + 1
                        end
                    end
                end
            end
            if cluster > best_count then
                best_count = cluster
                best_entry = center
            end
        end
    end

    if best_count >= min_targets then
        return best_entry, best_count
    end
    return nil, 0
end
