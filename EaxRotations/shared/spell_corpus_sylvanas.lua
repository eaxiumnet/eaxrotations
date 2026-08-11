-- spell_corpus_sylvanas.lua -- shared spell corpus used for parser fallback and lookup (Lua-key-value table).
-- WHAT:   shared spell corpus used for parser fallback and lookup (Lua-key-value table).
-- WHEN:   required at module load by parser call sites; pure constant data.
-- WHY:    single source of spell names/IDs across all spec files.
-- SAFETY: static Lua table; no api calls; nil-tolerant on key miss.
-- DECISION: pure data; consumed via require(); nil-tolerant key fetch.

-- ============================================================================
-- Shared Helper: Spell Corpus
-- ============================================================================
-- What:   Provides access to embedded wowhead spell data for rotation optimization.
-- When:   On-demand (cached). Used by spec files for spell metadata lookup.
-- Why:    Enrich spell decisions with data-driven spell cost, range, cast_time,
--         damage, periodic effects, and talent modifiers.
-- Safety: Read-only. Falls back gracefully if bridge module is unavailable.
--         Uses embedded Lua tables (ship-safe) — no io.open or JSON.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}
NS.SpellCorpus = M

-- ============================================================================
-- Data bridge — loads embedded spell data (ship-safe Lua tables)
-- ============================================================================
---@class SpellDetailEntry
---Positional fields from bridge.spell_detail:
---  1=cost_type, 2=cost_amount, 3=range, 4=cast_time, 5=duration,
---  6=periodic_amount, 7=periodic_school, 8=periodic_interval, 9=flags, 10=school, 11=gcd

local _bridge = nil
local function get_bridge()
    if _bridge then return _bridge end
    local ok, mod = pcall(require, "shared/wowhead_data_bridge_sylvanas")
    if ok and type(mod) == "table" then
        _bridge = mod
        return mod
    end
    return nil
end

-- ============================================================================
-- Cache: spell_id -> spell data table (false = miss, table = hit)
-- ============================================================================
local _spell_cache = {}

-- ============================================================================
-- Index loading (from bridge module — lightweight, load once)
-- ============================================================================
local _spell_index = {}
local _index_loaded = false

local function load_index()
    if _index_loaded then return end
    _index_loaded = true

    local bridge = get_bridge()
    if not bridge then return end

    -- Bridge: [spell_id] = {name, class, level, school, is_heal, aoe, cast_time, rank, gcd, cooldown_seconds}
    -- Pos:      1=name, 2=class, 3=level, 4=school, 5=is_heal, 6=aoe, 7=cast_time, 8=rank, 9=gcd, 10=cooldown_seconds
    local raw = bridge.spell_index_tbc
    if not raw then return end
    for id, entry in pairs(raw) do
        _spell_index[id] = {
            name = entry[1],
            class = entry[2],
            school = entry[4],
            is_heal = entry[5],
            aoe = entry[6],
            cast_time = entry[7],
            level = entry[3],
            gcd = entry[9],
            cooldown_seconds = entry[10],
        }
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get full spell data for a spell ID (from embedded bridge data).
--- Cached after first read. Returns nil if not found.
--- @param spell_id number Spell ID
--- @return table|nil data Full spell data, or nil if not found
function M.get_spell_info(spell_id)
    if not spell_id then return nil end
    local cached = _spell_cache[spell_id]
    if cached ~= nil then return cached or nil end

    local bridge = get_bridge()
    if not bridge or not bridge.spell_detail then
        _spell_cache[spell_id] = false
        return nil
    end

    local detail = bridge.spell_detail[spell_id]
    if not detail then
        _spell_cache[spell_id] = false
        return nil
    end

    -- Bridge detail format: positional array
    -- 1=cost_type, 2=cost_amount, 3=range, 4=cast_time, 5=duration,
    -- 6=periodic_amount, 7=periodic_school, 8=periodic_interval, 9=flags, 10=school, 11=gcd
    local index_entry = M.get_spell_index(spell_id)
    local data = {
        id = spell_id,
        name = index_entry and index_entry.name or nil,
        icon = nil,
        school = detail[10] or (index_entry and index_entry.school),
        cast_time = detail[4] or (index_entry and index_entry.cast_time),
        required_level = index_entry and index_entry.level,
        description = nil,
        duration = detail[5],
        target_type = nil,
        cost_type = detail[1],
        cost_amount = detail[2],
        periodic_amount = detail[6],
        periodic_school = detail[7],
        periodic_interval = detail[8],
        range = detail[3],
        has_buff = nil,
        buff_duration = nil,
        buff_text = nil,
        gcd = detail[11] or (index_entry and index_entry.gcd),
    }

    _spell_cache[spell_id] = data
    return data
end

--- Get lightweight spell info from the index (no per-spell file I/O).
--- @param spell_id number Spell ID
--- @return table|nil info {name, class, school, is_heal, aoe, cast_time, level}
function M.get_spell_index(spell_id)
    if not spell_id then return nil end
    load_index()
    return _spell_index[spell_id]
end



--- Get spell cost (convenience wrapper).
--- @param spell_id number Spell ID
--- @return number|nil cost_amount, string|nil cost_type
function M.get_spell_cost(spell_id)
    local info = M.get_spell_info(spell_id)
    if not info then return nil, nil end
    return info.cost_amount, info.cost_type
end

--- Get spell GCD in seconds.
--- @param spell_id number Spell ID
--- @return number|nil gcd_seconds (typically 1.5, 1.0, or 0.5)
function M.get_gcd(spell_id)
    if not spell_id then return nil end
    load_index()
    local info = _spell_index[spell_id]
    if not info then return nil end
    return info.gcd
end



return M

