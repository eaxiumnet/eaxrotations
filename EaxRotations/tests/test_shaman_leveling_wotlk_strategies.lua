-- test_shaman_leveling_wotlk_strategies.lua — Shaman leveling WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua through its real build_state read
--        path (the real leveling_helpers interrupt read for Wind Shear,
--        NS.buff_up for Lightning Shield, NS.debuff_remains for Flame Shock,
--        NS.get_totem_info for the shared fire slot, ctx.hp / ctx.mana_pct /
--        ctx.enemy_count), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): shaman leveling had only
--        synthetic dsl_priority coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local enemy_count = 1
local casting = false
local debuffs = {}
local buffs = {}
local totem_slots = {}

local function flame(secs) debuffs[49233] = secs end
local function shield(up) buffs[49281] = up or nil end

local me = { get_health_percentage = function() return hp end }

local function reset_env()
    combat, hp, mana, enemy_count, casting = true, 100, 100, 1, false
    debuffs, buffs, totem_slots = {}, {}, {}
end

_G.EaxRotations = {
    me = me,
    GetPlayer = function() return me end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    get_totem_info = function(slot) return totem_slots[slot] end,
    is_interruptible = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/shaman/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "shaman leveling_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        hp = hp,
        mana_pct = mana,
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
-- WindShear: in combat + enemy cast.
-- ============================================================================
assert_lane("WindShear fires on an enemy cast", "WindShear",
    function() casting = true end, true)
assert_lane("WindShear blocked when nothing is casting", "WindShear", function() end, false)
assert_lane("WindShear blocked out of combat", "WindShear",
    function() combat = false; casting = true end, false)

-- ============================================================================
-- HealingWave: emergency band in combat.
-- ============================================================================
assert_lane("HealingWave fires below 50% hp in combat", "HealingWave",
    function() hp = 49 end, true)
assert_lane("HealingWave blocked at 50% hp", "HealingWave", function() hp = 50 end, false)
assert_lane("HealingWave blocked below 25% mana", "HealingWave",
    function() hp = 40; mana = 24 end, false)
assert_lane("HealingWave blocked out of combat", "HealingWave",
    function() hp = 40; combat = false end, false)

-- ============================================================================
-- LightningShield: re-apply when the aura is down (no combat gate).
-- ============================================================================
assert_lane("LightningShield applies when down", "LightningShield", function() end, true)
assert_lane("LightningShield held while up", "LightningShield",
    function() shield(true) end, false)
assert_lane("LightningShield blocked below 5% mana", "LightningShield",
    function() mana = 4 end, false)

-- ============================================================================
-- SearingTotem / MagmaTotem: shared fire-slot occupancy + volume gates.
-- ============================================================================
assert_lane("SearingTotem drops in combat on 1+ enemies", "SearingTotem",
    function() end, true)
assert_lane("SearingTotem blocked when the fire slot is occupied", "SearingTotem",
    function() totem_slots[1] = { have_totem = true } end, false)
assert_lane("SearingTotem blocked below 10% mana", "SearingTotem",
    function() mana = 9 end, false)
assert_lane("SearingTotem blocked out of combat", "SearingTotem",
    function() combat = false end, false)
assert_lane("MagmaTotem fires on 3+ enemies", "MagmaTotem",
    function() enemy_count = 3 end, true)
assert_lane("MagmaTotem blocked on 2 enemies", "MagmaTotem",
    function() enemy_count = 2 end, false)
assert_lane("MagmaTotem blocked when the fire slot is occupied", "MagmaTotem",
    function() enemy_count = 3; totem_slots[1] = { have_totem = true } end, false)
assert_lane("MagmaTotem blocked below 20% mana", "MagmaTotem",
    function() enemy_count = 3; mana = 19 end, false)

-- ============================================================================
-- ChainLightning: cleave at 2+ enemies.
-- ============================================================================
assert_lane("ChainLightning fires on 2 enemies", "ChainLightning",
    function() enemy_count = 2 end, true)
assert_lane("ChainLightning blocked single-target", "ChainLightning", function() end, false)
assert_lane("ChainLightning blocked below 20% mana", "ChainLightning",
    function() enemy_count = 2; mana = 19 end, false)

-- ============================================================================
-- FlameShock / LavaBurst: debuff refresh + guaranteed-crit pairing.
-- ============================================================================
assert_lane("FlameShock refreshes at 2.9s", "FlameShock", function() flame(2.9) end, true)
assert_lane("FlameShock blocked at the 3.0s boundary", "FlameShock", function() flame(3) end, false)
assert_lane("FlameShock blocked out of combat", "FlameShock",
    function() combat = false end, false)
assert_lane("LavaBurst fires while Flame Shock is live", "LavaBurst",
    function() flame(6) end, true)
assert_lane("LavaBurst blocked with Flame Shock down", "LavaBurst", function() end, false)
assert_lane("LavaBurst blocked below 20% mana", "LavaBurst",
    function() flame(6); mana = 19 end, false)

-- ============================================================================
-- Stormstrike / EarthShock / LightningBolt: in-combat mana-gated fillers.
-- ============================================================================
assert_lane("Stormstrike fires at 10% mana", "Stormstrike", function() mana = 10 end, true)
assert_lane("Stormstrike blocked below 10% mana", "Stormstrike", function() mana = 9 end, false)
assert_lane("EarthShock fires at 15% mana", "EarthShock", function() mana = 15 end, true)
assert_lane("EarthShock blocked below 15% mana", "EarthShock", function() mana = 14 end, false)
assert_lane("LightningBolt fires at 15% mana", "LightningBolt", function() mana = 15 end, true)
assert_lane("LightningBolt blocked below 15% mana", "LightningBolt", function() mana = 14 end, false)
assert_lane("LightningBolt blocked out of combat", "LightningBolt",
    function() mana = 50; combat = false end, false)

print("PASS test_shaman_leveling_wotlk_strategies")
