-- test_apl_conformance.lua — Phase 2 APL order conformance (pilot specs).
-- WHAT:  Asserts that the strategy priority order of the 3 pilot WotLK specs
--        (fire mage, affliction warlock, feral cat) matches the pinned wowsims
--        APL priority list, parsed from the committed JSON fixtures under
--        tools/evidence/apl/ via shared/apl_parser.lua.
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
--            order pinned below from sim/druid/feral/rotation.go doRotation()).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;tools/?.lua;" .. package.path

local apl = require("shared/apl_parser")

local assert_true = function(v, label) if not v then error(label or "assert_true failed", 2) end end
local failures, total_tests, total_passed = {}, 0, 0

local function test(label, fn)
    total_tests = total_tests + 1
    local ok, err = pcall(fn)
    if ok then total_passed = total_passed + 1
    else failures[#failures + 1] = { label = label, error = err } end
end

-- ---------------------------------------------------------------------------
-- Fixture loading
-- ---------------------------------------------------------------------------
local function read_file(path)
    local f = io.open(path, "rb")
    if not f then return nil, "missing fixture: " .. path end
    local s = f:read("*a")
    f:close()
    return s
end

local FIXTURES = {
    fire  = "tools/evidence/apl/fire_wotlk.apl.json",
    affl  = "tools/evidence/apl/affliction_wotlk.apl.json",
    feral = "tools/evidence/apl/feralcat_wotlk.apl.json",
}

test("fixtures exist and decode as TypeAPL", function()
    for name, path in pairs(FIXTURES) do
        local raw, err = read_file(path)
        assert_true(raw ~= nil, err or "no fixture content for " .. name)
        local apl_table = apl.decode_json(raw)
        assert_true(type(apl_table) == "table", name .. ": expected decoded table")
        assert_true(apl_table.type == "TypeAPL", name .. ": expected TypeAPL, got " .. tostring(apl_table.type))
    end
end)

-- ---------------------------------------------------------------------------
-- Spec loading (mock NS per the existing *_wotlk_dsl_priority tests)
-- ---------------------------------------------------------------------------
local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

local function base_ns()
    return {
        GetPlayer = function() return {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
        } end,
        me = {
            get_health_percentage = function() return 80 end,
            get_mana_percentage = function() return 80 end,
            get_energy = function() return 100 end,
            get_combo_points = function() return 5 end,
        },
        core = {
            spell_book = { get_spell_cast_time = function() return 1.75 end },
        },
        spell_action = make_action,
        spell_ready = function() return true end,
        spell_exists = function() return true end,
        try_cast = function() return true end,
        buff_up = function() return false end,
        buff_remains = function() return 0 end,
        debuff_up = function() return false end,
        debuff_remains = function() return 0 end,
        debuff_stacks = function() return 0 end,
        get_debuff_stacks = function() return 0 end,
        cooldown_remains = function() return 0 end,
        is_behind_target = function() return true end,
        is_item_ready = function() return false end,
        use_item_by_id = function() return true end,
        broken_api_throttled = function() return false end,
        should_use_long_cd = function() return true end,
        time_now = function() return 0 end,
        log = function() end,
        log_warning = function() end,
        rotation_registry = {
            register = function(self, name, strategies, options) end,
        },
    }
end

local function load_spec(path, spells)
    _G.EaxRotations = base_ns()
    _G.EaxRotations[spells] = {
        Pyroblast = make_action(42891, "Pyroblast"),
        LivingBomb = make_action(55360, "LivingBomb"),
        FireBlast = make_action(42873, "FireBlast"),
        Scorch = make_action(42859, "Scorch"),
        Fireball = make_action(42833, "Fireball"),
        Combustion = make_action(11129, "Combustion"),
        FaerieFireFeral = make_action(27011, "FaerieFireFeral"),
        Ravage = make_action(27005, "Ravage"),
        MangleCat = make_action(48566, "MangleCat"),
        Rake = make_action(48574, "Rake"),
        Rip = make_action(49800, "Rip"),
        SavageRoar = make_action(52610, "SavageRoar"),
        FerociousBite = make_action(48576, "FerociousBite"),
        Shred = make_action(48572, "Shred"),
        UnstableAffliction = make_action(47843, "UnstableAffliction"),
        Haunt = make_action(59164, "Haunt"),
        Corruption = make_action(47813, "Corruption"),
        CurseOfAgony = make_action(47864, "CurseOfAgony"),
        DrainSoul = make_action(47855, "DrainSoul"),
        ShadowBolt = make_action(47809, "ShadowBolt"),
    }
    local mod = dofile(path)
    assert_true(type(mod) == "table" and type(mod.strategies) == "table",
        path .. " should return { strategies = ... }")
    return mod.strategies
end

local function strategy_names(strategies)
    local names = {}
    for i, s in ipairs(strategies) do names[i] = s.name end
    return names
end

-- ---------------------------------------------------------------------------
-- Reference order per pilot spec
-- ---------------------------------------------------------------------------
-- fire: APL priority list (occurrence-preserving):
--   Scorch-refresh (42859) -> Pyroblast-hotstreak (42891) -> Living Bomb
--   multidot (55360) -> FireBlast-execute (42873) -> Scorch-execute (42859)
--   -> Fireball (42833).  Our rotation splits the two Scorch casts into the
--   "Scorch" (debuff refresh) and "ScorchFinal" (execute) lanes; the resolver
--   maps occurrence 1 -> Scorch, occurrence 2 -> ScorchFinal.
local function fire_resolve(id, occurrence)
    if id == 42859 then
        return occurrence == 1 and "Scorch" or "ScorchFinal"
    end
    if id == 42891 then return "Pyroblast" end
    if id == 55360 then return "LivingBomb" end
    if id == 42873 then return "FireBlast" end
    if id == 42833 then return "Fireball" end
    return nil
end

-- affl: steady-state DoT refresh order in the APL (trinkets/racials and Life
-- Tap excluded — they are not strategies in affliction_wotlk.lua):
--   Haunt (59164) -> Corruption (47813) -> UnstableAffliction (47843)
--   -> CurseOfAgony (47864) -> Drain Soul (47855, x2) -> Shadow Bolt (47809)
local function affl_resolve(id)
    if id == 59164 then return "Haunt" end
    if id == 47813 then return "Corruption" end
    if id == 47843 then return "UnstableAffliction" end
    if id == 47864 then return "CurseOfAgony" end
    if id == 47855 then return "DrainSoul" end
    if id == 47809 then return "ShadowBolt" end
    return nil
end

-- feral: JSON is a Go black box (catOptimalRotationAction) — reference order
-- pinned from sim/druid/feral/rotation.go doRotation() dispatch at the same
-- wowsims commit: FaerieFireFeral (ffNow) -> SavageRoar (roarNow) -> Rip
-- (ripNow) -> FerociousBite (biteNow) -> MangleCat (mangleNow) -> Rake
-- (rakeNow) -> Shred (filler). Ravage is a stealth opener not in the loop.
local FERAL_REFERENCE = {
    "FaerieFireFeral", "SavageRoar", "Rip", "FerociousBite", "MangleCat", "Rake", "Shred",
}

-- ---------------------------------------------------------------------------
-- Conformance tests
-- ---------------------------------------------------------------------------
print("=== test_apl_conformance ===")

-- Fire mage
test("fire: strategy order conforms to wowsims APL", function()
    local strategies = load_spec("EaxRotations/classes/mage/fire_wotlk.lua", "MageSpells")
    local raw = read_file(FIXTURES.fire)
    local apl_table = apl.decode_json(raw)
    local ids = apl.priority_ids(apl_table)
    local violation = apl.check_id_order(strategy_names(strategies), ids, fire_resolve)
    assert_true(violation == nil, "fire APL violation: " .. (violation and (
        violation.prev .. " (pos " .. violation.prev_pos .. ") should be before "
        .. violation.name .. " (pos " .. violation.name_pos .. ")") or "unknown"))
end)

-- Affliction warlock
test("affliction: strategy order conforms to wowsims APL", function()
    local strategies = load_spec("EaxRotations/classes/warlock/affliction_wotlk.lua", "WarlockSpells")
    local raw = read_file(FIXTURES.affl)
    local apl_table = apl.decode_json(raw)
    local ids = apl.priority_ids(apl_table)
    local violation = apl.check_id_order(strategy_names(strategies), ids, affl_resolve)
    assert_true(violation == nil, "affliction APL violation: " .. (violation and (
        violation.prev .. " (pos " .. violation.prev_pos .. ") should be before "
        .. violation.name .. " (pos " .. violation.name_pos .. ")") or "unknown"))
end)

-- Feral cat (Go-derived pinned reference)
test("feral cat: strategy order conforms to wowsims Go dispatch order", function()
    local strategies = load_spec("EaxRotations/classes/druid/cat_wotlk.lua", "DruidSpells")
    local violation = apl.check_name_order(strategy_names(strategies), FERAL_REFERENCE)
    assert_true(violation == nil, "feral cat conformance violation: " .. (violation and (
        violation.prev .. " (pos " .. violation.prev_pos .. ") should be before "
        .. violation.name .. " (pos " .. violation.name_pos .. ")") or "unknown"))
end)

-- Negative self-tests: prove the checker actually catches a reorder.
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

-- Fixture ids sanity: every referenced strategy id must actually appear in the
-- fixture (guards against a stale fixture silently testing nothing).
test("fire: all core strategy ids appear in fixture", function()
    local raw = read_file(FIXTURES.fire)
    local ids = apl.unique_ids(apl.decode_json(raw))
    local seen = {}
    for _, id in ipairs(ids) do seen[id] = true end
    for _, id in ipairs({ 42859, 42891, 55360, 42873, 42833 }) do
        assert_true(seen[id], "fire fixture missing id " .. id)
    end
end)

test("affl: all core strategy ids appear in fixture", function()
    local raw = read_file(FIXTURES.affl)
    local ids = apl.unique_ids(apl.decode_json(raw))
    local seen = {}
    for _, id in ipairs(ids) do seen[id] = true end
    for _, id in ipairs({ 59164, 47813, 47843, 47864, 47855, 47809 }) do
        assert_true(seen[id], "affl fixture missing id " .. id)
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
