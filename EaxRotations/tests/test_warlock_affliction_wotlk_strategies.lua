-- test_warlock_affliction_wotlk_strategies.lua — Affliction warlock WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL affliction_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for the UA 47843 / Corruption 47813 / CoA
--        47864 / Haunt 59164 debuffs, ctx.target_hp for DrainSoul, ctx.hp /
--        ctx.mana_pct for the LifeTap sustain gate), pinning both sides of
--        every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): affliction had only static DSL
--        coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real affliction_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local target_hp = 100
local hp = 100
local mana = 100
local debuffs = {}

local function set(secs) debuffs[1] = secs end
local function ua(secs) debuffs[47843] = secs end
local function corr(secs) debuffs[47813] = secs end
local function agony(secs) debuffs[47864] = secs end
local function haunt(secs) debuffs[59164] = secs end

local function reset_env()
    combat, target_hp, hp, mana = true, 100, 100, 100
    debuffs = {}
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
    buff_up = function() return false end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/affliction_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "affliction_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        mana_pct = mana,
        hp = hp,
        target_hp = target_hp,
        enemy_count = 1,
        target = { is_casting = function() return false end },
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
-- Haunt: refresh at/below 3s.
-- ============================================================================
assert_lane("Haunt refreshes when the debuff is down", "Haunt", function() end, true)
assert_lane("Haunt refreshes at 2.9s remaining", "Haunt", function() haunt(2.9) end, true)
assert_lane("Haunt blocked at the 3.0s boundary", "Haunt", function() haunt(3) end, false)
assert_lane("Haunt blocked while the debuff is healthy", "Haunt", function() haunt(3.1) end, false)

-- ============================================================================
-- Corruption: refresh at/below 3s.
-- ============================================================================
assert_lane("Corruption refreshes when the debuff is down", "Corruption", function() end, true)
assert_lane("Corruption refreshes at 2.9s remaining", "Corruption", function() corr(2.9) end, true)
assert_lane("Corruption blocked at the 3.0s boundary", "Corruption", function() corr(3) end, false)
assert_lane("Corruption blocked while the debuff is healthy", "Corruption", function() corr(3.1) end, false)

-- ============================================================================
-- UnstableAffliction: refresh at/below 3s.
-- ============================================================================
assert_lane("UA refreshes when the debuff is down", "UnstableAffliction", function() end, true)
assert_lane("UA refreshes at 2.9s remaining", "UnstableAffliction", function() ua(2.9) end, true)
assert_lane("UA blocked at the 3.0s boundary", "UnstableAffliction", function() ua(3) end, false)
assert_lane("UA blocked while the debuff is healthy", "UnstableAffliction", function() ua(3.1) end, false)

-- ============================================================================
-- CurseOfAgony: refresh at/below 3s.
-- ============================================================================
assert_lane("CoA refreshes when the debuff is down", "CurseOfAgony", function() end, true)
assert_lane("CoA refreshes at 2.9s remaining", "CurseOfAgony", function() agony(2.9) end, true)
assert_lane("CoA blocked at the 3.0s boundary", "CurseOfAgony", function() agony(3) end, false)
assert_lane("CoA blocked while the debuff is healthy", "CurseOfAgony", function() agony(3.1) end, false)

-- ============================================================================
-- DrainSoul: execute band at target hp < 25 (no combat gate in this file).
-- ============================================================================
assert_lane("DrainSoul fires below 25% target hp", "DrainSoul", function() target_hp = 24 end, true)
assert_lane("DrainSoul blocked at 25% target hp", "DrainSoul", function() target_hp = 25 end, false)
assert_lane("DrainSoul blocked on a healthy target", "DrainSoul", function() end, false)

-- ============================================================================
-- ShadowBolt: filler at >= 20% mana.
-- ============================================================================
assert_lane("ShadowBolt fires at 20% mana", "ShadowBolt", function() mana = 20 end, true)
assert_lane("ShadowBolt blocked below 20% mana", "ShadowBolt", function() mana = 19 end, false)

-- ============================================================================
-- LifeTap: in combat + mana < 40 + hp > 50 (sustain, appended after fillers).
-- ============================================================================
assert_lane("LifeTap fires when mana drops to 39 with hp healthy", "LifeTap",
    function() mana = 39 end, true)
assert_lane("LifeTap fires at 1% mana with hp healthy", "LifeTap",
    function() mana = 1 end, true)
assert_lane("LifeTap blocked at 40% mana", "LifeTap", function() mana = 40 end, false)
assert_lane("LifeTap blocked when hp is at the 50 floor", "LifeTap",
    function() mana = 30; hp = 50 end, false)
assert_lane("LifeTap blocked below the hp floor", "LifeTap",
    function() mana = 30; hp = 49 end, false)
assert_lane("LifeTap blocked out of combat", "LifeTap",
    function() mana = 30; combat = false end, false)

print("PASS test_warlock_affliction_wotlk_strategies")
