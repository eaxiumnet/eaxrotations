-- test_priest_leveling_forever.lua -- unit pins for the priest leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (Devouring Plague above ShadowWordPain, Fear Ward above
--        PowerWordFortitude), the dot refresh window, the self-buff pattern,
--        the class-map resolution dormancy, append fallback,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   DP without the refresh window recasts every frame; Fear Ward
--        without the out-of-combat/not-already-buffed gates fights the
--        baseline's buff lanes.
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
local buffs = {}
local DP = 19170
local FW = 19171
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = { name = "me" },
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    PriestSpells = {
        DevouringPlague = { _meta = { ids = { DP, 2944 } }, name = "DevouringPlague" },
        FearWard = { _meta = { ids = { FW } }, name = "FearWard" },
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
    buff_up = function(unit, ids)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if buffs[id] then return true end
            end
        end
        return false
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "PowerWordFortitude", matches = function() return false end, execute = function() return false end },
        { name = "InnerFire", matches = function() return false end, execute = function() return false end },
        { name = "ShadowWordPain", matches = function() return false end, execute = function() return false end },
        { name = "HolyFire", matches = function() return false end, execute = function() return false end },
        { name = "MindBlast", matches = function() return false end, execute = function() return false end },
        { name = "Wand", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
function require(path)
    if path == "classes/priest/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/priest/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta()
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/priest/leveling_forever.lua")
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
                  has_valid_enemy_target = true, me = {}, settings = {} }
    for k, v in pairs(overrides or {}) do ctx[k] = v end
    return ctx
end

local function fresh_state(overrides)
    local s = {
        in_combat = true,
        target = { name = "enemy" },
        is_moving = false,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

-- A. Both lanes live and lead their blocks.
do
    remains = {}
    buffs = {}
    local combined = load_delta()
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_DevouringPlague"), find_lane(combined, "ShadowWordPain") - 1,
        "A: DP leads the dot block")
    assert_eq(find_lane(combined, "Forever_FearWard"), find_lane(combined, "PowerWordFortitude") - 1,
        "A: Fear Ward leads the self-buff block")
end

-- A2. Class-map gates off: both lanes dormant.
do
    local saved = NS.PriestSpells
    NS.PriestSpells = {}
    local combined = load_delta()
    NS.PriestSpells = saved
    assert_true(not find_lane(combined, "Forever_DevouringPlague"), "A2: DP dormant without the class-map row")
    assert_true(not find_lane(combined, "Forever_FearWard"), "A2: Fear Ward dormant without the class-map row")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. DP matcher: the dot block pattern.
do
    remains = {}
    buffs = {}
    local combined = load_delta()
    local dp = combined[find_lane(combined, "Forever_DevouringPlague")]
    local ctx = fresh_ctx()
    assert_true(dp.matches(ctx, fresh_state()), "B: a missing plague fires")
    remains = { [DP] = 10 }
    assert_true(not dp.matches(ctx, fresh_state()), "B: a fresh plague holds")
    remains = { [DP] = 2 }
    assert_true(dp.matches(ctx, fresh_state()), "B: an expiring plague refreshes")
    remains = {}
    assert_true(not dp.matches(ctx, fresh_state({ is_moving = true })), "B: movement holds")
    assert_true(not dp.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not dp.matches(ctx, no_target), "B: no target holds")
    cast_log = {}
    local state = fresh_state()
    assert_true(dp.execute(ctx, state), "B: the plague executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.DevouringPlague, "B: it casts the class-map plague")
    assert_eq(cast_log[1] and cast_log[1].target, state.target, "B: it lands on the target")
end

-- B2. Fear Ward matcher: the self-buff pattern.
do
    remains = {}
    buffs = {}
    local combined = load_delta()
    local fw = combined[find_lane(combined, "Forever_FearWard")]
    local ctx = fresh_ctx()
    assert_true(fw.matches(ctx, fresh_state({ in_combat = false })), "B2: out of combat fires Fear Ward")
    assert_true(not fw.matches(ctx, fresh_state()), "B2: in combat holds")
    buffs = { [FW] = true }
    assert_true(not fw.matches(ctx, fresh_state({ in_combat = false })), "B2: an existing ward holds")
    buffs = {}
    cast_log = {}
    assert_true(fw.execute(ctx, fresh_state({ in_combat = false })), "B2: Fear Ward executes")
    assert_eq(cast_log[1] and cast_log[1].spell, NS.PriestSpells.FearWard, "B2: it casts the class-map ward")
    assert_eq(cast_log[1] and cast_log[1].target, NS.PLAYER_UNIT, "B2: it wards the priest")
end

-- C. Dormancy: an empty class map leaves both lanes out.
do
    local saved = NS.PriestSpells
    NS.PriestSpells = {}
    local combined = load_delta()
    NS.PriestSpells = saved
    assert_true(not find_lane(combined, "Forever_DevouringPlague"), "C: dormant")
    assert_true(not find_lane(combined, "Forever_FearWard"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched")
end

-- D. Splice fallback: without the anchors the lanes append.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "Smite", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta()
    FAKE_BASELINE = saved
    assert_eq(#combined, 3, "D: both lanes appended without anchors")
    assert_eq(find_lane(combined, "Forever_DevouringPlague"), 2, "D: DP appended first")
    assert_eq(find_lane(combined, "Forever_FearWard"), 3, "D: Fear Ward appended second")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/priest/leveling_forever.lua", "rb")
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

print("test_priest_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS priest_leveling_forever")
