-- test_warrior_protection_forever.lua -- unit pins for the warrior prot Forever delta.
-- WHAT:  protection_forever.lua contract: baseline capture + re-register
--        splice (Vanguard Charge above Revenge; the baseline ThunderClap
--        lane REPLACED with a stance-agnostic one in the same position), the
--        passive-learned gate, matcher gates (stance, OOC, charge range,
--        AoE/rage for TC), by-name dormancy, zero-numeric-literal contract.
-- WHEN:  standalone or via run_rotation_tests.lua.
-- WHY:   the two kit changes are exactly a stance unlock and a new
--        out-of-combat opener: if the replacement TC lane loses its
--        Defensive allowance the tank never AoEs, and if the charge lane
--        loses its OOC/learned gates it either charges mid-fight (illegal)
--        or fires for warriors who never took Vanguard.
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
local aoe_calls = 0
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
        Charge = { ids = { 100 } },
        ThunderClap = { ids = { 6343 } },
        Revenge = { ids = { 6572 } },
        ShieldSlam = { ids = { 23922 } },
    },
    spell_ready = function() return true end,
    try_cast = function(spell, target, reason, opts)
        cast_log[#cast_log + 1] = { spell = spell, target = target }
        return true
    end,
    is_spell_learned = function(id) return learnt[id] == true end,
    aoe_self_meets = function(count, radius, ctx, state)
        aoe_calls = aoe_calls + 1
        return true
    end,
    AOE_RADIUS = { SELF_8 = 8 },
    GetPlayer = function() return {} end,
}
_G.EaxRotations = NS

local FAKE_BASELINE = {
    name = "protection",
    strategies = {
        { name = "LastStand", matches = function() return false end, execute = function() return false end },
        { name = "ShieldWall", matches = function() return false end, execute = function() return false end },
        { name = "Revenge", matches = function() return false end, execute = function() return false end },
        { name = "ShieldSlam", matches = function() return false end, execute = function() return false end },
        { name = "SunderArmor", matches = function() return false end, execute = function() return false end },
        { name = "ThunderClap", matches = function() return false end, execute = function() return false end },
        { name = "DemoralizingShout", matches = function() return false end, execute = function() return false end },
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
    if path == "classes/warrior/protection_vanilla" then
        if FAKE_BASELINE then
            NS.rotation_registry:register(FAKE_BASELINE.name, FAKE_BASELINE.strategies, FAKE_BASELINE.options)
            return FAKE_BASELINE.strategies
        end
        error("module 'classes/warrior/protection_vanilla' not found", 0)
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
    local chunk, err = loadfile("EaxRotations/classes/warrior/protection_forever.lua")
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
    local s = { in_combat = true, stance = 2, rage = 40, tclap_remains = 0, me = {} }
    if overrides then
        for k, v in pairs(overrides) do s[k] = v end
    end
    return s
end

local function fresh_ctx(dist)
    return { in_combat = true, target = {}, has_valid_enemy_target = true, me = {},
             distance = dist or 5, settings = {} }
end

-- A. Vanguard learned: charge lane above Revenge, TC lane replaced in place.
do
    learnt = {}
    learnt[19123] = true
    local combined = load_delta({}, { ["Vanguard"] = 19123 }, {})
    assert_eq(registered and registered.name, "protection", "A: re-registers the protection playstyle")
    assert_eq(registered.strategies, combined, "A: registered strategies are the combined table")
    assert_eq(registered.options.get_state, FAKE_BASELINE.options.get_state, "A: baseline get_state passed through")
    assert_eq(#combined, #FAKE_BASELINE.strategies + 1, "A: +1 charge lane; TC replaced in place (count-neutral)")
    assert_true(not find_lane(combined, "ThunderClap"), "A: the baseline TC lane is replaced")
    assert_eq(find_lane(combined, "Forever_ThunderClap"), find_lane(combined, "DemoralizingShout") - 1,
        "A: the replacement TC takes the baseline lane's slot")
    assert_eq(find_lane(combined, "Forever_VanguardCharge"), find_lane(combined, "Revenge") - 1,
        "A: the charge lane sits above Revenge")
    assert_eq(find_lane(combined, "LastStand"), 1, "A: defensive head lanes untouched")
    learnt = {}
end

-- B. Vanguard not learned: no charge lane; the TC replacement still applies.
do
    learnt = {}
    local combined = load_delta({}, { ["Vanguard"] = 19123 }, {})
    assert_true(not find_lane(combined, "Forever_VanguardCharge"), "B: charge dormant without the passive")
    assert_true(find_lane(combined, "Forever_ThunderClap"), "B: the TC replacement is bridge-independent")
    assert_eq(#combined, #FAKE_BASELINE.strategies, "B: one lane replaced, nothing added")
end

-- B2. TC matcher: Defensive AND Battle both allowed, same window/rage/AoE gates.
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    local tc = combined[find_lane(combined, "Forever_ThunderClap")]
    local ctx = fresh_ctx(5)

    local def = fresh_state({ stance = 2 })
    assert_true(tc.matches(ctx, def), "B2: TC fires in Defensive Stance (the Forever unlock)")
    local battle = fresh_state({ stance = 1 })
    assert_true(tc.matches(ctx, battle), "B2: TC still fires in Battle Stance")
    local bers = fresh_state({ stance = 3 })
    assert_true(not tc.matches(ctx, bers), "B2: TC holds in Berserker Stance")
    local fresh_debuff = fresh_state({ stance = 2, tclap_remains = 10 })
    assert_true(not tc.matches(ctx, fresh_debuff), "B2: TC holds while its debuff is fresh")
    local poor = fresh_state({ stance = 2, rage = 5 })
    assert_true(not tc.matches(ctx, poor), "B2: TC respects the rage cost")
    -- TC is a self-centred AoE: the nearby-enemy probe is the gate (the
    -- baseline matcher has no explicit target read either).
    local orig_aoe = NS.aoe_self_meets
    local probed = 0
    NS.aoe_self_meets = function() probed = probed + 1; return false end
    assert_true(not tc.matches(ctx, fresh_state({ stance = 2 })), "B2: TC holds when the AoE probe finds nobody")
    assert_eq(probed, 1, "B2: the AoE probe is the reachable gate")
    NS.aoe_self_meets = orig_aoe
    cast_log = {}
    assert_true(tc.execute(ctx, def), "B2: TC executes")
end

-- B3. Vanguard charge matcher: OOC + defensive + range window.
do
    learnt = {}
    learnt[19123] = true
    local combined = load_delta({}, { ["Vanguard"] = 19123 }, {})
    local charge = combined[find_lane(combined, "Forever_VanguardCharge")]

    local ooc_def = fresh_state({ in_combat = false, stance = 2 })
    local range_ctx = fresh_ctx(20)
    assert_true(charge.matches(range_ctx, ooc_def), "B3: charge fires OOC in defensive at range")
    local in_combat_state = fresh_state({ in_combat = true, stance = 2 })
    assert_true(not charge.matches(range_ctx, in_combat_state), "B3: charge never fires in combat")
    local battle_state = fresh_state({ in_combat = false, stance = 1 })
    assert_true(not charge.matches(range_ctx, battle_state), "B3: charge needs Defensive Stance")
    local close_ctx = fresh_ctx(3)
    assert_true(not charge.matches(close_ctx, ooc_def), "B3: charge respects the dead zone")
    local far_ctx = fresh_ctx(30)
    assert_true(not charge.matches(far_ctx, ooc_def), "B3: charge respects max range")
    cast_log = {}
    assert_true(charge.execute(range_ctx, ooc_def), "B3: charge executes")
    learnt = {}
end

-- C. Dormancy: empty mirrors -> the TC replacement only (no charge lane).
do
    learnt = {}
    local combined = load_delta({}, {}, {})
    assert_eq(#combined, #FAKE_BASELINE.strategies, "C: TC replaced, charge dormant")
    assert_true(not find_lane(combined, "Forever_VanguardCharge"), "C: charge dormant on empty mirrors")
end

-- D. Splice fallback: no Revenge/ShieldSlam anchor appends the charge lane.
do
    FAKE_BASELINE.strategies = {
        { name = "LastStand", matches = function() return false end, execute = function() return false end },
        { name = "SunderArmor", matches = function() return false end, execute = function() return false end },
    }
    learnt = {}
    learnt[19123] = true
    local combined = load_delta({}, { ["Vanguard"] = 19123 }, {})
    assert_eq(find_lane(combined, "Forever_VanguardCharge"), #combined - 1, "D: charge appends before TC")
    assert_eq(find_lane(combined, "Forever_ThunderClap"), #combined, "D: TC appends last")
    learnt = {}
end

-- E. Zero numeric spell-ID literals (audit contract).
do
    local f = io.open("EaxRotations/classes/warrior/protection_forever.lua", "r")
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

print(string.format("test_warrior_protection_forever: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
print("PASS warrior_protection_forever")
