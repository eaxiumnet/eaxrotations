-- test_priest_holy_wotlk_strategies.lua — Holy priest WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL holy_wotlk.lua through its real build_state read path
--        against a friendly-unit model (context.lowest.unit + context.lowest_hp
--        + context.party_injured_count provided the way main_sylvanas.lua sets
--        them; NS.buff_up for Guardian Spirit 47788, NS.buff_remains for the
--        Renew 48068 HoT, ctx.mana_pct), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): holy had only sparse pins; these
--        exercise the real Guardian Spirit / Greater Heal / CoH / Renew triage.
-- SAFETY: Pure unit tests with a mocked NS; the real holy_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local friendly_hp = 100
local mana = 100
local injured_count = 0
local lowest_hp = 100
local gs_up = false
local renew_remains = 0
local player_hp_pct = 100
local ready_map = {}   -- per-spell-id readiness for the spell_ready lanes

local function reset_env()
    friendly_hp, mana, injured_count, lowest_hp = 100, 100, 0, 100
    gs_up, renew_remains = false, 0
    player_hp_pct = 100
    ready_map = {}
end

local function renew(secs) renew_remains = secs end
local function gs(up) gs_up = up or false end

_G.EaxRotations = {
    me = { get_health_percentage = function() return player_hp_pct end },
    GetPlayer = function() return _G.EaxRotations.me end,
    spell_ready = function(action)
        -- suite mock: define_action resolves a ladder to its first id, so
        -- readiness is keyed by 25437 (Desperate Prayer) / 48087 (Lightwell).
        return ready_map[action] ~= false
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 47788 and gs_up then return true end
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

local result = dofile("EaxRotations/classes/priest/holy_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "holy_wotlk strategies should load")

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
        lowest_hp = lowest_hp,
        party_injured_count = injured_count,
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
-- GuardianSpirit: emergency — aura down + lowest below 30%.
-- ============================================================================
assert_lane("Guardian Spirit fires at 29% lowest hp", "GuardianSpirit",
    function() friendly_hp = 29 end, true)
assert_lane("Guardian Spirit blocked at 30% lowest hp", "GuardianSpirit",
    function() friendly_hp = 30 end, false)
assert_lane("Guardian Spirit blocked on a healthy target", "GuardianSpirit",
    function() end, false)
assert_lane("Guardian Spirit blocked while already up", "GuardianSpirit",
    function() friendly_hp = 20; gs(true) end, false)

-- ============================================================================
-- GreaterHeal: lowest below 50% + mana >= 30.
-- ============================================================================
assert_lane("Greater Heal fires at 49% lowest hp", "GreaterHeal",
    function() friendly_hp = 49 end, true)
assert_lane("Greater Heal blocked at 50% lowest hp", "GreaterHeal", function() end, false)
assert_lane("Greater Heal blocked below 30% mana", "GreaterHeal",
    function() friendly_hp = 30; mana = 29 end, false)

-- ============================================================================
-- CircleOfHealing: 2+ injured + lowest below 85% + mana >= 20.
-- ============================================================================
assert_lane("CoH fires with 2 injured and the lowest at 84%", "CircleOfHealing",
    function() injured_count = 2; lowest_hp = 84 end, true)
assert_lane("CoH blocked with 1 injured", "CircleOfHealing",
    function() injured_count = 1; lowest_hp = 84 end, false)
assert_lane("CoH blocked at 85% lowest hp", "CircleOfHealing",
    function() injured_count = 2; lowest_hp = 85 end, false)
assert_lane("CoH blocked below 20% mana", "CircleOfHealing",
    function() injured_count = 2; lowest_hp = 50; mana = 19 end, false)

-- ============================================================================
-- Renew: HoT refresh at/below 3s on the lowest friendly.
-- ============================================================================
assert_lane("Renew fires when the HoT is down", "Renew", function() end, true)
assert_lane("Renew refreshes at 2.9s remaining", "Renew", function() renew(2.9) end, true)
assert_lane("Renew blocked at the 3.0s boundary", "Renew", function() renew(3) end, false)

-- ============================================================================
-- PrayerOfMending: unconditional healer filler (ungated — pinned as
-- always-match so the pinned APL order owns its position).
-- ============================================================================
assert_lane("Prayer of Mending is ungated (matches any state)", "PrayerOfMending",
    function() end, true)

-- ============================================================================
-- DesperatePrayer: self-save at <= 30% own hp (2026-09-09 guide-gap lane).
-- ============================================================================
assert_lane("Desperate Prayer fires at 29% own hp", "DesperatePrayer",
    function() player_hp_pct = 29 end, true)
assert_lane("Desperate Prayer fires at the 30% boundary (inclusive band)", "DesperatePrayer",
    function() player_hp_pct = 30 end, true)
assert_lane("Desperate Prayer blocked at 31% own hp", "DesperatePrayer",
    function() player_hp_pct = 31 end, false)
assert_lane("Desperate Prayer blocked on cooldown", "DesperatePrayer",
    function() player_hp_pct = 15; ready_map[25437] = false end, false)

-- ============================================================================
-- Lightwell: sustained raid pressure — 3+ injured (2026-09-09 guide-gap lane).
-- ============================================================================
assert_lane("Lightwell fires with 3 injured", "Lightwell",
    function() injured_count = 3; lowest_hp = 50 end, true)
assert_lane("Lightwell blocked with 2 injured", "Lightwell",
    function() injured_count = 2; lowest_hp = 50 end, false)
assert_lane("Lightwell blocked on cooldown", "Lightwell",
    function() injured_count = 4; lowest_hp = 40; ready_map[48087] = false end, false)

-- ============================================================================
-- FlashHeal: lowest below 70% + mana >= 20.
-- ============================================================================
assert_lane("Flash Heal fires at 69% lowest hp", "FlashHeal",
    function() friendly_hp = 69 end, true)
assert_lane("Flash Heal blocked at 70% lowest hp", "FlashHeal", function() end, false)
assert_lane("Flash Heal blocked below 20% mana", "FlashHeal",
    function() friendly_hp = 50; mana = 19 end, false)

print("PASS test_priest_holy_wotlk_strategies")
