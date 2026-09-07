-- test_rogue_assassination_wotlk_strategies.lua — Assassination rogue WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL assassination_wotlk.lua through its real build_state
--        read path (ctx.energy/combo_points, NS.buff_remains for Slice and
--        Dice, NS.debuff_remains for Rupture, NS.get_debuff_stacks for Deadly
--        Poison, NS.buff_up for Envenom/Hunger for Blood, the real dagger_set
--        + equipped-item IDs for the Mutilate dagger gate, target:is_casting
--        for Kick), pinning both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite mutates
--        build_state output post-hoc, so no suite exercised the real state
--        plumbing (poison stacks, buff/debuff remains, dagger eligibility).
-- SAFETY: Pure unit tests with a mocked NS; the real assassination_wotlk.lua
--         and real shared modules (spec_kit / strategy_dsl /
--         combo_points_reader / dagger_set) load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Mutable scenario state.
local energy = 0
local cp = 0
local snd = 0
local rupture = 0
local dp = 0
local combat = true
local casting = false
local daggers = false
local buffs = {}     -- 57993 = Envenom buff, 51662 = Hunger for Blood buff

local me = {
    get_health_percentage = function() return 100 end,
    get_power = function(self, power_type)
        if power_type == 3 then return energy end
        return 0
    end,
}

local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    energy, cp, snd, rupture, dp = 0, 0, 0, 0, 0
    combat, casting, daggers = true, false, false
    buffs = {}
end

_G.EaxRotations = {
    POWER_ENERGY = 3,
    POWER_COMBO = 4,
    EQUIPMENT_SLOTS = { MAIN_HAND = 16, OFF_HAND = 17 },
    me = me,
    GetPlayer = function() return me end,
    get_equipped_item_id = function(slot)
        if not daggers then return 0 end
        if slot == 16 then return 776 end   -- real dagger item ids (dagger_set map)
        if slot == 17 then return 820 end
        return 0
    end,
    buff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 6774 or id == 5171 then return snd end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 48672 then return rupture end
        end
        return 0
    end,
    get_debuff_stacks = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 57970 or id == 57969 then return dp end
        end
        return 0
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/rogue/assassination_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "assassination_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        energy = energy,
        combo_points = cp,
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return casting end,
        },
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
-- Kick interrupt: in combat + an enemy cast. Driven through the real
-- target:is_casting read.
-- ============================================================================
assert_lane("Kick fires on an enemy cast in combat", "Kick",
    function() casting = true end, true)
assert_lane("Kick blocked when the target is not casting", "Kick",
    function() casting = false end, false)
assert_lane("Kick blocked out of combat", "Kick",
    function() casting = true; combat = false end, false)

-- ============================================================================
-- Slice and Dice: refresh under 3s with >= 1 combo point (real buff_remains).
-- ============================================================================
assert_lane("SliceAndDice fires when Slice and Dice is expiring", "SliceAndDice",
    function() snd = 2; cp = 1 end, true)
assert_lane("SliceAndDice fires with no buff up at all", "SliceAndDice",
    function() snd = 0; cp = 5 end, true)
assert_lane("SliceAndDice blocked while fresh (>= 3s)", "SliceAndDice",
    function() snd = 3; cp = 5 end, false)
assert_lane("SliceAndDice blocked with 0 combo points", "SliceAndDice",
    function() snd = 0; cp = 0 end, false)

-- ============================================================================
-- Rupture: refresh under 3s with >= 1 combo point (real debuff_remains).
-- ============================================================================
assert_lane("Rupture fires when the bleed is down", "Rupture",
    function() rupture = 0; cp = 2 end, true)
assert_lane("Rupture fires when the bleed is about to expire", "Rupture",
    function() rupture = 2; cp = 2 end, true)
assert_lane("Rupture blocked while the bleed is healthy", "Rupture",
    function() rupture = 10; cp = 5 end, false)
assert_lane("Rupture blocked with 0 combo points", "Rupture",
    function() rupture = 0; cp = 0 end, false)

-- ============================================================================
-- Hunger for Blood: upkeep only — re-apply when the buff is down.
-- ============================================================================
assert_lane("HungerForBlood fires with the buff down", "HungerForBlood", function() end, true)
assert_lane("HungerForBlood blocked while the buff is up", "HungerForBlood",
    function() set_buff(51662, true) end, false)

-- ============================================================================
-- Tricks of the Trade: APL energy gate <= 50 (real ctx.energy read).
-- ============================================================================
assert_lane("TricksOfTheTrade fires at 50 energy", "TricksOfTheTrade",
    function() energy = 50 end, true)
assert_lane("TricksOfTheTrade fires at 0 energy", "TricksOfTheTrade", function() end, true)
assert_lane("TricksOfTheTrade blocked above 50 energy", "TricksOfTheTrade",
    function() energy = 51 end, false)

-- ============================================================================
-- Envenom: >= 4 CP + >= 3 Deadly Poison stacks + (buff down or energy >= 85).
-- Driven through real get_debuff_stacks / buff_up.
-- ============================================================================
assert_lane("Envenom fires at 4 CP / 3 DP stacks with the buff down", "Envenom",
    function() cp = 4; dp = 3 end, true)
assert_lane("Envenom fires at 5 CP / 5 DP stacks with the buff down", "Envenom",
    function() cp = 5; dp = 5 end, true)
assert_lane("Envenom blocked below 4 CP", "Envenom",
    function() cp = 3; dp = 5 end, false)
assert_lane("Envenom blocked below 3 Deadly Poison stacks", "Envenom",
    function() cp = 5; dp = 2 end, false)
assert_lane("Envenom held while the Envenom buff is up below 85 energy", "Envenom",
    function() cp = 5; dp = 5; set_buff(57993, true); energy = 84 end, false)
assert_lane("Envenom refreshes at 85+ energy with the buff up", "Envenom",
    function() cp = 5; dp = 5; set_buff(57993, true); energy = 85 end, true)

-- ============================================================================
-- Mutilate: >= 60 energy + daggers in both hands (real equipped-item read
-- through the dagger_set map).
-- ============================================================================
assert_lane("Mutilate fires at 60+ energy with daggers", "Mutilate",
    function() energy = 60; daggers = true end, true)
assert_lane("Mutilate blocked below 60 energy with daggers", "Mutilate",
    function() energy = 59; daggers = true end, false)
assert_lane("Mutilate blocked without daggers equipped", "Mutilate",
    function() energy = 100; daggers = false end, false)

print("PASS test_rogue_assassination_wotlk_strategies")
