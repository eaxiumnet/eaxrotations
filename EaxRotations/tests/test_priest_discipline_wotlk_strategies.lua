-- test_priest_discipline_wotlk_strategies.lua — Discipline priest WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL discipline_wotlk.lua through its real build_state read
--        path against a friendly-unit model (context.lowest.unit resolved the
--        way main_sylvanas.lua provides it; NS.debuff_up for Weakened Soul 6788
--        on that unit, NS.buff_remains for the Renew 48068 HoT), pinning both
--        sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): discipline had only synthetic
--        pins; these exercise the real Weakened Soul / Renew triage plumbing.
-- SAFETY: Pure unit tests with a mocked NS; the real discipline_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local friendly_hp = 100
local weakened = false
local renew_remains = 0
local mana = 100

local function reset_env()
    friendly_hp, weakened, renew_remains, mana = 100, false, 0, 100
end

local function renew(secs) renew_remains = secs end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 6788 and weakened then return true end
        end
        return false
    end,
    buff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 48068 and renew_remains > 0 then return renew_remains end
        end
        return 0
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/priest/discipline_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "discipline_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local friendly = {
        get_health_percentage = function() return friendly_hp end,
    }
    local ctx = {
        in_combat = true,
        mana_pct = mana,
        enemy_count = 0,
        lowest = { unit = friendly },
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
-- PowerWordShield: fire when the target is free of Weakened Soul.
-- ============================================================================
assert_lane("PWS applies when the target has no Weakened Soul", "PowerWordShield",
    function() end, true)
assert_lane("PWS held while Weakened Soul is up", "PowerWordShield",
    function() weakened = true end, false)

-- ============================================================================
-- Penance / PrayerOfMending: unconditional healer fillers (ungated — pinned
-- as always-match so the pinned order owns the priority).
-- ============================================================================
assert_lane("Penance is ungated (matches any state)", "Penance", function() end, true)
assert_lane("Prayer of Mending is ungated (matches any state)", "PrayerOfMending",
    function() end, true)

-- ============================================================================
-- Renew: HoT refresh at/below 3s on the lowest friendly.
-- ============================================================================
assert_lane("Renew fires when the HoT is down", "Renew", function() end, true)
assert_lane("Renew refreshes at 2.9s remaining", "Renew", function() renew(2.9) end, true)
assert_lane("Renew blocked at the 3.0s boundary", "Renew", function() renew(3) end, false)

-- ============================================================================
-- Direct-heal fillers (2026-09-10 guide-gap lanes): Greater Heal < 50 at
-- mana >= 30, Flash Heal < 70 at mana >= 20 — the mana-gated band after
-- Renew so the shield engine never starves itself.
-- ============================================================================
assert_lane("Greater Heal fires below 50% at 30% mana", "GreaterHeal",
    function() friendly_hp = 49; mana = 30 end, true)
assert_lane("Greater Heal blocked at/above 50%", "GreaterHeal",
    function() friendly_hp = 50; mana = 100 end, false)
assert_lane("Greater Heal blocked below 30% mana", "GreaterHeal",
    function() friendly_hp = 40; mana = 29 end, false)
assert_lane("Flash Heal fires below 70% at 20% mana", "FlashHeal",
    function() friendly_hp = 69; mana = 20 end, true)
assert_lane("Flash Heal blocked at/above 70%", "FlashHeal",
    function() friendly_hp = 70; mana = 100 end, false)
assert_lane("Flash Heal blocked below 20% mana", "FlashHeal",
    function() friendly_hp = 50; mana = 19 end, false)

print("PASS test_priest_discipline_wotlk_strategies")
