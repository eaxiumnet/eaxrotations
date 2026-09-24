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
-- Safety: read-only source scans (tests/source_scan.lua) and a require of the owner module
--      itself; no writes, no execution of scanned code.

-- Path setup for standalone run
package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

local mock = require("EaxAutoQuester/tests/mock_core")
mock.install()
mock.reset()

-- The scans below are tests/source_scan.lua's: one production-file walk, one comment stripper
-- and one assignment test for all three tripwires, so they cannot cover different surfaces.
local scan = require("tests/source_scan")

-- The five fields, and the assignment shape to look for. A pattern (not a plain needle) so the
-- trailing `=` is matched and the char AFTER it decides: `==` and `~=` are comparisons (reads)
-- and must never trip the scan; anything else is an assignment.
local FIELDS = { "destination", "unit_dest", "unit_dest_key", "engage_dest", "engage_sq" }
local OWNER = "shared/nav_destination.lua"

--- Line of the first direct assignment to `shared._nav_<field>` in `stripped`, or nil.
--- The `=` that follows the field must be an assignment: scan.is_assignment tells it from the
--- `==` / `~=` / `<=` / `>=` comparisons, which are reads and must not trip the scan.
--- @param stripped string comment-stripped source
--- @param field string one of FIELDS
--- @return number|nil line
local function find_write(stripped, field)
    local pat = "%._nav_" .. field .. "[%s]*="
    local at = stripped:find(pat)
    while at do
        local eq = at + #stripped:match(pat, at) - 1        -- the '=' itself
        if scan.is_assignment(stripped, eq) then
            return scan.line_at(stripped, at)
        end
        at = stripped:find(pat, at + 1)
    end
    return nil
end

-- =============================================================================
-- S1 — the scanner itself: it must catch a real write and ignore reads and prose
-- =============================================================================

do
    local offender = "local function f(shared)\n    shared._nav_destination = point\nend\n"
    local line = find_write(scan.strip_comments(offender), "destination")
    assert(line == 2, "S1 FAIL: a real direct write must be caught (got " .. tostring(line) .. ")")

    -- Descriptors are as banned as the destination itself.
    for _, field in ipairs(FIELDS) do
        local src = "shared._nav_" .. field .. " = nil\n"
        assert(find_write(scan.strip_comments(src), field) == 1,
            "S1 FAIL: a direct write of _nav_" .. field .. " must be caught")
    end

    -- Comparisons are reads: the whole point of the owner is that these fields may still be READ.
    local cmp1 = "if shared._nav_engage_dest == shared._nav_destination then return 1 end\n"
    assert(find_write(scan.strip_comments(cmp1), "engage_dest") == nil,
        "S1 FAIL: an == comparison must not trip the scan")
    local cmp2 = "if shared._nav_unit_dest_key ~= dest then return 1 end\n"
    assert(find_write(scan.strip_comments(cmp2), "unit_dest_key") == nil,
        "S1 FAIL: a ~= comparison must not trip the scan")

    -- Prose about the banned write is prose.
    local prose = "-- shared._nav_destination = nil is gone from production\nreturn 1\n"
    assert(find_write(scan.strip_comments(prose), "destination") == nil,
        "S1 FAIL: a comment about the write must not trip the scan")
    local block = "--[[ shared._nav_destination = nil ]]\nreturn 1\n"
    assert(find_write(scan.strip_comments(block), "destination") == nil,
        "S1 FAIL: a long comment must not trip the scan")

    print("  S1 PASS: scanner catches direct writes and ignores comparisons and prose")
end

-- =============================================================================
-- S2 — no production file outside the owner writes the destination fields
-- =============================================================================

do
    local files = scan.production_files()
    assert(#files >= 40,
        "S2 FAIL: the walk found only " .. tostring(#files) ..
        " production files — a scan this thin proves nothing")

    local offenders = {}
    for _, rel in ipairs(files) do
        if rel ~= OWNER then
            local src = scan.read(rel)
            assert(src, "S2 FAIL: production file listed but unreadable: " .. rel)
            local stripped = scan.strip_comments(src)
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
