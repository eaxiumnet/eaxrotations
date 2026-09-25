-- What: EaxAutoQuester/object_spawns.lua — the quest game-object spawn index, and its no-data
--       contract. Runs BEFORE any fixture is installed on purpose: the state a fresh checkout is
--       in is the state the sweep is allowed to meet.
-- When: Run via `lua EaxAutoQuester/tests/run_quester_tests.lua`
-- Why: the index answers "where is the thing the guide named" for entries that no creature index
--       can describe. It ships as an accessor plus GENERATED chunks that are not committed, so
--       "no data" is the normal first-run state and must be silent, nil-returning and harmless —
--       the sweep then does exactly what it did before the index existed (the step's waypoints).
--       A loud failure here would turn a missing data file into a broken quest loop.
-- Safety: pure module + installed fixture tables; no client, no network, no file writes.

package.path = package.path .. ";./EaxAutoQuester/?.lua;./EaxAutoQuester/?/init.lua"

-- Force the no-data state even when a developer has generated the ignored index locally. The
-- contract under test is what a fresh checkout must do, not what happens to be on this machine.
package.loaded["object_spawns"] = nil
package.loaded["object_spawns/manifest"] = nil
local object_spawns = require("object_spawns")

-- =============================================================================
-- O1 — no data is a normal state: everything answers nil / {} and says so
-- =============================================================================
do
    assert(object_spawns.available == false,
        "O1a FAIL: with no manifest the index must report itself unavailable, got " ..
        tostring(object_spawns.available))
    assert(object_spawns.chunk_count == 0,
        "O1b FAIL: no manifest means no chunks, got " .. tostring(object_spawns.chunk_count))
    assert(object_spawns.find_object_spawns(233818) == nil,
        "O1c FAIL: an unknown entry must answer nil, not an empty list the sweep would read as data")
    local ids = object_spawns.find_object_ids_by_name("Ogre Remains")
    assert(type(ids) == "table" and #ids == 0,
        "O1d FAIL: a name must answer an empty list with no data, got " .. tostring(#ids))
    assert(#object_spawns.find_object_ids_by_name(nil) == 0
        and #object_spawns.find_object_ids_by_name("") == 0,
        "O1e FAIL: nil and empty names answer an empty list")
    print("  O1 PASS: no generated data — the index is silent and answers nil/{}")
end

-- =============================================================================
-- The fixture: what the generator emits, at the size a test can read.
-- Two entries that differ in exactly the way this index has to be right about: one whose
-- whole name IS the search string, and one that only contains it.
-- =============================================================================
package.loaded["object_spawns/manifest"] = {
    chunk_count = 1,
    entry_count = 3,
    generated_from = "test fixture",
}
package.loaded["object_spawns/chunk_000"] = {
    by_entry = {
        ["233818"] = {
            name = "Ogre Remains",
            maps = {
                { map_id = 0, x = -4000.0, y = 1200.0, z = 145.25 },
                { map_id = 0, x = -4050.0, y = 1250.0, z = 146.0 },
            },
        },
        ["190000"] = {
            name = "Ogre Remains Cache",
            maps = { { map_id = 0, x = -4100.0, y = 1300.0, z = 147.5 } },
        },
        ["190001"] = { name = "Empty Coffer", maps = {} },
    },
}
assert(object_spawns.reload() == true,
    "O2a FAIL: a manifest with chunks must make the index available")

-- =============================================================================
-- O2/O3 — by entry, and the shape of the answer
-- =============================================================================
do
    assert(object_spawns.available == true and object_spawns.chunk_count == 1
        and object_spawns.entry_count == 3,
        "O2b FAIL: the manifest's own numbers must be readable after a reload")

    local spawns = object_spawns.find_object_spawns(233818)
    assert(type(spawns) == "table" and #spawns == 2,
        "O3a FAIL: every spawn of the entry must be returned, got " .. tostring(spawns and #spawns))
    assert(spawns[1].x == -4000.0 and spawns[1].map_id == 0 and spawns[1].z == 145.25,
        "O3b FAIL: a spawn point must keep its map, x, y and z — the sweep walks these coordinates")
    assert(object_spawns.find_object_spawns(999999) == nil,
        "O3c FAIL: an entry with no row must answer nil")
    assert(object_spawns.find_object_spawns(190001) == nil,
        "O3d FAIL: an entry with no spawn rows must answer nil, not an empty list")
    assert(object_spawns.find_object_spawns(nil) == nil,
        "O3e FAIL: a nil entry must answer nil")
    print("  O3 PASS: entries resolve to their spawn rows; unknown and empty answer nil")
end

-- =============================================================================
-- O4/O5 — identity, not similarity: exact name wins, substring is the fallback
-- =============================================================================
do
    local exact = object_spawns.find_object_ids_by_name("Ogre Remains")
    assert(#exact == 1 and exact[1].object_id == 233818,
        "O4a FAIL: an exact whole-name match must be the only answer, got " .. tostring(#exact))
    assert(exact[1].name == "Ogre Remains",
        "O4b FAIL: the answer must carry the world's own name for the entry")

    local partial = object_spawns.find_object_ids_by_name("Remains Cache")
    assert(#partial == 1 and partial[1].object_id == 190000,
        "O5a FAIL: with no exact match, a partial name still resolves (the guide's own wording)")
    assert(#object_spawns.find_object_ids_by_name("nothing here at all") == 0,
        "O5b FAIL: a name no entry carries answers an empty list")
    print("  O4 PASS: exact names win, partial names are the fallback")
end

-- =============================================================================
-- O6 — the name answer is cached, because the sweep asks the same question per step
-- =============================================================================
do
    local first = object_spawns.find_object_ids_by_name("Ogre Remains")
    local second = object_spawns.find_object_ids_by_name("Ogre Remains")
    assert(first == second,
        "O6a FAIL: the same question twice must return the same table (the caller treats it as " ..
        "read-only shared state)")
    object_spawns.clear_name_cache()
    local third = object_spawns.find_object_ids_by_name("Ogre Remains")
    assert(third ~= first and #third == #first and third[1].object_id == first[1].object_id,
        "O6b FAIL: after a cache drop the answer is rebuilt with the same content")
    print("  O6 PASS: the name answer is cached and rebuildable")
end

-- =============================================================================
-- O7 — a manifest promising a chunk this checkout does not have is missing data, not a crash
-- =============================================================================
do
    package.loaded["object_spawns/manifest"] = { chunk_count = 2, entry_count = 2 }
    object_spawns.reload()
    assert(object_spawns.available == true,
        "O7a FAIL: a present manifest still counts as an index")
    local ok_missing, missing = pcall(object_spawns.find_object_spawns, 500000)
    assert(ok_missing and missing == nil,
        "O7b FAIL: an entry in a chunk that will not load must answer nil quietly, not raise — " ..
        "the sweep has to be able to fall back to the guide's waypoints")
    local ok_present, present = pcall(object_spawns.find_object_spawns, 233818)
    assert(ok_present and present and #present == 2,
        "O7c FAIL: the chunk that IS present must keep answering while a sibling is missing")
    print("  O7 PASS: a manifest naming an absent chunk answers nil without raising")
end

-- =============================================================================
-- O8 — a name that legitimately matches many entries is bounded
-- =============================================================================
do
    local bulk = {}
    for i = 1, 40 do
        bulk[tostring(300000 + i)] = {
            name = "Bone Pile " .. i,
            maps = { { map_id = 0, x = -5000.0 + i, y = 0, z = 1 } },
        }
    end
    package.loaded["object_spawns/manifest"] = { chunk_count = 1, entry_count = 40 }
    package.loaded["object_spawns/chunk_000"] = { by_entry = bulk }
    object_spawns.reload()
    local found = object_spawns.find_object_ids_by_name("Bone Pile")
    assert(#found == 32,
        "O8 FAIL: a substring matching 40 entries must be capped at 32, got " .. tostring(#found))
    print("  O8 PASS: a broad name is capped at 32 entries")
end

print("PASS test_object_spawns")
os.exit(0)
