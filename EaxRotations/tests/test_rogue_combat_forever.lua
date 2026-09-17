-- test_rogue_combat_forever.lua -- unit pins for the rogue combat Forever delta.
-- WHAT:  combat_forever.lua contract: baseline capture + re-register splice
--        (the Restless Blades lane above the Eviscerate finisher, the
--        Puncturing Wounds lane above the Hemorrhage generator), the
--        CD-shave window math, the dagger/behind/stealth/energy gates,
--        by-name dormancy, mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   The RB lane without the window math would break the baseline's
--        5-CP Eviscerate rule for nothing; the PW lane without the dagger
--        gates would cast an unusable Backstab from the front.
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
local learnt = {}
local cds = {}
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    RogueSpells = {
        AdrenalineRush = { ids = { 13750 }, name = "AdrenalineRush" },
        BladeFlurry = { ids = { 13877 }, name = "BladeFlurry" },
        Evasion = { ids = { 26669, 5277 }, name = "Evasion" },
        Sprint = { ids = { 11305, 8696, 2983 }, name = "Sprint" },
        Vanish = { ids = { 26889, 1857, 1856 }, name = "Vanish" },
        Eviscerate = { ids = { 26865, 2098 }, name = "Eviscerate" },
        Rupture = { ids = { 26867, 1943 }, name = "Rupture" },
        Hemorrhage = { ids = { 16511 }, name = "Hemorrhage" },
        Backstab = { ids = { 11281, 2589 }, name = "Backstab" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    cooldown_remains = function(spell)
        local id = type(spell) == "table" and spell.ids and spell.ids[1]
        return cds[id] or 0
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "combat",
    strategies = {
        { name = "AdrenalineRush", matches = function() return false end, execute = function() return false end },
        { name = "BladeFlurry", matches = function() return false end, execute = function() return false end },
        { name = "SliceAndDice", matches = function() return false end, execute = function() return false end },
        { name = "Rupture", matches = function() return false end, execute = function() return false end },
        { name = "Eviscerate", matches = function() return false end, execute = function() return false end },
        { name = "Hemorrhage", matches = function() return false end, execute = function() return false end },
        { name = "Backstab", matches = function() return false end, execute = function() return false end },
        { name = "SinisterStrike", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/rogue/combat_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/rogue/combat_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/rogue/combat_forever.lua")
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
    return { in_combat = true, target = { name = "enemy" }, has_valid_enemy_target = true,
             me = {}, settings = {} }
end

local function fresh_state(overrides)
    local s = {
        combo_points = 5,
        energy = 100,
        energy_pool_finisher = false,
        has_daggers = true,
        is_behind = true,
        has_stealth = false,
        in_combat = true,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local RB = 19070
local PW = 19071
local MIRRORS = { ["Restless Blades"] = RB, ["Puncturing Wounds"] = PW }
local MAXRANK = {}
local BUFFS = {}

-- A. Both lanes live.
do
    learnt = { [RB] = true, [PW] = true }
    cds = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "combat", "A: re-registers the combat playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 8 baseline lanes")
    assert_eq(find_lane(combined, "Forever_RestlessBlades"), find_lane(combined, "Eviscerate") - 1,
        "A: the Restless Blades lane leads the Eviscerate finisher")
    assert_true(find_lane(combined, "Forever_RestlessBlades") > find_lane(combined, "Rupture"),
        "A: the shave spend sits below the Rupture bleed refresh")
    assert_eq(find_lane(combined, "Forever_PuncturingWounds"), find_lane(combined, "Hemorrhage") - 1,
        "A: the Puncturing Wounds lane leads the Hemorrhage generator")
end

-- A2. Talents off: both lanes dormant.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_RestlessBlades"), "A2: RB dormant without the talent")
    assert_true(not find_lane(combined, "Forever_PuncturingWounds"), "A2: PW dormant without the talent")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Restless Blades matcher: the shave window spends below the 5-CP rule.
do
    learnt = { [RB] = true, [PW] = true }
    cds = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local rb = combined[find_lane(combined, "Forever_RestlessBlades")]
    local ctx = fresh_ctx()
    assert_true(not rb.matches(ctx, fresh_state()), "B: no tracked CD running = the 5-CP rule holds")
    cds = { [13750] = 6 }
    assert_true(rb.matches(ctx, fresh_state()), "B: AR inside 2x5s fires the shave spend")
    assert_true(not rb.matches(ctx, fresh_state({ combo_points = 2 })), "B: the minimum combo gate holds")
    cds = { [13750] = 3 }
    assert_true(not rb.matches(ctx, fresh_state({ combo_points = 2 })),
        "B: the minimum combo gate holds even inside the reduced window")
    cds = { [13750] = 60 }
    assert_true(not rb.matches(ctx, fresh_state()), "B: a distant CD does not open the lane")
    cds = { [13877] = 8 }
    assert_true(rb.matches(ctx, fresh_state()), "B: any tracked CD counts (Blade Flurry)")
    assert_true(not rb.matches(ctx, fresh_state({ energy_pool_finisher = true })), "B: energy pooling holds")
    assert_true(not rb.matches(ctx, fresh_state({ energy = 20 })), "B: the Eviscerate cost floor holds")
    cast_log = {}
    assert_true(rb.execute(ctx, fresh_state()), "B: the RB lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Eviscerate, "B: it casts Eviscerate")
    assert_true(cast_log[1] and cast_log[1].reason:find("Restless Blades", 1, true) ~= nil,
        "B: the shave is labelled")
end

-- B2. Puncturing Wounds matcher: the promoted dagger generator.
do
    learnt = { [RB] = true, [PW] = true }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local pw = combined[find_lane(combined, "Forever_PuncturingWounds")]
    local ctx = fresh_ctx()
    assert_true(pw.matches(ctx, fresh_state()), "B2: dagger + behind + energy fires Backstab")
    assert_true(not pw.matches(ctx, fresh_state({ has_daggers = false })), "B2: the dagger gate holds")
    assert_true(not pw.matches(ctx, fresh_state({ is_behind = false })), "B2: the behind gate holds")
    assert_true(not pw.matches(ctx, fresh_state({ has_stealth = true })), "B2: stealth prefers the opener")
    assert_true(not pw.matches(ctx, fresh_state({ energy = 50 })), "B2: the Backstab cost gate holds")
    cast_log = {}
    assert_true(pw.execute(ctx, fresh_state()), "B2: the PW lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Backstab, "B2: it casts Backstab")
end

-- C. Dormancy: empty mirrors leave both lanes out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_RestlessBlades"), "C: RB dormant")
    assert_true(not find_lane(combined, "Forever_PuncturingWounds"), "C: PW dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    learnt = { [RB] = true, [PW] = true }
    local shrunk = {
        name = "combat",
        strategies = {
            { name = "SliceAndDice", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: both lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_RestlessBlades"), 2, "D: the RB lane appended first")
    assert_eq(find_lane(combined, "Forever_PuncturingWounds"), 3, "D: the PW lane appended second")
end

-- G. Mirror selection: both lanes read the rank-1 learn gate only.
do
    learnt = { [RB] = true, [PW] = true }
    cds = { [13750] = 6 }
    local no_name = load_delta({}, MAXRANK, BUFFS)
    assert_true(not find_lane(no_name, "Forever_RestlessBlades"), "G: no talent row = dormant RB")
    assert_true(not find_lane(no_name, "Forever_PuncturingWounds"), "G: no talent row = dormant PW")
    local live = load_delta(MIRRORS, MAXRANK, BUFFS)
    local rb = live[find_lane(live, "Forever_RestlessBlades")]
    cast_log = {}
    assert_true(rb.execute(fresh_ctx(), fresh_state()), "G: the talent sentinel drives the lane")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Eviscerate, "G: the class-map Eviscerate is cast")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/rogue/combat_forever.lua", "rb")
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

print("test_rogue_combat_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS rogue_combat_forever")
