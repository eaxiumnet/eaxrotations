-- test_deathknight_blood_wotlk_strategies.lua — Blood DK WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Exercises the real blood_wotlk.lua DSL lanes under era-appropriate
--        state, pinning both sides of each gate: Icebound Fortitude /
--        Vampiric Blood hp bands, Horn of Winter upkeep, Dancing Rune Weapon
--        commit gate (combat + target_hp + runic power + long-CD), disease
--        maintenance (Icy Touch / Plague Strike / Pestilence refresh), the
--        Death Strike disease-uptime guard, Heart Strike filler, and the
--        Death Coil runic-power spend gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): blood_wotlk had only partial
--        coverage; this pins the unpinned lanes behaviorally both sides.
-- SAFETY: Pure unit tests with a mocked NS; the real blood_wotlk.lua and the
--         real shared modules (spec_kit / strategy_dsl / rune_manager /
--         presence_manager) load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local function make_action(ids, label)
    local id = type(ids) == "table" and ids[1] or ids
    return {
        id = id,
        ids = type(ids) == "table" and ids or { ids },
        name = label or tostring(id),
        cast_safe = function(self, target) return true end,
        cooldown_remaining = function(self) return 0 end,
        can_cast = function(self, target) return true end,
        is_learned = function(self) return true end,
    }
end

-- Mutable scenario state.
local hp = 100
local target_hp = 100
local rp = 0
local ff = 0              -- Frost Fever debuff seconds remaining (55095)
local bp = 0              -- Blood Plague debuff seconds remaining (55078)
local combat = true
local longcd = true
local buffs = {}          -- player buff ids currently up (self-cast upkeep)

-- Presence buffs (48266 blood / 48263 frost / 48265 unholy).
local function set_buff(id, up) buffs[id] = up or nil end

local me = {
    get_health_percentage = function() return hp end,
    get_power = function(self, power_type)
        if power_type == 6 then return rp end
        return 0
    end,
}

local function reset_env()
    hp, target_hp, rp, ff, bp, combat, longcd = 100, 100, 0, 0, 0, true, true
    buffs = {}
end

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action({ 49909, 45477, 49903, 49904 }, "IcyTouch"),
        PlagueStrike = make_action({ 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
        Pestilence = make_action(50842, "Pestilence"),
        HeartStrike = make_action({ 55262, 55050, 55258, 55259, 55260, 55261 }, "HeartStrike"),
        DeathStrike = make_action({ 49999, 49998, 45463, 49924 }, "DeathStrike"),
        DeathCoil = make_action({ 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
        DancingRuneWeapon = make_action(49028, "DancingRuneWeapon"),
        HornOfWinter = make_action({ 57623, 57330 }, "HornOfWinter"),
        VampiricBlood = make_action(55233, "VampiricBlood"),
        IceboundFortitude = make_action(48792, "IceboundFortitude"),
        BloodPresence = make_action(48266, "BloodPresence"),
        FrostPresence = make_action(48263, "FrostPresence"),
        UnholyPresence = make_action(48265, "UnholyPresence"),
        MindFreeze = make_action(47528, "MindFreeze"),
    },
    POWER_RUNICPOWER = 6,
    me = me,
    GetPlayer = function() return me end,
    is_wotlk = function() return true end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 55095 then return ff end
            if id == 55078 then return bp end
        end
        return 0
    end,
    should_use_long_cd = function(context, cd) return longcd end,
    cooldown_remains = function(action) return 0 end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/deathknight/blood_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "blood_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        target = { get_health_percentage = function() return target_hp end },
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
-- Icebound Fortitude: emergency band hp < 40 (no combat gate).
-- ============================================================================
assert_lane("IceboundFortitude fires under 40% hp", "IceboundFortitude",
    function() hp = 39 end, true)
assert_lane("IceboundFortitude blocked at/above 40% hp", "IceboundFortitude",
    function() hp = 40 end, false)
assert_lane("IceboundFortitude fires even out of combat (band-only gate)",
    "IceboundFortitude", function() hp = 25; combat = false end, true)

-- ============================================================================
-- Vampiric Blood: emergency band hp < 50.
-- ============================================================================
assert_lane("VampiricBlood fires under 50% hp", "VampiricBlood",
    function() hp = 49 end, true)
assert_lane("VampiricBlood blocked at/above 50% hp", "VampiricBlood",
    function() hp = 50 end, false)

-- ============================================================================
-- Horn of Winter: upkeep when the buff is down; never when up.
-- ============================================================================
assert_lane("HornOfWinter fires with the buff down", "HornOfWinter", function() end, true)
assert_lane("HornOfWinter blocked while buff is up", "HornOfWinter",
    function() set_buff(57623, true) end, false)

-- ============================================================================
-- Dancing Rune Weapon: commit gate = combat + target alive-ish (>50%) +
-- runic power >= 60 + long-CD consent.
-- ============================================================================
assert_lane("DancingRuneWeapon fires on a boss target with 60+ RP", "DancingRuneWeapon",
    function() rp = 60; target_hp = 90 end, true)
assert_lane("DancingRuneWeapon blocked out of combat", "DancingRuneWeapon",
    function() rp = 100; target_hp = 90; combat = false end, false)
assert_lane("DancingRuneWeapon blocked on a low-hp target", "DancingRuneWeapon",
    function() rp = 100; target_hp = 50 end, false)
assert_lane("DancingRuneWeapon blocked below 60 RP", "DancingRuneWeapon",
    function() rp = 59; target_hp = 90 end, false)
assert_lane("DancingRuneWeapon blocked when long-CD gate refuses",
    "DancingRuneWeapon", function() rp = 100; target_hp = 90; longcd = false end, false)

-- ============================================================================
-- Disease maintenance: Icy Touch (Frost Fever) / Plague Strike (Blood Plague)
-- refresh under 3s; Pestilence refreshes when one is about to fall.
-- ============================================================================
assert_lane("IcyTouch fires when Frost Fever is down", "IcyTouch", function() end, true)
assert_lane("IcyTouch fires when Frost Fever is about to expire", "IcyTouch",
    function() ff = 2.9 end, true)
assert_lane("IcyTouch blocked while Frost Fever is healthy", "IcyTouch",
    function() ff = 3 end, false)
assert_lane("PlagueStrike fires when Blood Plague is down", "PlagueStrike", function() end, true)
assert_lane("PlagueStrike blocked while Blood Plague is healthy", "PlagueStrike",
    function() bp = 5 end, false)

-- Pestilence: both diseases up and either one < 3s.
assert_lane("Pestilence fires when one disease is about to expire", "Pestilence",
    function() ff = 10; bp = 1 end, true)
assert_lane("Pestilence blocked while both diseases are healthy", "Pestilence",
    function() ff = 10; bp = 10 end, false)
assert_lane("Pestilence blocked when Frost Fever is missing entirely", "Pestilence",
    function() bp = 1 end, false)
assert_lane("Pestilence blocked when Blood Plague is missing entirely", "Pestilence",
    function() ff = 1 end, false)

-- ============================================================================
-- Death Strike self-heal: hp < 80 AND Frost Fever up (>3s). The disease-
-- uptime guard must refuse when the frost rune is needed for the refresh.
-- ============================================================================
assert_lane("DeathStrike fires below 80% hp with Frost Fever healthy",
    "DeathStrike", function() hp = 70; ff = 10 end, true)
assert_lane("DeathStrike blocked at/above 80% hp", "DeathStrike",
    function() hp = 80; ff = 10 end, false)
assert_lane("DeathStrike blocked below 80% hp when Frost Fever is down",
    "DeathStrike", function() hp = 70; ff = 0 end, false)
assert_lane("DeathStrike blocked below 80% hp when Frost Fever is about to expire",
    "DeathStrike", function() hp = 70; ff = 3 end, false)

-- ============================================================================
-- Heart Strike filler: unconditional (no gates).
-- ============================================================================
assert_lane("HeartStrike fires as the unconditional filler", "HeartStrike",
    function() hp = 100; combat = false end, true)

-- ============================================================================
-- Death Coil runic-power dump: RP >= 40 (no combat gate).
-- ============================================================================
assert_lane("DeathCoil fires at 40+ RP", "DeathCoil", function() rp = 40 end, true)
assert_lane("DeathCoil blocked below 40 RP", "DeathCoil", function() rp = 39 end, false)

-- ============================================================================
-- Manager-backed interrupt lane (2026-09-12 cast-timing pass). This file
-- registers Mind Freeze through interrupt_manager.register_interrupt_spell, so
-- its gate is the shared cast_has_interrupt_window: an interrupt whose lead is
-- at or below 0.30s is refused (the cast lands first and the cooldown is
-- wasted). Driven through the REAL spec file with the engine end-time accessor
-- on the mock target; an absent end time stays fail-open.
-- ============================================================================
_G.EaxRotations.try_interrupt = function() return true end
_G.EaxRotations.spell_ready = function() return true end
_G.EaxRotations.gcd_remains = function() return 0 end
_G.EaxRotations.try_cast = function() return true end
_G.EaxRotations.time_now = function() return 0 end
_G.EaxRotations.is_interruptible = function() return true end

-- The manager-registered strategy keeps its generic default name ("Interrupt")
-- in this file (frost_wotlk.lua renames it to "MindFreeze"), and blood's
-- not-loaded fallback is "MindFreezeSkip", so resolve by any of the three.
local function find_interrupt_lane()
    for i = 1, #result.strategies do
        local s = result.strategies[i]
        if s.name == "MindFreeze" or s.name == "Interrupt" or s.name == "MindFreezeSkip" then
            return s
        end
    end
    error("interrupt strategy not found")
end

local function interrupt_probe(remaining)
    local tgt = {
        is_casting = function() return true end,
        get_channeling_or_casting_remaining_sec = function() return remaining end,
    }
    local ctx = {
        in_combat = true, me = me, target = tgt,
        settings = { use_interrupt = true, interrupt_humanize_enabled = false },
        target_cast_remaining = remaining,
    }
    return find_interrupt_lane().matches(ctx, result.build_state(ctx))
end

assert_true(interrupt_probe(1.0), "MindFreeze fires with 1.0s left on the target cast")
assert_true(interrupt_probe(0.31), "MindFreeze fires above the 0.30s lead floor")
assert_false(interrupt_probe(0.30), "MindFreeze holds ON the 0.30s lead floor")
assert_false(interrupt_probe(0.20), "MindFreeze holds with 0.20s left on the cast")
assert_false(interrupt_probe(0.05), "MindFreeze holds when the cast lands first")

print("PASS test_deathknight_blood_wotlk_strategies")
