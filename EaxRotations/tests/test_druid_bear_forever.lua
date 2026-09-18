-- test_druid_bear_forever.lua -- unit pins for the druid bear Forever delta.
-- WHAT:  bear_forever.lua contract: baseline capture + re-register splice
--        (Berserk / Mangle / Lacerate just above the Swipe block), by-name
--        dormancy, matcher gates (bear form, rage floors, long-CD gate,
--        Lacerate stack maintenance), zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Maul-spam is the vanilla bear rotation; on Forever the core is
--        Mangle on cooldown plus a 5-stack Lacerate, with Berserk removing
--        the Mangle cooldown. A delta lane that loses its rage floor, its
--        bear-form gate, or the Lacerate stack read silently reverts the
--        spec to Maul-spam while the battery stays green (byte-identical
--        cells), and a class-map Mangle would be dead in production (its
--        TBC ids are absent from this client).
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
        Maul = { ids = { 9881 } },
        SwipeBear = { ids = { 9908 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    should_use_long_cd = function() return true end,
    debuff_stacks = function() return 0 end,
    debuff_remains = function() return 0 end,
    buff_up = function() return false end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "bear",
    strategies = {
        { name = "Growl", matches = function() return false end, execute = function() return false end },
        { name = "FaerieFireFeral", matches = function() return false end, execute = function() return false end },
        { name = "SwipeAoE", matches = function() return false end, execute = function() return false end },
        { name = "Swipe", matches = function() return false end, execute = function() return false end },
        { name = "Maul", matches = function() return false end, execute = function() return false end },
        { name = "EnrageCombat", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/druid/bear_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/druid/bear_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/druid/bear_forever.lua")
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
    local s = { is_bear = true, rage = 60, enemy_count = 1, target = {} }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

-- A. Full kit: bridge names resolve; splice shape (above the Swipe block,
-- below the taunt/utility lanes).
do
    local combined = load_delta({},
        { ["Berserk"] = 19110, ["Mangle"] = 19114, ["Lacerate"] = 19115 }, {})
    assert_eq(registered and registered.name, "bear", "A: re-registers the bear playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 3, "A: 3 delta lanes over 6 baseline lanes")
    local swipe = find_lane(combined, "SwipeAoE")
    assert_eq(find_lane(combined, "Forever_BerserkBear"), swipe - 3, "A: Berserk leads the delta block")
    assert_eq(find_lane(combined, "Forever_MangleBear"), swipe - 2, "A: Mangle second")
    assert_eq(find_lane(combined, "Forever_Lacerate"), swipe - 1, "A: Lacerate then the Swipe block")
    assert_true(find_lane(combined, "Growl") < find_lane(combined, "Forever_BerserkBear"),
        "A: taunt/utility head lanes keep first refusal")
    assert_true(find_lane(combined, "Maul") > find_lane(combined, "Forever_Lacerate"),
        "A: Maul stays below the new core (rage dump by priority)")
end

-- B. Matcher behavior: Berserk / Mangle / Lacerate gates.
do
    local combined = load_delta({},
        { ["Berserk"] = 19110, ["Mangle"] = 19114, ["Lacerate"] = 19115 }, {})
    local ctx = fresh_ctx()
    local state = fresh_state()

    local berserk = combined[find_lane(combined, "Forever_BerserkBear")]
    assert_true(berserk.matches(ctx, state), "B: Berserk fires in bear form with rage")
    state.is_bear = false
    assert_true(not berserk.matches(ctx, state), "B: Berserk holds outside bear form")
    state.is_bear = true
    state.rage = 5
    assert_true(not berserk.matches(ctx, state), "B: Berserk holds below the rage floor")
    state.rage = 60
    NS.should_use_long_cd = function() return false end
    assert_true(not berserk.matches(ctx, state), "B: Berserk respects the long-CD gate")
    NS.should_use_long_cd = function() return true end
    cast_log = {}
    assert_true(berserk.execute(ctx, state), "B: Berserk executes")

    local mangle = combined[find_lane(combined, "Forever_MangleBear")]
    assert_true(mangle.matches(ctx, state), "B: Mangle fires with rage and a valid enemy")
    state.rage = 5
    assert_true(not mangle.matches(ctx, state), "B: Mangle respects the rage floor")
    state.rage = 60
    local no_target = fresh_ctx()
    no_target.has_valid_enemy_target = false
    assert_true(not mangle.matches(no_target, state), "B: Mangle needs a valid enemy")
    cast_log = {}
    assert_true(mangle.execute(ctx, state), "B: Mangle executes")

    local lac = combined[find_lane(combined, "Forever_Lacerate")]
    NS.debuff_stacks = function() return 0 end
    NS.debuff_remains = function() return 0 end
    assert_true(lac.matches(ctx, state), "B: Lacerate fires with no stacks up")
    NS.debuff_stacks = function() return 3 end
    NS.debuff_remains = function() return 12 end
    assert_true(lac.matches(ctx, state), "B: Lacerate keeps building below the stack cap")
    NS.debuff_stacks = function() return 5 end
    NS.debuff_remains = function() return 12 end
    assert_true(not lac.matches(ctx, state), "B: Lacerate holds at 5 fresh stacks")
    NS.debuff_remains = function() return 2 end
    assert_true(lac.matches(ctx, state), "B: Lacerate refreshes inside the expiry window")
    NS.debuff_remains = function() return 12 end
    state.rage = 5
    NS.debuff_stacks = function() return 0 end
    assert_true(not lac.matches(ctx, state), "B: Lacerate respects the rage floor")
    state.rage = 60
    cast_log = {}
    assert_true(lac.execute(ctx, state), "B: Lacerate executes")
end

-- C. Dormancy on nil lookups: zero delta lanes on empty mirrors (the
-- baseline is additive-safe here — nothing is dropped).
do
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_BerserkBear"), "C: Berserk dormant")
    assert_true(not find_lane(combined, "Forever_MangleBear"), "C: Mangle dormant")
    assert_true(not find_lane(combined, "Forever_Lacerate"), "C: Lacerate dormant")
    assert_eq(find_lane(combined, "SwipeAoE"), 3, "C: baseline order unchanged")
end

-- D. Splice fallback: no Swipe/Maul anchor appends the block in order.
do
    FAKE_BASELINE.strategies = {
        { name = "Growl", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({}, { ["Berserk"] = 19110, ["Mangle"] = 19114, ["Lacerate"] = 19115 }, {})
    assert_eq(find_lane(combined, "Forever_BerserkBear"), #combined - 2, "D: Berserk appends first")
    assert_eq(find_lane(combined, "Forever_MangleBear"), #combined - 1, "D: Mangle second")
    assert_eq(find_lane(combined, "Forever_Lacerate"), #combined, "D: Lacerate last")
end

-- G. Mirror selection: the lanes gate/cast on the maxrank sentinels and the
-- Lacerate stack read uses the maxrank id -- never the rank-1 baseline.
do
    local combined = load_delta({},
        { ["Berserk"] = 19110, ["Mangle"] = 19114, ["Lacerate"] = 19115 }, {})
    local ctx = fresh_ctx()
    local state = fresh_state()

    local berserk = combined[find_lane(combined, "Forever_BerserkBear")]
    cast_log = {}
    assert_true(berserk.execute(ctx, state), "G: Berserk executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19110, "G: Berserk casts the maxrank sentinel")

    local mangle = combined[find_lane(combined, "Forever_MangleBear")]
    cast_log = {}
    assert_true(mangle.execute(ctx, state), "G: Mangle executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19114, "G: Mangle casts the maxrank sentinel")

    local lac = combined[find_lane(combined, "Forever_Lacerate")]
    local seen_stack_ids = nil
    NS.debuff_stacks = function(unit, ids) seen_stack_ids = ids; return 0 end
    NS.debuff_remains = function() return 0 end
    assert_true(lac.matches(ctx, state), "G: Lacerate matches with no stacks")
    assert_eq(seen_stack_ids and seen_stack_ids[1], 19115, "G: Lacerate reads the maxrank mirror id")
    cast_log = {}
    assert_true(lac.execute(ctx, state), "G: Lacerate executes")
    assert_eq(cast_log[1] and cast_log[1].spell, 19115, "G: Lacerate casts the maxrank sentinel")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/druid/bear_forever.lua", "r")
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

print(string.format("test_druid_bear_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS druid_bear_forever")
