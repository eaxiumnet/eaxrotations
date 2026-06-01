-- ============================================================================
-- Shared Helper: Spell Rank Resolver
-- ============================================================================
-- What:   Auto-resolves spell rank chains from wowhead_data/spell_list_tbc.json.
-- When:   Module load (cached). Used by spec files for rank-by-level lookups.
-- Why:    Replace hardcoded spell rank arrays with data-driven resolution.
-- Safety: Read-only. Falls back gracefully if wowhead_data is unavailable.
--         All results cached at load time — no JSON parsing in hot paths.
--         Uses io.open (allowed) — NOT io.popen (banned).

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}

-- ============================================================================
-- JSON decode (cjson-first, minimal fallback)
-- ============================================================================
local _json_decode = nil
do
    local ok, cjson = pcall(require, "cjson")
    if ok and type(cjson) == "table" then
        _json_decode = cjson.decode
    else
        -- Minimal recursive JSON parser (same pattern as spell_corpus_sylvanas.lua)
        local function skip_ws(s, i)
            while i <= #s and s:sub(i, i):match("[ \t\n\r]") do i = i + 1 end
            return i
        end

        local function parse_number(s, i)
            i = skip_ws(s, i)
            local start = i
            if s:sub(i, i) == "-" then i = i + 1 end
            while i <= #s and s:sub(i, i):match("[0-9.]") do i = i + 1 end
            return tonumber(s:sub(start, i - 1)), i
        end

        local function parse_string(s, i)
            i = skip_ws(s, i)
            if s:sub(i, i) ~= '"' then return nil, i end
            i = i + 1
            local start = i
            while i <= #s and s:sub(i, i) ~= '"' do
                if s:sub(i, i) == "\\" then i = i + 1 end
                i = i + 1
            end
            return s:sub(start, i - 1), i + 1
        end

        local parse_value

        local function parse_object(s, i)
            i = skip_ws(s, i)
            i = i + 1  -- skip '{'
            local obj = {}
            while true do
                i = skip_ws(s, i)
                if s:sub(i, i) == "}" then return obj, i + 1 end
                local key
                key, i = parse_string(s, i)
                i = skip_ws(s, i)
                i = i + 1  -- skip ':'
                obj[key], i = parse_value(s, i)
                i = skip_ws(s, i)
                if s:sub(i, i) == "," then i = i + 1 end
            end
        end

        local function parse_array(s, i)
            i = skip_ws(s, i)
            i = i + 1  -- skip '['
            local arr = {}
            local n = 0
            while true do
                i = skip_ws(s, i)
                if s:sub(i, i) == "]" then return arr, i + 1 end
                n = n + 1
                arr[n], i = parse_value(s, i)
                i = skip_ws(s, i)
                if s:sub(i, i) == "," then i = i + 1 end
            end
        end

        parse_value = function(s, i)
            i = skip_ws(s, i)
            local c = s:sub(i, i)
            if c == '"' then return parse_string(s, i)
            elseif c == "{" then return parse_object(s, i)
            elseif c == "[" then return parse_array(s, i)
            elseif c == "t" then return true, i + 4
            elseif c == "f" then return false, i + 5
            elseif c == "n" then return nil, i + 4
            else return parse_number(s, i)
            end
        end

        _json_decode = function(str)
            if not str or #str == 0 then return nil end
            local ok2, result = pcall(parse_value, str, 1)
            if ok2 then return result end
            return nil
        end
    end
end

-- ============================================================================
-- File reader
-- ============================================================================
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- ============================================================================
-- Rank tables: keyed by "name:class" -> sorted array of {id, level, rank}
-- ============================================================================
local _rank_tables = {}  -- ["Fireball:Mage"] = {{id=133,level=1,rank=nil}, ...}
local _loaded = false

local function load_rank_data()
    if _loaded then return end
    _loaded = true

    local content = read_file("wowhead_data/spell_list_tbc.json")
    if not content then return end

    local parsed = _json_decode(content)
    if type(parsed) ~= "table" then return end

    -- Group by name:class to avoid cross-class name collisions
    local groups = {}
    for _, entry in ipairs(parsed) do
        if type(entry) == "table" and entry.id and entry.name and entry.required_class then
            local key = entry.name .. ":" .. entry.required_class
            local g = groups[key]
            if not g then
                g = {}
                groups[key] = g
            end
            local n = #g + 1
            g[n] = {
                id = entry.id,
                level = entry.required_level or 0,
                rank = entry.rank,
            }
        end
    end

    -- Sort each group: primary by level ascending, secondary by rank ascending
    -- Ascending order enables early-break in level-based lookups
    for _, g in pairs(groups) do
        table.sort(g, function(a, b)
            if a.level ~= b.level then return a.level < b.level end
            local ar = a.rank or 9999
            local br = b.rank or 9999
            return ar < br
        end)
    end

    _rank_tables = groups
end

-- ============================================================================
-- Internal: find the rank group for a spell name + optional class
-- ============================================================================
local function find_group(spell_name, class_name)
    if not spell_name then return nil end
    load_rank_data()

    if class_name then
        return _rank_tables[spell_name .. ":" .. class_name]
    end

    -- No class specified: try to find any matching group
    -- Exact key scan (bounded by number of unique spells, ~839)
    for key, g in pairs(_rank_tables) do
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
---        If nil, returns ranks from the first matching class.
--- @return number[] ids Sorted array of spell IDs (ascending level), empty if not found
function M.get_spell_ranks(spell_name, class_name)
    local g = find_group(spell_name, class_name)
    if not g then return {} end
    local result = {}
    for i = 1, #g do result[i] = g[i].id end
    return result
end

--- Get the highest rank spell ID available at or below a player level.
--- @param spell_name string Spell name (e.g., "Fireball")
--- @param player_level number Player level
--- @param class_name string|nil Optional class filter
--- @return number|nil spell_id nil if no rank available at that level
function M.get_highest_rank(spell_name, player_level, class_name)
    if not spell_name or not player_level then return nil end
    local g = find_group(spell_name, class_name)
    if not g then return nil end

    -- Array sorted ascending by level — walk forward, track last qualifying
    local best = nil
    for i = 1, #g do
        if g[i].level <= player_level then
            best = g[i].id
        else
            break  -- sorted ascending, no more qualifying entries
        end
    end
    return best
end

--- Get the spell ID for a rank at a specific level.
--- Returns the spell whose required_level is closest to (not exceeding) the
--- given level.
--- @param spell_name string Spell name
--- @param level number Target level
--- @param class_name string|nil Optional class filter
--- @return number|nil spell_id nil if no rank found
function M.get_rank_by_level(spell_name, level, class_name)
    return M.get_highest_rank(spell_name, level, class_name)
end

--- Check if a spell name exists in the rank database.
--- @param spell_name string Spell name
--- @param class_name string|nil Optional class filter
--- @return boolean exists
function M.has_spell(spell_name, class_name)
    return find_group(spell_name, class_name) ~= nil
end

--- Get all spell names for a class.
--- @param class_name string Class name (e.g., "Mage")
--- @return string[] names Array of spell names
function M.get_class_spell_names(class_name)
    if not class_name then return {} end
    load_rank_data()
    local seen = {}
    local result = {}
    local n = 0
    for key, _ in pairs(_rank_tables) do
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

--- Force reload (for testing).
function M._reload()
    _loaded = false
    _rank_tables = {}
    load_rank_data()
end

-- ============================================================================
-- Attach to NS
-- ============================================================================
NS.SpellRankResolver = M

return M
