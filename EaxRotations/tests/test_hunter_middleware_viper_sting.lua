-- test_hunter_middleware_viper_sting.lua — Hunter class-middleware Viper Sting
-- behavioral match-gate scenarios.
-- WHAT:  Proves the stings claim in the BM spec comments: Viper Sting is handled
--        by the hunter class middleware (hunter/middleware_sylvanas.lua), not by
--        the BM rotation. Loads the REAL middleware, captures the strategies it
--        registers via NS.register_class_middleware("hunter", ...), and pins
--        both sides of the ViperSting lane through its real matches(context):
--        PvE/PvP settings, target power type (mana only), the 30% target-HP
--        threshold, debuff-overlap refresh (remains <= 2), the PvP class
--        whitelist, and spell readiness.
-- WHEN:  During rotation battery execution (run_rotation_tests.lua).
-- WHY:   TBC/vanilla-era parity pass (2026-09-06): the middleware ViperSting
--        lane had no behavioral pin; BM's own sting lane only handles serpent.
-- SAFETY: Pure unit tests with a mocked NS; the real middleware_sylvanas.lua
--         and its real shared-module requires load.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

-- Mutable scenario state.
local combat = false
local has_target = true
local is_pvp = false
local power_type = 0          -- 0 = MANA
local target_class = "MAGE"
local target_hp = 50
local viper_remains = 0       -- 0 = no debuff
local viper_up = false
local settings = {}
local not_ready = {}
local pve = true
local pvp = true

local captured

local function reset_env()
    combat, has_target, is_pvp = true, true, false
    power_type, target_class, target_hp = 0, "MAGE", 50
    viper_remains, viper_up = 0, false
    settings, not_ready = {}, {}
    pve, pvp = true, true
end

_G.EaxRotations = {
    HunterSpells = {
        SilencingShot = 34490, ScatterShot = 19503, FeignDeath = 5384,
        ViperSting = 27018, FreezingTrap = 1499, RapidFire = 3045,
        MendPet = 27046, RevivePet = 1515, CallPet = 883, HuntersMark = 27019,
        AspectOfTheHawk = 13165, AspectOfTheViper = 34074,
    },
    register_class_middleware = function(key, strategies) captured = strategies end,
    spell_ready = function(spell, target, opts)
        local id = type(spell) == "number" and spell or (spell and (spell.id or spell[1])) or 0
        if not_ready[id] then return false end
        return true
    end,
    is_spell_learned = function() return true end,
    debuff_up = function(target, id)
        return viper_up and id == 27018
    end,
    debuff_remains = function(target, id)
        return viper_remains
    end,
    log = function() end,
    time_now = function() return 100 end,
    rotation_registry = { register = function() end },
}

local result = dofile("EaxRotations/classes/hunter/middleware_sylvanas.lua")
assert_true(captured, "middleware should register class strategies")
assert_true(result == captured or result ~= nil, "middleware returns its strategies")

local function find_strategy(name)
    for i = 1, #captured do
        if captured[i].name == name then return captured[i] end
    end
    error("strategy not found: " .. name)
end

local viper = find_strategy("ViperSting")

local function scenario(label, expect)
    local ctx = {
        in_combat = combat,
        has_valid_enemy_target = has_target,
        is_pvp = is_pvp,
        target_hp = target_hp,
        settings = {
            use_viper_sting_pve = pve,
            use_viper_sting_pvp = pvp,
        },
        target = {
            get_power_type = function() return power_type end,
            get_class = function() return target_class end,
        },
        me = {},
    }
    local matched = viper.matches(ctx)
    if expect then
        assert_true(matched, label .. " should match")
    else
        assert_false(matched, label .. " should NOT match")
    end
end

local function assert_lane(label, setup, expect)
    reset_env()
    setup()
    scenario(label, expect)
end

-- ============================================================================
-- Register-level proof: the class middleware owns a live ViperSting lane.
-- ============================================================================
assert_true(find_strategy("HuntersMark") ~= nil, "middleware also registers Hunter's Mark")
assert_true(find_strategy("ThreatDrop") ~= nil, "middleware also registers ThreatDrop")

-- ============================================================================
-- Fire side: in combat, valid enemy target, mana user, healthy target.
-- ============================================================================
assert_lane("ViperSting fires in combat on a mana-using target",
    function() end, true)
assert_lane("ViperSting fires when the PvE setting is the only one on",
    function() pvp = false end, true)

-- ============================================================================
-- Don't-fire sides.
-- ============================================================================
assert_lane("ViperSting held when both settings are off",
    function() pve = false; pvp = false end, false)
assert_lane("ViperSting held out of combat",
    function() combat = false end, false)
assert_lane("ViperSting held without a valid enemy target",
    function() has_target = false end, false)
assert_lane("ViperSting held on a non-mana target (rage user)",
    function() power_type = 1 end, false)
assert_lane("ViperSting held on a low-HP target (nothing left to drain value)",
    function() target_hp = 29 end, false)
assert_lane("ViperSting fires at the 30% HP threshold boundary",
    function() target_hp = 30 end, true)
assert_lane("ViperSting held while a fresh Viper debuff is live",
    function() viper_up = true; viper_remains = 3 end, false)
assert_lane("ViperSting refreshes when the live debuff is at 2s",
    function() viper_up = true; viper_remains = 2 end, true)
assert_lane("ViperSting held on cooldown",
    function() not_ready[27018] = true end, false)
assert_lane("ViperSting held in PvE when only the PvP setting is on",
    function() pve = false end, false)

-- PvP class whitelist (only mana-using classes get drained in PvP).
assert_lane("ViperSting fires on a whitelisted PvP class",
    function() is_pvp = true; target_class = "MAGE" end, true)
assert_lane("ViperSting held on a non-whitelisted PvP class",
    function() is_pvp = true; target_class = "WARRIOR" end, false)
assert_lane("ViperSting held in PvP when the PvP setting is off",
    function() is_pvp = true; pvp = false end, false)

print("PASS test_hunter_middleware_viper_sting")
