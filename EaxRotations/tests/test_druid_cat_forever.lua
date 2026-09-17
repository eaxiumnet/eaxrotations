-- test_druid_cat_forever.lua -- unit pins for the druid cat Forever delta.
-- WHAT:  cat_forever.lua contract: baseline capture + re-register splice
--        (Berserk above the first damage lane, Tiger's Fury replacement in
--        the baseline lane's position, Powershift + baseline TigersFury
--        DROPPED), by-name dormancy, matcher gates, zero-numeric-literal
--        contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the destructive delta is the point: if the Powershift lane survives,
--        Forever cat keeps burning GCDs on a dead mechanic (Furor restore),
--        and if the Tiger's Fury replacement loses its buff gate or its
--        free-CD semantics, the lane either spams a live buff or holds a
--        free damage window.
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
local PLAYER_UNIT_REF = {}
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = PLAYER_UNIT_REF,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    DruidSpells = {
        TigersFury = { ids = { 9846, 5217 } },
        Rip = { ids = { 1079 } },
        Shred = { ids = { 5221 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    should_use_long_cd = function() return true end,
    buff_up = function() return false end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "cat",
    strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
        { name = "Powershift", matches = function() return false end, execute = function() return false end },
        { name = "Rip", matches = function() return false end, execute = function() return false end },
        { name = "TigersFury", matches = function() return false end, execute = function() return false end },
        { name = "Shred", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/druid/cat_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/druid/cat_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(by_name, maxrank, buff)
    pending_by_name = by_name or {}
    pending_maxrank = maxrank or {}
    pending_buff = buff or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/druid/cat_forever.lua")
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
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }
end

local function fresh_state(overrides)
    local s = { is_cat = true, energy = 60, mana_pct = 80, target = {} }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

-- A. Full kit: bridge names resolve; destructive splice shape.
do
    local combined = load_delta({ ["Berserk"] = 19010, ["Tiger's Fury"] = 19011 },
        { ["Berserk"] = 19110 }, { ["Tiger's Fury"] = 19211 })
    assert_eq(registered and registered.name, "cat", "A: re-registers the cat playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "A: 5 baseline lanes, 2 dropped + 2 added")
    assert_true(find_lane(combined, "Powershift") == nil, "A: Powershift lane DROPPED (Furor rework)")
    assert_true(find_lane(combined, "TigersFury") == nil, "A: baseline TigersFury lane replaced")
    assert_eq(find_lane(combined, "Forever_BerserkCat"), find_lane(combined, "Rip") - 1,
        "A: Berserk sits just above the first damage lane (Rip)")
    assert_eq(find_lane(combined, "Forever_TigersFuryBurst"), find_lane(combined, "Shred") - 1,
        "A: Tiger's Fury replacement takes the baseline lane's position")
    assert_true(find_lane(combined, "IceBarrier") == 1, "A: defensive head lanes untouched")
end

-- B. Matcher behavior: Berserk burst gates; Tiger's Fury free-CD gates.
do
    local combined = load_delta({ ["Berserk"] = 19010, ["Tiger's Fury"] = 19011 },
        { ["Berserk"] = 19110 }, { ["Tiger's Fury"] = 19211 })
    local ctx = fresh_ctx()
    local state = fresh_state()

    local berserk = combined[find_lane(combined, "Forever_BerserkCat")]
    assert_true(berserk.matches(ctx, state), "B: Berserk fires in cat form with energy")
    state.is_cat = false
    assert_true(not berserk.matches(ctx, state), "B: Berserk holds outside cat form")
    state.is_cat = true
    state.energy = 10
    assert_true(not berserk.matches(ctx, state), "B: Berserk holds below the energy floor")
    state.energy = 60
    NS.should_use_long_cd = function() return false end
    assert_true(not berserk.matches(ctx, state), "B: Berserk respects the long-CD gate")
    NS.should_use_long_cd = function() return true end
    local ooc = fresh_ctx()
    ooc.in_combat = false
    assert_true(not berserk.matches(ooc, state), "B: Berserk needs combat")
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not berserk.matches(no_target, state), "B: Berserk needs a valid enemy")
    cast_log = {}
    assert_true(berserk.execute(ctx, state), "B: Berserk executes")

    local tf = combined[find_lane(combined, "Forever_TigersFuryBurst")]
    assert_true(tf.matches(ctx, state), "B: Tiger's Fury fires with the buff down")
    NS.has_player_buff = function(id) return id == 19211 end
    assert_true(not tf.matches(ctx, state), "B: Tiger's Fury holds while the buff is up (buff mirror)")
    NS.has_player_buff = function() return false end
    state.is_stealthed = true
    assert_true(not tf.matches(ctx, state), "B: Tiger's Fury holds while stealthed")
    state.is_stealthed = false
    assert_true(not tf.matches(ooc, state), "B: Tiger's Fury needs combat")
    -- The reworked TF is FREE: high energy must not block it (the baseline's
    -- "+30 fits under the cap" gate is exactly what this replacement drops).
    state.energy = 95
    assert_true(tf.matches(ctx, state), "B: Tiger's Fury fires at high energy (no cost, no cap gate)")
    state.energy = 60
    cast_log = {}
    assert_true(tf.execute(ctx, state), "B: Tiger's Fury executes")
end

-- C. Dormancy on nil lookups: empty mirrors drop both delta lanes (the two
-- destructive removals still apply — they are bridge-independent).
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies - 2, "C: both delta lanes dormant, 2 baseline lanes dropped")
    assert_true(not find_lane(combined, "Forever_BerserkCat"), "C: Berserk dormant")
    assert_true(not find_lane(combined, "Forever_TigersFuryBurst"), "C: Tiger's Fury dormant")
    assert_true(not find_lane(combined, "Powershift"), "C: Powershift still dropped")
    assert_eq(find_lane(combined, "Rip"), 2, "C: baseline order otherwise intact")
end

-- D. Splice fallback: missing anchors append the delta lanes.
do
    FAKE_BASELINE.strategies = {
        { name = "ManaPotion", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Berserk"] = 19010 }, { ["Berserk"] = 19110 }, { ["Tiger's Fury"] = 19211 })
    assert_eq(find_lane(combined, "Forever_BerserkCat"), #combined - 1, "D: Berserk appends before Tiger's Fury")
    assert_eq(find_lane(combined, "Forever_TigersFuryBurst"), #combined, "D: Tiger's Fury appends last")
end

-- G. Mirror selection: Berserk casts the maxrank sentinel; Tiger's Fury
-- gates on the buff-mirror sentinel -- never the rank-1 baseline.
do
    local combined = load_delta({ ["Berserk"] = 19010, ["Tiger's Fury"] = 19011 },
        { ["Berserk"] = 19110 }, { ["Tiger's Fury"] = 19211 })
    local ctx = fresh_ctx()
    local state = fresh_state()

    local berserk = combined[find_lane(combined, "Forever_BerserkCat")]
    cast_log = {}
    assert_true(berserk.execute(ctx, state), "G: Berserk executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19110, "G: Berserk casts the maxrank sentinel (not the 19010 baseline)")

    local tf = combined[find_lane(combined, "Forever_TigersFuryBurst")]
    NS.has_player_buff = function(id) return id == 19211 end
    assert_true(not tf.matches(ctx, state), "G: Tiger's Fury reads the buff-mirror sentinel")
    NS.has_player_buff = function(id) return id == 19011 end
    assert_true(tf.matches(ctx, state), "G: Tiger's Fury ignores the rank-1 baseline sentinel")
    NS.has_player_buff = function() return false end
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/druid/cat_forever.lua", "r")
    local content = f and f:read("*a") or ""
    if f then f:close() end
    assert_true(#content > 0, "E: delta source readable")
    local bad = {}
    local line_no = 0
    for line in content:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        if line:match("^%s*%-%-") ~= nil then
            -- comment line: exempt
        else
            for table_part in line:gmatch("(%b{})") do
                local inner = table_part:sub(2, -2)
                if inner:match("^[%s%d,]*$") then
                    for num in inner:gmatch("%d+") do
                        if tonumber(num) >= 100 then bad[#bad + 1] = line_no .. ":" .. num end
                    end
                end
            end
        end
    end
    assert_eq(#bad, 0, "E: zero numeric ID literals in code (found: " .. table.concat(bad, ", ") .. ")")
end

-- F. Baseline load failure is loud.
do
    FAKE_BASELINE = nil
    local ok, err = pcall(load_delta, {})
    assert_true(not ok, "F: delta errors when the baseline cannot load")
    assert_true(tostring(err):find("baseline load failed", 1, true) ~= nil, "F: error names the baseline failure")
end

require = orig_require

print(string.format("test_druid_cat_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS druid_cat_forever")
