-- test_warlock_leveling_wotlk_strategies.lua — Warlock leveling WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua through its real build_state read
--        path (the real leveling_helpers interrupt read for Spell Lock, real
--        pet_manager pet state for the summon gates, NS.debuff_remains for the
--        DoT family, ctx.hp / ctx.target_hp / ctx.mana_pct, and the real
--        hit-volume AoE gate for Seed of Corruption / Rain of Fire via
--        ctx._aoe_hit_count), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): warlock leveling had only
--        synthetic dsl_priority coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local target_hp = 100
local mana = 100
local casting = false
local aoe_hits = 0
local debuffs = {}
local buffs = {}
local pet_dead = true

local function ua(secs) debuffs[47843] = secs end
local function corr(secs) debuffs[47813] = secs end
local function immo(secs) debuffs[47811] = secs end
local function agony(secs) debuffs[47864] = secs end
local function haunt(secs) debuffs[59164] = secs end

local me = {
    get_health_percentage = function() return hp end,
    get_pet = function()
        return { is_dead = function() return pet_dead end }
    end,
}

local function reset_env()
    combat, hp, target_hp, mana, casting, aoe_hits = true, 100, 100, 100, false, 0
    debuffs, buffs = {}, {}
    pet_dead = true
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
    is_interruptible = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "warlock leveling_wotlk strategies should load")

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
        target_hp = target_hp,
        mana_pct = mana,
        enemy_count = 1,
        target = {
            get_health_percentage = function() return target_hp end,
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
-- SpellLock: in combat + enemy cast + mana >= 5.
-- ============================================================================
assert_lane("SpellLock fires on an enemy cast", "SpellLock",
    function() casting = true end, true)
assert_lane("SpellLock blocked when nothing is casting", "SpellLock", function() end, false)
assert_lane("SpellLock blocked below 5% mana", "SpellLock",
    function() casting = true; mana = 4 end, false)

-- ============================================================================
-- SummonPet: OOC + pet missing/dead + mana >= 60.
-- ============================================================================
assert_lane("SummonPet fires OOC when the pet is dead", "SummonPet",
    function() combat = false end, true)
assert_lane("SummonPet fires OOC when the pet is absent", "SummonPet",
    function() combat = false; pet_dead = true end, true)
assert_lane("SummonPet held while the pet is alive", "SummonPet",
    function() combat = false; pet_dead = false end, false)
assert_lane("SummonPet held in combat", "SummonPet", function() end, false)
assert_lane("SummonPet held below 60% mana OOC", "SummonPet",
    function() combat = false; mana = 59 end, false)

-- ============================================================================
-- Soulstone / Healthstone / FelArmor: OOC stocking.
-- ============================================================================
assert_lane("Soulstone creates OOC", "CreateSoulstone", function() combat = false end, true)
assert_lane("Soulstone blocked in combat", "CreateSoulstone", function() end, false)
assert_lane("Healthstone creates OOC", "CreateHealthstone", function() combat = false end, true)
assert_lane("FelArmor applies OOC when both armors are down", "FelArmor",
    function() combat = false end, true)
assert_lane("FelArmor held while Fel Armor is up", "FelArmor",
    function() combat = false; buffs[28189] = true end, false)
assert_lane("FelArmor held while Demon Armor is up", "FelArmor",
    function() combat = false; buffs[27260] = true end, false)
assert_lane("FelArmor blocked in combat", "FelArmor", function() end, false)

-- ============================================================================
-- DoT lanes: combat + refresh at/below 3s + mana.
-- ============================================================================
assert_lane("Haunt refreshes at 2.9s", "Haunt", function() haunt(2.9) end, true)
assert_lane("Haunt blocked at the 3.0s boundary", "Haunt", function() haunt(3) end, false)
assert_lane("Haunt blocked below 10% mana", "Haunt", function() mana = 9 end, false)
assert_lane("UA refreshes at 2.9s", "UnstableAffliction", function() ua(2.9) end, true)
assert_lane("UA blocked at the 3.0s boundary", "UnstableAffliction", function() ua(3) end, false)
assert_lane("Corruption refreshes at 2.9s", "Corruption", function() corr(2.9) end, true)
assert_lane("Corruption blocked at the 3.0s boundary", "Corruption", function() corr(3) end, false)
assert_lane("Immolate refreshes at 2.9s", "Immolate", function() immo(2.9) end, true)
assert_lane("Immolate blocked at the 3.0s boundary", "Immolate", function() immo(3) end, false)
assert_lane("CurseOfAgony refreshes at 2.9s", "CurseOfAgony", function() agony(2.9) end, true)
assert_lane("CurseOfAgony blocked at the 3.0s boundary", "CurseOfAgony", function() agony(3) end, false)
assert_lane("DoT lanes blocked out of combat", "Corruption",
    function() combat = false end, false)

-- ============================================================================
-- Seed of Corruption / Rain of Fire: real hit-volume AoE gates.
-- ============================================================================
assert_lane("Seed of Corruption fires on 3 targets", "SeedOfCorruption",
    function() aoe_hits = 3 end, true)
assert_lane("Seed of Corruption blocked on 2 targets", "SeedOfCorruption",
    function() aoe_hits = 2 end, false)
assert_lane("Seed of Corruption blocked below 34% mana", "SeedOfCorruption",
    function() aoe_hits = 3; mana = 33 end, false)
assert_lane("Rain of Fire fires on 3 targets", "RainOfFire",
    function() aoe_hits = 3 end, true)
assert_lane("Rain of Fire blocked on 2 targets", "RainOfFire",
    function() aoe_hits = 2 end, false)
assert_lane("Rain of Fire blocked below 57% mana", "RainOfFire",
    function() aoe_hits = 3; mana = 56 end, false)

-- ============================================================================
-- Conflagrate: Immolate live (> 3s in leveling) + combat + mana.
-- ============================================================================
assert_lane("Conflagrate fires with Immolate at 3.1s", "Conflagrate",
    function() immo(3.1) end, true)
assert_lane("Conflagrate blocked with Immolate at 3.0s", "Conflagrate",
    function() immo(3) end, false)
assert_lane("Conflagrate blocked with no Immolate", "Conflagrate", function() end, false)

-- ============================================================================
-- DrainSoul / DrainLife / LifeTap: execute + sustain bands.
-- ============================================================================
assert_lane("DrainSoul fires below 25% target hp", "DrainSoul",
    function() target_hp = 24 end, true)
assert_lane("DrainSoul blocked at 25% target hp", "DrainSoul",
    function() target_hp = 25 end, false)
assert_lane("DrainLife fires below 60% hp", "DrainLife", function() hp = 59 end, true)
assert_lane("DrainLife blocked at 60% hp", "DrainLife", function() hp = 60 end, false)
assert_lane("LifeTap fires below 30% mana with hp above 40", "LifeTap",
    function() mana = 29 end, true)
assert_lane("LifeTap blocked at the 40 hp floor", "LifeTap",
    function() mana = 29; hp = 40 end, false)

-- ============================================================================
-- Fillers: combat + mana gates.
-- ============================================================================
assert_lane("ChaosBolt fires at 15% mana", "ChaosBolt", function() mana = 15 end, true)
assert_lane("ChaosBolt blocked below 15% mana", "ChaosBolt", function() mana = 14 end, false)
assert_lane("Incinerate fires at 15% mana", "Incinerate", function() mana = 15 end, true)
assert_lane("ShadowBolt fires at 15% mana", "ShadowBolt", function() mana = 15 end, true)
assert_lane("SoulFire fires at 30% mana", "SoulFire", function() mana = 30 end, true)
assert_lane("Shoot fires below 10% mana", "Shoot", function() mana = 9 end, true)
assert_lane("Shoot blocked at 10% mana", "Shoot", function() mana = 10 end, false)

print("PASS test_warlock_leveling_wotlk_strategies")
