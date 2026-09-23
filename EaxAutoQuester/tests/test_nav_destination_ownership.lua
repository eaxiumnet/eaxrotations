-- What: Tripwire — only shared/nav_destination.lua may write the destination fields.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: The destination fields (_nav_destination and its four descriptors) used to have seven
--      production writers and no owner: each call site paired the destination with its
--      stand-off / live-unit link by hand, and a missed pairing leaked the previous
--      destination's descriptors into the next one — how a plain waypoint inherited the last
--      fight's "stop at range" and was never walked to, and how an engagement walked onto the
--      mob it should have stopped short of. Every write now goes through the owner's API
--      (point / engage / repoint / clear), so a producer that intends to fight at a point
--      cannot write the destination without its stand-off. This suite is what keeps it that
--      way: a read-only source scan with positive controls, so it cannot pass by looking at
--      nothing, plus the owner API's own contract.
-- Safety: read-only source scans (io.open + lfs) and a require of the owner module itself;
--      no writes, no execution of scanned code.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- =============================================================================
-- Helpers — plugin root, production file discovery, comment-stripping scan
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
assert(ROOT, "EaxAutoQuester root not found (expected main.lua in ./ or ./EaxAutoQuester/)")

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

--- Blank out comments while preserving newlines, so a line number in the stripped source is
--- still a line number in the file. Prose about a direct write must not trip the scan.
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

--- Line number of an occurrence in `stripped`, given the byte offset.
local function line_at(stripped, at)
    local _, count = stripped:sub(1, at):gsub("\n", "\n")
    return count + 1
end

-- The five fields, and the assignment shape to look for. A pattern (not a plain needle) so the
-- trailing `=` is matched and the char AFTER it decides: `==` and `~=` are comparisons (reads)
-- and must never trip the scan; anything else is an assignment.
local FIELDS = { "destination", "unit_dest", "unit_dest_key", "engage_dest", "engage_sq" }
local OWNER = "shared/nav_destination.lua"

--- Line of the first direct assignment to `shared._nav_<field>` in `stripped`, or nil.
--- A write is `<field><spaces>=<spaces><not an equals>`: for `==` the char after the first
--- `=` is a second `=`, which is a comparison and must not trip. (`~=` cannot match this
--- pattern at all — the `=` would have to follow a `~` — and is asserted anyway below.)
--- @param stripped string comment-stripped source
--- @param field string one of FIELDS
--- @return number|nil line
local function find_write(stripped, field)
    local pat = "%._nav_" .. field .. "[%s]*=[%s]*"
    local at = stripped:find(pat)
    while at do
        local after_eq = at + #stripped:match(pat, at)
        local nxt = stripped:sub(after_eq, after_eq)
        if nxt == "=" then
            at = stripped:find(pat, at + 1)
        else
            return line_at(stripped, at)
        end
    end
    return nil
end

-- =============================================================================
-- S1 — the scanner itself: it must catch a real write and ignore reads and prose
-- =============================================================================

do
    local offender = "local function f(shared)\n    shared._nav_destination = point\nend\n"
    local line = find_write(strip_comments(offender), "destination")
    assert(line == 2, "S1 FAIL: a real direct write must be caught (got " .. tostring(line) .. ")")

    -- Descriptors are as banned as the destination itself.
    for _, field in ipairs(FIELDS) do
        local src = "shared._nav_" .. field .. " = nil\n"
        assert(find_write(strip_comments(src), field) == 1,
            "S1 FAIL: a direct write of _nav_" .. field .. " must be caught")
    end

    -- Comparisons are reads: the whole point of the owner is that these fields may still be READ.
    local cmp1 = "if shared._nav_engage_dest == shared._nav_destination then return 1 end\n"
    assert(find_write(strip_comments(cmp1), "engage_dest") == nil,
        "S1 FAIL: an == comparison must not trip the scan")
    local cmp2 = "if shared._nav_unit_dest_key ~= dest then return 1 end\n"
    assert(find_write(strip_comments(cmp2), "unit_dest_key") == nil,
        "S1 FAIL: a ~= comparison must not trip the scan")

    -- Prose about the banned write is prose.
    local prose = "-- shared._nav_destination = nil is gone from production\nreturn 1\n"
    assert(find_write(strip_comments(prose), "destination") == nil,
        "S1 FAIL: a comment about the write must not trip the scan")
    local block = "--[[ shared._nav_destination = nil ]]\nreturn 1\n"
    assert(find_write(strip_comments(block), "destination") == nil,
        "S1 FAIL: a long comment must not trip the scan")

    print("  S1 PASS: scanner catches direct writes and ignores comparisons and prose")
end

-- =============================================================================
-- S2 — no production file outside the owner writes the destination fields
-- =============================================================================

do
    local files = list_production_files()
    assert(#files >= 40,
        "S2 FAIL: the walk found only " .. tostring(#files) ..
        " production files — a scan this thin proves nothing")

    local offenders = {}
    for _, rel in ipairs(files) do
        if rel ~= OWNER then
            local src = read_source(rel)
            assert(src, "S2 FAIL: production file listed but unreadable: " .. rel)
            local stripped = strip_comments(src)
            for _, field in ipairs(FIELDS) do
                local line = find_write(stripped, field)
                if line then
                    offenders[#offenders + 1] = rel .. ":" .. tostring(line) .. " (_nav_" .. field .. ")"
                end
            end
        end
    end

    assert(#offenders == 0,
        "S2 FAIL: the destination fields are shared/nav_destination.lua's — write through its API "
        .. "(point / engage / repoint / clear), never directly — found: "
        .. table.concat(offenders, ", "))
    print("  S2 PASS: " .. tostring(#files) .. " production files, zero direct destination writes")
end

-- =============================================================================
-- S3 — the owner API contract: a destination and its descriptors move together
-- =============================================================================

local nav_destination = require("shared/nav_destination")

do
    local shared = {}
    local p = { x = 1, y = 2, z = 3 }
    local unit = {}

    -- point(): a place. Stale descriptors from a previous destination must not ride along —
    -- that leak is the bug this owner exists to kill.
    shared._nav_unit_dest = {}
    shared._nav_unit_dest_key = {}
    shared._nav_engage_dest = {}
    shared._nav_engage_sq = 784
    nav_destination.point(shared, p)
    assert(shared._nav_destination == p, "S3 FAIL: point() must set the destination")
    assert(shared._nav_unit_dest == nil and shared._nav_unit_dest_key == nil
        and shared._nav_engage_dest == nil and shared._nav_engage_sq == nil,
        "S3 FAIL: point() must clear every descriptor (stale stand-off / unit link riding along)")

    -- point(shared, nil) drops the destination entirely.
    nav_destination.point(shared, nil)
    assert(shared._nav_destination == nil, "S3 FAIL: point(shared, nil) must clear the destination")

    -- engage(): the stand-off rides on the destination by construction, with the live-unit link.
    shared = {}
    nav_destination.engage(shared, unit, p, 784)
    assert(shared._nav_destination == p, "S3 FAIL: engage() must set the destination")
    assert(shared._nav_unit_dest == unit and shared._nav_unit_dest_key == p,
        "S3 FAIL: engage() must record the live-unit link on the point it was given")
    assert(shared._nav_engage_dest == p and shared._nav_engage_sq == 784,
        "S3 FAIL: engage() must record the stand-off with the destination")

    -- engage() of a static approachable: stand-off without a follow link.
    shared = {}
    nav_destination.engage(shared, nil, p, 400)
    assert(shared._nav_destination == p and shared._nav_unit_dest == nil
        and shared._nav_unit_dest_key == nil
        and shared._nav_engage_dest == p and shared._nav_engage_sq == 400,
        "S3 FAIL: engage(unit=nil) must keep the stand-off without a follow link")

    -- engage() with no stand-off: walk all the way in (melee-style closing), no descriptors.
    shared = {}
    nav_destination.engage(shared, unit, p, nil)
    assert(shared._nav_destination == p and shared._nav_unit_dest == unit
        and shared._nav_unit_dest_key == p
        and shared._nav_engage_dest == nil and shared._nav_engage_sq == nil,
        "S3 FAIL: engage(stand_off_sq=nil) must mean walk-in, not a stale stand-off")

    -- clear_engagement(): drops the descriptors, keeps the destination.
    nav_destination.clear_engagement(shared)
    assert(shared._nav_destination == p, "S3 FAIL: clear_engagement() must keep the destination")
    assert(shared._nav_unit_dest == nil and shared._nav_unit_dest_key == nil
        and shared._nav_engage_dest == nil and shared._nav_engage_sq == nil,
        "S3 FAIL: clear_engagement() must drop every descriptor")

    -- repoint(): the Z-fallback rewrite keeps every link that pointed AT the old table, and
    -- only those — a descriptor belonging to something else must not be stolen.
    shared = {}
    local old = { x = 9, y = 9, z = 99 }
    local replacement = { x = 9, y = 9, z = 5 }
    local other_key = {}
    nav_destination.engage(shared, unit, old, 784)
    shared._nav_unit_dest_key = other_key -- a link that points somewhere else
    nav_destination.repoint(shared, old, replacement)
    assert(shared._nav_destination == replacement, "S3 FAIL: repoint() must replace the destination")
    assert(shared._nav_engage_dest == replacement and shared._nav_engage_sq == 784,
        "S3 FAIL: repoint() must re-point the stand-off that named the old table")
    assert(shared._nav_unit_dest == unit and shared._nav_unit_dest_key == other_key,
        "S3 FAIL: repoint() must not steal a descriptor that pointed elsewhere")

    -- clear(): everything goes, so a later destination cannot inherit state from this one.
    nav_destination.clear(shared)
    assert(shared._nav_destination == nil and shared._nav_unit_dest == nil
        and shared._nav_unit_dest_key == nil
        and shared._nav_engage_dest == nil and shared._nav_engage_sq == nil,
        "S3 FAIL: clear() must drop the destination and every descriptor")

    print("  S3 PASS: owner API pairs every destination with its descriptors")
end

print("PASS test_nav_destination_ownership")
os.exit(0)
