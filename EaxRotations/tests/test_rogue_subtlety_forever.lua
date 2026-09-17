-- test_rogue_subtlety_forever.lua -- unit pins for the rogue subtlety Forever delta.
-- WHAT:  subtlety_forever.lua contract: baseline capture + re-register
--        splice (the Thousand Cuts lane above the Hemorrhage builder, the
--        Cutthroat lane above the Ambush opener), the stack-discounted
--        energy math, the behind/dagger/energy gates, by-name dormancy,
--        mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   The TC lane without the discount math would just duplicate the
--        baseline's flat 40-energy floor; the Cutthroat lane without the
--        proc/dagger/behind gates would cast an unusable Ambush.
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
local stacks = {}
local buffs = {}
local behind = true
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
        Hemorrhage = { ids = { 16511 }, name = "Hemorrhage" },
        Ambush = { ids = { 11269, 11268, 8676 }, name = "Ambush" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    buff_stacks = function(unit, id) return stacks[id] or 0 end,
    buff_up = function(unit, id) return buffs[id] == true end,
    is_behind_target = function(target) return behind end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "subtlety",
    strategies = {
        { name = "Stealth", matches = function() return false end, execute = function() return false end },
        { name = "Ambush", matches = function() return false end, execute = function() return false end },
        { name = "Backstab", matches = function() return false end, execute = function() return false end },
        { name = "HemorrhageDebuff", matches = function() return false end, execute = function() return false end },
        { name = "Rupture", matches = function() return false end, execute = function() return false end },
        { name = "Hemorrhage", matches = function() return false end, execute = function() return false end },
        { name = "SinisterStrikeFallback", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/rogue/subtlety_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/rogue/subtlety_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/rogue/subtlety_forever.lua")
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
        energy = 100,
        energy_low = false,
        energy_pool_finisher = false,
        combo = 2,
        mh_dagger_ok = true,
        stealth_up = false,
        hemo_remains = 0,
        rupture_remains = 5,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local TC = 19060
local CUTTHROAT = 19061
local MIRRORS = {}
local MAXRANK = {}
local BUFFS = { ["Thousand Cuts"] = TC, ["Cutthroat"] = CUTTHROAT }

-- A. Both lanes live.
do
    stacks = {}
    buffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "subtlety", "A: re-registers the subtlety playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 7 baseline lanes")
    assert_eq(find_lane(combined, "Forever_ThousandCuts"), find_lane(combined, "Hemorrhage") - 1,
        "A: the TC lane leads the Hemorrhage builder")
    assert_eq(find_lane(combined, "Forever_CutthroatAmbush"), find_lane(combined, "Ambush") - 1,
        "A: the Cutthroat lane leads the Ambush opener")
end

-- A2. Mirror gates off: both lanes dormant.
do
    local combined = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(combined, "Forever_ThousandCuts"), "A2: TC dormant without the buff row")
    assert_true(not find_lane(combined, "Forever_CutthroatAmbush"), "A2: Cutthroat dormant without the buff row")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Thousand Cuts matcher: the stack discount beats the flat pooling floor.
do
    stacks = {}
    buffs = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local tc = combined[find_lane(combined, "Forever_ThousandCuts")]
    local ctx = fresh_ctx()
    assert_true(not tc.matches(ctx, fresh_state({ energy = 32 })), "B: no stacks = the baseline floor applies")
    assert_true(not tc.matches(ctx, fresh_state({ energy = 50 })),
        "B: no stacks = dormant even above the pooling floor (the lane is TC-only)")
    stacks = { [TC] = 3 }
    assert_true(tc.matches(ctx, fresh_state({ energy = 32 })),
        "B: 3 stacks (32 + 9 >= 40) fire the discounted generator")
    assert_true(not tc.matches(ctx, fresh_state({ energy = 20 })),
        "B: 20 + 9 is still under the pooling floor")
    stacks = { [TC] = 5 }
    assert_true(tc.matches(ctx, fresh_state({ energy = 25 })), "B: 5 stacks fire at 25 energy")
    cast_log = {}
    assert_true(tc.execute(ctx, fresh_state({ energy = 32 })), "B: the TC lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Hemorrhage, "B: it casts Hemorrhage")
    assert_true(cast_log[1] and cast_log[1].reason:find("Thousand Cuts", 1, true) ~= nil,
        "B: the stack count is labelled")
end

-- B2. Cutthroat matcher: proc + dagger + behind + energy.
do
    stacks = {}
    buffs = {}
    behind = true
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local cutthroat = combined[find_lane(combined, "Forever_CutthroatAmbush")]
    local ctx = fresh_ctx()
    assert_true(not cutthroat.matches(ctx, fresh_state()), "B2: no proc = no stealth-free Ambush")
    buffs = { [CUTTHROAT] = true }
    assert_true(cutthroat.matches(ctx, fresh_state()), "B2: the proc fires the lane")
    behind = false
    assert_true(not cutthroat.matches(ctx, fresh_state()), "B2: Ambush still needs the behind position")
    behind = true
    assert_true(not cutthroat.matches(ctx, fresh_state({ mh_dagger_ok = false })),
        "B2: a non-dagger main hand holds the lane")
    assert_true(not cutthroat.matches(ctx, fresh_state({ energy = 50 })), "B2: the Ambush energy gate holds")
    cast_log = {}
    assert_true(cutthroat.execute(ctx, fresh_state()), "B2: the Cutthroat lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Ambush, "B2: it casts the class-map Ambush")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B2: the Ambush lands on the target")
end

-- C. Dormancy: empty mirrors leave both lanes out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_ThousandCuts"), "C: TC dormant")
    assert_true(not find_lane(combined, "Forever_CutthroatAmbush"), "C: Cutthroat dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the primary anchors the lanes append.
do
    local shrunk = {
        name = "subtlety",
        strategies = {
            { name = "Stealth", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: both lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_ThousandCuts"), 2, "D: the TC lane appended first")
    assert_eq(find_lane(combined, "Forever_CutthroatAmbush"), 3, "D: the Cutthroat lane appended second")
end

-- G. Mirror selection: both lanes read the buff mirror only.
do
    stacks = { [TC] = 3 }
    buffs = { [CUTTHROAT] = true }
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(no_buff, "Forever_ThousandCuts"), "G: no buff mirror = dormant TC")
    assert_true(not find_lane(no_buff, "Forever_CutthroatAmbush"), "G: no buff mirror = dormant Cutthroat")
    local live = load_delta(MIRRORS, MAXRANK, BUFFS)
    local tc = live[find_lane(live, "Forever_ThousandCuts")]
    cast_log = {}
    assert_true(tc.execute(fresh_ctx(), fresh_state({ energy = 32 })), "G: the buff sentinel drives the lane")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.RogueSpells.Hemorrhage, "G: the class-map Hemorrhage is cast")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/rogue/subtlety_forever.lua", "rb")
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

print("test_rogue_subtlety_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS rogue_subtlety_forever")
