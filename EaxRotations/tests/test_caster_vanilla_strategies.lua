-- test_caster_vanilla_strategies.lua — Vanilla druid caster strategy gates.
-- WHAT:  Starfire/HealingTouch/Moonfire match coverage for caster_vanilla.
-- WHEN:  rotation suite.
-- WHY:  closes features gap on low-scoring caster vanilla (overall was 3).
-- SAFETY: synthetic NS mock; no live game.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;./?.lua;api/?.lua;" .. package.path

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
        Starfire = 2912,
        HealingTouch = 5185,
    },
    PLAYER_UNIT = {},
    spell_ready = function() return true end,
    debuff_remains = function() return 0 end,
    try_cast = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    setting = function(ctx, key, fallback)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return fallback
    end,
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    is_low_level = function() return false end,
}

local result = dofile("EaxRotations/classes/druid/caster_vanilla.lua")
local strategies = result.strategies or result
assert_true(type(strategies) == "table", "strategies table")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("missing strategy: " .. name)
end

local starfire = find("Starfire")
local ht = find("HealingTouch")
local moonfire = find("Moonfire")
local barkskin = find("Barkskin")

assert_true(starfire.matches({ is_solo = true, is_moving = false, target = {} }, {}), "Starfire when stationary solo")
assert_false(starfire.matches({ is_solo = true, is_moving = true, target = {} }, {}), "Starfire blocked while moving")
assert_true(ht.matches({ is_solo = true, is_moving = false, hp = 30 }, { hp_pct = 30 }), "HT at low HP")
assert_false(ht.matches({ is_solo = true, is_moving = false, hp = 80 }, { hp_pct = 80 }), "HT skipped when healthy")
assert_true(moonfire.matches({ is_solo = true, target = {} }, { moonfire_remains = 0 }), "Moonfire when missing")
assert_false(moonfire.matches({ is_solo = true, target = {} }, { moonfire_remains = 5 }), "Moonfire skipped when up")
assert_true(barkskin.matches({ is_solo = true, hp = 40 }, {}), "Barkskin at low HP")
assert_false(barkskin.matches({ is_solo = true, hp = 90 }, {}), "Barkskin skipped when healthy")

print("PASS test_caster_vanilla_strategies")
