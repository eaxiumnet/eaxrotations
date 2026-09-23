-- What: Tripwire — every shared._* field production writes is declared in the shared state table.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why:  quest_state/coordinator.lua declares the shared state table, and until now the states and
--       shared modules wrote fields into it that it never declared — eleven _patrol_* fields, the
--       pull gate's two notice keys, the step's retirement set, the sweep clock, the dialog
--       hand-off, the combat-override latch. Nothing failed when one appeared: the field simply
--       existed, invisible to anyone reading the state surface, and no audit could tell a
--       forgotten declaration from a field that was never meant to exist. This is the detection —
--       a comment-stripping source scan asserting that every field written as `shared._*` is
--       declared in the coordinator's table, with positive controls on the detectors and on real
--       source, so it cannot pass by looking at nothing.
--       Scope note: scanning the literally-named `shared` is scanning the table — the coordinator
--       is the only production file that binds the name (`local shared = {`), every other module
--       receives it as an argument, and no production file rebinds it to a second name.
-- Safety: read-only source scans (io.open + lfs); no requires of the scanned modules, no writes.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local DECLARATION_FILE = "quest_state/coordinator.lua"

-- =============================================================================
-- Helpers — plugin root, production discovery, comment-stripping scan
-- =============================================================================

--- Locate the plugin root so this suite runs from the repo root or the plugin root.
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
assert(ROOT, "FAIL: EaxAutoQuester root not found (expected main.lua in ./ or ./EaxAutoQuester/)")

local function read_source(rel)
    local f = io.open(ROOT .. rel, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--- Every production Lua file: everything under the plugin root except the suites, the docs and
--- the throwaway `_`-prefixed probes.
local function list_production_files()
    local ok, lfs = pcall(require, "lfs")
    assert(ok and lfs and lfs.dir,
        "FAIL: lfs is required — a partial scan of production code must not be able to pass")

    local out = {}
    local function walk(dir)
        for entry in lfs.dir(dir) do
            if entry ~= "." and entry ~= ".." then
                local path = dir .. "/" .. entry
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if entry ~= "tests" and entry ~= "docs" then walk(path) end
                elseif entry:match("%.lua$") and not entry:match("^_") then
                    out[#out + 1] = path:sub(#ROOT + 1)
                end
            end
        end
    end
    walk(ROOT:sub(1, #ROOT - 1))
    table.sort(out)
    return out
end

--- Blank out comments while preserving newlines, so prose about a write cannot trip the scan and
--- a line number in the stripped source is still a line number in the file.
--- @param src string
--- @return string
local function strip_comments(src)
    local out = {}
    local i, n = 1, #src
    while i <= n do
        if src:sub(i, i + 1) == "--" then
            local eq = src:match("^%-%-%[(=*)%[", i)
            if eq then
                local close = "]" .. eq .. "]"
                local start = i + 4 + #eq
                local e = src:find(close, start, true)
                e = e and (e + #close) or (n + 1)
                for nl in src:sub(i, e - 1):gmatch("[\r\n]") do out[#out + 1] = nl end
                i = e
            else
                local e = src:find("[\r\n]", i) or (n + 1)
                i = e
            end
        else
            out[#out + 1] = src:sub(i, i)
            i = i + 1
        end
    end
    return table.concat(out)
end

--- How many keys a set holds.
--- @param set table
--- @return number
local function count(set)
    local n = 0
    for _ in pairs(set) do n = n + 1 end
    return n
end

--- 1-based line number of a byte offset in `s`.
local function line_at(s, at)
    local _, count = s:sub(1, at):gsub("\n", "\n")
    return count + 1
end

-- =============================================================================
-- The two detectors
-- =============================================================================

--- The field an occurrence of `shared.` writes, or nil when it only reads one.
--- `shared._x = v`, `shared._x.k = v` and `shared._x[i] = v` all write _x; `shared._x == v`,
--- `shared._x or 0`, `local x = shared._x` and `shared._x[i]` are reads.
--- @param s string comment-stripped source
--- @param at number byte offset of the occurrence
--- @return string|nil
local function written_field(s, at)
    local _, e, name = s:find("^shared%.(_[%w_]+)", at)
    if not name then return nil end

    -- Walk the accessor chain: `.name` and `[index]` segments still name the same field.
    local i = e + 1
    while true do
        local c = s:sub(i, i)
        if c == "." then
            local _, ee = s:find("^%.[%w_]+", i)
            if not ee then return nil end
            i = ee + 1
        elseif c == "[" then
            local close = s:find("]", i, true)
            if not close then return nil end
            i = close + 1
        else
            break
        end
    end

    local eq = s:find("=", i)
    if not eq then return nil end
    -- Only whitespace may stand between the field and the '='; otherwise this '=' belongs to some
    -- later statement and the occurrence is a read.
    if s:sub(i, eq - 1):match("^%s*$") == nil then return nil end
    -- `==` is a comparison; `~=`, `<=`, `>=` are comparisons whose '=' is preceded by an operator.
    if s:sub(eq + 1, eq + 1) == "=" then return nil end
    local before = s:sub(eq - 1, eq - 1)
    if before == "~" or before == "<" or before == ">" then return nil end
    return name
end

--- Every field a source writes as `shared._*`, with the site of each write when asked.
--- @param src string
--- @param rel string|nil file label for the sites
--- @param sites table|nil name -> list of "file:line"
--- @return table set
local function written_fields(src, rel, sites)
    local s = strip_comments(src)
    local set = {}
    local at = s:find("shared%.")
    while at do
        local name = written_field(s, at)
        if name then
            set[name] = true
            if sites then
                local list = sites[name]
                if not list then
                    list = {}
                    sites[name] = list
                end
                list[#list + 1] = tostring(rel) .. ":" .. tostring(line_at(s, at))
            end
        end
        at = s:find("shared%.", at + 1)
    end
    return set
end

--- The fields the shared state table declares, from the coordinator's source. nil when the table
--- or its end cannot be found — a parse that finds nothing must be visible, not silently empty.
--- @param src string
--- @return table|nil set
local function declared_fields(src)
    local s = strip_comments(src)
    local _, at = s:find("local shared%s*=%s*%{")
    if not at then return nil end

    -- Balance the braces: comments are gone, and the table body is plain `key = value` pairs, so a
    -- brace count is enough to find its end.
    local i, depth = at + 1, 1
    while i <= #s and depth > 0 do
        local c = s:sub(i, i)
        if c == "{" then depth = depth + 1
        elseif c == "}" then depth = depth - 1 end
        i = i + 1
    end
    if depth ~= 0 then return nil end

    local set = {}
    for name in ("\n" .. s:sub(at + 1, i - 2)):gmatch("\n%s*(_[%w_]+)%s*=") do set[name] = true end
    return set
end

--- Every production write, compared against a declaration set. This is the whole check: the
--- files are read once, every `shared._*` write is collected with its site, and the fields that
--- are not declared come back sorted.
--- @param declared table field -> true
--- @param files string[] production files (relative to the plugin root)
--- @return string[] undeclared (sorted), number written_count, table sites
local function undeclared_against(declared, files)
    local written, sites = {}, {}
    for _, rel in ipairs(files) do
        local src = read_source(rel)
        assert(src, "FAIL: production file listed but unreadable: " .. rel)
        local per_file = {}
        local set = written_fields(src, rel, per_file)
        for name in pairs(set) do
            written[name] = true
            local list = sites[name]
            if not list then
                list = {}
                sites[name] = list
            end
            for _, site in ipairs(per_file[name] or {}) do list[#list + 1] = site end
        end
    end

    local out = {}
    for name in pairs(written) do
        if not declared[name] then out[#out + 1] = name end
    end
    table.sort(out)
    return out, count(written), sites
end

-- =============================================================================
-- S1 — the detectors: writes and declarations, on sources whose answer is known
-- =============================================================================

do
    local coord = "local shared = {\n    _state = \"IDLE\",\n    _nav_x = nil,\n}\nreturn shared\n"
    local declared = declared_fields(coord)
    assert(declared, "S1a FAIL: the declaration parser found no table")
    assert(declared._state and declared._nav_x, "S1b FAIL: the declaration parser missed a key")
    assert(not declared._other, "S1c FAIL: the declaration parser invented a key")

    local writes = "local n = 0\nfunction f(shared)\n    shared._state = \"NAV\"\n"
        .. "    shared._nav_x = { x = 1 }\nend\n"
    local w = written_fields(writes)
    assert(w._state and w._nav_x, "S1d FAIL: an assignment must read as a write")
    assert(count(w) == 2, "S1e FAIL: the write scan invented a field (" .. tostring(count(w)) .. " fields)")

    local undeclared_src = "function f(shared)\n    shared._undeclared = 1\nend\n"
    local bad = written_fields(undeclared_src)
    assert(bad._undeclared, "S1f FAIL: an undeclared write must be detected")
    assert(not declared._undeclared, "S1g FAIL: the fixture's undeclared field leaked into the table")

    local reads = "function f(shared)\n"
        .. "    if shared._nav_x == nil then return end\n"
        .. "    local a = shared._nav_x or 0\n"
        .. "    if shared._state ~= \"IDLE\" then return end\n"
        .. "    if shared._nav_x <= 3 then return end\n"
        .. "    local y = shared._nav_x[1]\n"
        .. "    local z = shared._nav_x.x\n"
        .. "end\n"
    assert(count(written_fields(reads)) == 0,
        "S1h FAIL: a read (==, ~=, <=, or a bare access) must not read as a write")

    local element = "function f(shared)\n    shared._seen[7] = true\n    shared._sub.k = 1\nend\n"
    local ew = written_fields(element)
    assert(ew._seen and ew._sub,
        "S1i FAIL: an element or subfield assignment is a write of the field")

    local prose = "-- shared._prose_field = 1 shows how the declaration would look\nreturn 1\n"
    assert(count(written_fields(prose)) == 0, "S1j FAIL: a comment must not trip the scan")

    print("  S1 PASS: detectors tell a write from a read, and a declaration from its absence")
end

-- =============================================================================
-- S2 — the real surface: every field production writes is declared
-- =============================================================================

do
    local coord_src = read_source(DECLARATION_FILE)
    assert(coord_src, "S2a FAIL: could not read " .. DECLARATION_FILE ..
        " — the declaration set is one half of this check and cannot be missing")
    local declared = declared_fields(coord_src)
    assert(declared, "S2b FAIL: " .. DECLARATION_FILE ..
        " no longer holds a `local shared = {...}` table — the declaration site moved")

    local declared_count = count(declared)
    assert(declared_count >= 40, "S2c FAIL: the declaration parse found only " ..
        tostring(declared_count) .. " fields — a parse this thin proves nothing")

    local files = list_production_files()
    assert(#files >= 40, "S2d FAIL: the walk found only " .. tostring(#files) ..
        " production files — a scan this thin proves nothing")

    local undeclared, written_count, sites = undeclared_against(declared, files)
    assert(written_count >= 40, "S2e FAIL: the scan saw only " .. tostring(written_count) ..
        " written fields — it is not looking at the real shared state")

    local detail = {}
    for _, name in ipairs(undeclared) do
        detail[#detail + 1] = name .. " (" .. table.concat(sites[name], ", ") .. ")"
    end
    assert(#undeclared == 0, "S2g FAIL: production writes " .. tostring(#undeclared) ..
        " shared field(s) the state table does not declare — declare each in " .. DECLARATION_FILE ..
        " with one line saying what owns it: " .. table.concat(detail, "; "))

    -- Informational, not a failure: declarations nothing writes are a separate question (a field
    -- whose writer was deleted), and this suite guards the write -> declaration direction only.
    local unwritten = 0
    local written_names = {}
    for name in pairs(sites) do written_names[name] = true end
    for name in pairs(declared) do
        if not written_names[name] then unwritten = unwritten + 1 end
    end

    print("  S2 PASS: " .. tostring(#files) .. " production files write " .. tostring(written_count) ..
        " shared fields, all declared in " .. tostring(declared_count) .. " (" ..
        tostring(unwritten) .. " declared but never written)")
end

-- =============================================================================
-- S3 — non-vacuous on real source: an undeclared write added to production is caught
-- =============================================================================

do
    local rel = "quest_state/do_action_state.lua"
    local src = read_source(rel)
    assert(src, "S3a FAIL: could not read " .. rel)

    local poisoned = src:gsub("local function ", "shared._declaration_probe = 1\nlocal function ", 1)
    assert(poisoned ~= src, "S3b FAIL: the control could not inject a write into " .. rel)
    assert(written_fields(poisoned)._declaration_probe,
        "S3c FAIL: the scan cannot see an undeclared write added to real production source")

    local declared = declared_fields(read_source(DECLARATION_FILE))
    assert(declared and not declared._declaration_probe,
        "S3d FAIL: the probe field must not be declared — the control proves nothing if it is")

    -- The compare step itself, on the real surface: remove one real declaration and the scan must
    -- report the field production still writes. Without this, only the detector is proven — the
    -- comparison could be inverted and every control above would still pass.
    local coord_src = read_source(DECLARATION_FILE)
    assert(coord_src, "S3e FAIL: could not read " .. DECLARATION_FILE)
    local mutated_src = coord_src:gsub("%s*_patrol_sweeps%s*=[^\n]*", "\n", 1)
    assert(mutated_src ~= coord_src, "S3f FAIL: the control could not remove a declaration")
    local mutated = declared_fields(mutated_src)
    assert(mutated and not mutated._patrol_sweeps,
        "S3g FAIL: the mutated table still declares the removed field")
    local reported = undeclared_against(mutated, list_production_files())
    local flagged = false
    for _, name in ipairs(reported) do
        if name == "_patrol_sweeps" then flagged = true end
    end
    assert(flagged,
        "S3h FAIL: removing the real declaration did not make the scan report the field that "
        .. "still writes it")

    print("  S3 PASS: an undeclared write injected into real production source is caught")
end

print("PASS test_shared_state_declaration")
os.exit(0)
