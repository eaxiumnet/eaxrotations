-- test_warrior_leveling_forever.lua -- unit pins for the warrior leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Victory Rush lane above Execute), the rune learn gate, the
--        kill-window (Victorious) read, the melee/combat/target gates,
--        by-name dormancy, mirror selection, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Victory Rush without the Victorious gate would attempt a cast the
--        client refuses (the ability is only usable inside the kill window);
--        without the learn gate an un-engraved warrior would stall the lane.
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
local victorious = false
local VICTORIOUS = 19120
local VR = 19121
local VR_R1 = 19122
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarriorSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
    buff_up = function(unit, ids)
        if type(ids) == "number" then return victorious and ids == VICTORIOUS end
        return false
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "BattleShout", matches = function() return false end, execute = function() return false end },
        { name = "Charge", matches = function() return false end, execute = function() return false end },
        { name = "Execute", matches = function() return false end, execute = function() return false end },
        { name = "Bloodthirst", matches = function() return false end, execute = function() return false end },
        { name = "MortalStrike", matches = function() return false end, execute = function() return false end },
        { name = "Overpower", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warrior/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warrior/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/warrior/leveling_forever.lua")
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
        in_melee_range = true,
        rage = 50,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MIRRORS = { ["Victory Rush"] = VR_R1 }
local MAXRANK = { ["Victory Rush"] = VR }
local BUFFS = { ["Victorious"] = VICTORIOUS }

-- A. The lane is live and leads the Execute lane.
do
    learnt = { [VR] = true }
    victorious = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_VictoryRush"), find_lane(combined, "Execute") - 1,
        "A: Victory Rush leads the Execute lane")
end

-- A2. Gates off: the lane is dormant without the learn or the mirrors.
do
    learnt = {}
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_true(not find_lane(combined, "Forever_VictoryRush"), "A2: dormant without the learn")
    learnt = { [VR] = true }
    local no_mirrors = load_delta({}, {}, {})
    assert_true(not find_lane(no_mirrors, "Forever_VictoryRush"), "A2: dormant without the name resolution")
    assert_eq(#no_mirrors, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the kill window + the melee gates.
do
    learnt = { [VR] = true }
    victorious = false
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local vr = combined[find_lane(combined, "Forever_VictoryRush")]
    local ctx = fresh_ctx()
    assert_true(not vr.matches(ctx, fresh_state()), "B: no kill window = no lane")
    victorious = true
    assert_true(vr.matches(ctx, fresh_state()), "B: the Victorious window fires the lane")
    assert_true(not vr.matches(ctx, fresh_state({ in_melee_range = false })), "B: out of melee holds")
    assert_true(not vr.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not vr.matches(ctx, no_target), "B: no target holds")
    cast_log = {}
    assert_true(vr.execute(ctx, fresh_state()), "B: Victory Rush executes")
    assert_eq(cast_log[1] and cast_log[1].spell, VR, "B: the maxrank Victory Rush id is cast")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B: it lands on the target")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_VictoryRush"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    learnt = { [VR] = true }
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "BattleShout", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_VictoryRush"), 2, "D: appended last")
end

-- G. Mirror selection: the cast reads maxrank, the learn gate both mirrors,
-- the kill window the buff mirror.
do
    learnt = { [VR_R1] = true }
    victorious = true
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local vr = combined[find_lane(combined, "Forever_VictoryRush")]
    cast_log = {}
    assert_true(vr.execute(fresh_ctx(), fresh_state()), "G: the rank-1 learn gate keeps the lane live")
    assert_eq(cast_log[1] and cast_log[1].spell, VR, "G: the maxrank sentinel is the cast id")
    local no_buff = load_delta(MIRRORS, MAXRANK, {})
    assert_true(not find_lane(no_buff, "Forever_VictoryRush"), "G: no buff mirror = dormant lane")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warrior/leveling_forever.lua", "rb")
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

print("test_warrior_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS warrior_leveling_forever")
