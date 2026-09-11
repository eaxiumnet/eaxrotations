-- test_druid_bear_wotlk_strategies.lua — Bear druid WotLK behavioral strategy
-- match-gate scenarios.
-- WHAT:  Drives the REAL bear_wotlk.lua through its real build_state read path
--        (ctx.rage, ctx.hp, ctx.enemy_count, NS.debuff_remains for Lacerate /
--        Mangle / Faerie Fire, and real NS.spell_ready for the Frenzied
--        Regeneration CD gate), pinning both sides of every lane: the
--        Lacerate stack refresh, Swipe AoE, the Mangle bleed-vulnerability
--        refresh, Faerie Fire upkeep, the Maul rage dump, and the Frenzied
--        Regeneration panic heal.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): druid bear had zero behavioral
--        coverage (only a static priority-order suite); every lane here is a
--        first behavioral pin.
-- SAFETY: Pure unit tests with a mocked NS; the real bear_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local hp = 100
local rage = 0
local enemy_count = 1
local combat = true
-- 2026-09-10 bear guide pass: controllable threat readout for the Growl
-- fail-closed gate (the dispatcher produces ctx.threat_pct from
-- NS.threat_status, main_sylvanas:1311; the battery presents it in
-- threat_high=95).
local threat_pct = nil
local debuffs = {}
local not_ready = {}
local cds = {}

local function lacerate(secs) debuffs[48568] = secs end
local function mangle(secs) debuffs[48564] = secs end
local function ff(secs) debuffs[27011] = secs end

local function reset_env()
    hp, rage, enemy_count, combat = 100, 0, 1, true
    threat_pct = nil
    debuffs, not_ready, cds = {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return hp end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    spell_ready = function(spell, target)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1]))
        if not_ready[id] then return false end
        return true
    end,
    cooldown_remains = function(action)
        local id = type(action) == "number" and action or (action and action.id)
        return cds[id] or 0
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/bear_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "bear_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        rage = rage,
        hp = hp,
        enemy_count = enemy_count,
        threat_pct = threat_pct,
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
-- Lacerate: threat stack refresh under 3s at >= 15 rage.
-- ============================================================================
assert_lane("Lacerate fires when the stack is down at 15 rage", "Lacerate",
    function() rage = 15; lacerate(0) end, true)
assert_lane("Lacerate fires when the stack is about to expire", "Lacerate",
    function() rage = 15; lacerate(2) end, true)
assert_lane("Lacerate blocked below 15 rage", "Lacerate",
    function() rage = 14; lacerate(0) end, false)
assert_lane("Lacerate blocked while the stack is healthy", "Lacerate",
    function() rage = 100; lacerate(3) end, false)
assert_lane("Lacerate blocked out of combat", "Lacerate",
    function() rage = 100; lacerate(0); combat = false end, false)

-- ============================================================================
-- Swipe (Bear): AoE on 2+ enemies at >= 15 rage.
-- ============================================================================
assert_lane("SwipeBear fires on 2 enemies at 15 rage", "SwipeBear",
    function() rage = 15; enemy_count = 2 end, true)
assert_lane("SwipeBear blocked single-target", "SwipeBear",
    function() rage = 100; enemy_count = 1 end, false)
assert_lane("SwipeBear blocked below 15 rage", "SwipeBear",
    function() rage = 14; enemy_count = 2 end, false)

-- ============================================================================
-- Mangle (Bear): bleed-vulnerability refresh under 3s at >= 15 rage.
-- ============================================================================
assert_lane("MangleBear fires with the debuff down at 15 rage", "MangleBear",
    function() rage = 15; mangle(0) end, true)
assert_lane("MangleBear blocked while the debuff is healthy", "MangleBear",
    function() rage = 100; mangle(3) end, false)
assert_lane("MangleBear blocked below 15 rage", "MangleBear",
    function() rage = 14; mangle(0) end, false)

-- ============================================================================
-- Faerie Fire (Feral): upkeep under 3s (no rage/combat gate).
-- ============================================================================
assert_lane("FeralFaerieFire fires with the debuff down", "FeralFaerieFire", function() end, true)
assert_lane("FeralFaerieFire fires when about to expire", "FeralFaerieFire",
    function() ff(2) end, true)
assert_lane("FeralFaerieFire blocked while the debuff is healthy", "FeralFaerieFire",
    function() ff(3) end, false)

-- ============================================================================
-- Maul: rage dump at >= 30 rage.
-- ============================================================================
assert_lane("Maul fires at 30 rage", "Maul", function() rage = 30 end, true)
assert_lane("Maul blocked below 30 rage", "Maul", function() rage = 29 end, false)
assert_lane("Maul blocked out of combat", "Maul",
    function() rage = 100; combat = false end, false)

-- ============================================================================
-- Frenzied Regeneration: panic heal at <= 40% hp with >= 10 rage off CD.
-- ============================================================================
assert_lane("FrenziedRegeneration fires at 40% hp with 10 rage", "FrenziedRegeneration",
    function() hp = 40; rage = 10 end, true)
assert_lane("FrenziedRegeneration blocked above 40% hp", "FrenziedRegeneration",
    function() hp = 41; rage = 100 end, false)
assert_lane("FrenziedRegeneration blocked below 10 rage", "FrenziedRegeneration",
    function() hp = 20; rage = 9 end, false)
assert_lane("FrenziedRegeneration blocked while on cooldown", "FrenziedRegeneration",
    function() hp = 20; rage = 100; not_ready[26999] = true end, false)
assert_lane("FrenziedRegeneration blocked out of combat", "FrenziedRegeneration",
    function() hp = 20; rage = 100; combat = false end, false)

-- ============================================================================
-- Survival Instincts: emergency defensive at < 35% hp off CD (2026-09-09
-- guide pass). Real cooldown_remains read on 61336.
-- ============================================================================
assert_lane("SurvivalInstincts fires at 34% hp off cooldown", "SurvivalInstincts",
    function() hp = 34 end, true)
assert_lane("SurvivalInstincts blocked above 35% hp", "SurvivalInstincts",
    function() hp = 35 end, false)
assert_lane("SurvivalInstincts blocked while on cooldown", "SurvivalInstincts",
    function() hp = 20; cds[61336] = 60 end, false)
assert_lane("SurvivalInstincts blocked out of combat", "SurvivalInstincts",
    function() hp = 20; combat = false end, false)

-- ============================================================================
-- Growl (6795): taunt fires only on real evidence the mob is heading
-- elsewhere — threat_pct < 100 AND a readout exists (fail closed, tank_sod
-- idiom). The DSL's nil-coercing "<" would fire on every missing readout.
-- ============================================================================
assert_lane("Growl fires when the mob is heading elsewhere (95 < 100)", "Growl",
    function() rage = 0; threat_pct = 95 end, true)
assert_lane("Growl held while the mob is on the tank (100+)", "Growl",
    function() rage = 0; threat_pct = 100 end, false)
assert_lane("Growl held with NO threat readout (fail closed)", "Growl",
    function() rage = 0; threat_pct = nil end, false)

-- ============================================================================
-- ChallengingRoar (5209): pack-recovery AoE taunt at 3+ targets.
-- ============================================================================
assert_lane("ChallengingRoar fires into a 3-pack", "ChallengingRoar",
    function() enemy_count = 3 end, true)
assert_lane("ChallengingRoar held on a single target", "ChallengingRoar",
    function() enemy_count = 1 end, false)
assert_lane("ChallengingRoar held while on cooldown", "ChallengingRoar",
    function() enemy_count = 3; not_ready[5209] = true end, false)

-- ============================================================================
-- Berserk (50334): bear-side of the feral 51-pt (rage-free abilities 15s).
-- ============================================================================
assert_lane("Berserk fires in combat off cooldown", "Berserk",
    function() rage = 50 end, true)
assert_lane("Berserk held out of combat", "Berserk",
    function() combat = false end, false)

-- ============================================================================
-- Enrage (5229): in-combat rage generation at <= 10 rage (TBC EnrageCombat
-- precedent: starved-tank rage tool).
-- ============================================================================
assert_lane("Enrage fires while rage-starved (10)", "Enrage",
    function() rage = 10 end, true)
assert_lane("Enrage held with rage available", "Enrage",
    function() rage = 30 end, false)

print("PASS test_druid_bear_wotlk_strategies")
