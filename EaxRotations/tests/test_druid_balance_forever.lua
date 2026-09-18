-- test_druid_balance_forever.lua -- unit pins for the druid balance Forever delta.
-- WHAT:  balance_forever.lua contract: baseline capture + re-register splice
--        (the Eclipse pair above StarfirePrimary), the engraving-known gate
--        at load, the charge-read fail-safe (missing API keeps the baseline
--        priority), matcher gates, by-name dormancy, zero-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Eclipse is a Wrath-procs-fast-Starfire loop (the kit's "4-stack
--        alternation" is wrong): if the charge read silently returns 0 the
--        pair degenerates into Wrath spam, which is exactly why the read's
--        unusable case must keep the classic Starfire priority.
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
local charge_value = 0
local charges_readable = true
local NS = {
    settings = {},
    log = function() end,
    PLAYER_UNIT = {},
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    DruidSpells = {
        Starfire = { ids = { 2912 } },
        Wrath = { ids = { 5176 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
    buff_stacks = function(unit, ids)
        if not charges_readable then return nil end
        return charge_value
    end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "balance",
    strategies = {
        { name = "BarkskinDefense", matches = function() return false end, execute = function() return false end },
        { name = "MoonfireDoT", matches = function() return false end, execute = function() return false end },
        { name = "StarfirePrimary", matches = function() return false end, execute = function() return false end },
        { name = "WrathFiller", matches = function() return false end, execute = function() return false end },
        { name = "MarkOfTheWild", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/druid/balance_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/druid/balance_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/druid/balance_forever.lua")
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
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {}, is_moving = false }
end

local function fresh_state(overrides)
    local s = { mana_pct = 80, is_moving = false }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

-- A. Full kit: engraving learned -> the pair splices above StarfirePrimary.
do
    learnt = {}
    learnt[19131] = true
    charge_value = 2
    charges_readable = true
    local combined = load_delta({}, { ["Eclipse"] = 19131 }, { ["Eclipse"] = 19132 })
    assert_eq(registered and registered.name, "balance", "A: re-registers the balance playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(combined[1] and combined[1].name, "BarkskinDefense", "A: defensive head lanes untouched")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 eclipse lanes over 5 baseline lanes")
    local sf = find_lane(combined, "StarfirePrimary")
    assert_eq(find_lane(combined, "Forever_EclipseStarfire"), sf - 2, "A: Starfire lane leads the pair")
    assert_eq(find_lane(combined, "Forever_EclipseWrath"), sf - 1, "A: Wrath lane follows")
    learnt = {}
end

-- B. Engraving not learned: the pair stays out (the classic priority runs).
do
    learnt = {}
    charge_value = 0
    local combined = load_delta({}, { ["Eclipse"] = 19131 }, { ["Eclipse"] = 19132 })
    assert_eq(#combined, #FAKE_BASELINE.strategies, "B: no delta lanes without the engraving")
    assert_true(not find_lane(combined, "Forever_EclipseStarfire"), "B: Starfire lane absent")
    assert_true(not find_lane(combined, "Forever_EclipseWrath"), "B: Wrath lane absent")
end

-- B2. Matcher behavior: charges up -> Starfire; no charges -> Wrath;
-- unreadable charges -> neither (baseline priority).
do
    learnt = {}
    learnt[19131] = true
    charges_readable = true
    local combined = load_delta({}, { ["Eclipse"] = 19131 }, { ["Eclipse"] = 19132 })
    local ctx = fresh_ctx()
    local state = fresh_state()
    local sf = combined[find_lane(combined, "Forever_EclipseStarfire")]
    local wr = combined[find_lane(combined, "Forever_EclipseWrath")]

    charge_value = 3
    assert_true(sf.matches(ctx, state), "B2: charged Eclipse fires Starfire")
    assert_true(not wr.matches(ctx, state), "B2: Wrath holds while charged")
    charge_value = 0
    assert_true(not sf.matches(ctx, state), "B2: Starfire holds without charges")
    assert_true(wr.matches(ctx, state), "B2: Wrath re-procs with no charges")
    charges_readable = false
    assert_true(not sf.matches(ctx, state), "B2: no Starfire on an unreadable charge state")
    assert_true(not wr.matches(ctx, state), "B2: no Wrath on an unreadable charge state (baseline priority)")
    charges_readable = true
    charge_value = 2
    local moving = fresh_state({ is_moving = true })
    assert_true(not sf.matches(ctx, moving), "B2: Starfire holds while moving")
    local poor = fresh_state({ mana_pct = 5 })
    assert_true(not sf.matches(ctx, poor), "B2: Starfire respects the mana floor")
    charge_value = 0
    assert_true(not wr.matches(ctx, poor), "B2: Wrath respects the mana floor")
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not wr.matches(no_target, state), "B2: Wrath needs a valid enemy")
    cast_log = {}
    assert_true(wr.execute(ctx, state), "B2: Wrath executes")
    charge_value = 2
    cast_log = {}
    assert_true(sf.execute(ctx, state), "B2: Starfire executes")
    learnt = {}
end

-- C. Dormancy: empty mirrors -> no lanes at all.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_EclipseStarfire"), "C: Starfire dormant")
    assert_true(not find_lane(combined, "Forever_EclipseWrath"), "C: Wrath dormant")
end

-- D. Splice fallback: no nuke anchor appends the pair.
do
    FAKE_BASELINE.strategies = {
        { name = "BarkskinDefense", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    learnt[19131] = true
    local combined = load_delta({}, { ["Eclipse"] = 19131 }, { ["Eclipse"] = 19132 })
    assert_eq(find_lane(combined, "Forever_EclipseStarfire"), #combined - 1, "D: Starfire appends first")
    assert_eq(find_lane(combined, "Forever_EclipseWrath"), #combined, "D: Wrath appends last")
    learnt = {}
end

-- G. Mirror selection: the charge read uses the BUFF-mirror id (the builder
-- pin), never the talent text sentinel.
do
    learnt = {}
    learnt[19131] = true
    charges_readable = true
    charge_value = 3
    local combined = load_delta({}, { ["Eclipse"] = 19131 }, { ["Eclipse"] = 19132 })
    local ctx = fresh_ctx()
    local state = fresh_state()
    local sf = combined[find_lane(combined, "Forever_EclipseStarfire")]
    local seen_ids = nil
    local orig_stacks = NS.buff_stacks
    NS.buff_stacks = function(unit, ids) seen_ids = ids; return 3 end
    assert_true(sf.matches(ctx, state), "G: charged Starfire matches on the buff-mirror read")
    assert_eq(seen_ids and seen_ids[1], 19132, "G: the charge read uses the buff-mirror id (not the 19131 talent)")
    NS.buff_stacks = orig_stacks
    learnt = {}
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/druid/balance_forever.lua", "r")
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

print(string.format("test_druid_balance_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS druid_balance_forever")
