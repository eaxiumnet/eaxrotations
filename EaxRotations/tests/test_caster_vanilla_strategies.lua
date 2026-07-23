-- test_caster_vanilla_strategies.lua — Druid Caster Vanilla strategy coverage.
-- WHAT:  Exercises Starfire, self-heals, MotW, Moonfire refresh, context gates.
-- WHEN:  During rotation test suite execution.
-- WHY:   Scorecard gap: caster_vanilla features/tests were low.
-- SAFETY: Pure unit tests with mocked NS; no live game data.

package.path = "EaxRotations/?.lua;EaxRotations/?/?.lua;EaxRotations/?/?/?.lua;./?.lua;api/?.lua;api/?/?.lua;" .. package.path

local function assert_true(v, label) if not v then error(label or "assert_true failed", 2) end end
local function assert_false(v, label) if v then error(label or "assert_false failed", 2) end end

_G.EaxRotations = {
    DruidSpells = {
        Barkskin = 22812, FaerieFire = 770, Innervate = 29166, Moonfire = 8921,
        Starfire = 2912, Wrath = 5176, InsectSwarm = 5570, HealingTouch = 5185,
        Rejuvenation = 774, MarkOfTheWild = 1126, Thorns = 467,
    },
    PLAYER_UNIT = {},
    GetPlayer = function() return {} end,
    spell_ready = function() return true end,
    spell_action = function(ids, name) return { id = function() return type(ids) == "table" and ids[1] or ids end, name = name } end,
    try_cast = function() return true end,
    debuff_remains = function() return 0 end,
    buff_up = function() return false end,
    has_player_buff = function() return false end,
    broken_api_throttled = function() return false end,
    should_use_long_cd = function() return true end,
    log = function() end,
    rotation_registry = { register = function() end },
}

package.loaded["shared/spec_kit_sylvanas"] = {
    merge_state = dofile("EaxRotations/tests/spec_kit_merge_state.lua").merge_state,
    setting = function(_, _, d) return d end,
    setting_bool = function(_, _, d) return d end,
    setting_number = function(_, _, d) return d end,
    define_action_for_class = function(SPELLS)
        return function(name, ids)
            if SPELLS and SPELLS[name] ~= nil then return SPELLS[name] end
            return type(ids) == "table" and ids[1] or ids
        end
    end,
    safe_state = function(s) return s end,
}
package.loaded["shared/leveling_helpers_sylvanas"] = {
    is_low_level = function(level) return (level or 60) < 20 end,
}
package.loaded["shared/potion_helper_sylvanas"] = {
    HEALTH_POTION_IDS = { 13446 },
    MANA_POTION_IDS = { 13444 },
    try_use_potion = function() return false end,
}

local mod = dofile("EaxRotations/classes/druid/caster_vanilla.lua")
local strategies = mod.strategies or mod
assert_true(type(strategies) == "table" and #strategies >= 10, ">=10 strategies, got " .. tostring(#strategies))

local function find(name)
    for i = 1, #strategies do
        if strategies[i].name == name then return strategies[i] end
    end
    return nil
end

for _, name in ipairs({
    "Barkskin", "HealingTouch", "Rejuvenation", "MarkOfTheWild", "Thorns",
    "Innervate", "FaerieFire", "Moonfire", "InsectSwarm", "Starfire", "Wrath",
    "ManaPotion", "HealthPotion",
}) do
    assert_true(find(name) ~= nil, "strategy present: " .. name)
end

local starfire = find("Starfire")
assert_true(starfire.matches({
    is_solo = true, is_moving = false, target = {},
}, { level = 60, mana_pct = 50 }), "Starfire matches stationary solo")
assert_false(starfire.matches({
    is_solo = true, is_moving = true, target = {},
}, { level = 60, mana_pct = 50 }), "Starfire blocked while moving")

local ht = find("HealingTouch")
assert_true(ht.matches({
    is_solo = true, is_moving = false,
}, { hp_pct = 30, mana_pct = 50 }), "HealingTouch at low HP")
assert_false(ht.matches({
    is_solo = true, is_moving = false,
}, { hp_pct = 80, mana_pct = 50 }), "HealingTouch skips high HP")

local motw = find("MarkOfTheWild")
assert_true(motw.matches({
    is_solo = true, in_combat = false,
}, { has_motw = false }), "MotW OOC")
assert_false(motw.matches({
    is_solo = true, in_combat = true,
}, { has_motw = false }), "MotW skips combat")

local moonfire = find("Moonfire")
assert_true(moonfire.matches({
    is_solo = true, target = {},
}, { moonfire_remains = 0 }), "Moonfire when missing")
assert_false(moonfire.matches({
    is_solo = true, target = {},
}, { moonfire_remains = 8 }), "Moonfire skips fresh DoT")

local build_state = mod.build_state
assert_true(type(build_state) == "function", "build_state exported")
local state = build_state({
    in_combat = true, is_solo = true, mana_pct = 40, hp = 70, target = {}, target_hp = 80,
})
assert_true((state.mana_pct or 0) == 40, "build_state mana")
assert_true((state.hp_pct or 0) == 70, "build_state hp_pct")

print("PASS test_caster_vanilla_strategies (" .. #strategies .. " strategies)")
