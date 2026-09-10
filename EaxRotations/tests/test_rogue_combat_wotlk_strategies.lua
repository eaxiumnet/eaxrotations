-- test_rogue_combat_wotlk_strategies.lua — Combat rogue WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL combat_wotlk.lua through its real build_state read
--        path: ctx.energy/combo_points, NS.buff_remains/buff_up for Slice and
--        Dice, real NS.cooldown_remains for the Blade Flurry (13877) and
--        Killing Spree (51690) readiness gates, target:is_casting for Kick,
--        and ctx.enemy_count for the Blade Flurry 2-target APL gate. Pins
--        both sides of every lane, including the long-CD consent gates.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite injects
--        raw state (skipping build_state), so no suite drove the real read
--        plumbing for the strike core, SnD maintenance, or Kick.
-- SAFETY: Pure unit tests with a mocked NS; the real combat_wotlk.lua and
--         real shared modules (spec_kit / strategy_dsl / combo_points_reader)
--         load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Mutable scenario state.
local energy = 0
local cp = 0
local snd = 0
local combat = true
local casting = false
local enemy_count = 1
local longcd = true
local bf_cd = 0
local ks_cd = 0
local ar_cd = 0
local buffs = {}     -- 6774/5171 = Slice and Dice buff

local me = {
    get_health_percentage = function() return 100 end,
    get_power = function(self, power_type)
        if power_type == 3 then return energy end
        return 0
    end,
}

local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    energy, cp, snd = 0, 0, 0
    combat, casting, enemy_count, longcd = true, false, 1, true
    bf_cd, ks_cd, ar_cd = 0, 0, 0
    buffs = {}
end

_G.EaxRotations = {
    POWER_ENERGY = 3,
    POWER_COMBO = 4,
    me = me,
    GetPlayer = function() return me end,
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
    -- combat_wotlk builds ACTION via spec_kit.define_action; single-rank
    -- actions resolve to a bare spell id, so cooldown_remains receives 13877 /
    -- 51690 directly.
    cooldown_remains = function(action)
        if action == 13877 then return bf_cd end
        if action == 51690 then return ks_cd end
        if action == 13750 then return ar_cd end
        return 0
    end,
    should_use_long_cd = function(context, cd) return longcd end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/rogue/combat_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "combat_wotlk strategies should load")

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
        enemy_count = enemy_count,
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
-- Kick interrupt: in combat + an enemy cast.
-- ============================================================================
assert_lane("Kick fires on an enemy cast in combat", "Kick",
    function() casting = true end, true)
assert_lane("Kick blocked when the target is not casting", "Kick",
    function() casting = false end, false)
assert_lane("Kick blocked out of combat", "Kick",
    function() casting = true; combat = false end, false)

-- ============================================================================
-- Slice and Dice: refresh when <= 1s remains with >= 1 combo point.
-- ============================================================================
assert_lane("SliceAndDice fires at 1s remaining with combo points", "SliceAndDice",
    function() snd = 1; cp = 2 end, true)
assert_lane("SliceAndDice fires with the buff fully down", "SliceAndDice",
    function() snd = 0; cp = 2 end, true)
assert_lane("SliceAndDice blocked just past the 1s boundary", "SliceAndDice",
    function() snd = 1.01; cp = 2 end, false)
assert_lane("SliceAndDice blocked while fresh", "SliceAndDice",
    function() snd = 10; cp = 5 end, false)
assert_lane("SliceAndDice blocked with 0 combo points", "SliceAndDice",
    function() snd = 1; cp = 0 end, false)

-- ============================================================================
-- Eviscerate: finisher at >= 4 combo points.
-- ============================================================================
assert_lane("Eviscerate fires at 4 combo points", "Eviscerate",
    function() cp = 4 end, true)
assert_lane("Eviscerate blocked at 3 combo points", "Eviscerate",
    function() cp = 3 end, false)

-- ============================================================================
-- Blade Flurry: in combat + cooldown ready + SnD up + 2+ enemies + long-CD
-- consent (APL alignment). Real cooldown_remains read.
-- ============================================================================
assert_lane("BladeFlurry fires with SnD up on 2 enemies", "BladeFlurry",
    function() set_buff(6774, true); enemy_count = 2 end, true)
assert_lane("BladeFlurry blocked single-target", "BladeFlurry",
    function() set_buff(6774, true); enemy_count = 1 end, false)
assert_lane("BladeFlurry blocked without Slice and Dice up", "BladeFlurry",
    function() set_buff(6774, false); enemy_count = 2 end, false)
assert_lane("BladeFlurry blocked while on cooldown", "BladeFlurry",
    function() set_buff(6774, true); enemy_count = 2; bf_cd = 120 end, false)
assert_lane("BladeFlurry blocked out of combat", "BladeFlurry",
    function() set_buff(6774, true); enemy_count = 2; combat = false end, false)
assert_lane("BladeFlurry blocked when long-CD gate refuses", "BladeFlurry",
    function() set_buff(6774, true); enemy_count = 2; longcd = false end, false)

-- ============================================================================
-- Killing Spree: in combat + cooldown ready + energy <= 50 (APL gate so it
-- never wastes a builder GCD of energy).
-- ============================================================================
assert_lane("KillingSpree fires at 50 energy", "KillingSpree",
    function() energy = 50 end, true)
assert_lane("KillingSpree fires at 0 energy", "KillingSpree", function() end, true)
assert_lane("KillingSpree blocked above 50 energy", "KillingSpree",
    function() energy = 51 end, false)
assert_lane("KillingSpree blocked while on cooldown", "KillingSpree",
    function() energy = 0; ks_cd = 120 end, false)
assert_lane("KillingSpree blocked out of combat", "KillingSpree",
    function() energy = 0; combat = false end, false)
assert_lane("KillingSpree blocked when long-CD gate refuses", "KillingSpree",
    function() energy = 0; longcd = false end, false)

-- ============================================================================
-- Sinister Strike: builder at >= 45 energy.
-- ============================================================================
assert_lane("SinisterStrike fires at 45 energy", "SinisterStrike",
    function() energy = 45 end, true)
assert_lane("SinisterStrike blocked below 45 energy", "SinisterStrike",
    function() energy = 44 end, false)

-- ============================================================================
-- Adrenaline Rush: in combat + cooldown ready + long-CD consent (2026-09-09
-- guide pass). Real cooldown_remains read on 13750.
-- ============================================================================
assert_lane("AdrenalineRush fires off cooldown in combat", "AdrenalineRush",
    function() end, true)
assert_lane("AdrenalineRush blocked while on cooldown", "AdrenalineRush",
    function() ar_cd = 120 end, false)
assert_lane("AdrenalineRush blocked out of combat", "AdrenalineRush",
    function() combat = false end, false)
assert_lane("AdrenalineRush blocked when long-CD gate refuses", "AdrenalineRush",
    function() longcd = false end, false)

print("PASS test_rogue_combat_wotlk_strategies")
