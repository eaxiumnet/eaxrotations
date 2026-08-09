-- test_apl_conformance.lua — Phase 2 APL order conformance (manifest-driven).
-- WHAT:  Asserts that the strategy priority order of every manifest entry in
--        tools/apl_status.lua matches the pinned wowsims APL priority list.
--        The manifest is the single source of truth (fixture -> spec file ->
--        spell-id resolver); the scorecard consumes the SAME manifest, so this
--        test and the scorecard's APL column can never drift apart.
-- WHEN:  run_wotlk_tests.lua and run_rotation_tests.lua.
-- WHY:   A refactor must never silently reorder a rotation; this test pins the
--        wowsims reference order so CI fails on drift (Phase 2 of the S+ plan).
-- SAFETY: Standalone; mocks all NS dependencies; fixtures are git-tracked.
--
-- Reference provenance (see tools/evidence/apl/SOURCES.md):
--   wowsims/wotlk @ 563e4a08cb15729f1fdcbcf68e6d68224553bfef
--   fire   = ui/mage/apls/fire.apl.json
--   affl   = ui/warlock/apls/affliction.apl.json
--   feral  = ui/feral_druid/apls/default.apl.json (Go black box — reference
--            order pinned in the manifest from sim/druid/feral/rotation.go)
--   2026-08-09 batch: arcane/frost (mage), combat/mutilate (rogue),
--   advanced (elemental shaman), shadow (priest) — see the manifest's
--   ENTRIES table in tools/apl_status.lua for the full fixture list.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;tools/?.lua;tools/build_tools/?.lua;" .. package.path

local apl = require("shared/apl_parser")
local manifest = require("tools/apl_status")

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function test(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil, "missing fixture: " .. path end
    local s = f:read("*a")
    f:close()
    return s
end

-- ---------------------------------------------------------------------------
-- Fixture sanity: every manifest entry with a JSON fixture must exist, decode
-- as TypeAPL, and carry a non-empty priority list (guards stale fixtures).
-- ---------------------------------------------------------------------------
test("manifest entries with fixtures exist and decode as TypeAPL", function()
    assert_true(#manifest.ENTRIES > 0, "manifest is empty")
    for _, e in ipairs(manifest.ENTRIES) do
        if e.fixture then
            local raw, err = read_file(e.fixture)
            assert_true(raw ~= nil, err or "no fixture content for " .. e.key)
            local apl_table = apl.decode_json(raw)
            assert_true(type(apl_table) == "table", e.key .. ": expected decoded table")
            assert_true(apl_table.type == "TypeAPL", e.key .. ": expected TypeAPL, got " .. tostring(apl_table.type))
            if e.resolve then
                local ids = apl.priority_ids(apl_table)
                assert_true(#ids > 0, e.key .. ": fixture has empty priorityList")
            end
        end
    end
end)

-- Every manifest entry must define exactly one reference form.
test("manifest: each entry has one reference form (resolve XOR reference_names)", function()
    for _, e in ipairs(manifest.ENTRIES) do
        local has_resolve = e.resolve ~= nil
        local has_names = e.reference_names ~= nil
        assert_true(has_resolve ~= has_names,
            e.key .. ": must define exactly one of resolve/reference_names")
        assert_true(type(e.key) == "string" and type(e.spec_file) == "string",
            e.key .. ": key/spec_file must be strings")
        assert_true(type(e.actions) == "table" and next(e.actions) ~= nil,
            e.key .. ": actions table required")
    end
end)

-- ---------------------------------------------------------------------------
-- Conformance per manifest entry (the scorecard computes the same verdict).
-- ---------------------------------------------------------------------------
print("=== test_apl_conformance ===")

for _, e in ipairs(manifest.ENTRIES) do
    test(e.key .. ": strategy order conforms to wowsims reference", function()
        -- Pass class_id exactly like compute() so both consumers share one load path
        -- (entries that gate on enums.class_id would load differently otherwise).
        local strategies = manifest.load_spec(e.spec_file, e.spells, e.actions, e.class_id)
        local names = manifest.strategy_names(strategies)
        local violation
        if e.reference_names then
            violation = apl.check_name_order(names, e.reference_names)
        else
            local raw = read_file(e.fixture)
            assert_true(raw ~= nil, "missing fixture: " .. e.fixture)
            local ids = apl.priority_ids(apl.decode_json(raw))
            violation = apl.check_id_order(names, ids, e.resolve)
        end
        assert_true(violation == nil, e.key .. " APL violation: " .. (violation and (
            violation.prev .. " (pos " .. violation.prev_pos .. ") should be before "
            .. violation.name .. " (pos " .. violation.name_pos .. ")") or "unknown"))
    end)

    -- A reference_names pin must match ALL of its names — reference_names are
    -- OUR strategy names pinned in Go-dispatch order, so a pin with even one
    -- typo'd name is weaker than intended (that name is silently skipped by
    -- check_name_order). Requiring all-of-them keeps the pin provably live.
    if e.reference_names then
        test(e.key .. ": reference_names pin is non-empty", function()
            assert_true(#e.reference_names > 0,
                e.key .. ": reference_names must not be empty (tests nothing)")
        end)
        test(e.key .. ": reference_names pin matches ALL real strategies", function()
            local strategies = manifest.load_spec(e.spec_file, e.spells, e.actions, e.class_id)
            local names = manifest.strategy_names(strategies)
            local known = {}
            for _, n in ipairs(names) do known[n] = true end
            local bad = {}
            for _, n in ipairs(e.reference_names) do
                if not known[n] then bad[#bad + 1] = n end
            end
            assert_true(#bad == 0, e.key .. ": reference_names pin has names missing from the spec: "
                .. table.concat(bad, ", ") .. " (actual strategies: " .. table.concat(names, ", ") .. ")")
        end)
    end

    -- The resolver must actually map fixture ids to real strategy names — a
    -- resolver that resolves nothing would make the conformance check vacuous.
    if e.resolve then
        test(e.key .. ": resolver maps fixture ids to real strategies", function()
            local strategies = manifest.load_spec(e.spec_file, e.spells, e.actions, e.class_id)
            local names = manifest.strategy_names(strategies)
            local known = {}
            for _, n in ipairs(names) do known[n] = true end
            local raw = read_file(e.fixture)
            local ids = apl.priority_ids(apl.decode_json(raw))
            local seen, count = {}, 0
            for _, id in ipairs(ids) do
                local name = e.resolve(id, 1)
                if name and not seen[name] then
                    seen[name] = true
                    assert_true(known[name], e.key .. ": resolver maps id " .. id
                        .. " to unknown strategy '" .. name .. "'")
                    count = count + 1
                end
            end
            assert_true(count > 0, e.key .. ": resolver maps 0 fixture ids (vacuous check)")
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Negative self-tests: prove the checker actually catches a reorder.
-- ---------------------------------------------------------------------------
test("checker: reversed affliction order is caught", function()
    local reversed = { "ShadowBolt", "DrainSoul", "CurseOfAgony", "UnstableAffliction", "Corruption", "Haunt" }
    local violation = apl.check_name_order(reversed, {
        "Haunt", "Corruption", "UnstableAffliction", "CurseOfAgony", "DrainSoul", "ShadowBolt",
    })
    assert_true(violation ~= nil, "checker should flag a fully-reversed order")
end)

test("checker: conformant order passes", function()
    local ok_order = { "Haunt", "Corruption", "UnstableAffliction", "CurseOfAgony", "DrainSoul", "ShadowBolt" }
    local violation = apl.check_name_order(ok_order, {
        "Haunt", "Corruption", "UnstableAffliction", "CurseOfAgony", "DrainSoul", "ShadowBolt",
    })
    assert_true(violation == nil, "checker should pass a conformant order")
end)

-- The manifest compute() (consumed by the scorecard) must agree with this test.
test("manifest.compute(): all entries pass (matches conformance above)", function()
    local res = manifest.compute()
    for _, e in ipairs(manifest.ENTRIES) do
        assert_true(res.status[e.key] == "pass",
            e.key .. ": compute() = " .. tostring(res.status[e.key]) .. " — " .. tostring(res.evidence[e.key]))
        assert_true(type(res.evidence[e.key]) == "string" and res.evidence[e.key] ~= "",
            e.key .. ": missing evidence string")
    end
end)

print(string.format("Tests: %d/%d passed", total_passed, total_tests))
if #failures > 0 then
    print("FAILURES:")
    for _, f in ipairs(failures) do
        print("  " .. f.label .. ": " .. tostring(f.error))
    end
    os.exit(1)
end
