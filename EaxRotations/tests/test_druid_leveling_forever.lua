-- test_druid_leveling_forever.lua -- unit pins for the druid leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Omen clearcast weave above Shred), the cat/combat/target/
--        combo-ceiling gates, the free-cast energy waiver, the behind-based
--        pick (Shred vs Claw), by-name dormancy, mirror selection,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   The clearcast window is the whole point of the lane: if it kept the
--        baseline's flat energy floors the free cast would never fire at low
--        energy; without the combo ceiling it would waste the proc on a
--        capped bar.
-- SAFETY: fully mocked NS + require (fake baseline module).

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;" .. package.path

local pass, fail = 0, 0
local function assert_true(v, label)
    if v then pass = pass + 1 else fail = fail + 1; print("  FAIL: " .. tostring(label)) end
end
local function assert_eq(a, b, label)
    if a == b then pass = pass + 1
    else fail = fail + 1; print("  FAIL: " .. tostring(label) .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")") end
end

local registered = nil
local cast_log = {}
local clearcast = false
local OMEN = 19110
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    DruidSpells = {
        Shred = { ids = { 27002, 9830, 5221 }, name = "Shred" },
        Claw = { ids = { 27000, 9850, 1082 }, name = "Claw" },
    },
    buff_up = function(unit, ids)
        if type(ids) == "number" then return clearcast and ids == OMEN end
        return false
    end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "CatFormEntry", matches = function() return false end, execute = function() return false end },
        { name = "Rake", matches = function() return false end, execute = function() return false end },
        { name = "Shred", matches = function() return false end, execute = function() return false end },
        { name = "Rip", matches = function() return false end, execute = function() return false end },
        { name = "FerociousBite", matches = function() return false end, execute = function() return false end },
        { name = "Claw", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_by_name, pending_maxrank, pending_buff = {}, {}, {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_by_name,
                 spell_maxrank_by_name_forever = pending_maxrank,
                 spell_buff_by_name_forever = pending_buff }
    end
    if path == "classes/druid/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/druid/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/druid/leveling_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx()
    return { is_leveling = true, in_combat = true, target = { name = "enemy" },
             has_valid_enemy_target = true, me = {}, settings = {} }
end

local function fresh_state(overrides)
    local s = {
        is_cat = true,
        in_combat = true,
        target = { name = "enemy" },
        combo_points = 2,
        energy = 0,
        is_behind = true,
        shred_ready = true,
        claw_ready = true,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- A. The lane is live and leads the Shred lane.
do
    clearcast = false
    local combined = load_delta({}, {}, { ["Omen of Clarity"] = OMEN })
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_OmenClearcast"), find_lane(combined, "Shred") - 1,
        "A: the clearcast weave leads the Shred lane")
end

-- A2. No mirror: the lane is dormant (fail closed).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_OmenClearcast"), "A2: dormant without the buff row")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the gates + the free-cast waiver.
do
    clearcast = false
    local combined = load_delta({}, {}, { ["Omen of Clarity"] = OMEN })
    local weave = combined[find_lane(combined, "Forever_OmenClearcast")]
    local ctx = fresh_ctx()
    assert_true(not weave.matches(ctx, fresh_state()), "B: no clearcast = no weave")
    clearcast = true
    assert_true(weave.matches(ctx, fresh_state()), "B: clearcast + behind fires at ZERO energy (the free cast)")
    assert_true(not weave.matches(ctx, fresh_state({ is_cat = false })), "B: caster form holds")
    assert_true(not weave.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    assert_true(not weave.matches(ctx, fresh_state({ combo_points = 5 })), "B: the combo ceiling holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not weave.matches(ctx, no_target), "B: no target holds")
    cast_log = {}
    assert_true(weave.execute(ctx, fresh_state()), "B: the weave executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.DruidSpells.Shred, "B: behind picks Shred")
    cast_log = {}
    assert_true(weave.execute(ctx, fresh_state({ is_behind = false })), "B: the front executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.DruidSpells.Claw, "B: the front picks Claw")
    cast_log = {}
    assert_true(weave.execute(ctx, fresh_state({ shred_ready = false })), "B: an unavailable Shred falls through")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.DruidSpells.Claw, "B: the fallback is Claw")
    assert_true(not weave.matches(ctx, fresh_state({ shred_ready = false, claw_ready = false })),
        "B: no free-castable ability holds the lane")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_OmenClearcast"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "CatFormEntry", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta({}, {}, { ["Omen of Clarity"] = OMEN })
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_OmenClearcast"), 2, "D: appended last")
end

-- G. Mirror selection: the buff mirror id drives the clearcast read.
do
    clearcast = true
    local combined = load_delta({}, {}, { ["Omen of Clarity"] = OMEN })
    local weave = combined[find_lane(combined, "Forever_OmenClearcast")]
    cast_log = {}
    assert_true(weave.execute(fresh_ctx(), fresh_state()), "G: the sentinel drives the lane")
    assert_true(cast_log[1] ~= nil, "G: a cast was logged")
    clearcast = false
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/druid/leveling_forever.lua", "rb")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local body = content:gsub("%-%-[^\n]*", "")
    local found = nil
    for line in body:gmatch("([^\n]*)") do
        local digits = line:match("%f[%d]%d%f[^%d]")
        if digits and #digits >= 4 then
            found = found or line
        end
    end
    assert_true(found == nil, "E: no numeric spell-ID literals (found: " .. tostring(found) .. ")")
end

print("test_druid_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS druid_leveling_forever")
