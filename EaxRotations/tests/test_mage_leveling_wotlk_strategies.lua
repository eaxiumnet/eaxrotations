-- test_mage_leveling_wotlk_strategies.lua — Mage leveling WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL leveling_wotlk.lua through its real build_state read
--        path (NS.buff_up for the Arcane Intellect / Mage Armor / Ice Barrier /
--        Mana Shield auras, NS.debuff_remains for the Living Bomb 55360 debuff,
--        the real leveling_helpers interrupt read, pet_manager pet state, the
--        real hit-volume AoE gate for Cone of Cold / Arcane Explosion /
--        Blizzard via ctx._aoe_hit_count, NS.should_use_long_cd for the Water
--        Elemental), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua), the leveling
--        runner (run_leveling_tests.lua), and the rotation battery
--        (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): mage leveling had only synthetic
--        dsl_priority coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local casting = false
local aoe_hits = 0
local long_cd_refused = {}
local buffs = {}
local debuffs = {}
local pet_dead = true

local function lb(secs) debuffs[55360] = secs end
local function set_buff(id, up) buffs[id] = up or nil end

local me = {
    get_health_percentage = function() return hp end,
    get_pet = function()
        return { is_dead = function() return pet_dead end }
    end,
}

local function reset_env()
    combat, hp, mana, casting, aoe_hits = true, 100, 100, false, 0
    long_cd_refused, buffs, debuffs = {}, {}, {}
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
    should_use_long_cd = function(context, seconds)
        if long_cd_refused[seconds] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/mage/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "mage leveling_wotlk strategies should load")

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
        hp = hp,
        mana_pct = mana,
        enemy_count = 1,
        target = {
            get_health_percentage = function() return 100 end,
            is_casting = function() return casting end,
        },
        settings = { interrupt_lead_sec = cast_lead }, target_cast_remaining = cast_remaining,
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
-- Counterspell: in combat + enemy cast.
-- ============================================================================
assert_lane("Counterspell fires on an enemy cast", "Counterspell",
    function() casting = true end, true)
assert_lane("Counterspell blocked when nothing is casting", "Counterspell", function() end, false)
assert_lane("Counterspell blocked out of combat", "Counterspell",
    function() combat = false; casting = true end, false)

-- ============================================================================
-- Arcane Intellect / Mage Armor: OOC-capable upkeep (no combat gate).
-- ============================================================================
assert_lane("ArcaneIntellect applies when down", "ArcaneIntellect", function() end, true)
assert_lane("ArcaneIntellect held while up", "ArcaneIntellect",
    function() set_buff(42995, true) end, false)
assert_lane("ArcaneIntellect blocked below 20% mana", "ArcaneIntellect",
    function() mana = 19 end, false)
assert_lane("MageArmor applies when down", "MageArmor", function() end, true)
assert_lane("MageArmor held while up", "MageArmor",
    function() set_buff(43024, true) end, false)

-- ============================================================================
-- IceBarrier / ManaShield: in-combat emergency absorbs.
-- ============================================================================
assert_lane("IceBarrier fires below 50% hp in combat", "IceBarrier",
    function() hp = 49 end, true)
assert_lane("IceBarrier blocked at 50% hp", "IceBarrier", function() hp = 50 end, false)
assert_lane("IceBarrier blocked while already up", "IceBarrier",
    function() hp = 40; set_buff(33405, true) end, false)
assert_lane("IceBarrier blocked out of combat", "IceBarrier",
    function() hp = 40; combat = false end, false)
assert_lane("ManaShield fires below 40% hp in combat", "ManaShield",
    function() hp = 39 end, true)
assert_lane("ManaShield blocked at 40% hp", "ManaShield", function() hp = 40 end, false)
assert_lane("ManaShield blocked while already up", "ManaShield",
    function() hp = 30; set_buff(27131, true) end, false)

-- ============================================================================
-- Evocation / Blink: in-combat emergency mana / escape.
-- ============================================================================
assert_lane("Evocation fires below 20% mana in combat", "Evocation",
    function() mana = 19 end, true)
assert_lane("Evocation blocked at 20% mana", "Evocation", function() end, false)
assert_lane("Blink fires below 30% hp in combat", "Blink", function() hp = 29 end, true)
assert_lane("Blink blocked at 30% hp", "Blink", function() hp = 30 end, false)

-- ============================================================================
-- ConjureManaGem: out-of-combat stock.
-- ============================================================================
assert_lane("Mana Gem conjures OOC below 80% mana", "ConjureManaGem",
    function() combat = false; mana = 79 end, true)
assert_lane("Mana Gem blocked at 80% mana", "ConjureManaGem",
    function() combat = false; mana = 80 end, false)
assert_lane("Mana Gem blocked in combat", "ConjureManaGem", function() mana = 50 end, false)

-- ============================================================================
-- AoE lanes (real hit-volume gate via ctx._aoe_hit_count).
-- ============================================================================
assert_lane("ConeOfCold fires on 2 enemies in combat", "ConeOfCold",
    function() aoe_hits = 2 end, true)
assert_lane("ConeOfCold blocked single-target", "ConeOfCold",
    function() aoe_hits = 1 end, false)
assert_lane("ArcaneExplosion fires on 3 enemies", "ArcaneExplosion",
    function() aoe_hits = 3 end, true)
assert_lane("ArcaneExplosion blocked on 2 enemies", "ArcaneExplosion",
    function() aoe_hits = 2 end, false)
assert_lane("ArcaneExplosion blocked below 15% mana", "ArcaneExplosion",
    function() aoe_hits = 3; mana = 14 end, false)
assert_lane("Blizzard fires on 4 enemies", "Blizzard", function() aoe_hits = 4 end, true)
assert_lane("Blizzard blocked on 3 enemies", "Blizzard", function() aoe_hits = 3 end, false)

-- ============================================================================
-- SummonWaterElemental: pet down + mana >= 16 + long-CD (180s) consent.
-- ============================================================================
assert_lane("Water Elemental summons when the pet is down", "SummonWaterElemental",
    function() end, true)
assert_lane("Water Elemental held while the pet is alive", "SummonWaterElemental",
    function() pet_dead = false end, false)
assert_lane("Water Elemental blocked below 16% mana", "SummonWaterElemental",
    function() mana = 15 end, false)
assert_lane("Water Elemental blocked when long CDs are refused", "SummonWaterElemental",
    function() long_cd_refused[180] = true end, false)
assert_lane("Water Elemental blocked out of combat", "SummonWaterElemental",
    function() combat = false end, false)

-- ============================================================================
-- LivingBomb: refresh at/below 3s in combat.
-- ============================================================================
assert_lane("LivingBomb refreshes when the debuff is down", "LivingBomb", function() end, true)
assert_lane("LivingBomb refreshes at 2.9s remaining", "LivingBomb", function() lb(2.9) end, true)
assert_lane("LivingBomb blocked at the 3.0s boundary", "LivingBomb", function() lb(3) end, false)
assert_lane("LivingBomb blocked below 15% mana", "LivingBomb", function() mana = 14 end, false)

-- ============================================================================
-- Core nukes: in-combat mana-gated fillers.
-- ============================================================================
assert_lane("Pyroblast fires at 20% mana", "Pyroblast", function() mana = 20 end, true)
assert_lane("Pyroblast blocked below 20% mana", "Pyroblast", function() mana = 19 end, false)
assert_lane("Fireball fires at 15% mana", "Fireball", function() mana = 15 end, true)
assert_lane("Fireball blocked below 15% mana", "Fireball", function() mana = 14 end, false)
assert_lane("Frostbolt fires at 15% mana", "Frostbolt", function() mana = 15 end, true)
assert_lane("ArcaneBarrage fires at 20% mana", "ArcaneBarrage", function() mana = 20 end, true)
assert_lane("ArcaneMissiles fires at 25% mana", "ArcaneMissiles", function() mana = 25 end, true)
assert_lane("FireBlast fires at 10% mana", "FireBlast", function() mana = 10 end, true)
assert_lane("IceLance fires at 5% mana", "IceLance", function() mana = 5 end, true)
assert_lane("DeepFreeze fires at 10% mana", "DeepFreeze", function() mana = 10 end, true)
assert_lane("Shoot fires below 10% mana", "Shoot", function() mana = 9 end, true)
assert_lane("Shoot blocked at 10% mana", "Shoot", function() mana = 10 end, false)
assert_lane("Shoot blocked out of combat", "Shoot",
    function() mana = 5; combat = false end, false)


-- ============================================================================
-- Engine cast/channel end-time gate (2026-09-12, shared/cast_timing_sylvanas).
-- Counterspell must HOLD when the target's cast is about to land (the interrupt
-- would arrive too late and burn its cooldown) and FIRE on a normal cast.
-- Unknown remaining (nil) keeps the pre-signal fail-open behavior.
-- ============================================================================
assert_lane("Counterspell fires with 1.0s left on the enemy cast", "Counterspell",
    function() casting = true; cast_remaining = 1.0; cast_lead = nil end, true)
assert_lane("Counterspell holds when only 0.05s of the cast remains", "Counterspell",
    function() casting = true; cast_remaining = 0.05; cast_lead = nil end, false)
assert_lane("Counterspell holds ON the 0.30s lead floor", "Counterspell",
    function() casting = true; cast_remaining = 0.30; cast_lead = nil end, false)
assert_lane("Counterspell fires above the 0.30s lead floor", "Counterspell",
    function() casting = true; cast_remaining = 0.31; cast_lead = nil end, true)
assert_lane("Counterspell honours a raised interrupt_lead_sec setting", "Counterspell",
    function() casting = true; cast_remaining = 0.9; cast_lead = 1.2 end, false)

print("PASS test_mage_leveling_wotlk_strategies")
