-- ============================================================================
-- Shared Helper: Spell Rank Resolver
-- ============================================================================
-- What:   Auto-resolves spell ranks from wowhead_data spell index.
-- When:   At module load time (cached). Used by spec files for rank selection.
-- Why:    Replace hardcoded spell rank arrays with data-driven resolution.
-- Safety: Read-only. Falls back gracefully if wowhead_data is unavailable.
--         Only reads file at load time, never in on_update.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
NS.SpellRankResolver = M

-- Cache: spell_name -> { {id=133, level=1}, {id=143, level=6}, ... }
-- Sorted by level descending (higher level = higher rank for rankless spells)
local _rank_cache = {}
local _loaded = false

-- Load and index spell ranks from wowhead_data.
-- Called once at module load; results cached for runtime.
local function load_spell_data()
    if _loaded then return end
    _loaded = true

    -- Try to load the spell list index
    local ok, content = pcall(function()
        local f = io.open("wowhead_data/spell_list_tbc.json", "r")
        if not f then return nil end
        local data = f:read("*a")
        f:close()
        return data
    end)

    if not ok or not content or content == "" then return end

    -- Parse JSON manually (lightweight — the format is predictable)
    -- Each entry: {"id":133,"name":"Fireball","rank":null,...,"required_level":1,...}
    for entry in content:gmatch('{[^}]+}') do
        local id = entry:match('"id"%s*:%s*(%d+)')
        local name = entry:match('"name"%s*:%s*"([^"]+)"')
        local class_name = entry:match('"required_class"%s*:%s*"([^"]*)"')
        local rank_str = entry:match('"rank"%s*:%s*(%d+)')
        local level_str = entry:match('"required_level"%s*:%s*(%d+)')

        if id and name then
            id = tonumber(id)
            local rank = rank_str and tonumber(rank_str) or nil
            local level = level_str and tonumber(level_str) or 0

            if not _rank_cache[name] then
                _rank_cache[name] = {}
            end

            local entry_count = #_rank_cache[name] + 1
            _rank_cache[name][entry_count] = {
                id = id,
                class = class_name,
                rank = rank,
                level = level,
            }
        end
    end

    -- Sort each spell's ranks:
    -- - If spells have explicit ranks, sort by rank descending
    -- - Otherwise sort by required_level descending (higher level = higher rank)
    for _, ranks in pairs(_rank_cache) do
        table.sort(ranks, function(a, b)
            -- Prefer explicit rank if both have it
            if a.rank and b.rank then return a.rank > b.rank end
            -- Fall back to level
            return a.level > b.level
        end)
    end
end

-- Public API ----------------------------------------------------------------

--- Get all rank entries for a spell name, sorted highest-first.
---@param spell_name string Spell name (e.g., "Fireball")
---@return table ranks Array of {id, class, rank, level} sorted by rank (highest first)
function M.get_spell_ranks(spell_name)
    load_spell_data()
    return _rank_cache[spell_name] or {}
end

--- Get the highest rank ID for a spell name.
---@param spell_name string Spell name
---@return number|nil spell_id Highest rank spell ID, or nil if not found
function M.get_highest_rank(spell_name)
    local ranks = M.get_spell_ranks(spell_name)
    if #ranks > 0 then return ranks[1].id end
    return nil
end

--- Get a specific rank by index (1 = highest).
---@param spell_name string Spell name
---@param rank number Rank index (1 = highest)
---@return number|nil spell_id
function M.get_rank(spell_name, rank)
    local ranks = M.get_spell_ranks(spell_name)
    return ranks[rank] and ranks[rank].id or nil
end

--- Get all rank IDs as a flat array, highest-first.
---@param spell_name string Spell name
---@return number[] ids Array of spell IDs, highest rank first
function M.get_rank_ids(spell_name)
    local ranks = M.get_spell_ranks(spell_name)
    local ids = {}
    for i = 1, #ranks do
        ids[i] = ranks[i].id
    end
    return ids
end

--- Check if a spell name exists in the database.
---@param spell_name string Spell name
---@return boolean exists
function M.has_spell(spell_name)
    load_spell_data()
    return _rank_cache[spell_name] ~= nil
end

--- Get rank entry for a specific spell ID (reverse lookup).
---@param spell_id number Spell ID
---@return table|nil entry {name, rank, level, class} or nil if not found
function M.get_spell_info(spell_id)
    load_spell_data()
    for name, ranks in pairs(_rank_cache) do
        for _, entry in ipairs(ranks) do
            if entry.id == spell_id then
                return {
                    name = name,
                    rank = entry.rank,
                    level = entry.level,
                    class = entry.class,
                }
            end
        end
    end
    return nil
end

--- Get all spells for a specific class.
---@param class_name string Class name (e.g., "Mage", "Priest")
---@return table spells Map of spell_name -> ranks_array
function M.get_class_spells(class_name)
    load_spell_data()
    local result = {}
    for name, ranks in pairs(_rank_cache) do
        for _, entry in ipairs(ranks) do
            if entry.class == class_name then
                result[name] = ranks
                break
            end
        end
    end
    return result
end

--- Force reload (for testing).
function M._reload()
    _loaded = false
    _rank_cache = {}
    load_spell_data()
end

return M
