-- test_druid_cat_wotlk_strategies.lua — Feral cat druid WotLK behavioral
-- strategy match-gate scenarios.
-- WHAT:  Drives the REAL cat_wotlk.lua through its real build_state read path
--        (ctx.energy/combo_points, NS.debuff_remains for Rake / Rip / Mangle /
--        Faerie Fire, NS.buff_remains for Savage Roar, NS.buff_up for the
--        Omen of Clarity and Tiger's Fury auras, ctx.is_behind / ctx.is_stealthed,
--        and real NS.spell_ready for the Tiger's Fury / Berserk CD gates),
--        pinning both sides of every lane.
-- WHEN:  During WotLK test suite execution (run_wotlk_tests.lua) and the
--        rotation battery (run_rotation_tests.lua).
-- WHY:   WotLK era-content pass (2026-09-06): druid cat had zero behavioral
--        coverage (only a static priority-order suite); every lane here is a
--        first behavioral pin.
-- SAFETY: Pure unit tests with a mocked NS; the real cat_wotlk.lua and real
--         shared modules load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

local thp = 100
local energy = 0
local cp = 0
local combat = true
local behind = false
local stealthed = false
local debuffs = {}
local buff_remains_map = {}
local buffs = {}
local not_ready = {}   -- spell ids on cooldown (NS.spell_ready false)

local function rake(secs) debuffs[48574] = secs end
local function rip(secs) debuffs[49800] = secs end
local function ff(secs) debuffs[27011] = secs end
local function mangle(secs) debuffs[48566] = secs end
local function savage_roar(secs) buff_remains_map[52610] = secs end
local function set_buff(id, up) buffs[id] = up or nil end

local function reset_env()
    thp, energy, cp = 100, 0, 0
    combat, behind, stealthed = true, false, false
    debuffs, buff_remains_map, buffs, not_ready = {}, {}, {}, {}
end

_G.EaxRotations = {
    me = { get_health_percentage = function() return 100 end },
    GetPlayer = function() return _G.EaxRotations.me end,
    debuff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if debuffs[id] then return debuffs[id] end
        end
        return 0
    end,
    buff_remains = function(unit, ids)
        for _, id in ipairs(ids) do
            if buff_remains_map[id] then return buff_remains_map[id] end
        end
        return 0
    end,
    buff_up = function(unit, ids)
        for _, id in ipairs(ids) do
            if buffs[id] then return true end
        end
        return false
    end,
    spell_ready = function(spell, target)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1]))
        if not_ready[id] then return false end
        return true
    end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/druid/cat_wotlk.lua")
local strategies = result.strategies
assert_true(strategies, "cat_wotlk strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local function scenario(label, strategy_name, expect)
    local ctx = {
        in_combat = combat,
        energy = energy,
        combo_points = cp,
        is_behind = behind,
        is_stealthed = stealthed,
        target = { get_health_percentage = function() return thp end },
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
-- Faerie Fire (Feral): combat + armor debuff refresh under 3s.
-- ============================================================================
assert_lane("FaerieFireFeral fires when the debuff is down", "FaerieFireFeral", function() end, true)
assert_lane("FaerieFireFeral fires when about to expire", "FaerieFireFeral",
    function() ff(2) end, true)
assert_lane("FaerieFireFeral blocked while the debuff is healthy", "FaerieFireFeral",
    function() ff(3) end, false)
assert_lane("FaerieFireFeral blocked out of combat", "FaerieFireFeral",
    function() combat = false end, false)

-- ============================================================================
-- Ravage: stealth opener — stealthed + behind + >= 60 energy.
-- ============================================================================
assert_lane("Ravage fires stealthed behind the target", "Ravage",
    function() stealthed = true; behind = true; energy = 60 end, true)
assert_lane("Ravage blocked when not stealthed", "Ravage",
    function() stealthed = false; behind = true; energy = 100 end, false)
assert_lane("Ravage blocked in front of the target", "Ravage",
    function() stealthed = true; behind = false; energy = 100 end, false)
assert_lane("Ravage blocked below 60 energy", "Ravage",
    function() stealthed = true; behind = true; energy = 59 end, false)

-- ============================================================================
-- Tiger's Fury: CD + energy-fit + never preempt a 5-CP finisher.
-- ============================================================================
assert_lane("TigersFury fires at 40 energy below 5 CP", "TigersFury",
    function() energy = 40; cp = 4 end, true)
assert_lane("TigersFury blocked above 40 energy", "TigersFury",
    function() energy = 41; cp = 4 end, false)
assert_lane("TigersFury blocked at 5 combo points (finisher protection)", "TigersFury",
    function() energy = 0; cp = 5 end, false)
assert_lane("TigersFury blocked while the buff is already up", "TigersFury",
    function() set_buff(48479, true); energy = 0 end, false)
assert_lane("TigersFury blocked while on cooldown", "TigersFury",
    function() energy = 0; cp = 4; not_ready[48479] = true end, false)

-- ============================================================================
-- Berserk: CD window, never during a 5-CP finisher.
-- ============================================================================
assert_lane("Berserk fires below 5 CP", "Berserk", function() cp = 4 end, true)
assert_lane("Berserk blocked at 5 combo points", "Berserk",
    function() cp = 5 end, false)
assert_lane("Berserk blocked while on cooldown", "Berserk",
    function() cp = 0; not_ready[50334] = true end, false)

-- ============================================================================
-- Savage Roar: 5-CP finisher refresh under 3s.
-- ============================================================================
assert_lane("SavageRoar fires at 5 CP with the buff down", "SavageRoar",
    function() cp = 5; savage_roar(0) end, true)
assert_lane("SavageRoar fires just before the 3s boundary", "SavageRoar",
    function() cp = 5; savage_roar(2) end, true)
assert_lane("SavageRoar blocked at 4 combo points", "SavageRoar",
    function() cp = 4; savage_roar(0) end, false)
assert_lane("SavageRoar blocked while the buff is healthy", "SavageRoar",
    function() cp = 5; savage_roar(3) end, false)

-- ============================================================================
-- Rip: 5-CP bleed finisher refresh under 3s.
-- ============================================================================
assert_lane("Rip fires at 5 CP with the bleed down", "Rip",
    function() cp = 5; rip(0) end, true)
assert_lane("Rip blocked at 4 combo points", "Rip",
    function() cp = 4; rip(0) end, false)
assert_lane("Rip blocked while the bleed is healthy", "Rip",
    function() cp = 5; rip(3) end, false)

-- ============================================================================
-- Ferocious Bite: 5-CP dump in the execute band (<25%) OR when Rip and Savage
-- Roar are both healthy (CP banked otherwise).
-- ============================================================================
assert_lane("FerociousBite fires in the execute band", "FerociousBite",
    function() cp = 5; thp = 24 end, true)
assert_lane("FerociousBite fires above the band when Rip and Roar are healthy", "FerociousBite",
    function() cp = 5; thp = 50; rip(10); savage_roar(10) end, true)
assert_lane("FerociousBite blocked above the band with Rip expiring", "FerociousBite",
    function() cp = 5; thp = 50; rip(2); savage_roar(10) end, false)
assert_lane("FerociousBite blocked above the band with Savage Roar expiring", "FerociousBite",
    function() cp = 5; thp = 50; rip(10); savage_roar(2) end, false)
assert_lane("FerociousBite blocked at 4 combo points in the execute band", "FerociousBite",
    function() cp = 4; thp = 10 end, false)

-- ============================================================================
-- Mangle (Cat): bleed-vulnerability debuff refresh at >= 45 energy.
-- ============================================================================
assert_lane("MangleCat fires with the debuff down at 45 energy", "MangleCat",
    function() energy = 45; mangle(0) end, true)
assert_lane("MangleCat blocked below 45 energy", "MangleCat",
    function() energy = 44; mangle(0) end, false)
assert_lane("MangleCat blocked while the debuff is healthy", "MangleCat",
    function() energy = 100; mangle(3) end, false)

-- ============================================================================
-- Rake: bleed refresh under 3s at >= 40 energy.
-- ============================================================================
assert_lane("Rake fires with the bleed down at 40 energy", "Rake",
    function() energy = 40; rake(0) end, true)
assert_lane("Rake blocked below 40 energy", "Rake",
    function() energy = 39; rake(0) end, false)
assert_lane("Rake blocked while the bleed is healthy", "Rake",
    function() energy = 100; rake(3) end, false)

-- ============================================================================
-- Shred: behind the target at >= 50 energy.
-- ============================================================================
assert_lane("Shred fires behind the target at 50 energy", "Shred",
    function() behind = true; energy = 50 end, true)
assert_lane("Shred blocked in front of the target", "Shred",
    function() behind = false; energy = 100 end, false)
assert_lane("Shred blocked below 50 energy", "Shred",
    function() behind = true; energy = 49 end, false)

-- ============================================================================
-- Shred (Omen of Clarity): free proc Shred below 5 CP.
-- ============================================================================
assert_lane("ShredOmen fires on an Omen proc behind the target", "ShredOmen",
    function() set_buff(16864, true); behind = true; cp = 4 end, true)
assert_lane("ShredOmen blocked without the proc", "ShredOmen",
    function() set_buff(16864, false); behind = true; cp = 4 end, false)
assert_lane("ShredOmen blocked at 5 combo points", "ShredOmen",
    function() set_buff(16864, true); behind = true; cp = 5 end, false)
assert_lane("ShredOmen blocked in front of the target", "ShredOmen",
    function() set_buff(16864, true); behind = false; cp = 4 end, false)

print("PASS test_druid_cat_wotlk_strategies")
