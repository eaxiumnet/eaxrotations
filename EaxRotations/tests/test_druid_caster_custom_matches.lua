-- behavior tests for Druid Caster leveling/solo gates.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    DruidSpells = {
        Wrath = 5176,
        Moonfire = 8921,
        FaerieFire = 770,
        Innervate = 29166,
        Barkskin = 22812,
        Thorns = 467,
    },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    debuff_remains = function() return 0 end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

local strategies = dofile("EaxRotations/classes/druid/caster_sylvanas.lua")
assert_true(strategies, "caster strategies should load")

local function find_strategy(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local wrath = find_strategy("Wrath")
local moonfire = find_strategy("Moonfire")

assert_true(wrath.matches({ is_leveling = true, is_moving = false, target = {}, settings = {} }, {}), "Wrath should run while leveling")
assert_true(moonfire.matches({ is_solo = true, target = {}, settings = {} }, { moonfire_remains = 0 }), "Moonfire should run while solo")
assert_false(wrath.matches({ is_raid = true, is_moving = false, target = {}, settings = {} }, {}), "Wrath should not run in raid without explicit caster selection")
assert_false(moonfire.matches({ is_pvp = true, target = {}, settings = {} }, { moonfire_remains = 0 }), "Moonfire should not run in PvP without explicit caster selection")
assert_true(wrath.matches({ is_raid = true, active_playstyle = "caster", is_moving = false, target = {}, settings = {} }, {}), "Wrath should run in raid when caster is explicitly selected")
assert_true(moonfire.matches({ is_pvp = true, target = {}, settings = { playstyle = "caster" } }, { moonfire_remains = 0 }), "Moonfire should run in PvP when caster is explicitly selected")

print("PASS test_druid_caster_custom_matches")
