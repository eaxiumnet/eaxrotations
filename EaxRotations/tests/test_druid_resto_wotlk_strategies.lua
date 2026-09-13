-- test_druid_resto_wotlk_strategies.lua — Restoration druid WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL resto_wotlk.lua through its real build_state read
--        path against a modeled injured friendly unit (context.lowest.unit,
--        the engine party-scan shape): NS.buff_remains / NS.buff_stacks for
--        the Rejuvenation / Regrowth / Lifebloom HoTs on the lowest-HP ally,
--        ctx.lowest_hp / party_injured_count, ctx.mana_pct, and real
--        NS.spell_ready for Wild Growth / Swiftmend / Nourish / Innervate.
--        Pins both sides of every lane, including the Lifebloom 3-stack
--        roll discipline (<1.2s refresh at 3 stacks) and the Swiftmend HoT
--        consumption rule.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc against a stub state, so the real
--        friendly-target HoT / triage plumbing was never exercised.
-- SAFETY: Pure unit tests with a mocked NS; the real resto_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local lowest_hp = 100
local injured = 0
local mana = 100
local ho = {}          -- HoT id -> seconds remaining on the lowest unit
local stacks = {}      -- HoT id -> stacks on the lowest unit
local not_ready = {}

local function rejuv(secs) ho[48441] = secs end
local function regr(secs) ho[48443] = secs end
local function lifebloom(secs) ho[48451] = secs end
local function lb_stacks(n) stacks[48451] = n end

local function reset_env()
    lowest_hp, injured, mana = 100, 0, 100
    ho, stacks, not_ready = {}, {}, {}
end

-- Friendly-cycle harness (2026-09-13): shared/periodic_cycler_sylvanas scans
-- the player plus NS.GetPartyMembers, so the mock exposes a party list and a
-- per-unit HoT table (unit.hot). Empty list => the pre-cycling behavior.
local party = {}
local function ally(hp, hot_remains)
    return {
        get_health_percentage = function() return hp end,
        hot = hot_remains and { [48441] = hot_remains } or nil,
    }
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    GetPartyMembers = function() return party end,
    mana_pct = function() return mana end,
    buff_remains = function(unit, ids)
        if unit and unit.hot then
            for _, id in ipairs(ids) do
                if unit.hot[id] then return unit.hot[id] end
            end
            return 0
        end
        for _, id in ipairs(ids) do
            if ho[id] then return ho[id] end
        end
        return 0
    end,
    buff_stacks = function(unit, ids)
        for _, id in ipairs(ids) do
            if stacks[id] then return stacks[id] end
        end
        return 0
    end,
    spell_ready = function(spell, target)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1]))
        if not_ready[id] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/resto_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "resto_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local lowest = { unit = {}, hp = lowest_hp }
    local ctx = {
        in_combat = true,
        mana_pct = mana,
        party_injured_count = injured,
        lowest = lowest,
        lowest_hp = lowest_hp,
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
-- Wild Growth: raid HoT on 2+ injured allies at >= 25% mana.
-- ============================================================================
assert_lane("WildGrowth fires on 2 injured allies", "WildGrowth",
    function() injured = 2; mana = 25 end, true)
assert_lane("WildGrowth blocked with 1 injured ally", "WildGrowth",
    function() injured = 1; mana = 100 end, false)
assert_lane("WildGrowth blocked below 25% mana", "WildGrowth",
    function() injured = 2; mana = 24 end, false)
assert_lane("WildGrowth blocked while on cooldown", "WildGrowth",
    function() injured = 2; mana = 100; not_ready[53251] = true end, false)

-- ============================================================================
-- Swiftmend: consumes a Rejuv/Regrowth HoT on a <= 50% hp ally.
-- ============================================================================
assert_lane("Swiftmend fires on a hurt ally with Rejuvenation up", "Swiftmend",
    function() lowest_hp = 50; rejuv(5) end, true)
assert_lane("Swiftmend fires on a hurt ally with Regrowth up", "Swiftmend",
    function() lowest_hp = 40; regr(5) end, true)
assert_lane("Swiftmend blocked above 50% hp", "Swiftmend",
    function() lowest_hp = 51; rejuv(5) end, false)
assert_lane("Swiftmend blocked with no HoT to consume", "Swiftmend",
    function() lowest_hp = 40; rejuv(0); regr(0) end, false)
assert_lane("Swiftmend blocked while on cooldown", "Swiftmend",
    function() lowest_hp = 40; rejuv(5); not_ready[18562] = true end, false)

-- ============================================================================
-- Lifebloom: roll stacks freely; at 3 stacks refresh only inside 1.2s.
-- ============================================================================
assert_lane("Lifebloom rolls at 1 stack when the buff is low", "Lifebloom",
    function() mana = 25; lb_stacks(1); lifebloom(2) end, true)
assert_lane("Lifebloom refresh blocked at 3 stacks with 2s left", "Lifebloom",
    function() mana = 100; lb_stacks(3); lifebloom(2) end, false)
assert_lane("Lifebloom refresh fires at 3 stacks inside the 1.2s window", "Lifebloom",
    function() mana = 100; lb_stacks(3); lifebloom(1) end, true)
assert_lane("Lifebloom blocked while the buff is healthy", "Lifebloom",
    function() mana = 100; lb_stacks(1); lifebloom(3) end, false)
assert_lane("Lifebloom blocked below 25% mana", "Lifebloom",
    function() mana = 24; lb_stacks(1); lifebloom(0) end, false)

-- ============================================================================
-- Rejuvenation: triage HoT on <= 88% hp allies, refresh under 3s.
-- ============================================================================
assert_lane("Rejuvenation fires on a hurt ally when the HoT is down", "Rejuvenation",
    function() lowest_hp = 88; mana = 25; rejuv(0) end, true)
assert_lane("Rejuvenation blocked on a healthy ally", "Rejuvenation",
    function() lowest_hp = 89; mana = 100; rejuv(0) end, false)
assert_lane("Rejuvenation blocked while the HoT is healthy", "Rejuvenation",
    function() lowest_hp = 50; mana = 100; rejuv(3) end, false)
assert_lane("Rejuvenation blocked below 25% mana", "Rejuvenation",
    function() lowest_hp = 50; mana = 24; rejuv(0) end, false)

-- ============================================================================
-- Regrowth: triage heal on <= 70% hp, refresh under 3s.
-- ============================================================================
assert_lane("Regrowth fires on a hurt ally when the HoT is down", "Regrowth",
    function() lowest_hp = 70; mana = 25; regr(0) end, true)
assert_lane("Regrowth blocked on a healthier ally", "Regrowth",
    function() lowest_hp = 71; mana = 100; regr(0) end, false)
assert_lane("Regrowth blocked while the HoT is healthy", "Regrowth",
    function() lowest_hp = 50; mana = 100; regr(3) end, false)

-- ============================================================================
-- Nourish: direct spot heal on <= 60% hp at >= 15% mana.
-- ============================================================================
assert_lane("Nourish fires on a hurt ally at 15% mana", "Nourish",
    function() lowest_hp = 60; mana = 15 end, true)
assert_lane("Nourish blocked on a healthier ally", "Nourish",
    function() lowest_hp = 61; mana = 100 end, false)
assert_lane("Nourish blocked below 15% mana", "Nourish",
    function() lowest_hp = 50; mana = 14 end, false)
assert_lane("Nourish blocked while on cooldown", "Nourish",
    function() lowest_hp = 50; mana = 100; not_ready[50464] = true end, false)

-- ============================================================================
-- Innervate: mana recovery at <= 30% mana.
-- ============================================================================
assert_lane("Innervate fires at 30% mana", "Innervate", function() mana = 30 end, true)
assert_lane("Innervate blocked above 30% mana", "Innervate", function() mana = 31 end, false)
assert_lane("Innervate blocked while on cooldown", "Innervate",
    function() mana = 20; not_ready[29166] = true end, false)

-- ============================================================================
-- Friendly multi-HoT cycling (2026-09-13, shared/periodic_cycler_sylvanas).
-- The pre-cycling lane always refreshed the single lowest ally, so when that
-- ally already carried a fresh Rejuvenation a second injured ally was never
-- covered. The lane now follows the CYCLED unit (state.hot_unit).
-- ============================================================================
local cyc = require("shared/periodic_cycler_sylvanas")
assert_true(cyc and type(cyc.friendly) == "function", "periodic_cycler must export friendly()")

-- FIRE: lowest ally already carries a fresh Rejuv -> cover the OTHER ally.
do
    local lowest = ally(60, 10)          -- fresh HoT, must NOT be re-HoTted
    local other  = ally(70, nil)         -- injured, uncovered
    party = { lowest, other }
    reset_env()
    local ctx = {
        in_combat = true, mana_pct = 100, party_injured_count = 2,
        lowest = { unit = lowest, hp = 60 }, lowest_hp = 60,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
    }
    local state = result.build_state(ctx)
    assert_true(state.hot_unit == other,
        "cycled HoT unit should be the second injured ally, got "
        .. tostring(state.hot_unit == lowest and "lowest" or "other"))
    assert_true(state.hot_remains == 0, "cycled unit has no HoT -> remains 0")
    assert_true(find_strategy("Rejuvenation").matches(ctx, state),
        "Rejuvenation should cover the second injured ally")
end

-- HOLD: every candidate already carries the HoT -> hold the lane.
do
    local lowest = ally(60, 10)
    local other  = ally(70, 4)
    party = { lowest, other }
    reset_env()
    rejuv(10)
    local ctx = {
        in_combat = true, mana_pct = 100, party_injured_count = 2,
        lowest = { unit = lowest, hp = 60 }, lowest_hp = 60,
        target = { get_health_percentage = function() return 100 end },
        settings = {},
    }
    local state = result.build_state(ctx)
    assert_true(state.hot_unit == lowest, "no uncovered candidate -> lowest ally")
    assert_false(find_strategy("Rejuvenation").matches(ctx, state),
        "Rejuvenation must hold when every candidate is already HoTted")
    party = {}
end

-- ROTATION: consecutive picks must move on, and a lone candidate must never
-- be starved by its own cursor.
do
    local a, b = ally(60, nil), ally(70, nil)
    party = { a, b }
    reset_env()          -- the HOLD block above left a Rejuv in the flat ho map
    cyc.reset()
    local ctx = { target = {} }
    local first = cyc.friendly(ctx, { 48441 }, { hp_below = 88 })
    assert_true(first == a, "first pick is the most injured candidate")
    local second = cyc.friendly(ctx, { 48441 }, { hp_below = 88 })
    assert_true(second == b, "second pick must rotate off the cursor unit")
    local third = cyc.friendly(ctx, { 48441 }, { hp_below = 88 })
    assert_true(third == a, "third pick rotates back (round-robin)")

    party = { a }
    cyc.reset()
    assert_true(cyc.friendly(ctx, { 48441 }, { hp_below = 88 }) == a, "sole candidate picked")
    assert_true(cyc.friendly(ctx, { 48441 }, { hp_below = 88 }) == a,
        "a lone candidate must never be starved by the cursor")

    -- FAIL-OPEN: no party API at all -> nil, and the lane keeps its old target.
    local saved = _G.EaxRotations.GetPartyMembers
    _G.EaxRotations.GetPartyMembers = nil
    cyc.reset()
    assert_true(cyc.friendly(ctx, { 48441 }, { hp_below = 88 }) == nil,
        "no party API must return nil (fail-open)")
    _G.EaxRotations.GetPartyMembers = saved
    party = {}
end

print("PASS test_druid_resto_wotlk_strategies")
