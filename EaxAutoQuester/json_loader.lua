-- json_loader.lua — dependency-free JSON decoder for EaxAutoQuester.
-- WHAT:  decode(str) -> table|nil and load_data_file(path) -> table|nil, which reads
--        the file through core.read_data_file (the only runtime file API we touch).
-- WHEN:  lazy data loads only (npc_db_sylvanas loads the NPC spawn index on first
--        lookup); nothing here is ever called from a per-frame path.
-- WHY:   npc_db_sylvanas requires a "json_loader" module that the runtime does not
--        ship and that was not in this repo, so ensure_data() always failed and every
--        spawn lookup silently returned nil. Ship the decoder with the plugin so the
--        data path is deterministic and testable instead of depending on a module
--        that may or may not exist in a given client build.
-- SAFETY: pure Lua 5.1 (no loadstring/ffi/io/os.execute); core.read_data_file is
--         pcall-guarded; parse errors return nil plus a message instead of throwing;
--         results are cached per path so an 8 MB spawn index is parsed at most once.
--         Scanner uses string.find jumps rather than per-character s:sub() calls, so
--         a multi-megabyte document does not allocate once per byte.

local M = {}

-- ============================================================================
-- Cached document tables, keyed by the path passed to load_data_file.
-- ============================================================================

local _cache = {}

-- ============================================================================
-- Scanner helpers
-- ============================================================================

-- Whitespace skipped with a single pattern jump (no per-character loop).
local function skip_ws(s, i)
    local j = s:find("[^ \t\r\n]", i)
    return j or (#s + 1)
end

local ESCAPES = {
    ['"'] = '"',
    ["\\"] = "\\",
    ["/"] = "/",
    b = "\b",
    f = "\f",
    n = "\n",
    r = "\r",
    t = "\t",
}

-- Encode a Unicode code point as UTF-8 bytes (Lua 5.1 has no utf8 library).
local function utf8_encode(code)
    if code < 0x80 then
        return string.char(code)
    elseif code < 0x800 then
        return string.char(0xC0 + math.floor(code / 0x40), 0x80 + (code % 0x40))
    elseif code < 0x10000 then
        return string.char(
            0xE0 + math.floor(code / 0x1000),
            0x80 + (math.floor(code / 0x40) % 0x40),
            0x80 + (code % 0x40)
        )
    end
    return string.char(
        0xF0 + math.floor(code / 0x40000),
        0x80 + (math.floor(code / 0x1000) % 0x40),
        0x80 + (math.floor(code / 0x40) % 0x40),
        0x80 + (code % 0x40)
    )
end

local parse_value  -- forward declaration (mutually recursive with containers)

--- Parse one JSON string starting at the opening quote.
--- @param s string Document
--- @param i integer Index of the opening quote
--- @return string|nil value
--- @return integer|nil next_index
--- @return string|nil err
local function parse_string(s, i)
    local buf, n = {}, 0
    i = i + 1  -- skip opening quote

    while true do
        local stop = s:find('["\\]', i)
        if not stop then return nil, nil, "unterminated string" end

        if stop > i then
            n = n + 1
            buf[n] = s:sub(i, stop - 1)   -- whole run at once
        end

        if s:sub(stop, stop) == '"' then
            return table.concat(buf), stop + 1, nil
        end

        -- Backslash escape starting at `stop`.
        local esc = s:sub(stop + 1, stop + 1)
        if esc == "" then return nil, nil, "truncated escape" end

        if esc == "u" then
            local hex = s:sub(stop + 2, stop + 5)
            if #hex < 4 then return nil, nil, "truncated \\u escape" end
            local code = tonumber(hex, 16)
            if not code then return nil, nil, "bad \\u escape" end
            i = stop + 6

            -- Surrogate pair: high surrogate followed by a low surrogate.
            if code >= 0xD800 and code <= 0xDBFF and s:sub(i, i + 1) == "\\u" then
                local low = tonumber(s:sub(i + 2, i + 5), 16)
                if low and low >= 0xDC00 and low <= 0xDFFF then
                    code = 0x10000 + (code - 0xD800) * 0x400 + (low - 0xDC00)
                    i = i + 6
                end
            end

            n = n + 1
            buf[n] = utf8_encode(code)
        else
            local mapped = ESCAPES[esc]
            if not mapped then return nil, nil, "unknown escape \\" .. esc end
            n = n + 1
            buf[n] = mapped
            i = stop + 2
        end
    end
end

--- Parse one JSON number starting at i.
local function parse_number(s, i)
    local num_str = s:match("^[-+]?%d+%.?%d*[eE]?[-+]?%d*", i)
    if not num_str or num_str == "" then return nil, nil, "bad number" end
    local num = tonumber(num_str)
    if not num then return nil, nil, "bad number: " .. num_str end
    return num, i + #num_str, nil
end

--- Parse a JSON array starting at the opening bracket.
local function parse_array(s, i)
    local arr, n = {}, 0
    i = skip_ws(s, i + 1)

    if s:sub(i, i) == "]" then return arr, i + 1, nil end

    while true do
        local val, next_i, err = parse_value(s, skip_ws(s, i))
        if err then return nil, nil, err end
        n = n + 1
        arr[n] = val
        i = skip_ws(s, next_i)

        local c = s:sub(i, i)
        if c == "," then
            i = skip_ws(s, i + 1)
        elseif c == "]" then
            return arr, i + 1, nil
        else
            return nil, nil, "expected ',' or ']' in array"
        end
    end
end

--- Parse a JSON object starting at the opening brace.
local function parse_object(s, i)
    local obj = {}
    i = skip_ws(s, i + 1)

    if s:sub(i, i) == "}" then return obj, i + 1, nil end

    while true do
        i = skip_ws(s, i)
        if s:sub(i, i) ~= '"' then return nil, nil, "expected object key" end

        local key, after_key, key_err = parse_string(s, i)
        if key_err then return nil, nil, key_err end

        i = skip_ws(s, after_key)
        if s:sub(i, i) ~= ":" then return nil, nil, "expected ':' after key" end

        local val, next_i, err = parse_value(s, skip_ws(s, i + 1))
        if err then return nil, nil, err end
        obj[key] = val

        i = skip_ws(s, next_i)
        local c = s:sub(i, i)
        if c == "," then
            i = skip_ws(s, i + 1)
        elseif c == "}" then
            return obj, i + 1, nil
        else
            return nil, nil, "expected ',' or '}' in object"
        end
    end
end

--- Dispatch on the next non-whitespace character.
--- @return any value, integer|nil next_index, string|nil err
function parse_value(s, i)
    local c = s:sub(i, i)

    if c == "{" then return parse_object(s, i) end
    if c == "[" then return parse_array(s, i) end
    if c == '"' then return parse_string(s, i) end

    if c == "t" then
        if s:sub(i, i + 3) == "true" then return true, i + 4, nil end
        return nil, nil, "bad literal"
    end
    if c == "f" then
        if s:sub(i, i + 4) == "false" then return false, i + 5, nil end
        return nil, nil, "bad literal"
    end
    if c == "n" then
        if s:sub(i, i + 3) == "null" then return nil, i + 4, nil end
        return nil, nil, "bad literal"
    end

    return parse_number(s, i)
end

-- ============================================================================
-- Public API
-- ============================================================================

--- Decode a JSON document.
--- @param raw string JSON text
--- @return table|nil data Decoded value (nil when the document is not valid JSON)
--- @return string|nil err Error message when decoding failed
function M.decode(raw)
    if type(raw) ~= "string" or raw == "" then return nil, "empty input" end

    local ok, data, _, err = pcall(function()
        local i = skip_ws(raw, 1)
        return parse_value(raw, i)
    end)

    if not ok then return nil, tostring(data) end
    if err then return nil, err end
    if type(data) ~= "table" then return nil, "root value is not an object/array" end
    return data, nil
end

--- Read and decode a data file through core.read_data_file.
--- Cached: the file is read and parsed at most once per path per session.
--- @param path string Data-file path, e.g. "tbc_db/creature_spawn_index.json"
--- @return table|nil data
function M.load_data_file(path)
    if type(path) ~= "string" or path == "" then return nil end

    local cached = _cache[path]
    if cached ~= nil then return cached end

    local c = rawget(_G, "core")
    if type(c) ~= "table" or type(c.read_data_file) ~= "function" then return nil end

    local read_ok, raw = pcall(c.read_data_file, path)
    if not read_ok or type(raw) ~= "string" or raw == "" then return nil end

    local data = M.decode(raw)
    if type(data) ~= "table" then return nil end

    _cache[path] = data
    return data
end

--- Drop cached documents (tests and /reload use this).
function M.clear_cache()
    _cache = {}
end

_G.EaxAutoQuester = _G.EaxAutoQuester or {}
_G.EaxAutoQuester.json_loader = M

return M
