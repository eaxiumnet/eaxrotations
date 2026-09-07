-- test_warrior_leveling_wotlk_strategies.lua — Warrior leveling WotLK strategy
-- match-gate scenarios.
-- WHAT:  Exercises the leveling_wotlk.lua DSL lanes under era-appropriate
--        state: OOC stance/shout setup, Charge 8-25 yd range, proc-gated
--        Victory Rush + Overpower (dodge window), execute-range, hit-volume
--        AoE gates, Rend maintenance, rage dump.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): the leveling file had only static
--        DSL-order coverage — its proc/range/AoE gates were never pinned to
--        fire/dodge behavior.
-- SAFETY: Pure unit tests with a mocked NS; the real leveling_wotlk.lua loads.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Mutable scenario state.
local stance = STANCE.BATTLE
local ctx_rage = 0
local target_hp = 100
local distance = 0
local cds = {}
local buffs = {}
local rend_remains = 0
local target_casting = false
local interruptible = true
local dodge = 0
local aoe_self = false
local aoe_target = false

local me = {
    get_power = function() return 0 end,
    get_stance = function() return stance end,
}

local function mk_target()
    return {
        get_health_percentage = function() return target_hp end,
        is_casting = function() return target_casting end,
        get_dodge_chance = function() return dodge end,
    }
end

_G.EaxRotations = {
    WarriorSpells = {},
    WarriorConstants = { STANCE = STANCE },
    POWER_RAGE = 1,
    AOE_RADIUS = { SELF_8 = 8, TARGET_8 = 8 },
    PLAYER_UNIT = {},
    me = me,
    GetPlayer = function() return me end,
    spell_action = function(rank_ids, label)
        local id = type(rank_ids) == "table" and rank_ids[1] or rank_ids
        return {
            id = id,
            ids = type(rank_ids) == "table" and rank_ids or { rank_ids },
            name = label or tostring(id),
        }
    end,
    buff_up = function(_, ids)
        for _, i in ipairs(ids) do if buffs[i] then return true end end
        return false
    end,
    debuff_remains = function(_, ids)
        for _, i in ipairs(ids) do
            if i == 47465 then return rend_remains end
        end
        return 0
    end,
    cooldown_remains = function(action) return cds[action and action.id] or 0 end,
    is_interruptible = function() return interruptible end,
    aoe_self_meets = function() return aoe_self end,
    aoe_target_meets = function() return aoe_target end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warrior/leveling_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "leveling_wotlk strategies should load")

-- leveling_wotlk.lua installs the real hit-volume helpers onto NS at load
-- (aoe_hit_volume_sylvanas.install overwrites aoe_self/target_meets with the
-- vec2/vec3 geometry reads), which would shadow the scenario knobs below.
-- Re-bind the scenario-driven closures AFTER the file loads.
_G.EaxRotations.aoe_self_meets = function() return aoe_self end
_G.EaxRotations.aoe_target_meets = function() return aoe_target end

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, mutations, expect_match, in_combat)
    local save = { stance, ctx_rage, target_hp, distance, target_casting, interruptible,
                   dodge, aoe_self, aoe_target, rend_remains }
    for k in pairs(cds) do cds[k] = nil end
    for k in pairs(buffs) do buffs[k] = nil end
    mutations()
    local combat = in_combat ~= false
    local ctx = {
        in_combat = combat, target = mk_target(), settings = {},
        enemy_count = 1, rage = ctx_rage, target_distance = distance,
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect_match then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
    stance, ctx_rage, target_hp, distance, target_casting, interruptible,
        dodge, aoe_self, aoe_target, rend_remains =
        save[1], save[2], save[3], save[4], save[5], save[6],
        save[7], save[8], save[9], save[10]
end

-- ============================================================================
-- OOC setup: Battle Stance + Battle Shout only out of combat.
-- ============================================================================
scenario("enters Battle Stance OOC when in another stance", "BattleStance",
    function() stance = STANCE.BERSERKER end, true, false)
scenario("stays in Battle Stance (already there)", "BattleStance",
    function() stance = STANCE.BATTLE end, false, false)
scenario("does not stance-swap in combat", "BattleStance",
    function() stance = STANCE.BERSERKER end, false, true)
scenario("Battle Shout fires OOC with the buff down", "BattleShout",
    function() buffs[47436] = nil end, true, false)
scenario("Battle Shout held while the buff is up", "BattleShout",
    function() buffs[47436] = true end, false, false)

-- ============================================================================
-- Charge: 8-25 yd gap-closer, out of combat only.
-- ============================================================================
scenario("Charge fires at 15 yd OOC", "Charge",
    function() distance = 15 end, true, false)
scenario("Charge blocked in melee range", "Charge",
    function() distance = 5 end, false, false)
scenario("Charge blocked beyond 25 yd", "Charge",
    function() distance = 30 end, false, false)
scenario("Charge blocked in combat", "Charge",
    function() distance = 15 end, false, true)

-- ============================================================================
-- Proc-gated lanes: Victory Rush (killing-blow proc) / Overpower (dodge).
-- ============================================================================
scenario("Victory Rush fires on the killing-blow proc", "VictoryRush",
    function() buffs[34428] = true end, true)
scenario("Victory Rush blocked without the proc", "VictoryRush",
    function() end, false)
scenario("Overpower fires in Battle stance on a dodge", "Overpower",
    function() ctx_rage = 10; stance = STANCE.BATTLE; dodge = 12 end, true)
scenario("Overpower blocked when the target never dodged", "Overpower",
    function() ctx_rage = 10; stance = STANCE.BATTLE; dodge = 0 end, false)
scenario("Overpower blocked outside Battle stance", "Overpower",
    function() ctx_rage = 10; stance = STANCE.DEFENSIVE; dodge = 12 end, false)

-- ============================================================================
-- Execute range (WotLK cost 15).
-- ============================================================================
scenario("Execute fires under 20% with 15+ rage", "Execute",
    function() ctx_rage = 20; target_hp = 10 end, true)
scenario("Execute blocked above 20%", "Execute",
    function() ctx_rage = 100; target_hp = 40 end, false)
scenario("Execute blocked below 15 rage", "Execute",
    function() ctx_rage = 10; target_hp = 5 end, false)

-- ============================================================================
-- Hit-volume AoE gates: ThunderClap / Whirlwind (self 8 yd), Cleave (target).
-- ============================================================================
scenario("ThunderClap fires on 2+ nearby enemies", "ThunderClap",
    function() ctx_rage = 25; aoe_self = true end, true)
scenario("ThunderClap blocked on a single target", "ThunderClap",
    function() ctx_rage = 25; aoe_self = false end, false)
scenario("Whirlwind fires on 2+ nearby enemies", "Whirlwind",
    function() ctx_rage = 30; aoe_self = true end, true)
scenario("Whirlwind blocked on a single target", "Whirlwind",
    function() ctx_rage = 30; aoe_self = false end, false)
scenario("Cleave fires with 2+ targets in front", "Cleave",
    function() ctx_rage = 25; aoe_target = true end, true)
scenario("Cleave blocked on a single target", "Cleave",
    function() ctx_rage = 25; aoe_target = false end, false)

-- ============================================================================
-- Rend maintenance + Heroic Strike rage dump + interrupt lane.
-- ============================================================================
scenario("Rend refreshes when the bleed is fading", "Rend",
    function() ctx_rage = 15; rend_remains = 1 end, true)
scenario("Rend held while the bleed is fresh", "Rend",
    function() ctx_rage = 15; rend_remains = 8 end, false)
scenario("Heroic Strike dumps at 30+ rage", "HeroicStrike",
    function() ctx_rage = 35 end, true)
scenario("Heroic Strike held below 30 rage", "HeroicStrike",
    function() ctx_rage = 20 end, false)
scenario("Pummel fires on a cast at 10+ rage", "Pummel",
    function() ctx_rage = 15; target_casting = true; interruptible = true end, true)
scenario("Pummel blocked when the target is not casting", "Pummel",
    function() ctx_rage = 15; target_casting = false end, false)

print("PASS test_warrior_leveling_wotlk_strategies")
