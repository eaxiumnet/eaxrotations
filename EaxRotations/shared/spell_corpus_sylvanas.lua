-- ============================================================================
-- Shared Helper: Spell Corpus
-- ============================================================================
-- What:   Provides access to wowhead spell data for rotation optimization.
-- When:   On-demand (cached). Used by spec files for spell metadata lookup.
-- Why:    Enrich spell decisions with data-driven spell cost, range, cast_time,
--         damage, periodic effects, and talent modifiers.
-- Safety: Read-only. Falls back gracefully if wowhead_data is unavailable.
--         Uses io.open (allowed) — NOT io.popen (banned).

local _G = _G
local NS = _G.EaxRotations
if not NS then return end

local M = {}
NS.SpellCorpus = M

-- ============================================================================
-- JSON decode (cjson-first, minimal fallback)
-- ============================================================================
local _json_decode = nil
do
    local ok, cjson = pcall(require, "cjson")
    if ok and type(cjson) == "table" then
        _json_decode = cjson.decode
    else
        -- Minimal JSON parser (same approach as dot_refresh_sylvanas.lua)
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
            local ok, result = pcall(parse_value, str, 1)
            if ok then return result end
            return nil
        end
    end
end

-- ============================================================================
-- Cache: spell_id -> spell data table (false = miss, table = hit)
-- ============================================================================
local _spell_cache = {}
local _index_loaded = false
local _spell_index = {}  -- spell_id -> {name, class, school, is_heal, aoe, cast_time, level}

-- ============================================================================
-- Helper: read file content
-- ============================================================================
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- ============================================================================
-- Index loading (spell_list_tbc.json — lightweight, load once)
-- ============================================================================
local function load_index()
    if _index_loaded then return end
    _index_loaded = true

    local content = read_file("wowhead_data/spell_list_tbc.json")
    if not content then return end

    local parsed = _json_decode(content)
    if type(parsed) ~= "table" then return end

    -- spell_list_tbc.json is an array of objects
    for _, entry in ipairs(parsed) do
        if type(entry) == "table" and entry.id then
            _spell_index[entry.id] = {
                name = entry.name,
                class = entry.required_class,  -- field is "required_class" in source
                school = entry.school,
                is_heal = entry.is_heal == true,
                aoe = entry.aoe == true,
                cast_time = entry.cast_time,
                level = entry.required_level,
            }
        end
    end
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Get full spell data for a spell ID (loads from individual JSON file).
--- Cached after first read. Returns nil if not found.
--- @param spell_id number Spell ID
--- @return table|nil data Full spell data, or nil if not found
function M.get_spell_info(spell_id)
    if not spell_id then return nil end
    local cached = _spell_cache[spell_id]
    if cached ~= nil then return cached or nil end

    local content = read_file("wowhead_data/spells/tbc/" .. spell_id .. ".json")
    if not content then
        content = read_file("wowhead_data/spells/vanilla/" .. spell_id .. ".json")
    end
    if not content then
        _spell_cache[spell_id] = false
        return nil
    end

    local parsed = _json_decode(content)
    if type(parsed) ~= "table" then
        _spell_cache[spell_id] = false
        return nil
    end

    -- Normalize nested objects into flat access
    local data = {
        id = parsed._id or spell_id,
        name = parsed.name,
        icon = parsed.icon,
        school = parsed.school,
        cast_time = parsed.cast_time,
        required_level = parsed.required_level,
        description = parsed.description,
        duration = parsed.duration,
        target_type = parsed.target_type,
    }

    -- Flatten cost: {type, amount} -> cost_type, cost_amount
    if type(parsed.cost) == "table" then
        data.cost_type = parsed.cost.type
        data.cost_amount = parsed.cost.amount
    end

    -- Flatten periodic: {amount, school, interval} -> periodic_amount, etc.
    if type(parsed.periodic) == "table" then
        data.periodic_amount = parsed.periodic.amount
        data.periodic_school = parsed.periodic.school
        data.periodic_interval = parsed.periodic.interval
    end

    -- Pass through range and buff data
    data.range = parsed.range
    data.has_buff = parsed.has_buff
    data.buff_duration = parsed.buff_duration
    data.buff_text = parsed.buff_text

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

--- Get all spells for a class from the index.
--- @param class_name string Class name (e.g., "Warlock", "Priest")
--- @return table spells Array of {id, name, school, is_heal, aoe, cast_time, level}
function M.get_class_spells(class_name)
    load_index()
    local result = {}
    local n = 0
    for id, info in pairs(_spell_index) do
        if info.class == class_name then
            n = n + 1
            result[n] = {
                id = id,
                name = info.name,
                school = info.school,
                is_heal = info.is_heal,
                aoe = info.aoe,
                cast_time = info.cast_time,
                level = info.level,
            }
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

--- Get periodic tick data for a spell (convenience wrapper).
--- @param spell_id number Spell ID
--- @return table|nil {amount, school, interval} or nil
function M.get_periodic_data(spell_id)
    local info = M.get_spell_info(spell_id)
    if not info or not info.periodic_amount then return nil end
    return {
        amount = info.periodic_amount,
        school = info.periodic_school,
        interval = info.periodic_interval,
    }
end

--- Get spell cost (convenience wrapper).
--- @param spell_id number Spell ID
--- @return number|nil cost_amount, string|nil cost_type
function M.get_spell_cost(spell_id)
    local info = M.get_spell_info(spell_id)
    if not info then return nil, nil end
    return info.cost_amount, info.cost_type
end

--- Search spells for a class by filter criteria.
--- @param class_name string Class name (e.g., "Warlock", "Priest")
--- @param filter table Criteria: {is_heal=bool, aoe=bool, school=string, max_level=number, name_contains=string}
--- @return table spells Array of matching {id, name, school, is_heal, aoe, cast_time, level}
function M.search_spells(class_name, filter)
    load_index()
    if not class_name then return {} end
    filter = filter or {}
    local result = {}
    local n = 0
    for id, info in pairs(_spell_index) do
        if info.class == class_name then
            local match = true
            if filter.is_heal ~= nil and info.is_heal ~= filter.is_heal then match = false end
            if filter.aoe ~= nil and info.aoe ~= filter.aoe then match = false end
            if filter.school and info.school ~= filter.school then match = false end
            if filter.max_level and info.level and info.level > filter.max_level then match = false end
            if filter.name_contains and info.name and not info.name:find(filter.name_contains, 1, true) then match = false end
            if match then
                n = n + 1
                result[n] = {
                    id = id,
                    name = info.name,
                    school = info.school,
                    is_heal = info.is_heal,
                    aoe = info.aoe,
                    cast_time = info.cast_time,
                    level = info.level,
                }
            end
        end
    end
    table.sort(result, function(a, b) return a.id < b.id end)
    return result
end

return M
