-- ============================================================================
-- Shared Helper: Triage Scoring System
-- ============================================================================
-- What:   Ranks healing targets by urgency using a weighted multi-factor score,
--         replacing naive "lowest HP" targeting with intelligent prioritization.
-- When:   Called by healer spec files to rank healing_entries before target selection.
-- Why:    A unit at 40% HP with 2s TTD is more urgent than a unit at 30% HP with
--         20s TTD. Triage scoring captures this by combining HP, time-to-death,
--         role, debuffs, and incoming damage into a single comparable score.
-- Safety: All inputs are nil-guarded with sensible defaults. Falls back to
--         HP-only scoring when advanced data is unavailable.
--
-- Usage:
--   local triage = NS.Triage
--   local entries, count = scan_healing_targets()
--   local ranked = triage.rank(entries, count, context)
--   -- ranked[1] is the most urgent target
-- ============================================================================

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local math_max = math.max
local math_min = math.min
local table_sort = table.sort

local M = {}
NS.Triage = M

-- ---------------------------------------------------------------------------
-- Configuration: Weight factors (sum to 1.0)
-- ---------------------------------------------------------------------------
local WEIGHT_HP         = 0.35  -- Effective HP% (lower = more urgent)
local WEIGHT_TTD        = 0.30  -- Time-to-death (shorter = more urgent)
local WEIGHT_ROLE       = 0.15  -- Tank > Healer > DPS priority
local WEIGHT_DEBUFF     = 0.10  -- Healing reduction debuffs
local WEIGHT_INCOMING   = 0.10  -- Incoming damage rate

-- Role scores
local ROLE_SCORE_TANK   = 1.0
local ROLE_SCORE_HEALER = 0.6
local ROLE_SCORE_DPS    = 0.3
-- local ROLE_SCORE_DEFAULT = 0.3  -- reserved for future use

-- TTD thresholds (seconds)
local TTD_CRITICAL  = 3.0   -- About to die
local TTD_URGENT    = 6.0   -- Needs healing soon
local TTD_MODERATE  = 12.0  -- Can wait a bit

-- Healing reduction debuff IDs (TBC)
local HEALING_REDUCTION_IDS = {
    [12294] = 0.50, [21551] = 0.50, [21552] = 0.50, [21553] = 0.50,
    [25248] = 0.50, [30330] = 0.50, -- Mortal Strike ranks
    [19434] = 0.50, [20900] = 0.50, [20901] = 0.50, [20902] = 0.50,
    [20903] = 0.50, [20904] = 0.50, [27065] = 0.50, -- Aimed Shot ranks
    [13218] = 0.30, [13222] = 0.30, [13223] = 0.30, [13224] = 0.30,
    [27189] = 0.30, -- Wound Poison ranks
}

-- Boss debuffs that demand immediate healing attention
local BOSS_DEBUFF_CRITICAL = {
    -- TBC Raid Boss debuffs (high damage or healing reduction)
    [32231] = true,  -- Chaos Nova (Magtheridon)
    [34662] = true,  -- Bear Down (Gruul)
    [30495] = true,  -- Shadow of Death (High King Maulgar)
    [38029] = true,  -- Neurotoxin (Lady Vashj)
    [37676] = true,  -- Insignificance (Archimonde)
    [37850] = true,  -- Watery Grave (Morogrim Tidewalker)
    [39042] = true,  -- Rapid Burst (Kil'jaeden)
    [41303] = true,  -- Soul Drain (Reliquary of Souls)
    [41410] = true,  -- Deaden (Illidari Council)
    [40585] = true,  -- Dark Barrage (Illidan)
}

-- ---------------------------------------------------------------------------
-- Internal: compute per-factor scores (0.0 to 1.0, higher = more urgent)
-- ---------------------------------------------------------------------------

local function score_hp(entry)
    local effective_hp = entry.effective_hp
    if not effective_hp then return 0 end
    -- 0% HP = score 1.0, 100% HP = score 0.0
    return math_max(0, 1.0 - effective_hp / 100)
end

local function score_ttd(entry)
    local ttd = entry.time_to_die
    if not ttd or ttd >= 999 then return 0 end
    if ttd <= TTD_CRITICAL then return 1.0 end
    if ttd <= TTD_URGENT then return 0.7 end
    if ttd <= TTD_MODERATE then return 0.3 end
    return 0
end

local function score_role(entry)
    -- Check is_tank flag first (set by build_healing_entries)
    if entry.is_tank then return ROLE_SCORE_TANK end
    -- Check for healer role via group role API
    local unit = entry.unit
    if unit then
        local role_fn = unit.get_group_role
        if role_fn then
            local ok, role = pcall(role_fn, unit)
            if ok then
                if role == 0 then return ROLE_SCORE_TANK end   -- Tank
                if role == 1 then return ROLE_SCORE_HEALER end -- Healer
            end
        end
    end
    return ROLE_SCORE_DPS
end

local function score_debuff(entry)
    local unit = entry.unit
    if not unit then return 0 end
    -- Check healing reduction debuffs
    if NS.has_healing_reduction_debuff and NS.has_healing_reduction_debuff(unit) then
        return 0.8
    end
    -- Check critical boss debuffs
    local has_debuff = unit.has_debuff
    if has_debuff then
        for debuff_id in pairs(BOSS_DEBUFF_CRITICAL) do
            local ok, result = pcall(has_debuff, unit, debuff_id)
            if ok and result then return 1.0 end
        end
    end
    return 0
end

local function score_incoming(entry)
    local dps = entry.incoming_dps
    if not dps or dps <= 0 then return 0 end
    -- Normalize: 1000 DPS = 0.5, 2000+ DPS = 1.0
    return math_min(1.0, dps / 2000)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Compute triage score for a single healing entry.
-- Higher score = more urgent target.
---@param entry table Healing entry from build_healing_entries
---@return number score 0.0 to ~1.5 (can exceed 1.0 with debuffs)
function M.score(entry)
    if not entry then return 0 end

    local hp_s   = score_hp(entry)
    local ttd_s  = score_ttd(entry)
    local role_s = score_role(entry)
    local deb_s  = score_debuff(entry)
    local inc_s  = score_incoming(entry)

    return hp_s  * WEIGHT_HP
         + ttd_s * WEIGHT_TTD
         + role_s * WEIGHT_ROLE
         + deb_s  * WEIGHT_DEBUFF
         + inc_s  * WEIGHT_INCOMING
end

--- Rank healing entries by triage urgency (most urgent first).
-- Returns a new sorted array — does not modify the original.
---@param entries table Array of healing entries
---@param count number Number of entries
---@return table ranked Sorted array (most urgent first)
function M.rank(entries, count)
    if not entries or count <= 0 then return {} end

    -- Build scored array (reuse static table to avoid garbage)
    local scored = {}
    for i = 1, count do
        scored[i] = { entry = entries[i], score = M.score(entries[i]) }
    end

    -- Sort by score descending (highest urgency first)
    table_sort(scored, function(a, b) return a.score > b.score end)

    -- Extract sorted entries
    local ranked = {}
    for i = 1, count do
        ranked[i] = scored[i].entry
        ranked[i]._triage_score = scored[i].score
    end

    return ranked
end

--- Get the most urgent healing target (convenience wrapper).
---@param entries table Array of healing entries
---@param count number Number of entries
---@return table|nil entry Most urgent target, or nil if no entries
function M.get_top(entries, count)
    if not entries or count <= 0 then return nil end

    local best_entry = entries[1]
    local best_score = M.score(entries[1])

    for i = 2, count do
        local s = M.score(entries[i])
        if s > best_score then
            best_score = s
            best_entry = entries[i]
        end
    end

    return best_entry
end
