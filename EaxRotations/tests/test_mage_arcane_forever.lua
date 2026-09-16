-- test_mage_arcane_forever.lua -- unit pins for the mage arcane Forever delta.
-- WHAT:  arcane_forever.lua contract: baseline capture + re-register splice
--        (barrage lane ABOVE ArcaneMissiles; AB-spam block BELOW it and
--        above Frostbolt so the AM can_cast veto cannot shadow the loop),
--        by-name dormancy, matcher gates, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   a lost baseline lane, an AB spam lane that fires while the AM cusp
--        window is open, or a hardcoded spell ID each silently break day-1
--        arcane.
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
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    MageSpells = {
        ArcaneBlast = { ids = { 30451 } },
        ArcaneMissiles = { ids = { 38699, 25345 } },
    },
    has_player_buff = function() return false end,
    spell_ready = function() return true end,
    try_cast = function() return true end,
    cooldown_remains = function() return 5 end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "arcane",
    strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
        { name = "ArcaneMissiles", matches = function() return false end, execute = function() return false end },
        { name = "Frostbolt", matches = function() return false end, execute = function() return false end },
    },
    options = { get_state = function() return { fake = true } end },
}

local orig_require = require
local pending_bridge_by_name = {}
function require(path)
    if path == "shared/wowhead_data_bridge_spell_index_forever_sylvanas" then
        return { spell_index_by_name_forever = pending_bridge_by_name }
    end
    if path == "classes/mage/arcane_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/mage/arcane_vanilla' not found", 0)
    end
    if path == "shared/spec_kit_sylvanas" then
        return { setting = function(_, key, default) return default end }
    end
    return orig_require(path)
end

local function load_delta(bridge_by_name)
    pending_bridge_by_name = bridge_by_name or {}
    registered = nil
    local chunk, err = loadfile("EaxRotations/classes/mage/arcane_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

-- A. Full kit: both bridge names resolve; splice geometry.
do
    local combined = load_delta({ ["Arcane Blast"] = 19008, ["Missile Barrage"] = 19009 })
    assert_eq(registered and registered.name, "arcane", "A: re-registers the arcane playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 2, "A: 2 delta lanes over 3 baseline lanes")
    local barr = find_lane(combined, "Forever_MissileBarrageAM")
    local am = find_lane(combined, "ArcaneMissiles")
    local spam = find_lane(combined, "Forever_ArcaneBlastSpam")
    local fb = find_lane(combined, "Frostbolt")
    assert_true(barr == am - 1, "A: barrage sits just above ArcaneMissiles")
    assert_true(spam == fb - 1, "A: AB spam sits just above Frostbolt (below AM)")
    assert_true(barr < spam, "A: barrage outranks the spam block")
end

-- B. Matcher behavior: cusp window + barrage gating.
do
    local combined = load_delta({ ["Arcane Blast"] = 19008, ["Missile Barrage"] = 19009 })
    local state = { mana_pct = 80 }
    local ctx = { in_combat = true, target = {}, has_valid_enemy_target = true, me = {}, settings = {} }

    local spam = combined[find_lane(combined, "Forever_ArcaneBlastSpam")]
    NS.has_player_buff = function() return true end
    NS.cooldown_remains = function() return 5 end
    assert_true(spam.matches(ctx, state), "B: AB spam fires with stacks + AM far")
    NS.cooldown_remains = function() return 1 end
    assert_true(not spam.matches(ctx, state), "B: AB spam holds during the AM cusp window")
    NS.cooldown_remains = function() return 5 end
    NS.has_player_buff = function() return false end
    assert_true(not spam.matches(ctx, state), "B: AB spam dormant without stacks")
    state.mana_pct = 10
    NS.has_player_buff = function() return true end
    assert_true(not spam.matches(ctx, state), "B: AB spam respects the mana floor")
    state.mana_pct = 80

    local barr = combined[find_lane(combined, "Forever_MissileBarrageAM")]
    NS.has_player_buff = function() return true end
    assert_true(barr.matches(ctx, state), "B: barrage fires with the proc")
    NS.has_player_buff = function() return false end
    assert_true(not barr.matches(ctx, state), "B: barrage dormant without the proc")
end

-- C. Dormancy before the beta DBC: zero delta lanes pre-beta.
do
    local combined = load_delta({})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes pre-beta")
    assert_true(not find_lane(combined, "Forever_ArcaneBlastSpam"), "C: AB spam dormant")
    assert_true(not find_lane(combined, "Forever_MissileBarrageAM"), "C: barrage dormant")
    assert_eq(find_lane(combined, "ArcaneMissiles"), 2, "C: baseline order unchanged")
end

-- D. Splice fallback: no anchors appends barrage-then-spam.
do
    FAKE_BASELINE.strategies = {
        { name = "IceBarrier", matches = function() return false end, execute = function() return false end },
    }
    local combined = load_delta({ ["Arcane Blast"] = 19008, ["Missile Barrage"] = 19009 })
    assert_eq(find_lane(combined, "Forever_MissileBarrageAM"), #combined - 1, "D: barrage appends before spam")
    assert_eq(find_lane(combined, "Forever_ArcaneBlastSpam"), #combined, "D: spam appends last")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/mage/arcane_forever.lua", "r")
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

print(string.format("test_mage_arcane_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS mage_arcane_forever")
