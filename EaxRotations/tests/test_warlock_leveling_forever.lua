-- test_warlock_leveling_forever.lua -- unit pins for the warlock leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Curse of the Elements pair lane directly below the baseline's
--        Bane lane), the leveling/combat/mana gates, the Bane-present
--        precondition, the CoE refresh window, by-name dormancy, mirror
--        selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   The amp lane is only legal while the Bane is rolling (the
--        Banes-not-curses slot math): without the precondition it would
--        fight the baseline's Bane lane; without the mana floor it burns a
--        leveling warlock's mana on an amp.
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
local remains = {}
local COE = 19130
local COE_R1 = 19131
local BANE_R1 = 19132
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarlockSpells = {
        CurseOfAgony = { _meta = { ids = { BANE_R1, 980 } }, name = "CurseOfAgony" },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    debuff_remains = function(target, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if remains[id] ~= nil then return remains[id] end
            end
        end
        return 0
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "DemonArmor", matches = function() return false end, execute = function() return false end },
        { name = "Corruption", matches = function() return false end, execute = function() return false end },
        { name = "CurseOfAgony", matches = function() return false end, execute = function() return false end },
        { name = "SiphonLife", matches = function() return false end, execute = function() return false end },
        { name = "DrainLife", matches = function() return false end, execute = function() return false end },
        { name = "ShadowBolt", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warlock/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warlock/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/warlock/leveling_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_ctx(overrides)
    local ctx = { is_leveling = true, in_combat = true, target = { name = "enemy" },
                  has_valid_enemy_target = true, me = {}, settings = {}, mana_pct = 80 }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function fresh_state(overrides)
    local s = {
        in_combat = true,
        target = { name = "enemy" },
        mana_pct = 80,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MIRRORS = { ["Curse of the Elements"] = COE_R1 }
local MAXRANK = { ["Curse of the Elements"] = COE }
local BUFFS = {}

-- A. The lane is live and sits directly below the Bane lane.
do
    remains = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_CurseOfElements"), find_lane(combined, "CurseOfAgony") + 1,
        "A: the amp lane sits directly below the Bane lane")
end

-- A2. No mirrors: the lane is dormant (fail closed).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_CurseOfElements"), "A2: dormant without the name resolution")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the pair precondition + the gates.
do
    remains = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local coe = combined[find_lane(combined, "Forever_CurseOfElements")]
    local ctx = fresh_ctx()
    assert_true(not coe.matches(ctx, fresh_state()), "B: no Bane = no amp (the pair precondition)")
    remains = { [BANE_R1] = 10 }
    assert_true(coe.matches(ctx, fresh_state()), "B: the Bane rolling opens the amp lane")
    assert_true(not coe.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not coe.matches(ctx, no_target), "B: no target holds")
    assert_true(not coe.matches(ctx, fresh_state({ mana_pct = 10 })), "B: the mana floor holds")
    assert_true(not coe.matches(fresh_ctx({ is_leveling = false, is_solo = false }), fresh_state()),
        "B: the leveling context guard holds")
    remains = { [BANE_R1] = 10, [COE] = 8 }
    assert_true(not coe.matches(ctx, fresh_state()), "B: a fresh Curse of the Elements holds")
    remains = { [BANE_R1] = 10, [COE] = 1 }
    assert_true(coe.matches(ctx, fresh_state()), "B: an expiring amp refreshes")
    remains = { [BANE_R1] = 10 }
    cast_log = {}
    local state = fresh_state()
    assert_true(coe.execute(ctx, state), "B: the amp lane executes")
    assert_eq(cast_log[1] and cast_log[1].spell, COE, "B: the maxrank Curse of the Elements is cast")
    assert_eq(cast_log[1] and cast_log[1].target, state.target, "B: it lands on the target")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_CurseOfElements"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "DemonArmor", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_CurseOfElements"), 2, "D: appended last")
end

-- G. Mirror selection: the cast reads maxrank, the debuff read both rungs,
-- the Bane the class-map ladder.
do
    remains = { [BANE_R1] = 10, [COE_R1] = 1 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local coe = combined[find_lane(combined, "Forever_CurseOfElements")]
    assert_true(coe.matches(fresh_ctx(), fresh_state()),
        "G: the rank-1 rung satisfies the CoE refresh read")
    local no_max = load_delta(MIRRORS, {}, BUFFS)
    assert_true(not find_lane(no_max, "Forever_CurseOfElements"), "G: no maxrank = dormant lane")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warlock/leveling_forever.lua", "rb")
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

print("test_warlock_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS warlock_leveling_forever")
