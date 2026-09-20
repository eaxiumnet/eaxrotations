-- test_lua51_compat.lua — hard gate: the plugin must be valid Lua 5.1 / LuaJIT.
-- WHAT:  masks comments and string bodies, then fails with file:line on
--        (1) names that do not exist on the 5.1 runtime the game ships,
--        (2) syntax tokens Lua 5.1 does not have,
--        (3) string escapes Lua 5.1 silently mangles instead of rejecting,
--        (4) 5.1-valid names that 5.2+ REMOVED (portability pin: each has a
--            5.1-and-later spelling, so there is no reason to use it).
-- WHEN:  part of the plugin battery (`run_quester_tests.lua`), so it runs in
--        tools/pre-commit step 20 and the CI quester step.
-- WHY:   `luac -p` cannot catch (1) or (3). A post-5.1 stdlib name parses fine and
--        only explodes at runtime; and 5.1's lexer ACCEPTS an unknown escape
--        (backslash-d, backslash-x, ...) and mangles it rather than erroring, so a
--        parse-only gate is silent for both classes.
-- SAFETY: read-only, source-text only, no runtime behaviour touched.
--        Deliberately NOT banned: unpack / setfenv / getfenv / loadstring are
--        5.1-only APIs with no 5.1-and-later spelling. The one live use
--        (`unpack` in safe_api_wrapper.lua) sits inside a pcall, so on a 5.2+
--        interpreter the probe degrades to "unavailable" instead of throwing.
--        This file scans itself, which is why it carries no escape literals:
--        quotes, newlines and backslashes are all built with string.char.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local lfs_ok, lfs = pcall(require, "lfs")
assert(lfs_ok and lfs, "luafilesystem is required to enumerate the plugin for the compat gate")

local function plugin_root()
    for _, prefix in ipairs({ "EaxAutoQuester/", "" }) do
        local f = io.open(prefix .. "main.lua", "r")
        if f then
            f:close()
            return prefix
        end
    end
    return nil
end

local ROOT = plugin_root()
assert(ROOT, "could not locate the plugin root (main.lua)")

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

-- =============================================================================
-- Character constants and scanner
-- =============================================================================

local NL = string.char(10)   -- newline
local CR = string.char(13)   -- carriage return
local DQ = string.char(34)   -- double quote
local SQ = string.char(39)   -- single quote
local BS = string.char(92)   -- backslash

-- Escapes Lua 5.1 accepts. Anything else is silently mangled by 5.1.
local VALID_ESCAPE = {
    a = true, b = true, f = true, n = true, r = true, t = true, v = true,
    [DQ] = true,
    [SQ] = true,
    [BS] = true,
    [NL] = true,
}
for d = 0, 9 do VALID_ESCAPE[tostring(d)] = true end

-- (2) Syntax tokens absent from plain Lua 5.1. `luac -p` also rejects these, so
-- this half is belt-and-braces for readers of the failure output.
local SYNTAX_TOKENS = {
    { token = "//", label = "integer division (Lua 5.3+)" },
    { token = "<<", label = "bitwise shift left (Lua 5.3+)" },
    { token = ">>", label = "bitwise shift right (Lua 5.3+)" },
    { token = "&", label = "bitwise and (Lua 5.3+)" },
    { token = "|", label = "bitwise or (Lua 5.3+)" },
    { token = "::", label = "label / goto target (Lua 5.2+, not plain 5.1)" },
}

-- (1) Names that do not exist on the 5.1 runtime: calling one is a runtime error
-- in game and in the 5.1 battery, but a clean parse everywhere.
local POST_5_1_NAMES = {
    "table.pack", "table.unpack", "table.move",
    "rawlen", "bit32", "utf8.",
    "math.type", "math.tointeger", "math.maxinteger", "math.mininteger",
    "string.pack", "string.unpack",
}

-- (4) 5.1-valid, removed in 5.2+. Each has a 5.1-and-later spelling, so the pin
-- costs nothing today and stops the class that produced the math.pow incident.
local LEGACY_5_1_NAMES = {
    "math.pow", "math.mod", "table.getn", "table.setn", "table.maxn", "string.gfind",
}

--- Find a BARE reference to `name`: not preceded by an identifier character,
--- dot or colon (so `mytable.packer` and `obj:load(...)` are not hits), and when
--- the name ends in an identifier character, not followed by one either (so
--- `math.power` is not a hit for `math.pow`).
--- @return integer|nil position of the first bare occurrence
local function find_bare(masked, name)
    local init = 1
    local end_char = name:sub(-1)
    local end_is_ident = end_char:match("[%w_]") ~= nil
    while true do
        local s, e = masked:find(name, init, true)
        if not s then return nil end
        local before = s > 1 and masked:sub(s - 1, s - 1) or ""
        local after = masked:sub(e + 1, e + 1)
        local ok_before = before == "" or before:match("[%w_.:]") == nil
        local ok_after = (not end_is_ident) or after == "" or after:match("[%w_]") == nil
        if ok_before and ok_after then return s end
        init = s + 1
    end
end

local function line_of(src, pos)
    local line = 1
    for _ in src:sub(1, pos):gmatch(NL) do line = line + 1 end
    return line
end

--- Replace comments and string/comment bodies with spaces (newlines preserved) so
--- offsets in the result map 1:1 onto the source.
--- @return string masked, table escape_violations
local function mask(src)
    local out, viol, i, n = {}, {}, 1, #src

    local function report(pos, message)
        viol[#viol + 1] = { line = line_of(src, pos), message = message }
    end

    while i <= n do
        local c = src:sub(i, i)

        -- long bracket: [[ ]], [=[ ]=]
        if c == "[" and src:match("^%[(=*)%[", i) then
            local eqs = src:match("^%[(=*)%[", i)
            local close = "]" .. eqs .. "]"
            local j = src:find(close, i, true)
            j = j and (j + #close - 1) or n
            out[#out + 1] = (src:sub(i, j):gsub("[^" .. NL .. "]", " "))
            i = j + 1

        -- comment
        elseif src:sub(i, i + 1) == "--" then
            local j = src:find(NL, i, true)
            j = j and (j - 1) or n
            out[#out + 1] = (src:sub(i, j):gsub("[^" .. NL .. "]", " "))
            i = j + 1

        -- quoted string: mask the body, validate its escapes
        elseif c == DQ or c == SQ then
            local j = i + 1
            while j <= n do
                local ch = src:sub(j, j)
                if ch == BS then
                    local esc = src:sub(j + 1, j + 1)
                    if not VALID_ESCAPE[esc] then
                        report(j, "unknown escape " .. BS .. esc ..
                            " — Lua 5.1 mangles it silently")
                    end
                    j = j + 2
                elseif ch == c then
                    j = j + 1
                    break
                elseif ch == NL then
                    break
                else
                    j = j + 1
                end
            end
            out[#out + 1] = (src:sub(i, j - 1):gsub("[^" .. NL .. "]", " "))
            i = j

        -- plain code: copy up to the next character that can start a comment/string
        else
            -- search from i + 1: the char at i is already known to be plain code, so
            -- this always advances (a bare - or [ used to spin here until OOM)
            local j = src:find("[" .. "-" .. DQ .. SQ .. "[]", i + 1)
            j = j or (n + 1)
            out[#out + 1] = src:sub(i, j - 1)
            i = j
        end
    end

    return table.concat(out), viol
end

--- Scan one source string. Returns a list of { file, line, message, kind }.
local function scan_source(name, src)
    local violations = {}
    local masked, escape_violations = mask(src)
    for _, v in ipairs(escape_violations) do
        v.kind = "escape"
        violations[#violations + 1] = v
    end

    for _, entry in ipairs(SYNTAX_TOKENS) do
        local pos = masked:find(entry.token, 1, true)
        while pos do
            violations[#violations + 1] = {
                line = line_of(src, pos), kind = "syntax",
                message = entry.label .. " (" .. entry.token .. ")",
            }
            pos = masked:find(entry.token, pos + 1, true)
        end
    end

    -- The tilde operator is 5.3+; on 5.1 the character only ever appears in "~=".
    local tilde_free = masked:gsub("~=", "  ")
    local tpos = tilde_free:find("~", 1, true)
    if tpos then
        violations[#violations + 1] = {
            line = line_of(src, tpos), kind = "syntax",
            message = "bitwise not/xor (Lua 5.3+): tilde outside ~=",
        }
    end

    for pos in masked:gmatch("()%f[%a]goto%f[%A]") do
        violations[#violations + 1] = {
            line = line_of(src, pos), kind = "syntax",
            message = "goto (Lua 5.2+, absent in plain Lua 5.1)",
        }
    end

    local function collect(names, kind, suffix, validate)
        for _, banned in ipairs(names) do
            while true do
                local pos = find_bare(masked, banned)
                if not pos then break end
                if not validate or validate(pos) then
                    violations[#violations + 1] = {
                        line = line_of(src, pos), kind = kind,
                        message = banned .. suffix,
                    }
                end
                -- blank this hit in a working copy so the scan advances
                masked = masked:sub(1, pos - 1) .. string.rep(" ", #banned) ..
                    masked:sub(pos + #banned)
            end
        end
    end

    collect(POST_5_1_NAMES, "unavailable", " does not exist on Lua 5.1/LuaJIT")
    -- load() in 5.1 takes a FUNCTION (loadstring takes the text form); a literal
    -- string argument is the 5.2+ signature, so inspect the original source, not
    -- the masked copy, where the quote has already been blanked out.
    collect({ "load(" }, "unavailable",
        " with a string literal: 5.1 takes a function; the string form is loadstring()",
        function(pos)
            local k2 = pos + 5
            while src:sub(k2, k2):match("%s") do k2 = k2 + 1 end
            local c2 = src:sub(k2, k2)
            return c2 == DQ or c2 == SQ
        end)
    collect(LEGACY_5_1_NAMES, "pin",
        " is 5.1-only (removed in 5.2+) — use the 5.1-and-later spelling")

    for _, v in ipairs(violations) do v.file = name end
    return violations
end

--- Generated data chunks: no masking, just skip their header comments. Their Lua
--- syntax is proven separately by `luac -p` (pre-commit step 1, which sweeps
--- EaxAutoQuester/), so this only has to rule out post-5.1 stdlib NAMES.
local function scan_chunk(name, src)
    local violations = {}
    local line_no = 0
    for line in src:gmatch("[^" .. CR .. NL .. "]+") do
        line_no = line_no + 1
        if not line:match("^%s*%-%-") then
            for _, banned in ipairs(POST_5_1_NAMES) do
                if find_bare(line, banned) then
                    violations[#violations + 1] = {
                        file = name, line = line_no, kind = "unavailable",
                        message = banned .. " does not exist on Lua 5.1/LuaJIT",
                    }
                end
            end
        end
    end
    return violations
end

-- =============================================================================
-- 1. The scanner must fire on every hazard class, and stay silent on valid code
-- =============================================================================

local TRIPWIRES = {
    { src = "local a = 7 // 2" .. NL, expect = "integer division" },
    { src = "local a = b & c" .. NL, expect = "bitwise and" },
    { src = "local a = b | c" .. NL, expect = "bitwise or" },
    { src = "local a = b << 2" .. NL, expect = "bitwise shift left" },
    { src = "local a = b >> 2" .. NL, expect = "bitwise shift right" },
    { src = "local a = ~b" .. NL, expect = "bitwise not" },
    { src = "goto done" .. NL .. "::done::" .. NL, expect = "label" },
    { src = "local t = table.pack(1)" .. NL, expect = "table.pack" },
    { src = "local t = table.unpack(x)" .. NL, expect = "table.unpack" },
    { src = "local n = rawlen(t)" .. NL, expect = "rawlen" },
    { src = "local r = bit32.band(1, 2)" .. NL, expect = "bit32" },
    { src = "local n = utf8.len(s)" .. NL, expect = "utf8." },
    { src = "if math.type(x) then end" .. NL, expect = "math.type" },
    { src = "local s = load(" .. DQ .. "return 1" .. DQ .. ")" .. NL,
        expect = "string form is loadstring" },
    { src = "local p = math.pow(2, 3)" .. NL, expect = "math.pow" },
    { src = "local n = table.getn(t)" .. NL, expect = "table.getn" },
    { src = "local s = " .. DQ .. BS .. "d+" .. DQ .. NL, expect = "unknown escape" },
    { src = "local s = " .. SQ .. BS .. "x41" .. SQ .. NL, expect = "unknown escape" },
    { src = "local s = " .. DQ .. BS .. "z" .. DQ .. NL, expect = "unknown escape" },
}

for _, case in ipairs(TRIPWIRES) do
    local found = scan_source("tripwire", case.src)
    local hit = false
    for _, v in ipairs(found) do
        if v.message:find(case.expect, 1, true) then hit = true end
    end
    assert(hit, "compat gate must fire on " .. case.expect ..
        " (found " .. tostring(#found) .. " violation(s))")
end

-- Negative controls: valid 5.1 code — including the exact shapes that trip naive
-- substring greps, which is what the bare-name matcher exists to reject.
local CLEAN_SOURCES = {
    "-- table.pack and 7 // 2 and a | b live in this comment" .. NL .. "local ok = 1" .. NL,
    "local s = " .. DQ .. "path//to/thing" .. DQ .. NL ..
        "local q = " .. SQ .. "a & b | c" .. SQ .. NL,
    "if a ~= nil and b ~= c then return end" .. NL,
    "local text = " .. DQ .. "%d+ things" .. DQ .. NL ..
        "local n = text:match(" .. DQ .. "%d+" .. DQ .. ")" .. NL,
    "local t = {}" .. NL .. "t[#t + 1] = 1" .. NL ..
        "local s = " .. DQ .. "say " .. BS .. DQ .. "hi" .. BS .. DQ .. DQ .. NL,
    "local n = 7 -- goto is only named here" .. NL,
    "local function f(...) return select(" .. DQ .. "#" .. DQ .. ", ...) end" .. NL,
    "local pw = 2 ^ 3" .. NL .. "local frac = 1.5" .. NL,
    "local long = [[" .. NL .. "table.pack inside a long string" .. NL .. "]]" .. NL,
    -- prefix / method shapes: none of these are the banned global names
    "local m = mytable.packer" .. NL ..
        "local r = math.power(2, 3)" .. NL ..
        "local u = frame:unpacked()" .. NL ..
        "local b = rawlength(x)" .. NL ..
        "local s = obj:load(" .. DQ .. "x" .. DQ .. ")" .. NL ..
        "local f = load(function() return 1 end)" .. NL ..
        "local a = bit32ish" .. NL .. "local g = mytable.getn" .. NL,
    -- deliberately allowed 5.1-only APIs (documented in the header)
    "local a, b = unpack(args)" .. NL .. "local o = getfenv(1)" .. NL ..
        "setfenv(1, {})" .. NL .. "local f = loadstring(" .. DQ .. "return 1" .. DQ .. ")" .. NL,
}
for _, src in ipairs(CLEAN_SOURCES) do
    local found = scan_source("control", src)
    assert(#found == 0, "compat gate false-positives on valid 5.1 code: " ..
        tostring(#found) .. " violation(s), first: " ..
        tostring(found[1] and found[1].message))
end

-- =============================================================================
-- 2. Every plugin file must be clean
-- =============================================================================

local violations, scanned, chunks = {}, 0, 0

local function walk(dir)
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then
            local path = dir .. "/" .. entry
            local attr = lfs.attributes(path)
            if attr and attr.mode == "directory" then
                if entry ~= "docs" then walk(path) end
            elseif entry:match("%.lua$") then
                local rel = path:sub(#ROOT + 1)
                local src = read_file(path)
                assert(src, "could not read " .. path)
                scanned = scanned + 1
                local found
                if rel:find("npc_spawns/", 1, true) then
                    chunks = chunks + 1
                    found = scan_chunk(rel, src)
                else
                    found = scan_source(rel, src)
                end
                for _, v in ipairs(found) do violations[#violations + 1] = v end
            end
        end
    end
end

walk(ROOT:gsub("/$", ""))

-- The plugin is 92 .lua files with 7 generated spawn chunks; if enumeration ever
-- returns fewer, refuse to report a pass over a partial sweep.
assert(scanned >= 92, "expected the whole plugin, scanned only " .. tostring(scanned) .. " files")
assert(chunks >= 7, "expected the spawn chunks in the scan, saw " .. tostring(chunks))

if #violations > 0 then
    local msgs = {}
    for _, v in ipairs(violations) do
        msgs[#msgs + 1] = "[" .. v.kind .. "] " .. v.file .. ":" ..
            tostring(v.line) .. "  " .. v.message
    end
    error("Lua 5.1 incompatibilities found:" .. NL .. "  " .. table.concat(msgs, NL .. "  "))
end

print("PASS test_lua51_compat (" .. tostring(scanned) .. " files, " ..
    tostring(chunks) .. " spawn chunks, 0 violations)")
os.exit(0)
