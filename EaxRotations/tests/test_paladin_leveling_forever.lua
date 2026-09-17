-- test_paladin_leveling_forever.lua -- unit pins for the paladin leveling Forever delta.
-- WHAT:  leveling_forever.lua contract: baseline capture + re-register splice
--        (the Holy Strike lane above Consecration), the leveling guards
--        (context guard, combat, movement, the seal-up damage-lane gate),
--        the two-rung ladder resolution, by-name dormancy, mirror selection,
--        zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Holy Strike without the seal-up gate would spend the GCD seal-less
--        (the baseline's damage lanes all carry that gate); without the
--        context guard it would fire in raid contexts the leveling playstyle
--        must not touch.
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
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    PaladinSpells = {},
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target, reason = reason }
        return true
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "leveling",
    strategies = {
        { name = "BlessingMight", matches = function() return false end, execute = function() return false end },
        { name = "FlashOfLight", matches = function() return false end, execute = function() return false end },
        { name = "Judgement", matches = function() return false end, execute = function() return false end },
        { name = "Exorcism", matches = function() return false end, execute = function() return false end },
        { name = "Consecration", matches = function() return false end, execute = function() return false end },
        { name = "Seal", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/paladin/leveling_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/paladin/leveling_vanilla' not found", 0)
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/paladin/leveling_forever.lua")
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
        target = { name = "enemy" },
        in_combat = true,
        is_moving = false,
        has_any_seal = true,
        selected_seal = nil,
        enemies = 1,
    }
    for k, v in pairs(overrides or {}) do s[k] = v end
    return s
end

local MAX = 19100
local R1 = 19101
local MIRRORS = { ["Holy Strike"] = R1 }
local MAXRANK = { ["Holy Strike"] = MAX }
local BUFFS = {}

-- A. The lane is live and leads the AoE lane.
do
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    assert_eq(registered and registered.name, "leveling", "A: re-registers the leveling playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: 1 delta lane over 6 baseline lanes")
    assert_eq(find_lane(combined, "Forever_HolyStrike"), find_lane(combined, "Consecration") - 1,
        "A: Holy Strike leads the Consecration lane")
end

-- A2. No mirrors: the lane is dormant (fail closed).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_HolyStrike"), "A2: dormant without the name resolution")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A2: baseline untouched")
end

-- B. Matcher: the leveling guards + the seal-up damage-lane gate.
do
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local strike = combined[find_lane(combined, "Forever_HolyStrike")]
    local ctx = fresh_ctx()
    assert_true(strike.matches(ctx, fresh_state()), "B: a sealed, in-combat, stationary paladin fires the strike")
    assert_true(not strike.matches(ctx, fresh_state({ in_combat = false })), "B: out of combat holds")
    assert_true(not strike.matches(ctx, fresh_state({ is_moving = true })), "B: movement holds")
    local no_target = fresh_state()
    no_target.target = nil
    assert_true(not strike.matches(ctx, no_target), "B: no target holds")
    assert_true(not strike.matches(ctx, fresh_state({ has_any_seal = false, selected_seal = { ids = { 21084 } } })),
        "B: the seal-up gate holds a seal-less paladin with a seal available")
    assert_true(strike.matches(ctx, fresh_state({ has_any_seal = false, selected_seal = nil })),
        "B: a paladin with no seal to cast is not blocked")
    assert_true(not strike.matches(fresh_ctx({ is_leveling = false, is_solo = false }), fresh_state()),
        "B: the context guard holds a non-leveling context")
    cast_log = {}
    assert_true(strike.execute(ctx, fresh_state()), "B: the strike executes")
    assert_true(cast_log[1] ~= nil, "B: a cast was logged")
    assert_true(type(cast_log[1].spell) == "table" and cast_log[1].spell.ids ~= nil, "B: the ladder object is cast")
    assert_eq(cast_log[1] and cast_log[1].target, ctx.target, "B: the strike lands on the target")
end

-- C. Dormancy: empty mirrors leave the lane out (no guessed IDs).
do
    local combined = load_delta({}, {}, {})
    assert_true(not find_lane(combined, "Forever_HolyStrike"), "C: dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: baseline untouched with no name resolution")
end

-- D. Splice fallback: without the anchors the lane appends.
do
    local shrunk = {
        name = "leveling",
        strategies = {
            { name = "BlessingMight", matches = function() return false end, execute = function() return false end },
        },
        options = { get_state = function() return { fake = true } end },
    }
    local saved = FAKE_BASELINE
    FAKE_BASELINE = shrunk
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    FAKE_BASELINE = saved
    assert_eq(#combined, 2, "D: the lane appended without anchors")
    assert_eq(find_lane(combined, "Forever_HolyStrike"), 2, "D: appended last")
end

-- G. Mirror selection: the ladder carries the maxrank rung first.
do
    local combined = load_delta(MIRRORS, MAXRANK, BUFFS)
    local strike = combined[find_lane(combined, "Forever_HolyStrike")]
    local ladder = nil
    -- Capture the ladder via the execute's cast log.
    cast_log = {}
    assert_true(strike.execute(fresh_ctx(), fresh_state()), "G: executes")
    ladder = cast_log[1] and cast_log[1].spell
    assert_true(type(ladder) == "table" and ladder.ids ~= nil, "G: the cast carries an ids ladder")
    assert_eq(ladder.ids[1], MAX, "G: the maxrank rung leads the ladder")
    assert_eq(ladder.ids[2], R1, "G: the rank-1 rung follows")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/paladin/leveling_forever.lua", "rb")
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

print("test_paladin_leveling_forever: " .. pass .. " passed, " .. fail .. " failed")
if fail > 0 then os.exit(1) end
print("PASS paladin_leveling_forever")
