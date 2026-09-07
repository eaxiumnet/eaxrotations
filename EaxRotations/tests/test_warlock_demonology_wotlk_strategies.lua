-- test_warlock_demonology_wotlk_strategies.lua — Demonology warlock WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL demonology_wotlk.lua through its real build_state read
--        path (NS.debuff_remains for Corruption 47813 / Immolate 47811,
--        NS.buff_up for the 47241 Metamorphosis aura, ctx.mana_pct / ctx.hp for
--        SoulFire/ShadowBolt/LifeTap, ctx.in_combat and NS.should_use_long_cd
--        for the Metamorphosis long-CD gate), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): demonology had only static DSL
--        coverage; these are real-read behavioral pins.
-- SAFETY: Pure unit tests with a mocked NS; the real demonology_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local combat = true
local hp = 100
local mana = 100
local debuffs = {}
local buffs = {}
local long_cd_refused = {}

local function corr(secs) debuffs[47813] = secs end
local function immo(secs) debuffs[47811] = secs end
local function meta(up) buffs[47241] = up or nil end

local function reset_env()
    combat, hp, mana = true, 100, 100
    debuffs, buffs, long_cd_refused = {}, {}, {}
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
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    should_use_long_cd = function(context, seconds)
        if long_cd_refused[seconds] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/warlock/demonology_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "demonology_wotlk strategies should load")

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
-- Metamorphosis: in combat + aura down + long-CD (180s) permitted.
-- ============================================================================
assert_lane("Metamorphosis fires in combat when down", "Metamorphosis", function() end, true)
assert_lane("Metamorphosis blocked while transformed", "Metamorphosis", function() meta(true) end, false)
assert_lane("Metamorphosis blocked out of combat", "Metamorphosis", function() combat = false end, false)
assert_lane("Metamorphosis blocked when long CDs are refused", "Metamorphosis",
    function() long_cd_refused[180] = true end, false)

-- ============================================================================
-- Corruption: refresh at/below 3s (no combat gate in this file).
-- ============================================================================
assert_lane("Corruption refreshes when the debuff is down", "Corruption", function() end, true)
assert_lane("Corruption refreshes at 2.9s remaining", "Corruption", function() corr(2.9) end, true)
assert_lane("Corruption blocked at the 3.0s boundary", "Corruption", function() corr(3) end, false)
assert_lane("Corruption blocked while the debuff is healthy", "Corruption", function() corr(3.1) end, false)

-- ============================================================================
-- Immolate: refresh at/below 3s.
-- ============================================================================
assert_lane("Immolate refreshes when the debuff is down", "Immolate", function() end, true)
assert_lane("Immolate refreshes at 2.9s remaining", "Immolate", function() immo(2.9) end, true)
assert_lane("Immolate blocked at the 3.0s boundary", "Immolate", function() immo(3) end, false)
assert_lane("Immolate blocked while the debuff is healthy", "Immolate", function() immo(3.1) end, false)

-- ============================================================================
-- SoulFire: >= 30% mana.
-- ============================================================================
assert_lane("SoulFire fires at 30% mana", "SoulFire", function() mana = 30 end, true)
assert_lane("SoulFire blocked below 30% mana", "SoulFire", function() mana = 29 end, false)

-- ============================================================================
-- ShadowBolt: filler at >= 20% mana.
-- ============================================================================
assert_lane("ShadowBolt fires at 20% mana", "ShadowBolt", function() mana = 20 end, true)
assert_lane("ShadowBolt blocked below 20% mana", "ShadowBolt", function() mana = 19 end, false)

-- ============================================================================
-- LifeTap: in combat + mana < 65 + hp > 55 (sustain, appended after fillers).
-- ============================================================================
assert_lane("LifeTap fires when mana drops below 65 with hp healthy", "LifeTap",
    function() mana = 64 end, true)
assert_lane("LifeTap blocked at 65% mana", "LifeTap", function() mana = 65 end, false)
assert_lane("LifeTap blocked when hp is at the 55 floor", "LifeTap",
    function() mana = 50; hp = 55 end, false)
assert_lane("LifeTap blocked below the hp floor", "LifeTap",
    function() mana = 50; hp = 54 end, false)
assert_lane("LifeTap blocked out of combat", "LifeTap",
    function() mana = 50; combat = false end, false)

print("PASS test_warlock_demonology_wotlk_strategies")
