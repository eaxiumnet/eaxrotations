-- test_rogue_leveling_wotlk_strategies.lua — Rogue leveling WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua through its real build_state read
--        path: ctx.energy/combo_points, NS.buff_remains for Slice and Dice,
--        NS.debuff_remains for Rupture, NS.buff_up for Stealth, the real
--        leveling_helpers interrupt check (target:is_casting), target hp for
--        the Rupture low-hp guard, and the real hit-volume gate
--        (ctx._aoe_hit_count) for Fan of Knives. Pins both sides of every
--        lane: the out-of-combat Stealth enter, the Stealth Ambush opener,
--        Kick, SnD maintenance, the 3-target Fan of Knives, the Rupture bleed
--        finisher with its >25% target-hp guard, Gouge, Eviscerate, and
--        Sinister Strike.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the dsl_priority suite injects
--        raw state, so no suite exercised the real state plumbing for the
--        leveling opener/AoE/finisher core.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules (spec_kit / strategy_dsl / combo_points_reader /
--         leveling_helpers / aoe_hit_volume) load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Mutable scenario state.
local target_hp = 100
local energy = 0
local cp = 0
local snd = 0
local rupture = 0
local combat = true
local casting = false
local stealth = false
local aoe = 0
local buffs = {}

local me = {
    get_health_percentage = function() return 100 end,
    get_power = function(self, power_type)
        if power_type == 3 then return energy end
        return 0
    end,
}

local function reset_env()
    target_hp, energy, cp, snd, rupture = 100, 0, 0, 0, 0
    combat, casting, stealth, aoe = true, false, false, 0
    buffs = {}
end

_G.EaxRotations = {
    POWER_ENERGY = 3,
    POWER_COMBO = 4,
    me = me,
    GetPlayer = function() return me end,
    is_interruptible = function(target) return true end,
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
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/rogue/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "rogue leveling_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local cast_remaining = nil
local cast_lead = nil
local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        energy = energy,
        combo_points = cp,
        target = {
            get_health_percentage = function() return target_hp end,
            is_casting = function() return casting end,
        },
        settings = { interrupt_lead_sec = cast_lead }, target_cast_remaining = cast_remaining,
        _aoe_hit_count = aoe,
    }
    -- Stealth is driven through the buff mock, like every other aura state.
    buffs[1787] = stealth or nil
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
-- Stealth: enter out of combat when not already stealthed.
-- ============================================================================
assert_lane("Stealth fires out of combat", "Stealth",
    function() combat = false; stealth = false end, true)
assert_lane("Stealth blocked in combat", "Stealth",
    function() combat = true end, false)
assert_lane("Stealth blocked while already stealthed", "Stealth",
    function() combat = false; stealth = true end, false)

-- ============================================================================
-- Ambush opener: stealthed + >= 60 energy.
-- ============================================================================
assert_lane("Ambush fires stealthed at 60 energy", "Ambush",
    function() stealth = true; energy = 60 end, true)
assert_lane("Ambush blocked when not stealthed", "Ambush",
    function() stealth = false; energy = 100 end, false)
assert_lane("Ambush blocked below 60 energy", "Ambush",
    function() stealth = true; energy = 59 end, false)

-- ============================================================================
-- Kick interrupt: in combat + enemy cast + >= 25 energy.
-- ============================================================================
assert_lane("Kick fires on an enemy cast at 25 energy", "Kick",
    function() casting = true; energy = 25 end, true)
assert_lane("Kick blocked when the target is not casting", "Kick",
    function() casting = false; energy = 100 end, false)
assert_lane("Kick blocked below 25 energy", "Kick",
    function() casting = true; energy = 24 end, false)
assert_lane("Kick blocked out of combat", "Kick",
    function() casting = true; energy = 100; combat = false end, false)

-- ============================================================================
-- Slice and Dice: in combat, refresh under 3s with >= 1 combo point.
-- ============================================================================
assert_lane("SliceAndDice fires when expiring with combo points", "SliceAndDice",
    function() snd = 2; cp = 1 end, true)
assert_lane("SliceAndDice blocked while fresh", "SliceAndDice",
    function() snd = 10; cp = 5 end, false)
assert_lane("SliceAndDice blocked with 0 combo points", "SliceAndDice",
    function() snd = 0; cp = 0 end, false)
assert_lane("SliceAndDice blocked out of combat", "SliceAndDice",
    function() snd = 0; cp = 5; combat = false end, false)

-- ============================================================================
-- Fan of Knives: in combat + >= 50 energy + 3 targets in 8 yd (real hit gate).
-- ============================================================================
assert_lane("FanOfKnives fires surrounded by 3 targets", "FanOfKnives",
    function() energy = 50; aoe = 3 end, true)
assert_lane("FanOfKnives blocked on 2 targets", "FanOfKnives",
    function() energy = 100; aoe = 2 end, false)
assert_lane("FanOfKnives blocked below 50 energy", "FanOfKnives",
    function() energy = 49; aoe = 5 end, false)
assert_lane("FanOfKnives blocked out of combat", "FanOfKnives",
    function() energy = 100; aoe = 5; combat = false end, false)

-- ============================================================================
-- Rupture: in combat + >= 4 CP + bleed expiring + target above 25% hp.
-- ============================================================================
assert_lane("Rupture fires on a healthy target when the bleed falls", "Rupture",
    function() cp = 4; rupture = 0; target_hp = 80 end, true)
assert_lane("Rupture blocked while the bleed is healthy", "Rupture",
    function() cp = 4; rupture = 10; target_hp = 80 end, false)
assert_lane("Rupture blocked on a low-hp target", "Rupture",
    function() cp = 4; rupture = 0; target_hp = 25 end, false)
assert_lane("Rupture blocked below 4 combo points", "Rupture",
    function() cp = 3; rupture = 0; target_hp = 80 end, false)

-- ============================================================================
-- Gouge: in combat + >= 45 energy.
-- ============================================================================
assert_lane("Gouge fires at 45 energy", "Gouge", function() energy = 45 end, true)
assert_lane("Gouge blocked below 45 energy", "Gouge", function() energy = 44 end, false)
assert_lane("Gouge blocked out of combat", "Gouge",
    function() energy = 100; combat = false end, false)

-- ============================================================================
-- Eviscerate: in combat + >= 4 combo points.
-- ============================================================================
assert_lane("Eviscerate fires at 4 combo points", "Eviscerate",
    function() cp = 4 end, true)
assert_lane("Eviscerate blocked at 3 combo points", "Eviscerate",
    function() cp = 3 end, false)
assert_lane("Eviscerate blocked out of combat", "Eviscerate",
    function() cp = 4; combat = false end, false)

-- ============================================================================
-- Sinister Strike: in combat + >= 45 energy.
-- ============================================================================
assert_lane("SinisterStrike fires at 45 energy", "SinisterStrike",
    function() energy = 45 end, true)
assert_lane("SinisterStrike blocked below 45 energy", "SinisterStrike",
    function() energy = 44 end, false)
assert_lane("SinisterStrike blocked out of combat", "SinisterStrike",
    function() energy = 100; combat = false end, false)


-- ============================================================================
-- Engine cast/channel end-time gate (2026-09-12, shared/cast_timing_sylvanas).
-- Kick must HOLD when the target's cast is about to land (the interrupt
-- would arrive too late and burn its cooldown) and FIRE on a normal cast.
-- Unknown remaining (nil) keeps the pre-signal fail-open behavior.
-- ============================================================================
assert_lane("Kick fires with 1.0s left on the enemy cast", "Kick",
    function() casting = true; energy = 30; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("Kick holds when only 0.05s of the cast remains", "Kick",
    function() casting = true; energy = 30; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("Kick holds ON the 0.30s lead floor", "Kick",
    function() casting = true; energy = 30; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("Kick fires above the 0.30s lead floor", "Kick",
    function() casting = true; energy = 30; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("Kick honours a raised interrupt_lead_sec setting", "Kick",
    function() casting = true; energy = 30; cast_remaining = 0.9; cast_lead = 1.2 end, false)

print("PASS test_rogue_leveling_wotlk_strategies")
