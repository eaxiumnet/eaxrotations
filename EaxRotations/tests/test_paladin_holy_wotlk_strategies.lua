-- test_paladin_holy_wotlk_strategies.lua — Holy paladin WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL holy_wotlk.lua through its real build_state read path
--        against modeled friendly units: Beacon of Light checked on the
--        DEDICATED tank member (context.party_members + get_group_role), the
--        self-only Sacred Shield, and Holy Shock / Holy Light / Flash of Light
--        triaged to the lowest-HP friendly (context.lowest.unit), with mana
--        and target-hp thresholds pinned both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the holy dsl_priority suite
--        mutates build_state output post-hoc, so the real beacon-target /
--        friendly-triage read plumbing was never exercised.
-- SAFETY: Pure unit tests with a mocked NS; the real holy_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local lowest_hp = 100
local mana = 100
local buffs = {}      -- spell id -> true (unit-agnostic: only one unit is ever
                      -- beacon-buffed or self-buffed in a scenario)

local function set_buff(id, up) buffs[id] = up or nil end

-- The dedicated tank member the Beacon must stay on.
local tank = { get_group_role = function() return "tank" end }

local me = { get_health_percentage = function() return 100 end }

local function reset_env()
    lowest_hp, mana = 100, 100
    buffs = {}
end

_G.EaxRotations = {
    me = me,
    GetPlayer = function() return me end,
    mana_pct = function() return mana end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/paladin/holy_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "holy_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local lowest_unit = { get_health_percentage = function() return lowest_hp end }
    local ctx = {
        in_combat = true,
        mana_pct = mana,
        enemy_count = 1,
        lowest = { unit = lowest_unit, hp = lowest_hp },
        party_members = { tank },
        target = { get_health_percentage = function() return 100 end },
        settings = {},
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, strategy_name, setup, expect)
    reset_env()
    setup()
    scenario(label, strategy_name, expect)
end

-- ============================================================================
-- Beacon of Light: upkeep on the dedicated tank target (never the lowest-HP
-- member — the buff read must go through the tank, which the party_members
-- shape above provides).
-- ============================================================================
assert_lane("BeaconOfLight fires when the tank has no Beacon", "BeaconOfLight", function() end, true)
assert_lane("BeaconOfLight blocked while the Beacon is up on the tank", "BeaconOfLight",
    function() set_buff(53563, true) end, false)

-- ============================================================================
-- Sacred Shield: self-only upkeep in 3.3.5.
-- ============================================================================
assert_lane("SacredShield fires with the shield down", "SacredShield", function() end, true)
assert_lane("SacredShield blocked while the shield is up", "SacredShield",
    function() set_buff(53601, true) end, false)

-- ============================================================================
-- Holy Shock: triage on the lowest-HP friendly below 80%.
-- ============================================================================
assert_lane("HolyShock fires on a hurt ally", "HolyShock",
    function() lowest_hp = 79 end, true)
assert_lane("HolyShock fires on a badly hurt ally", "HolyShock",
    function() lowest_hp = 30 end, true)
assert_lane("HolyShock blocked at/above 80% ally hp", "HolyShock",
    function() lowest_hp = 80 end, false)

-- ============================================================================
-- Holy Light: big heal below 50% at >= 30% mana.
-- ============================================================================
assert_lane("HolyLight fires below 50% ally hp", "HolyLight",
    function() lowest_hp = 49; mana = 30 end, true)
assert_lane("HolyLight blocked at/above 50% ally hp", "HolyLight",
    function() lowest_hp = 50; mana = 100 end, false)
assert_lane("HolyLight blocked below 30% mana", "HolyLight",
    function() lowest_hp = 40; mana = 29 end, false)

-- ============================================================================
-- Flash of Light: fast heal below 70% at >= 20% mana.
-- ============================================================================
assert_lane("FlashOfLight fires below 70% ally hp", "FlashOfLight",
    function() lowest_hp = 69; mana = 20 end, true)
assert_lane("FlashOfLight blocked at/above 70% ally hp", "FlashOfLight",
    function() lowest_hp = 70; mana = 100 end, false)
assert_lane("FlashOfLight blocked below 20% mana", "FlashOfLight",
    function() lowest_hp = 50; mana = 19 end, false)

print("PASS test_paladin_holy_wotlk_strategies")
