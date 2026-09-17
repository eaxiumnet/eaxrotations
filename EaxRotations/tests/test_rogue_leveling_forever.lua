-- test_rogue_leveling_forever.lua -- unit pins for the rogue leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Mutilate builder above Sinister Strike), the learn gate, the
--        both-hand dagger gate, the energy/combo/combat/target gates, the
--        two-rung ladder shape, dormancy, mirror selection,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Mutilate without the dagger gate fails every cast (both weapons
--        required) and would stall the builder lane; without the energy gate
--        it starves the finishers.
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
local equipped = { main = 0, off = 0 }
local MAX = 19140
local R1 = 19141
local NS = {
    settings = {},
    log = function() end,
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    RogueSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    get_equipped_item_id = function(slot)
        if slot == 16 then return equipped.main end
        if slot == 17 then return equipped.off end
        return 0
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "Stealth", matches = function() return false end, execute = function() return false end },
        { name = "SliceAndDice", matches = function() return false end, execute = function() return false end },
        { name = "Rupture", matches = function() return false end, execute = function() return false end },
        { name = "Eviscerate", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/rogue/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/rogue/leveling_vanilla' not found", 0)
    end
    if path == "shared/dagger_set_sylvanas" then
        return { is_dagger = { [100] = true, [101] = true } }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/rogue/leveling_forever.lua")
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
        in_combat = true,
        target = { name = "enemy" },
        combo_points = 2,
        max_combo_points = 5,
        energy = 100,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MIRRORS = { ["Mutilate"] = R1 }
local MAXRANK = { ["Mutilate"] = MAX }
local BUFFS = {}

-- A. The lane is live and leads the Sinister Strike builder.
do
    learnt = { [MAX] = true }
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 5 baseline lanes")
    assert_eq(find_lane(combined, "Forever_Mutilate"), find_lane(combined, "SinisterStrike") - 1,
        "A: Mutilate leads the Sinister Strike builder")
end

-- A2. Gates off: dormant without the learn or the mirrors.
do
    learnt = {}
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_Mutilate"), "A2: dormant without the learn")
    learnt = { [MAX] = true }
    local no_mirrors = load_delta({}, {}, {})
    assert_true(not find_lane(no_mirrors, "Forever_Mutilate"), "A2: dormant without the name resolution")
    assert_eq(#no_mirrors, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the builder gates + the both-hand dagger requirement.
do
    learnt = { [MAX] = true }
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local mutilate = combined[find_lane(combined, "Forever_Mutilate")]
    local ctx = fresh_ctx()
    assert_true(mutilate.matches(ctx, fresh_state()), "B: a daggered, in-combat builder fires")
    assert_true(not mutilate.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not mutilate.matches(ctx, no_target), "B: no target holds")
    assert_true(not mutilate.matches(ctx, fresh_state({ combo_points = 5 })), "B: the combo ceiling holds")
    assert_true(not mutilate.matches(ctx, fresh_state({ energy = 50 })), "B: the energy cost gate holds")
    equipped = { main = 100, off = 0 }
    assert_true(not mutilate.matches(ctx, fresh_state()), "B: a missing off-hand dagger holds")
    equipped = { main = 0, off = 101 }
    assert_true(not mutilate.matches(ctx, fresh_state()), "B: a missing main-hand dagger holds")
    equipped = { main = 100, off = 101 }
    cast_log = {}
    local state = fresh_state()
    assert_true(mutilate.execute(ctx, state), "B: the builder executes")
    assert_eq(cast_log[1] and cast_log[1].target, state.target, "B: it lands on the target")
    assert_true(type(cast_log[1].spell) == "table" and cast_log[1].spell.ids ~= nil, "B: the ladder object is cast")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_Mutilate"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    learnt = { [MAX] = true }
    equipped = { main = 100, off = 101 }
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "Stealth", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_Mutilate"), 2, "D: appended last")
end

-- G. Mirror selection: the ladder carries the maxrank rung first; the
-- rank-1 learn gate keeps the lane live.
do
    learnt = { [R1] = true }
    equipped = { main = 100, off = 101 }
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local mutilate = combined[find_lane(combined, "Forever_Mutilate")]
    cast_log = {}
    assert_true(mutilate.execute(fresh_ctx(), fresh_state()), "G: the rank-1 learn gate keeps the lane live")
    local ladder = cast_log[1] and cast_log[1].spell
    assert_eq(ladder.ids[1], MAX, "G: the maxrank rung leads the ladder")
    assert_eq(ladder.ids[2], R1, "G: the rank-1 rung follows")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/rogue/leveling_forever.lua", "rb")
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

print("test_rogue_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS rogue_leveling_forever")
