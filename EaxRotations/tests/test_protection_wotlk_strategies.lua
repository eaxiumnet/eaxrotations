-- test_protection_wotlk_strategies.lua — Protection WotLK strategy match-gate
-- scenarios.
-- WHAT:  Exercises the protection_wotlk.lua DSL lanes under era-appropriate
--        state: Last Stand emergency band, swing-QUEUED Heroic Strike,
--        need-gated Shield Block (rage economy), Berserker dance for the
--        Berserker-only Pummel, CD/rage gates on the tank core.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): protection_wotlk had only static
--        priority-order coverage; this mirrors the TBC/vanilla strategy suites.
-- SAFETY: Pure unit tests with a mocked NS; the real protection_wotlk.lua loads.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local STANCE = { BATTLE = 1, DEFENSIVE = 2, BERSERKER = 3 }

-- Mutable scenario state.
local stance = STANCE.DEFENSIVE
local hp = 100
local ctx_rage = 0
local enemy_count = 1
local cds = {}
local target_casting = false
local interruptible = true
local tclap_remains = 0
local swing = 999
local shk_cd = 0

local me = {
    get_power = function() return 0 end,
    get_health_percentage = function() return hp end,
    get_stance = function() return stance end,
}

local function mk_target()
    return {
        get_health_percentage = function() return 100 end,
        is_casting = function() return target_casting end,
    }
end

_G.EaxRotations = {
    WarriorSpells = {},
    WarriorConstants = { STANCE = STANCE },
    POWER_RAGE = 1,
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
    buff_up = function() return false end,
    debuff_remains = function(_, ids)
        for _, i in ipairs(ids) do
            if i == 47502 then return tclap_remains end
        end
        return 0
    end,
    cooldown_remains = function(action)
        local id = action and action.id
        if id == 46968 then return shk_cd end
        return cds[id] or 0
    end,
    swing_time_until = function() return swing end,
    is_interruptible = function() return interruptible end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warrior/protection_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "protection_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, mutations, expect_match)
    local save = { stance, hp, ctx_rage, enemy_count, target_casting, interruptible, tclap_remains, swing }
    for k in pairs(cds) do cds[k] = nil end
    shk_cd = 0
    mutations()
    local ctx = {
        in_combat = true, target = mk_target(), settings = {},
        enemy_count = enemy_count, rage = ctx_rage,
    }
    local state = result.build_state(ctx)
    local matched = find_strategy(strategy_name).matches(ctx, state)
    if expect_match then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
    stance, hp, ctx_rage, enemy_count, target_casting, interruptible, tclap_remains, swing =
        save[1], save[2], save[3], save[4], save[5], save[6], save[7], save[8]
end

-- ============================================================================
-- Last Stand: emergency band hp < 30, in combat, cooldown ready.
-- ============================================================================
scenario("Last Stand fires under 30% hp", "LastStand",
    function() hp = 22 end, true)
scenario("Last Stand blocked above the emergency band", "LastStand",
    function() hp = 65 end, false)
scenario("Last Stand blocked while on cooldown", "LastStand",
    function() hp = 15; cds[12975] = 60 end, false)

-- ============================================================================
-- BerserkerStance dance (interrupt): Defensive-living tank dances out when a
-- cast must be interrupted and Pummel is ready; never when nothing to stop.
-- ============================================================================
scenario("tank dances to Berserker for an interrupt", "BerserkerStance",
    function() stance = STANCE.DEFENSIVE; target_casting = true; interruptible = true end, true)
scenario("tank does not dance when target is not casting", "BerserkerStance",
    function() stance = STANCE.DEFENSIVE; target_casting = false end, false)
scenario("tank does not dance when Pummel is on cooldown", "BerserkerStance",
    function() stance = STANCE.DEFENSIVE; target_casting = true; cds[6554] = 12 end, false)
scenario("no dance when already Berserker", "BerserkerStance",
    function() stance = STANCE.BERSERKER; target_casting = true end, false)

-- ============================================================================
-- Pummel: Berserker-only (WotLK), casting + interruptible, rage >= 10.
-- ============================================================================
scenario("Pummel fires in Berserker on a cast", "Pummel",
    function() ctx_rage = 20; stance = STANCE.BERSERKER; target_casting = true end, true)
scenario("Pummel blocked in Defensive (dance first, WotLK)", "Pummel",
    function() ctx_rage = 20; stance = STANCE.DEFENSIVE; target_casting = true end, false)

-- ============================================================================
-- Heroic Strike: swing-QUEUED rage dump (rage >= 30 + auto swing imminent).
-- ============================================================================
scenario("Heroic Strike queues on an imminent swing", "HeroicStrike",
    function() ctx_rage = 40; swing = 0.4 end, true)
scenario("Heroic Strike blocked when the swing is far out", "HeroicStrike",
    function() ctx_rage = 100; swing = 2.5 end, false)
scenario("Heroic Strike blocked below 30 rage", "HeroicStrike",
    function() ctx_rage = 20; swing = 0.4 end, false)

-- ============================================================================
-- Shield Block: 60 rage AND (under pressure OR multi-target) — not spammed.
-- ============================================================================
scenario("Shield Block fires under pressure (hp < 70)", "ShieldBlock",
    function() ctx_rage = 60; hp = 55; enemy_count = 1 end, true)
scenario("Shield Block fires on 2+ enemies at full hp", "ShieldBlock",
    function() ctx_rage = 60; hp = 100; enemy_count = 3 end, true)
scenario("Shield Block blocked at full hp on a single target", "ShieldBlock",
    function() ctx_rage = 100; hp = 100; enemy_count = 1 end, false)
scenario("Shield Block blocked below 60 rage", "ShieldBlock",
    function() ctx_rage = 40; hp = 50; enemy_count = 1 end, false)

-- ============================================================================
-- Shield Slam / Revenge / Devastate / ThunderClap: CD + rage gates.
-- ============================================================================
scenario("Shield Slam fires at 20+ rage off cooldown", "ShieldSlam",
    function() ctx_rage = 30 end, true)
scenario("Shield Slam blocked while on cooldown", "ShieldSlam",
    function() ctx_rage = 100; cds[47488] = 6 end, false)
scenario("Revenge fires at 5+ rage off cooldown", "Revenge",
    function() ctx_rage = 10 end, true)
scenario("Revenge blocked while on cooldown", "Revenge",
    function() ctx_rage = 100; cds[57823] = 5 end, false)
scenario("ThunderClap refreshes when the debuff is fading", "ThunderClap",
    function() ctx_rage = 25; tclap_remains = 1 end, true)
scenario("ThunderClap held while the debuff is fresh", "ThunderClap",
    function() ctx_rage = 25; tclap_remains = 6 end, false)
scenario("Devastate fires at 15+ rage", "Devastate",
    function() ctx_rage = 18 end, true)
scenario("Devastate blocked below 15 rage", "Devastate",
    function() ctx_rage = 10 end, false)

-- ============================================================================
-- Shockwave: 20s CD AoE stun on 2+ enemies at 15+ rage (2026-09-09 guide
-- pass). WotLK lane reads via the internal cd_remaining helper.
-- ============================================================================
scenario("Shockwave fires on 2 enemies at 20 rage", "Shockwave",
    function() ctx_rage = 20; enemy_count = 2 end, true)
scenario("Shockwave blocked single-target", "Shockwave",
    function() ctx_rage = 100; enemy_count = 1 end, false)
scenario("Shockwave blocked below 15 rage", "Shockwave",
    function() ctx_rage = 14; enemy_count = 2 end, false)
scenario("Shockwave blocked while on cooldown", "Shockwave",
    function() ctx_rage = 100; enemy_count = 2; shk_cd = 20 end, false)

print("PASS test_protection_wotlk_strategies")
