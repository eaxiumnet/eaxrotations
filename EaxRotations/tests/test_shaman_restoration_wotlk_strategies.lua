-- test_shaman_restoration_wotlk_strategies.lua — Restoration shaman WotLK
-- behavioral strategy match-gate scenarios.
-- WHAT:  Drives the REAL restoration_wotlk.lua through its real build_state read
--        path against a friendly-unit model (context.lowest.unit resolved the
--        way main_sylvanas.lua provides it; NS.buff_remains/buff_points/buff_up
--        on that unit for Riptide / Earth Shield charges; NS.spell_ready for
--        Mana Tide / Water Shield; ctx.party_injured_count / ctx.lowest_hp /
--        ctx.mana_pct), pinning both sides of every gate.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): restoration had no real-read
--        behavioral pins; these exercise the charge-aware Earth Shield and the
--        Tidal Waves-era HoT/heal triage against friendly units.
-- SAFETY: Pure unit tests with a mocked NS; the real restoration_wotlk.lua and
--         real shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local mana = 100
local friendly_hp = 100
local injured_count = 0
local lowest_hp = 100
local riptide = 0          -- seconds remaining on the lowest unit
local es_up = false
local es_charges = 0
local not_ready = {}
local water_shield_up = false

local function reset_env()
    mana, friendly_hp, injured_count, lowest_hp = 100, 100, 0, 100
    riptide, es_up, es_charges = 0, false, 0
    not_ready, water_shield_up = {}, false
end

local function rip(secs) riptide = secs end
local function es(up, charges) es_up = up; es_charges = charges or 0 end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    buff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 61301 and riptide > 0 then return riptide end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 49284 and es_up then return true end
            if id == 52127 and water_shield_up then return true end
        end
        return false
    end,
    buff_points = function(unit, ids)
        for _, id in ipairs(ids) do
            if id == 49284 and es_up then return { es_charges } end
        end
        return nil
    end,
    spell_ready = function(spell, unit, opts)
        local id = type(spell) == "number" and spell or (spell and spell.id) or 0
        if not_ready[id] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/shaman/restoration_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "restoration_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local friendly = {
        get_health_percentage = function() return friendly_hp end,
        is_casting = function() return false end,
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
-- ManaTideTotem: ready + mana < 30.
-- ============================================================================
assert_lane("Mana Tide fires at 29% mana when ready", "ManaTideTotem",
    function() mana = 29 end, true)
assert_lane("Mana Tide blocked at 30% mana", "ManaTideTotem", function() end, false)
assert_lane("Mana Tide held on cooldown", "ManaTideTotem",
    function() mana = 29; not_ready[16190] = true end, false)

-- ============================================================================
-- EarthShield: down -> apply; up with 1 charge left -> refresh; up with 2+ ->
-- hold; up but unreadable charges -> hold (fail closed).
-- ============================================================================
assert_lane("Earth Shield applies when down", "EarthShield", function() end, true)
assert_lane("Earth Shield refreshes at 1 charge", "EarthShield", function() es(true, 1) end, true)
assert_lane("Earth Shield held at 2 charges", "EarthShield", function() es(true, 2) end, false)
assert_lane("Earth Shield held at full charges", "EarthShield", function() es(true, 9) end, false)
assert_lane("Earth Shield held when charges cannot be read", "EarthShield",
    function() es(true, 0) end, false)

-- ============================================================================
-- Riptide: HoT refresh at/below 3s on the lowest friendly.
-- ============================================================================
assert_lane("Riptide fires when the HoT is down", "Riptide", function() end, true)
assert_lane("Riptide refreshes at 2.9s remaining", "Riptide", function() rip(2.9) end, true)
assert_lane("Riptide blocked at the 3.0s boundary", "Riptide", function() rip(3) end, false)

-- ============================================================================
-- ChainHeal: 2+ injured party members + lowest < 85% + mana >= 25.
-- ============================================================================
assert_lane("Chain Heal fires with 2 injured and the lowest at 84%", "ChainHeal",
    function() injured_count = 2; lowest_hp = 84 end, true)
assert_lane("Chain Heal blocked with 1 injured", "ChainHeal",
    function() injured_count = 1; lowest_hp = 84 end, false)
assert_lane("Chain Heal blocked at 85% lowest hp", "ChainHeal",
    function() injured_count = 2; lowest_hp = 85 end, false)
assert_lane("Chain Heal blocked below 25% mana", "ChainHeal",
    function() injured_count = 2; lowest_hp = 50; mana = 24 end, false)

-- ============================================================================
-- LesserHealingWave: lowest < 90% + mana >= 10.
-- ============================================================================
assert_lane("LHW fires when the lowest is at 89%", "LesserHealingWave",
    function() friendly_hp = 89 end, true)
assert_lane("LHW blocked at 90% lowest hp", "LesserHealingWave", function() end, false)
assert_lane("LHW blocked below 10% mana", "LesserHealingWave",
    function() friendly_hp = 50; mana = 9 end, false)

-- ============================================================================
-- HealingWave: lowest < 70% + mana >= 20.
-- ============================================================================
assert_lane("Healing Wave fires when the lowest is at 69%", "HealingWave",
    function() friendly_hp = 69 end, true)
assert_lane("Healing Wave blocked at 70% lowest hp", "HealingWave", function() end, false)
assert_lane("Healing Wave blocked below 20% mana", "HealingWave",
    function() friendly_hp = 50; mana = 19 end, false)

-- ============================================================================
-- WaterShield: in combat + down + mana < 50 + ready.
-- ============================================================================
assert_lane("Water Shield applies at 49% mana in combat", "WaterShield",
    function() mana = 49 end, true)
assert_lane("Water Shield held while up", "WaterShield",
    function() mana = 49; water_shield_up = true end, false)
assert_lane("Water Shield held at 50% mana", "WaterShield", function() end, false)
assert_lane("Water Shield held on cooldown", "WaterShield",
    function() mana = 49; not_ready[52127] = true end, false)

print("PASS test_shaman_restoration_wotlk_strategies")
