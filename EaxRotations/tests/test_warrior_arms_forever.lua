-- test_warrior_arms_forever.lua -- unit pins for the warrior arms Forever delta.
-- WHAT:  arms_forever.lua contract: baseline capture + re-register splice
--        (Spearing Strike above MortalStrike; the Slam lane REPLACED when
--        Improved Slam is learned), the creature-type encounter gate, matcher
--        gates, by-name dormancy, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   Spearing Strike is the only encounter-gated nuke in the class kit
--        (it fires on Giants/Dragonkin, not on anything else), and the Slam
--        replacement exists precisely because the baseline's swing-window
--        gate would suppress most 15s-cooldown casts once the talent removes
--        the swing penalty.
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
local NS = {
    settings = {},
    log = function() end,
    rotation_registry = {
        register = function(self, name, strategies, options)
            registered = { name = name, strategies = strategies, options = options or {} }
            return true
        end,
    },
    WarriorSpells = {
        Slam = { ids = { 1464 } },
        MortalStrike = { ids = { 12294 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "arms",
    strategies = {
        { name = "Pummel", matches = function() return false end, execute = function() return false end },
        { name = "Execute", matches = function() return false end, execute = function() return false end },
        { name = "MortalStrike", matches = function() return false end, execute = function() return false end },
        { name = "Overpower", matches = function() return false end, execute = function() return false end },
        { name = "Rend", matches = function() return false end, execute = function() return false end },
        { name = "Slam", matches = function() return false end, execute = function() return false end },
        { name = "HeroicStrike", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warrior/arms_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warrior/arms_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/warrior/arms_forever.lua")
    if not chunk then error("cannot load delta: " .. tostring(err)) end
    return chunk()
end

local function find_lane(list, name)
    for i, st in ipairs(list) do
        if type(st) == "table" and st.name == name then return i end
    end
    return nil
end

local function fresh_state(overrides)
    local s = { in_combat = true, rage = 50, is_moving = false, overpower_ready = false }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

local function fresh_ctx(ctype)
    local target = { get_creature_type = function() return ctype end }
    return { in_combat = true, target = target, has_valid_enemy_target = true, me = {}, settings = {} }
end

-- A. Full kit (Improved Slam learned): Spearing above MortalStrike, Slam
-- replaced in place.
do
    learnt = {}
    learnt[19124] = true
    local combined = load_delta({}, { ["Spearing Strike"] = 19125, ["Improved Slam"] = 19124 }, {})
    assert_eq(registered and registered.name, "arms", "A: re-registers the arms playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: +1 Spearing; Slam replaced in place (count-neutral)")
    assert_true(not find_lane(combined, "Slam"), "A: the baseline Slam lane is replaced")
    assert_eq(find_lane(combined, "Forever_SlamWeave"), find_lane(combined, "HeroicStrike") - 1,
        "A: the Slam replacement takes the baseline slot")
    assert_eq(find_lane(combined, "Forever_SpearingStrike"), find_lane(combined, "MortalStrike") - 1,
        "A: Spearing Strike sits above MortalStrike")
    assert_eq(find_lane(combined, "Pummel"), 1, "A: defensive/utility head lanes untouched")
    learnt = {}
end

-- B. No Improved Slam: no replacement, baseline Slam stays.
do
    learnt = {}
    local combined = load_delta({}, { ["Spearing Strike"] = 19125, ["Improved Slam"] = 19124 }, {})
    assert_true(find_lane(combined, "Slam"), "B: baseline Slam kept without the talent")
    assert_true(not find_lane(combined, "Forever_SlamWeave"), "B: replacement dormant")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "B: Spearing only")
end

-- B2. Spearing matcher: the creature-type encounter gate + rage/readiness.
do
    learnt = {}
    local combined = load_delta({}, { ["Spearing Strike"] = 19125 }, {})
    local spear = combined[find_lane(combined, "Forever_SpearingStrike")]
    local state = fresh_state()

    assert_true(spear.matches(fresh_ctx(2), state), "B2: Spearing fires on Dragonkin")
    assert_true(spear.matches(fresh_ctx(5), state), "B2: Spearing fires on Giants")
    assert_true(not spear.matches(fresh_ctx(7), state), "B2: Spearing holds on Humanoids")
    assert_true(not spear.matches(fresh_ctx(6), state), "B2: Spearing holds on Undead")
    assert_true(not spear.matches(fresh_ctx(nil), state), "B2: Spearing holds when the type is unreadable")
    local poor = fresh_state({ rage = 5 })
    assert_true(not spear.matches(fresh_ctx(2), poor), "B2: Spearing respects the rage cost")
    NS.spell_ready = function() return false end
    assert_true(not spear.matches(fresh_ctx(2), state), "B2: Spearing respects readiness")
    NS.spell_ready = function() return true end
    cast_log = {}
    assert_true(spear.execute(fresh_ctx(2), state), "B2: Spearing executes")
end

-- B3. Slam replacement matcher: no swing window, rage/movement/priority gates.
do
    learnt = {}
    learnt[19124] = true
    local combined = load_delta({}, { ["Improved Slam"] = 19124 }, {})
    local slam = combined[find_lane(combined, "Forever_SlamWeave")]
    local state = fresh_state()
    local ctx = fresh_ctx(7)

    assert_true(slam.matches(ctx, state), "B3: Improved Slam fires without a swing window")
    local moving = fresh_state({ is_moving = true })
    assert_true(not slam.matches(ctx, moving), "B3: Slam holds while moving")
    local poor = fresh_state({ rage = 5 })
    assert_true(not slam.matches(ctx, poor), "B3: Slam respects the rage cost")
    local op = fresh_state({ overpower_ready = true })
    assert_true(not slam.matches(ctx, op), "B3: Slam yields to an Overpower window")
    cast_log = {}
    assert_true(slam.execute(ctx, state), "B3: Slam executes")
    learnt = {}
end

-- C. Dormancy: empty mirrors -> no delta lanes, baseline Slam kept.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: zero delta lanes on empty mirrors")
    assert_true(not find_lane(combined, "Forever_SpearingStrike"), "C: Spearing dormant")
    assert_true(find_lane(combined, "Slam"), "C: baseline Slam kept")
end

-- D. Splice fallback: no MortalStrike/Rend anchor appends the nuke.
do
    FAKE_BASELINE.strategies = {
        { name = "Pummel", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    local combined = load_delta({}, { ["Spearing Strike"] = 19125 }, {})
    assert_eq(find_lane(combined, "Forever_SpearingStrike"), #combined, "D: Spearing appends when anchors are absent")
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warrior/arms_forever.lua", "r")
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

print(string.format("test_warrior_arms_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS warrior_arms_forever")
