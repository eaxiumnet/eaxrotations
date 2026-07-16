-- test_assassination_vanilla_strategies.lua — Assassination Vanilla strategy match coverage.
-- WHAT:  Exercises SliceAndDice / RuptureBleed / EviscerateFallback combo gates.
-- WHEN:  During rotation test suite execution.
-- WHY:  Scorecard gap: dedicated strategy tests for rogue assassination vanilla.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    RogueSpells = {
        Ambush = 8676, Backstab = 53, Blind = 2094, CheapShot = 1833,
        ColdBlood = 14177, Evasion = 5277, Eviscerate = 2098, ExposeArmor = 8647,
        Feint = 1966, Garrote = 703, Kick = 1766, KidneyShot = 408,
        Rupture = 1943, Sap = 6770, SinisterStrike = 1752, SliceAndDice = 5171,
        Sprint = 2983, Stealth = 1784, ThistleTea = 7676, Vanish = 1856,
    },
    PLAYER_UNIT = "player",
    GetPlayer = function() return nil end,
    spell_action = function(ids) return type(ids) == "table" and ids[1] or ids end,
    spell_ready = function() return true end,
    spell_exists = function() return true end,
    try_cast = function() return true end,
    buff_up = function() return false end,
    buff_remains = function() return 0 end,
    debuff_up = function() return false end,
    debuff_remains = function() return 0 end,
    is_vanilla = function() return true end,
    is_item_ready = function() return false end,
    time_now = function() return 0 end,
    setting = function(ctx, key, default)
        local s = ctx and ctx.settings
        if s and s[key] ~= nil then return s[key] end
        return default
    end,
    log = function() end,
    rotation_registry = { register = function() end },
    OffensiveDispelDB = { find_best_dispel_target = function() return nil end },
}

package.loaded["shared/potion_helper_sylvanas"] = {
    try_use_potion = function() return false end,
    HEALTH_POTION_IDS = {}, DAMAGE_POTION_IDS = {},
}
package.loaded["shared/offensive_dispel_sylvanas"] = {
    find_best_dispel_target = function() return nil end,
}
package.loaded["shared/tbc_data_sylvanas"] = {
    ITEMS = { healthstones = {}, potions = {} },
}

local result = dofile("EaxRotations/classes/rogue/assassination_vanilla.lua")
local strategies = (type(result) == "table" and result.strategies) or result
assert_true(type(strategies) == "table" and #strategies > 0, "assassination strategies load")
assert_true(type(result.build_state) == "function", "assassination exports build_state")

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    error("strategy not found: " .. name)
end

local snd = find("SliceAndDice")
local rupture = find("RuptureBleed")
local evis = find("EviscerateFallback")

assert_false(snd.matches({ settings = {} }, { slice_dice_active = true, snd_needs_refresh = false, combo = 5 }),
    "SliceAndDice must not match when active and not needing refresh")
assert_false(snd.matches({ settings = {} }, { slice_dice_active = false, combo = 1 }),
    "SliceAndDice must not match below 2 combo")
assert_true(snd.matches({ settings = {} }, { slice_dice_active = false, combo = 3 }),
    "SliceAndDice matches with 2+ combo when down")

assert_false(rupture.matches({ target = {}, settings = {} }, { combo = 3, rupture_remains = 0, energy_pool_finisher = false }),
    "Rupture must not match below 4 combo")
assert_false(rupture.matches({ target = {}, settings = {} }, { combo = 5, rupture_remains = 10, energy_pool_finisher = false }),
    "Rupture must not match when remains high")
assert_true(rupture.matches({ target = {}, settings = {} }, { combo = 5, rupture_remains = 0, energy_pool_finisher = false }),
    "Rupture matches at 4+ combo when missing")

assert_false(evis.matches({ target = {}, settings = {} }, { combo = 3, energy_pool_finisher = false }),
    "EviscerateFallback must not match below 5 combo")
assert_true(evis.matches({ target = {}, settings = {} }, { combo = 5, energy_pool_finisher = false }),
    "EviscerateFallback matches at 5 combo")

print("PASS test_assassination_vanilla_strategies")
