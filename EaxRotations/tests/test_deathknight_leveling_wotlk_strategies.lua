-- test_deathknight_leveling_wotlk_strategies.lua — Death Knight leveling WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua DSL lanes, pinning both sides of
--        the unpinned gates: Mind Freeze interrupt, Blood Presence / Horn of
--        Winter upkeep, disease maintenance, the AoE lanes (Pestilence spread,
--        Death and Decay, Blood Boil, Howling Blast) driven through the real
--        hit-volume gate, Death Strike's hp band, the in-combat-only strike
--        core (Obliterate / Scourge Strike / Heart Strike / Blood Strike),
--        the Death Coil runic-power dump, and Empower Rune Weapon.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the DK leveling file's strike
--        core, AoE-negative, and RP don't-fire sides had no coverage.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules (spec_kit / strategy_dsl / rune_manager /
--         leveling_helpers / aoe_hit_volume) load.

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
local rp = 0
local ff = 0
local bp = 0
local combat = true
local longcd = true
local erw_cd = 0
local casting = false
local aoe_hits = 0
local buffs = {}

local function set_buff(id, up) buffs[id] = up or nil end

local me = {
    get_health_percentage = function() return hp end,
    get_power = function(self, power_type)
        if power_type == 6 then return rp end
        return 0
    end,
}

local function reset_env()
    hp, rp, ff, bp = 100, 0, 0, 0
    combat, longcd, erw_cd, casting, aoe_hits = true, true, 0, false, 0
    buffs = {}
end

_G.EaxRotations = {
    DeathKnightSpells = {
        IcyTouch = make_action({ 49909, 45477, 49903, 49904 }, "IcyTouch"),
        PlagueStrike = make_action({ 49921, 49917, 49918, 49919, 49920 }, "PlagueStrike"),
        BloodStrike = make_action({ 49930, 49929, 49928, 49927, 49926, 45902 }, "BloodStrike"),
        DeathStrike = make_action({ 49999, 49998, 45463, 49924 }, "DeathStrike"),
        HeartStrike = make_action({ 55262, 55050, 55258, 55259, 55260, 55261 }, "HeartStrike"),
        Obliterate = make_action({ 51425, 49020, 51423, 51424 }, "Obliterate"),
        HowlingBlast = make_action({ 51411, 49184, 51409, 51410 }, "HowlingBlast"),
        ScourgeStrike = make_action({ 55271, 55090, 55265, 55270 }, "ScourgeStrike"),
        DeathCoil = make_action({ 49895, 47541, 49892, 49893, 49894 }, "DeathCoil"),
        HornOfWinter = make_action({ 57623, 57330 }, "HornOfWinter"),
        MindFreeze = make_action(47528, "MindFreeze"),
        BloodPresence = make_action(48266, "BloodPresence"),
        Pestilence = make_action(50842, "Pestilence"),
        DeathAndDecay = make_action({ 49938, 43265, 49936, 49937 }, "DeathAndDecay"),
        BloodBoil = make_action({ 49941, 48721, 49939, 49940 }, "BloodBoil"),
        EmpowerRuneWeapon = make_action(47568, "EmpowerRuneWeapon"),
    },
    POWER_RUNICPOWER = 6,
    me = me,
    GetPlayer = function() return me end,
    is_wotlk = function() return true end,
    is_interruptible = function(target) return true end,
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
    cooldown_remains = function(action)
        if action and action.name == "EmpowerRuneWeapon" then return erw_cd end
        return 0
    end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/deathknight/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "leveling_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return casting end,
        },
        settings = {},
        _aoe_hit_count = aoe_hits,
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
-- Mind Freeze interrupt: combat + an interruptible enemy cast.
-- ============================================================================
assert_lane("MindFreeze fires on an enemy cast in combat", "MindFreeze",
    function() casting = true end, true)
assert_lane("MindFreeze blocked when the target is not casting", "MindFreeze",
    function() casting = false end, false)
assert_lane("MindFreeze blocked out of combat", "MindFreeze",
    function() casting = true; combat = false end, false)

-- ============================================================================
-- Blood Presence and Horn of Winter upkeep.
-- ============================================================================
assert_lane("BloodPresence fires with the presence down", "BloodPresence", function() end, true)
assert_lane("BloodPresence blocked while the presence is up", "BloodPresence",
    function() set_buff(48266, true) end, false)
assert_lane("HornOfWinter fires with the buff down", "HornOfWinter", function() end, true)
assert_lane("HornOfWinter blocked while buff is up", "HornOfWinter",
    function() set_buff(57623, true) end, false)

-- ============================================================================
-- Disease maintenance: combat-gated, refresh under 3s.
-- ============================================================================
assert_lane("IcyTouch fires in combat with Frost Fever down", "IcyTouch", function() end, true)
assert_lane("IcyTouch blocked while Frost Fever is healthy", "IcyTouch",
    function() ff = 10 end, false)
assert_lane("IcyTouch blocked out of combat", "IcyTouch",
    function() combat = false end, false)
assert_lane("PlagueStrike fires in combat with Blood Plague down", "PlagueStrike", function() end, true)
assert_lane("PlagueStrike blocked while Blood Plague is healthy", "PlagueStrike",
    function() bp = 10 end, false)

-- ============================================================================
-- AoE lanes (real hit-volume gate via ctx._aoe_hit_count).
-- ============================================================================
assert_lane("Pestilence spreads on 2 targets with a disease up", "Pestilence",
    function() ff = 10; aoe_hits = 2 end, true)
assert_lane("Pestilence blocked single-target with a disease up", "Pestilence",
    function() ff = 10; aoe_hits = 1 end, false)
assert_lane("Pestilence blocked with no diseases up", "Pestilence",
    function() ff = 0; bp = 0; aoe_hits = 5 end, false)
assert_lane("DeathAndDecay fires on 3 targets in combat", "DeathAndDecay",
    function() aoe_hits = 3 end, true)
assert_lane("DeathAndDecay blocked on 2 targets", "DeathAndDecay",
    function() aoe_hits = 2 end, false)
assert_lane("BloodBoil fires on 2 targets around self", "BloodBoil",
    function() aoe_hits = 2 end, true)
assert_lane("BloodBoil blocked single-target", "BloodBoil",
    function() aoe_hits = 1 end, false)
assert_lane("HowlingBlast fires on 2 targets in combat", "HowlingBlast",
    function() aoe_hits = 2 end, true)
assert_lane("HowlingBlast blocked single-target", "HowlingBlast",
    function() aoe_hits = 1 end, false)

-- ============================================================================
-- Death Strike self-heal band (combat + hp < 80).
-- ============================================================================
assert_lane("DeathStrike fires below 80% hp in combat", "DeathStrike",
    function() hp = 79 end, true)
assert_lane("DeathStrike blocked at/above 80% hp", "DeathStrike",
    function() hp = 80 end, false)
assert_lane("DeathStrike blocked out of combat", "DeathStrike",
    function() hp = 50; combat = false end, false)

-- ============================================================================
-- Strike core: all combat-gated; the leveling file keeps them unconditional
-- inside combat (rune economy is engine-enforced).
-- ============================================================================
assert_lane("Obliterate fires in combat", "Obliterate", function() end, true)
assert_lane("Obliterate blocked out of combat", "Obliterate",
    function() combat = false end, false)
assert_lane("ScourgeStrike fires in combat", "ScourgeStrike", function() end, true)
assert_lane("ScourgeStrike blocked out of combat", "ScourgeStrike",
    function() combat = false end, false)
assert_lane("HeartStrike fires in combat", "HeartStrike", function() end, true)
assert_lane("HeartStrike blocked out of combat", "HeartStrike",
    function() combat = false end, false)
assert_lane("BloodStrike fires in combat", "BloodStrike", function() end, true)
assert_lane("BloodStrike blocked out of combat", "BloodStrike",
    function() combat = false end, false)

-- ============================================================================
-- Death Coil: combat-gated runic-power dump at 40+.
-- ============================================================================
assert_lane("DeathCoil fires at 40+ RP in combat", "DeathCoil", function() rp = 40 end, true)
assert_lane("DeathCoil blocked below 40 RP", "DeathCoil", function() rp = 39 end, false)
assert_lane("DeathCoil blocked out of combat", "DeathCoil",
    function() rp = 100; combat = false end, false)

-- ============================================================================
-- Empower Rune Weapon: combat + cooldown ready + long-CD consent.
-- ============================================================================
assert_lane("EmpowerRuneWeapon fires in combat with the cooldown ready",
    "EmpowerRuneWeapon", function() end, true)
assert_lane("EmpowerRuneWeapon blocked while on cooldown", "EmpowerRuneWeapon",
    function() erw_cd = 300 end, false)
assert_lane("EmpowerRuneWeapon blocked when long-CD gate refuses", "EmpowerRuneWeapon",
    function() longcd = false end, false)
assert_lane("EmpowerRuneWeapon blocked out of combat", "EmpowerRuneWeapon",
    function() combat = false end, false)

print("PASS test_deathknight_leveling_wotlk_strategies")
