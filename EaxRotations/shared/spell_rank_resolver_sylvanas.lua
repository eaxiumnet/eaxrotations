-- spell_rank_resolver_sylvanas.lua -- pick the highest learned spell rank for a class+level using expansion gates.
-- WHAT:   pick the highest learned spell rank for a class+level using expansion gates
-- WHEN:   called during spec build_state to decide which ID list to use
-- WHY:    harmonises TBC vs TBC Anniversary (2.5.5) spell IDs across specs
-- SAFETY: pure function; uses is_spell_learned fallback chain
-- DECISION: consumed by specs via require(); no on_update side-effects.

-- What:   Auto-resolves spell rank chains from embedded wowhead spell data.
-- When:   Module load (cached). Used by spec files for rank-by-level lookups.
-- Why:    Replace hardcoded spell rank arrays with data-driven resolution.
--         Supports both TBC and Vanilla expansions with separate rank tables.
-- Safety: Read-only. Falls back gracefully if bridge module is unavailable.
--         All results cached at load time — no table traversal in hot paths.
--         Uses embedded Lua tables (ship-safe) — no io.open or JSON.

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}

-- ============================================================================
-- Data bridge — loads embedded spell index (ship-safe Lua tables)
-- ============================================================================
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
-- Rank tables: keyed by "name:class" -> sorted array of {id, level, rank}
-- Separate tables per expansion to support cross-expansion resolution.
-- Built from bridge module's spell_index_* tables on first access.
-- ============================================================================
local _rank_tables_tbc = {}     -- ["Fireball:Mage"] = {{id=27070,level=66,...}, ...}
local _rank_tables_vanilla = {} -- ["Fireball:Mage"] = {{id=133,level=1,...}, ...}
local _loaded_tbc = false
local _loaded_vanilla = false

-- Convert bridge's positional format to rank tables.
-- Bridge format: [spell_id] = {name, class, level, school, is_heal, aoe, cast_time, rank}
-- Positional: 1=name, 2=class, 3=level, 8=rank
local function build_rank_tables(spell_index)
    local groups = {}
    for id, entry in pairs(spell_index) do
        local name = entry[1]
        local cls = entry[2]
        local level = entry[3]
        local rank = entry[8]
        if name and cls then
            local key = name .. ":" .. cls
            local g = groups[key]
            if not g then
                g = {}
                groups[key] = g
            end
            local n = #g + 1
            g[n] = { id = id, level = level or 0, rank = rank }
        end
    end

    -- Sort each group: primary by level ascending, secondary by rank ascending
    for _, g in pairs(groups) do
        table.sort(g, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            local ar = a.rank or 9999
            local br = b.rank or 9999
            return ar < br
        end)
    end

    return groups
end

local function load_tbc_data()
    if _loaded_tbc then return end
    _loaded_tbc = true
    local bridge = get_bridge()
    if not bridge or not bridge.spell_index_tbc then return end
    _rank_tables_tbc = build_rank_tables(bridge.spell_index_tbc)
end

local function load_vanilla_data()
    if _loaded_vanilla then return end
    _loaded_vanilla = true
    local bridge = get_bridge()
    if not bridge or not bridge.spell_index_vanilla then return end
    _rank_tables_vanilla = build_rank_tables(bridge.spell_index_vanilla)
end

-- ============================================================================
-- Internal: resolve expansion key to rank table
-- ============================================================================
local function get_rank_table(expansion)
    if expansion == "vanilla" then
        load_vanilla_data()
        return _rank_tables_vanilla
    end
    -- Default: TBC
    load_tbc_data()
    return _rank_tables_tbc
end

--- Returns the current expansion key based on NS.is_vanilla().
--- @return string "vanilla" or "tbc"
local function current_expansion()
    if NS and NS.is_vanilla and NS.is_vanilla() then return "vanilla" end
    return "tbc"
end

-- ============================================================================
-- Internal: find the rank group for a spell name + optional class
-- ============================================================================
local function find_group(spell_name, class_name, expansion)
    if not spell_name then return nil end
    local tables = get_rank_table(expansion or current_expansion())

    if class_name then
        return tables[spell_name .. ":" .. class_name]
    end

    -- No class specified: try to find any matching group
    for key, g in pairs(tables) do
        local kname = key:match("^(.-):")
        if kname == spell_name then return g end
    end
    return nil
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get all spell IDs for a spell name, sorted by level ascending.
--- @param spell_name string Spell name (e.g., "Fireball")
--- @param class_name string|nil Optional class name (e.g., "Mage").
--- @param expansion string|nil Optional expansion override ("tbc" or "vanilla"). Defaults to current.
--- @return number[] ids Sorted array of spell IDs (ascending level), empty if not found
function M.get_spell_ranks(spell_name, class_name, expansion)
    local g = find_group(spell_name, class_name, expansion)
    if not g then return {} end
    local result = {}
    for i = 1, #g do result[i] = g[i].id end
    return result
end

--- Get the highest rank spell ID available at or below a player level.
--- @param spell_name string Spell name (e.g., "Fireball")
--- @param player_level number Player level
--- @param class_name string|nil Optional class filter
--- @param expansion string|nil Optional expansion override ("tbc" or "vanilla"). Defaults to current.
--- @return number|nil spell_id nil if no rank available at that level
function M.get_highest_rank(spell_name, player_level, class_name, expansion)
    if not spell_name or not player_level then return nil end
    local g = find_group(spell_name, class_name, expansion)
    if not g then return nil end

    local best = nil
    for i = 1, #g do
        if g[i].level <= player_level then
            best = g[i].id
        else
            break
        end
    end
    return best
end

--- Get the spell ID for a rank at a specific level.
--- @param spell_name string Spell name
--- @param level number Target level
--- @param class_name string|nil Optional class filter
--- @param expansion string|nil Optional expansion override
--- @return number|nil spell_id nil if no rank found
function M.get_rank_by_level(spell_name, level, class_name, expansion)
    return M.get_highest_rank(spell_name, level, class_name, expansion)
end

--- Check if a spell name exists in the rank database.
--- @param spell_name string Spell name
--- @param class_name string|nil Optional class filter
--- @param expansion string|nil Optional expansion override
--- @return boolean exists
function M.has_spell(spell_name, class_name, expansion)
    return find_group(spell_name, class_name, expansion) ~= nil
end

--- Get all spell names for a class.
--- @param class_name string Class name (e.g., "Mage")
--- @param expansion string|nil Optional expansion override
--- @return string[] names Array of spell names
function M.get_class_spell_names(class_name, expansion)
    if not class_name then return {} end
    local tables = get_rank_table(expansion or current_expansion())
    local seen = {}
    local result = {}
    local n = 0
    for key, _ in pairs(tables) do
        local kname, kclass = key:match("^(.-):(.-)$")
        if kclass == class_name and kname and not seen[kname] then
            seen[kname] = true
            n = n + 1
            result[n] = kname
        end
    end
    table.sort(result)
    return result
end

--- Get the rank count for a spell in the current (or specified) expansion.
--- Useful for cross-expansion validation (TBC has more ranks than Vanilla for most spells).
--- @param spell_name string Spell name
--- @param class_name string|nil Optional class filter
--- @param expansion string|nil Optional expansion override
--- @return number count Number of ranks (0 if spell not found)
function M.get_rank_count(spell_name, class_name, expansion)
    local g = find_group(spell_name, class_name, expansion)
    return g and #g or 0
end

--- Force reload all expansion data (for testing).
function M._reload()
    _loaded_tbc = false
    _loaded_vanilla = false
    _rank_tables_tbc = {}
    _rank_tables_vanilla = {}
    load_tbc_data()
    load_vanilla_data()
end

--- Force reload a specific expansion (for testing).
--- @param expansion string "tbc" or "vanilla"
function M._reload_expansion(expansion)
    if expansion == "vanilla" then
        _loaded_vanilla = false
        _rank_tables_vanilla = {}
        load_vanilla_data()
    else
        _loaded_tbc = false
        _rank_tables_tbc = {}
        load_tbc_data()
    end
end

--- Get which expansions are loaded (for diagnostics).
--- @return table { tbc = boolean, vanilla = boolean }
function M._loaded_expansions()
    load_tbc_data()
    load_vanilla_data()
    local tbc_count = 0
    for _ in pairs(_rank_tables_tbc) do tbc_count = tbc_count + 1 end
    local van_count = 0
    for _ in pairs(_rank_tables_vanilla) do van_count = van_count + 1 end
    return {
        tbc = tbc_count > 0,
        vanilla = van_count > 0,
        tbc_spell_groups = tbc_count,
        vanilla_spell_groups = van_count,
    }
end

-- ============================================================================
-- Attach to NS
-- ============================================================================
NS.SpellRankResolver = M

return M
